import time
import datetime
import gc
import socket
import copy
import pickle
import logging
from collections import Counter
from typing import FrozenSet, Union, Iterable, Optional

import argparse
import pennylane as qml
import numpy as np
import pennylane.qchem as qchem
import pennylane.numpy as pnp
import json
import os
from pennylane import QueuingManager, QuantumFunctionError, QubitDevice
from pennylane.tape import QuantumTape, QuantumScript
from pennylane.measurements import (
    Expectation,
    MeasurementTransform,
    Probability,
    Sample,
    ShadowExpvalMP,
    State,
    Variance,
)

from braket.pennylane_plugin.braket_device import BraketQubitDevice, BraketLocalQubitDevice
from braket.pennylane_plugin.translation import (
    get_adjoint_gradient_result_type,
    supported_operations,
    translate_operation,
    translate_result,
    translate_result_type,
)
from braket.circuits import Circuit, Gate, Noise, Observable
from braket.circuits.noise_model import (
    GateCriteria,
    NoiseModel,
    ObservableCriteria,
    QubitInitializationCriteria,
)
from braket.circuits.noises import (
    AmplitudeDamping,
    BitFlip,
    Depolarizing,
    PauliChannel,
    PhaseDamping,
    PhaseFlip,
    TwoQubitDepolarizing,
)
import braket.ir.jaqcd.results
from braket.task_result import (
    AdditionalMetadata,
    ResultTypeValue,
    TaskMetadata,
    GateModelTaskResult,
)
from braket.task_result.simulator_metadata_v1 import SimulatorMetadata
from braket.tasks.local_quantum_task import LocalQuantumTask
from braket.devices import LocalSimulator
from braket.tasks import GateModelQuantumTaskResult

import juliacall
import juliapkg
Main = None

def init_julia(julia_project=None, quiet=False, julia_kwargs=None):
    global Main
    from juliacall import Main as _Main
    Main = _Main
    return Main

def _translate_rt(jl_rt):
    if str(jl_rt.type) == "expectation":
        return braket.ir.jaqcd.results.Expectation(targets=[t for t in jl_rt.targets], observable=[str(o) for o in jl_rt.observable])
    elif str(jl_rt.type) == "variance": 
        return braket.ir.jaqcd.results.Variance(targets=[t for t in jl_rt.targets], observable=[str(o) for o in jl_rt.observable])
    elif str(jl_rt.type) == "sample": 
        return braket.ir.jaqcd.results.Sample(targets=[t for t in jl_rt.targets], observable=[str(o) for o in jl_rt.observable])
    

def _translate_value(jl_v):
    if isinstance(jl_v, juliacall.VectorValue):
        return [v for v in jl_v]
    elif isinstance(jl_v, float):
        return jl_v
    elif isinstance(jl_v, juliacall.DictValue):
        return {str(k):v for (k,v) in jl_v.items()}

