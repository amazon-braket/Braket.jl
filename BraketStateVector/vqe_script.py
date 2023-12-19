import time
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
from pennylane.tape import QuantumTape
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

    def __init__(
        self,
        wires: Union[int, Iterable],
        device: str,
        *,
        shots: Union[int, None] = 0,
        parallel: bool = True,
        noise_model: Optional[NoiseModel] = None,
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
        self._parallel = parallel
        self.custom_expand_fn = None
        self._run_kwargs = run_kwargs
        ls = LocalSimulator(device)
        self._supported_ops = supported_operations(ls) 
        #[str(op) for op in Main.BraketStateVector.supported_operations(self._device._delegate)]
        self._check_supported_result_types()
        self._verbatim = False
        self._parametrize_differentiable = False

    @property
    def parallel(self):
        return self._parallel

    @property
    def operations(self):
        return self._supported_ops
    
    def _run_snapshots(self, snapshot_circuits, n_qubits, mapped_wires):
        n_snapshots = len(snapshot_circuits)
        outcomes = np.zeros((n_snapshots, n_qubits))
        for t in range(n_snapshots):
            c = snapshot_circuits[t]
            task_result = run_circuit_nonremote(c, self._device, 1, self._noise_model)
            outcomes[t] = np.array(task_result.measurements[0])[mapped_wires]
        return outcomes
    
    def _check_supported_result_types(self):
        supported_result_types = Main.properties(self._device._delegate).action[
            "braket.ir.openqasm.program"
        ].supportedResultTypes
        self._braket_result_types = frozenset(
            result_type.name for result_type in supported_result_types
        )
    
    def _run_task(self, circuit, inputs=None):
        task_start = time.time()
        jaqcd_ir   = circuit._to_jaqcd().json()
        jl_circ    = Main.Circuit(Main.Braket.parse_raw_schema(jaqcd_ir))
        shot_count = 0 if self.analytic else self.shots
        jl_r = Main.result(self._device(jl_circ, shots=shot_count))
        task_mtd = TaskMetadata.parse_raw(Main.JSON3.write(jl_r.task_mtetadata))
        addl_mtd = AdditionalMetadata(simulatorMetadata=SimulatorMetadata(executionDuration=0))
        result_types = [ResultTypeValue.parse_raw(Main.JSON3.write(rtv)) for rtv in jl_r.result_types]
        py_r = GateModelQuantumTaskResult(task_metadata=task_mtd,
                                          additional_metadata=addl_mtd,
                                          result_types=result_types,
                                          #values=list(jl_r.values),
                                          measurements=[list(m) for m in jl_r.measurements],
                                          measured_qubits=list(jl_r.measured_qubits))
        t = LocalQuantumTask(GateModelQuantumTaskResult.from_object(py_r))
        task_stop = time.time()
        return t 
   
    def batch_execute(self, circuits, **run_kwargs):
        gc.disable()
        if not self._parallel:
            return super().batch_execute(circuits)

        if all(isinstance(circuit.observables[0], ShadowExpvalMP) for circuit in circuits):
            return [self.shadow_expval(circuit.observables[0], circuit) for circuit in circuits]

        for circuit in circuits:
            self.check_validity(circuit.operations, circuit.observables)
        braket_circuits = [self._pl_to_braket_circuit(circuit, **run_kwargs) for circuit in circuits]
        
        jl_start = time.time()
        #print("Begin Julia segment.", flush=True)
        start = time.time()
        jaqcd_progs     = [braket_circuit._to_jaqcd() for braket_circuit in braket_circuits]
        jaqcd_irs       = [jaqcd_prog.json() for jaqcd_prog in jaqcd_progs]
        stop = time.time()
        print(f"\tTranslation to JAQCD in: {stop-start}.", flush=True)

        start = time.time()
        braket_circuits = [Main.Braket.parse_raw_schema(jaqcd_ir) for jaqcd_ir in jaqcd_irs]
        stop = time.time()
        print(f"\tReload back to Julia complete in: {stop-start}.", flush=True)

        batch_shots = 0 if self.analytic else self.shots
        start = time.time()
        braket_jl_results_batch = Main.results(self._device(braket_circuits, shots=batch_shots))
        stop = time.time()
        print(f"\tJulia time to compute batch: {stop-start}.", flush=True) 
        start = time.time()
        measurements_time = 0.0
        tmtd_time = 0.0
        amtd_time = 0.0
        rtv_time  = 0.0
        val_time  = 0.0
        gtm_time  = 0.0
        braket_py_results_batch = []
        for (j_ix, jl_r) in enumerate(braket_jl_results_batch):
            r_start = time.time()
            task_mtd     = TaskMetadata(id=str(jl_r.task_metadata.id), shots=jl_r.task_metadata.shots, deviceId=str(jl_r.task_metadata.deviceId))
            r_stop = time.time()
            tmtd_time += r_stop - r_start
            #print(f"\tTime to translate task_metadata: {r_stop-r_start}.", flush=True)
            r_start = time.time()
            addl_mtd = AdditionalMetadata(action=jaqcd_progs[j_ix])
            r_stop = time.time()
            amtd_time += r_stop - r_start
            #print(f"\tTime to translate additional metadata: {r_stop-r_start}.", flush=True)
            r_start = time.time()
            # PROBLEM IS HERE
            result_types = [ResultTypeValue(type=_translate_rt(rtv.type), value=_translate_value(rtv.value)) for rtv in jl_r.result_types] 
            r_stop = time.time()
            #print(f"\tTime to translate result types: {r_stop-r_start}.", flush=True)
            rtv_time += r_stop - r_start
            
            r_start = time.time()
            #py_m = [[m_i for m_i in m] for m in jl_r.measurements]
            r_stop = time.time()
            #measurements_time += r_stop - r_start
            r_start = time.time()
            #values = [v for v in jl_r.values] 
            values = [_translate_value(jl_v) for jl_v in jl_r.values]
            r_stop = time.time()
            val_time += r_stop - r_start
            r_start = time.time()
            py_r = GateModelQuantumTaskResult(task_metadata=task_mtd,
                                              additional_metadata=addl_mtd,
                                              result_types=result_types,
                                              values = values,
                                              measured_qubits=list(jl_r.measured_qubits),
                                              #measurements=py_m,
                                              )
            r_stop = time.time()
            gtm_time += r_stop - r_start
            braket_py_results_batch.append(py_r)
        
        braket_results_batch = braket_py_results_batch
        stop = time.time()
        print(f"\tJulia time to translate batch results: {stop-start}.", flush=True)
        print(f"\tJulia time to translate measurements: {measurements_time}.", flush=True)
        print(f"\tJulia time to translate task_metadata: {tmtd_time}.", flush=True)
        print(f"\tJulia time to translate additional_metadata: {amtd_time}.", flush=True)
        print(f"\tJulia time to translate result types: {rtv_time}.", flush=True)
        print(f"\tJulia time to translate values: {val_time}.", flush=True)
        print(f"\tJulia time to build GateModelQuantumTaskResults: {gtm_time}.", flush=True)
        jl_stop = time.time()
        print(f"All around Julia time: {jl_stop-jl_start}.", flush=True)
        start = time.time()
        pl_results = [self._braket_to_pl_result(braket_result, circuit) for braket_result, circuit in zip(braket_results_batch, circuits)]
        stop = time.time()
        print(f"Time to translate results back to PL: {stop-start}.", flush=True)
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
        ex_grad = [0.0]*len(excitation_pool)
        for ix in range(len(excitation_pool)):
            g_start = time.time()
            ex_grad[ix] = gradient_circ([params[ix]], [excitation_pool[ix]], selected_params, selected_excitations)
            g_stop = time.time()
            print(f"Done computing {ix}-th gradient. Duration: {g_stop-g_start}.", flush=True)
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
#Main.seval('using Pkg; Pkg.activate("."); Pkg.resolve(); Pkg.instantiate()')
Main.seval('using Braket, BraketStateVector, JSON3')
Main.seval('Braket.IRType[] = :JAQCD')

parser = argparse.ArgumentParser(description='Options for VQE circuit simulation.')
parser.add_argument("--shot", type=int, default=100)
parser.add_argument("--protocol", type=str, default="qwc")
parser.add_argument("--mol", type=str, default="H8")
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
dev = get_python_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
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
