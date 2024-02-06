import juliacall
import juliapkg
jl = None

import numpy as np
import time
import datetime
from typing import FrozenSet, Union, Iterable, Optional

import pennylane as qml
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
from braket.devices import LocalSimulator

from braket.pennylane_plugin.braket_device import BraketQubitDevice, BraketLocalQubitDevice

def init_julia(julia_project=None, quiet=False, julia_kwargs=None):
    global jl
    from juliacall import Main as _Main
    jl = _Main
    return jl



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
        self._device = jl.LocalSimulator(device)
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
            return (not isinstance(obj, qml.tape.QuantumTape)) and getattr(
                self, "supports_operation", lambda name: False
            )(obj.name)

        return qml.BooleanFn(accepts_obj)

    def _check_supported_result_types(self):
        supported_result_types = jl.properties(self._device._delegate).action[
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
        outcomes, recipes = jl.classical_shadow(self._device, mapped_wires, to_pass, self.shots, obs.seed)
        return self._cast(self._stack([outcomes, recipes]), dtype=np.int8)
    
    def classical_shadow_batch(self, circuits):
        for circuit in circuits:
            if circuit is None:  # pragma: no cover
                raise ValueError("Circuit must be provided when measuring classical shadows")
        mapped_wires = [np.array(self.map_wires(circuit.observables[0].wires)) for circuit in circuits]
        to_pass = [QuantumScript(ops=c.operations) for c in circuits]
        all_outcomes, all_recipes = jl.classical_shadow(self._device, mapped_wires, to_pass, self.shots, [circuit.observables[0].seed for circuit in circuits])
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
        start = time.time()
        all_results = self.classical_shadow_batch(circuits)
        all_expvals = []
        for (circuit, (bits, recipes)) in zip(circuits, all_results):
            obs    = circuit.measurements[0]
            shadow = qml.shadows.ClassicalShadow(bits, recipes, wire_map=obs.wires.tolist())
            all_expvals.append(shadow.expval(obs.H, obs.k))
        stop = time.time()
        print(f"\tTime to compute shadow expal batch for {len(circuits)} circuits: {stop-start}.")
        return all_expvals 

    def batch_execute(self, circuits, **run_kwargs):
        print(f"\tEntering Julia segment at: {datetime.datetime.now()}.", flush=True)
        print(f"\tComputing batch with {len(circuits)} elements.", flush=True)
        if not self._parallel:
            return super().batch_execute(circuits)

        if all(isinstance(circuit.observables[0], ShadowExpvalMP) for circuit in circuits):
            return self.shadow_expval_batch(circuits)

        start = time.time()
        for circuit in circuits:
            self.check_validity(circuit.operations, circuit.observables)
        stop = time.time()
        print(f"\tTime to check validity: {stop-start}.")
        
        start = time.time()
        all_trainable = []
        for circuit in circuits:
            trainable = (
                BraketQubitDevice._get_trainable_parameters(circuit)
                if self._parametrize_differentiable
                else {}
            )
            all_trainable.append(trainable)
        stop = time.time()
        print(f"\tTime to get all trainable indicies: {stop-start}.")

        batch_shots = 0 if self.analytic else self.shots
        inputs = [{f"p_{k}": v for k, v in trainable.items()} for trainable in all_trainable]
        print(f"\tBegin Julia processing at {datetime.datetime.now()}.")
        start = time.time()
        jl_start = time.time()
        jl_results = self._device(circuits, inputs, shots=batch_shots)
        jl_stop = time.time()
        print(f"\tJulia time to compute batch: {jl_stop-jl_start}. Returned from Julia at {datetime.datetime.now()}", flush=True)
        pl_results = []
        for (circ, jl_r) in zip(circuits, jl_results):
            if len(circ.measurements) == 1:
                pl_results.append(np.array(jl_r).squeeze())
            else:
                pl_results.append(tuple(np.array(r).squeeze() for r in jl_r))
        stop = time.time()
        print(f"\tTotal time to compute batch: {stop-start}.", flush=True)
        print(f"\tExiting Julia segment at: {datetime.datetime.now()}.", flush=True)
        return pl_results 