class JuliaQubitDevice(BraketLocalQubitDevice):
    name = "Julia device for PennyLane"
    short_name = "julia.qubit"
    pennylane_requires = ">=0.18.0"
    version = "0.0.1" 
    author = "Amazon Web Services"

    supported_ops = {
        "Identity",
        "BasisState",
        "QubitStateVector",
        "StatePrep",
        "QubitUnitary",
        "ControlledQubitUnitary",
        "MultiControlledX",
        "DiagonalQubitUnitary",
        "PauliX",
        "PauliY",
        "PauliZ",
        "MultiRZ",
        "Hadamard",
        "S",
        "Adjoint(S)",
        "T",
        "Adjoint(T)",
        "SX",
        "Adjoint(SX)",
        "CNOT",
        "SWAP",
        "ISWAP",
        "PSWAP",
        "CSWAP",
        "Toffoli",
        "CY",
        "CZ",
        "PhaseShift",
        "ControlledPhaseShift",
        "CPhase",
        "RX",
        "RY",
        "RZ",
        "Rot",
        "CRX",
        "CRY",
        "CRZ",
        "C(PauliX)",
        "C(PauliY)",
        "C(PauliZ)",
        "C(Hadamard)",
        "C(S)",
        "C(T)",
        "C(PhaseShift)",
        "C(RX)",
        "C(RY)",
        "C(RZ)",
        "C(SWAP)",
        "C(IsingXX)",
        "C(IsingXY)",
        "C(IsingYY)",
        "C(IsingZZ)",
        "C(SingleExcitation)",
        "C(DoubleExcitation)",
        "CRot",
        "IsingXX",
        "IsingYY",
        "IsingZZ",
        "IsingXY",
        "SingleExcitation",
        "DoubleExcitation",
        "ECR",
    } 

    def __init__(
        self,
        wires: Union[int, Iterable],
        device: str,
        *,
        shots: Union[int, None] = 0,
        parallel: bool = True,
        noise_model: Optional[NoiseModel] = None,
        parametrize_differentiable: bool = False,
        **run_kwargs,
    ):
        self._wires = range(wires) if isinstance(wires, int) else wires
        self.num_wires = wires if isinstance(wires, int) else len(wires)
        self._wire_map = self.define_wire_map(self._wires)
        self._device = Main.LocalSimulator(device)
        self._device_name = device
        self.tracker = qml.Tracker()
        self.shots = shots
        self._noise_model = noise_model
        self._run_kwargs = run_kwargs
        self._circuit = None
        self._task = None
        self._parametrize_differentiable = parametrize_differentiable
        self._parallel = parallel
        self.custom_expand_fn = None
        self._run_kwargs = run_kwargs
        #self._supported_ops = supported_operations(LocalSimulator(device)) 
        self._check_supported_result_types()
        self._verbatim = False

    @property
    def parallel(self):
        return self._parallel

    @property
    def operations(self):
        return self.supported_ops

    @property
    def stopping_condition(self):

        def accepts_obj(obj):
            if obj.name == "QFT" and len(obj.wires) < 10:
                return True
            if obj.name == "GroverOperator" and len(obj.wires) < 13:
                return True
            return (not isinstance(obj, qml.tape.QuantumTape)) and getattr(
                self, "supports_operation", lambda name: False
            )(obj.name)

        return qml.BooleanFn(accepts_obj)

    def _check_supported_result_types(self):
        supported_result_types = Main.properties(self._device._delegate).action[
            "braket.ir.openqasm.program"
        ].supportedResultTypes
        self._braket_result_types = frozenset(
            result_type.name for result_type in supported_result_types
        )
    
    def classical_shadow(self, obs, circuit):
        if circuit is None:  # pragma: no cover
            raise ValueError("Circuit must be provided when measuring classical shadows")
        mapped_wires = np.array(self.map_wires(obs.wires))
        to_pass = QuantumScript(ops=circuit.operations)
        outcomes, recipes = Main.classical_shadow(self._device, mapped_wires, to_pass, self.shots, obs.seed)
        return self._cast(self._stack([outcomes, recipes]), dtype=np.int8)
    
    def classical_shadow_batch(self, circuits):
        for circuit in circuits:
            if circuit is None:  # pragma: no cover
                raise ValueError("Circuit must be provided when measuring classical shadows")
        mapped_wires = [np.array(self.map_wires(circuit.observables[0].wires)) for circuit in circuits]
        to_pass = [QuantumScript(ops=c.operations) for c in circuits]
        all_outcomes, all_recipes = Main.classical_shadow(self._device, mapped_wires, to_pass, self.shots, [circuit.observables[0].seed for circuit in circuits])
        return [self._cast(self._stack([outcomes, recipes]), dtype=np.int8) for (outcomes, recipes) in zip(all_outcomes, all_recipes)]

    def execute(self, circuit: QuantumTape, compute_gradient=False, **run_kwargs) -> np.ndarray:
        self.check_validity(circuit.operations, circuit.observables)
        trainable = (
            BraketQubitDevice._get_trainable_parameters(circuit)
            if compute_gradient or self._parametrize_differentiable
            else {}
        )

        if not isinstance(circuit.measurements[0], MeasurementTransform):
            shots = 0 if self.analytic else self.shots
            result = self._device(circuit, {f"p_{k}": v for k, v in trainable.items()}, shots=shots)
            if self.tracker.active:
                tracking_data = self._tracking_data(self._task)
                self.tracker.update(executions=1, shots=self.shots, **tracking_data)
                self.tracker.record()
            if len(circuit.measurements) == 1:
                return np.array(result).squeeze()
            return tuple(np.array(r).squeeze() for r in result)
        
        elif isinstance(circuit.measurements[0], ShadowExpvalMP):
            if len(circuit.observables) > 1:
                raise ValueError(
                    "A circuit with a ShadowExpvalMP observable must "
                    "have that as its only result type."
                )
            return [self.shadow_expval(circuit.measurements[0], circuit)]
        raise RuntimeError("The circuit has an unsupported MeasurementTransform.")
   
    def shadow_expval_batch(self, circuits):
        all_results = self.classical_shadow_batch(circuits)
        all_expvals = []
        for (circuit, (bits, recipes)) in zip(circuits, all_results):
            obs = circuit.measurements[0]
            shadow = qml.shadows.ClassicalShadow(bits, recipes, wire_map=obs.wires.tolist())
            all_expvals.append(shadow.expval(obs.H, obs.k))
        return all_expvals 

    def batch_execute(self, circuits, **run_kwargs):
        print(f"\tEntering Julia segment at: {datetime.datetime.now()}.", flush=True)
        print(f"\tComputing batch with {len(circuits)} elements.", flush=True)
        if not self._parallel:
            return super().batch_execute(circuits)

        if all(isinstance(circuit.observables[0], ShadowExpvalMP) for circuit in circuits):
            return self.shadow_expval_batch(circuits)

        for circuit in circuits:
            self.check_validity(circuit.operations, circuit.observables)
        
        all_trainable = []
        for circuit in circuits:
            trainable = (
                BraketQubitDevice._get_trainable_parameters(circuit)
                if self._parametrize_differentiable
                else {}
            )
            all_trainable.append(trainable)

        batch_shots = 0 if self.analytic else self.shots
        print("\tBegin Julia processing.")
        start = time.time()
        inputs = [{f"p_{k}": v for k, v in trainable.items()} for trainable in all_trainable]
        jl_results = self._device(circuits, inputs, shots=batch_shots)
        pl_results = []
        for (circ, jl_r) in zip(circuits, jl_results):
            if len(circ.measurements) == 1:
                pl_results.append(np.array(jl_r).squeeze())
            else:
                pl_results.append(tuple(np.array(r).squeeze() for r in jl_r))
        stop = time.time()
        print(f"\tJulia time to compute batch: {stop-start}.", flush=True)
        print(f"\tExiting Julia segment at: {datetime.datetime.now()}.", flush=True)
        return pl_results 

