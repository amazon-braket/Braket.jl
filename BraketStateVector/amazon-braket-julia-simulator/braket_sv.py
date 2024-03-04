from braket.devices.local_simulator import LocalSimulator, _simulator_devices
from braket.circuits import Circuit
from braket.ir.openqasm import Program
from braket.tasks import GateModelQuantumTaskResult
from braket.tasks.local_quantum_task import LocalQuantumTask
from braket.tasks.local_quantum_task_batch import LocalQuantumTaskBatch
from braket.circuits.noise_model import NoiseModel
from typing import List, Union, Optional

class JuliaLocalSimulator(LocalSimulator):
    """A simulator meant to run directly on the user's machine using a Julia backend.

    This class wraps a BraketSimulator object so that it can be run and returns
    results using constructs from the SDK rather than Braket IR.
    """
    def __init__(
        self,
        backend: str = "braket_sv",
        noise_model: Optional[NoiseModel] = None,
    ):
        self._device = BraketStateVector.LocalSimulator(backend)
        self._name   = backend
        self._status = "AVAILABLE"
        if noise_model:
            self._validate_device_noise_model_support(noise_model)
        self._noise_model = noise_model
    
    def _run_internal(self, spec: Union[Circuit, Program, List[Union[Circuit, Program]]], shots, inputs, *args, **kwargs):
        if isinstance(spec, Circuit) or isinstance(spec, Program):
            specs = [spec]
        else:
            specs = spec
        if inputs is None:
            inputs = {}
        return self._device(specs, inputs, shots=shots)

    def run_batch(  # noqa: C901
        self,
        task_specifications: Union[
            Union[Circuit, Program],
            list[Union[Circuit, Program]],
        ],
        shots: Optional[int] = 0,
        max_parallel: Optional[int] = None,
        inputs: Optional[Union[dict[str, float], list[dict[str, float]]]] = None,
        *args,
        **kwargs,
    ) -> LocalQuantumTaskBatch:
        """Executes a batch of quantum tasks in parallel

        Args:
            task_specifications (Union[Union[Circuit, Problem, Program, AnalogHamiltonianSimulation], list[Union[Circuit, Problem, Program, AnalogHamiltonianSimulation]]]): # noqa
                Single instance or list of quantum task specification.
            shots (Optional[int]): The number of times to run the quantum task.
                Default: 0.
            max_parallel (Optional[int]): The maximum number of quantum tasks to run  in parallel. Default
                is the number of CPU.
            inputs (Optional[Union[dict[str, float], list[dict[str, float]]]]): Inputs to be passed
                along with the IR. If the IR supports inputs, the inputs will be updated with
                this value. Default: {}.

        Returns:
            LocalQuantumTaskBatch: A batch containing all of the quantum tasks run

        See Also:
            `braket.tasks.local_quantum_task_batch.LocalQuantumTaskBatch`
        """
        inputs = inputs or {}

        if self._noise_model:
            task_specifications = [
                self._apply_noise_model_to_circuit(task_specification)
                for task_specification in task_specifications
            ]

        if not max_parallel:
            max_parallel = cpu_count()

        single_task = isinstance(
            task_specifications,
            (Circuit, Program),
        )

        single_input = isinstance(inputs, dict)

        if not single_task and not single_input:
            if len(task_specifications) != len(inputs):
                raise ValueError(
                    "Multiple inputs and task specifications must " "be equal in number."
                )
        if single_task:
            task_specifications = repeat(task_specifications)

        if single_input:
            inputs = repeat(inputs)
        
        results = self._run_internal(task_specifications, inputs, shots=shots, **kwargs)

        return LocalQuantumTaskBatch(results)