def noise_model():
    m = NoiseModel()
    m.add_noise(Depolarizing(1 - 0.9981), GateCriteria())
    m.add_noise(TwoQubitDepolarizing(1 - 0.9311), GateCriteria(gates=Gate.CNot))
    m.add_noise(BitFlip(1 - 0.99752), ObservableCriteria(observables=Observable.Z))
    return m

def get_julia_device(n_wires: int, shots, noise: bool = False):
    default_dev = "braket_dm" if noise else "braket_sv"
    nm = noise_model() if noise else None

    return JuliaQubitDevice(n_wires, default_dev, shots=shots, noise_model=nm)

def get_python_device(n_wires: int, shots, noise: bool = False):
    default_dev = "braket_dm" if noise else "braket_sv"
    nm = noise_model() if noise else None

    return qml.device("braket.local.qubit", backend=default_dev, wires=n_wires, shots=shots, noise_model=nm)

def get_lightning_device(n_wires: int, shots, noise: bool = False):
    return qml.device("lightning.qubit", wires=n_wires, shots=shots)

def get_touched_qubits(ex):
    return set().union(ex)

def run_adapt(
    circ,
    excitation_pool,
    opt,
    E,
    cutoff: float,
    n_wires: int,
    max_adapt_iter: int,
    max_opt_iter: int,
    key: dict,
    previous_progress: dict = {},
    drain_pool: bool = False,
):
    selected_excitations = previous_progress.get("excitations", [])
    selected_params = previous_progress.get("params", [])
    adapt_iter = previous_progress.get("adapt_iter", 0)
    prev_E_estimate = 1e5
    E_estimate = 1e6
    gradient_circ = qml.grad(circ, argnum=0)
    progress_tracker = {}
    mol = key["mol"]
    protocol = key["protocol"]
    shot = key["shots"]
    noise = key["noise"]
    while adapt_iter < max_adapt_iter and len(excitation_pool) > 0:
        # compute initial gradients
        progress_tracker[adapt_iter] = {} 
        params = [0.0]*len(excitation_pool)
        start = time.time()
        print(f"Compute gradients for {key} at iter {adapt_iter}", flush=True)
        ex_grad = gradient_circ(params, excitation_pool, selected_params, selected_excitations)
        #ex_grad = [0.0]*len(excitation_pool)
        #for ix in range(len(excitation_pool)):
        #    g_start = time.time()
        #    ex_grad[ix] = gradient_circ([params[ix]], [excitation_pool[ix]], selected_params, selected_excitations)
        #    g_stop = time.time()
        #    print(f"Done computing {ix}-th gradient. Duration: {g_stop-g_start}.", flush=True)
        stop = time.time()
        print(f"Done computing gradients. Duration: {stop-start}.", flush=True)
        grads = [
            -abs(ex_grad[ix].numpy())
            if isinstance(ex_grad[ix], pnp.tensor)
            else -abs(ex_grad[ix])
            for ix in range(len(ex_grad))
        ]

        # sort excitations by gradient magnitude
        sorted_inds = pnp.argsort(grads)
        select_this_round = [sorted_inds[0].numpy()]
        progress_tracker[adapt_iter]["largest_grad"] = abs(grads[sorted_inds[0]])
        # need to handle qubits properly here!
        touched_qubits = get_touched_qubits(excitation_pool[select_this_round[0]])
        progress_tracker[adapt_iter]["touched_qubits"] = touched_qubits
        opt_ex = [excitation_pool[ix] for ix in select_this_round]
        opt_params = [0.0 for ix in select_this_round]
        start = time.time()
        print(f"Begin optimization for {key} at iter {adapt_iter}")
        # do one round of optimization
        for n in range(max_opt_iter):
            opt_params_tensor = pnp.tensor(opt_params)
            opt_params_tensor = opt.step(
                circ,
                opt_params_tensor,
                opt_ex,
                selected_params,
                selected_excitations,
            )
            opt_params = opt_params_tensor[0].numpy().tolist()
        stop = time.time()
        print(f"Complete optimization for {key} at iter {adapt_iter}. Duration: {stop-start}.")
        # get final energy from this optimization round
        E_estimate = circ(opt_params, opt_ex, selected_params, selected_excitations)
        # now add selected excitations to the Ansatz
        selected_excitations.extend([excitation_pool[ix] for ix in select_this_round])
        selected_params.extend(opt_params)
        print(f"Largest grad: {grads[select_this_round[0]]}, E_estimate: {E_estimate}, Error: {np.abs(E_estimate-E)} at iteration {adapt_iter} for {key}")
        progress_tracker[adapt_iter]["E_estimate"] = E_estimate 
        progress_tracker[adapt_iter]["E_error"] = abs(E_estimate-E)

        qsm = circ.tape.to_openqasm()
        progress_tracker[adapt_iter]["circuit_qasm"] = qsm
        progress_tracker[adapt_iter]["params"] = selected_params
        progress_tracker[adapt_iter]["excitations"] = selected_excitations 

        with open(os.path.join(os.getenv("HOME"), f"vqe_{mol}_{protocol}_{shot}_{noise}_{adapt_iter}.pickle"), 'wb') as fi:
            pickle.dump(progress_tracker[adapt_iter], fi)
        if abs(grads[sorted_inds[0]]) <= cutoff:
            break
        prev_E_estimate = E_estimate
        adapt_iter += 1

    return progress_tracker

Main = init_julia()
#juliapkg.add("Braket", "19504a0f-b47d-4348-9127-acc6cc69ef67", dev=True, path="/Users/hyatkath/.julia/dev/Braket")
#juliapkg.add("BraketStateVector", "4face768-c059-465f-83fa-0d546ea16c1e", dev=True, path="/Users/hyatkath/.julia/dev/Braket/BraketStateVector")
Main.seval('using Pkg; Pkg.activate("."); Pkg.resolve()')
Main.seval('using Braket, BraketStateVector, JSON3, PythonCall')
Main.seval('Braket.IRType[] = :JAQCD')

parser = argparse.ArgumentParser(description='Options for VQE circuit simulation.')
parser.add_argument("--shot", type=int, default=100)
parser.add_argument("--protocol", type=str, default="qwc")
parser.add_argument("--mol", type=str, default="H4")
parser.add_argument('--noise', dest='noise', action='store_true')
parser.add_argument('--no-noise', dest='noise', action='store_false')
parser.add_argument('--prevprog', type=str, default="")
parser.add_argument('--use-python', dest='use_python', action='store_true')
parser.set_defaults(noise=False)
parser.set_defaults(use_python=False)
args = parser.parse_args()

previous_progress = {}
if args.prevprog:
    with open(args.prevprog, 'rb') as fi:
        prev_data = pickle.load(fi)

    file_name = os.path.basename(args.prevprog)

    previous_progress['excitations'] = prev_data['excitations']
    previous_progress['params'] = prev_data['params']
    # figure out adapt_iter
    suffix = file_name.split('_')[-1]
    adapt_iter = int(suffix.split('.')[0]) + 1
    previous_progress['adapt_iter'] = adapt_iter

grad_cutoff = 1e-5
stepsize = 0.5
n_iter = 20
spsa_iter = 10
adapt_iter = 1
cutoff = 1e-3
diff_method = "parameter-shift"
encoding = "jordan_wigner"
bond_lengths = {"H2": 0.7, "H4": 0.8, "H6": 0.8, "H8": 0.8, "H10": 1.0, "LiH": 1.71}

shot = args.shot
protocol = args.protocol
mol = args.mol
noise = args.noise
use_python = args.use_python
#output_file = args.output

datasets = qml.data.load("qchem", molname=mol, basis="STO-3G", bondlength=bond_lengths[mol])
dset = datasets[0]
E = dset.fci_energy
molecule = dset.molecule
n_electrons = molecule.n_electrons
n_orbitals = molecule.n_orbitals
H = dset.hamiltonian
#H, qubits = qml.qchem.molecular_hamiltonian(
#    molecule.symbols,
#    molecule.coordinates,
#    basis=molecule.basis_name,
#    active_electrons=n_electrons,
#    active_orbitals=n_orbitals,
#    mapping=encoding,
#    method="pyscf",
#)
qubits = len(H.wires)
hf_state = dset.hf_state
print(hf_state, flush=True)
scaled_shot = shot
coeffs, obs = H.coeffs, H.ops
H_qwc = qml.Hamiltonian(coeffs, obs, grouping_type="qwc")
#H.grouping_indices = dset.qwc_groupings
#H_qwc = H
n_groups = len(H_qwc.grouping_indices)
all_exs = []
# number of up- and down-spin electrons
singles, doubles = qchem.excitations(n_electrons, qubits)
all_exs = doubles + singles

if protocol == "qwc":
    H = H_qwc 
else: # figure out how many groups there are and scale shots
    scaled_shot = shot * n_groups
            
print("FCI energy:", dset.fci_energy, " VQE energy: ", dset.vqe_energy)
print(f"Number of qubits: {qubits}, number of groups: {n_groups}, number of excitations: {len(all_exs)}")
print(f"Running with protocol {protocol}, encoding {encoding}, molecule {mol}, shots {scaled_shot}, noise {noise}, n_qubits {qubits}:", flush=True)
#dev = get_python_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
dev = get_lightning_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
opt = qml.SPSAOptimizer(maxiter=n_iter)
                
@qml.qnode(dev, diff_method=diff_method)
def shadow_circuit(
    params, excitations, params_select, gates_select
):
    qml.BasisState(hf_state, wires=range(qubits))

    for i, gate in enumerate(gates_select):
        if len(gate) == 4:
            qml.DoubleExcitation(params_select[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params_select[i], wires=gate)

    for i, gate in enumerate(excitations):
        if len(gate) == 4:
            qml.DoubleExcitation(params[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params[i], wires=gate)
    return qml.shadow_expval(H)

@qml.qnode(dev, diff_method=diff_method)
def qwc_circuit(
    params, excitations, params_select, gates_select
):
    qml.BasisState(hf_state, wires=range(qubits))
    for i, gate in enumerate(gates_select):
        if len(gate) == 4:
            qml.DoubleExcitation(params_select[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params_select[i], wires=gate)

    for i, gate in enumerate(excitations):
        if len(gate) == 4:
            qml.DoubleExcitation(params[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params[i], wires=gate)
    return qml.expval(H)

circ = shadow_circuit if protocol == 'shadows' else qwc_circuit
key = {'mol': mol, 'noise': noise, 'protocol': protocol, 'shots': shot}

start = time.time()
result = run_adapt(
                    circ,
                    copy.deepcopy(all_exs),
                    opt,
                    E,
                    cutoff,
                    qubits,
                    adapt_iter,
                    n_iter,
                    key,
                    previous_progress,
                )

stop = time.time()
print(f'Simulation total duration: {stop-start}.')

key = key.update({"results": result})
with open(os.path.join(os.getenv("HOME"), f"vqe_{mol}_{protocol}_{shot}_{noise}.pickle"), 'wb') as fi:
    pickle.dump(key, fi)
