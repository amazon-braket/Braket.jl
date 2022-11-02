# Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
import uuid
import warnings
from abc import abstractmethod
from typing import Any, Callable, Dict, List, Union

from braket.device_schema import DeviceActionType, DeviceCapabilities
from braket.ir.jaqcd import Program as JaqcdProgram
from braket.ir.jaqcd.program_v1 import Results
from braket.ir.openqasm import Program as OpenQASMProgram
from braket.task_result import (
    AdditionalMetadata,
    GateModelTaskResult,
    ResultTypeValue,
    TaskMetadata,
)

from braket.default_simulator.observables import Hermitian, TensorProduct
from braket.default_simulator.openqasm.circuit import Circuit
from braket.default_simulator.openqasm.interpreter import Interpreter
from braket.default_simulator.operation import Observable, Operation
from braket.default_simulator.operation_helpers import from_braket_instruction
from braket.default_simulator.result_types import (
    ResultType,
    TargetedResultType,
    from_braket_result_type,
)
from braket.default_simulator.simulation import Simulation
from braket.simulator import BraketSimulator

_NOISE_INSTRUCTIONS = frozenset(
    instr.lower().replace("_", "")
    for instr in [
        "amplitude_damping",
        "bit_flip",
        "depolarizing",
        "generalized_amplitude_damping",
        "kraus",
        "pauli_channel",
        "two_qubit_pauli_channel",
        "phase_flip",
        "phase_damping",
        "two_qubit_dephasing",
        "two_qubit_depolarizing",
    ]
)


class BaseLocalSimulator(BraketSimulator):
    def run(
        self, circuit_ir: Union[OpenQASMProgram, JaqcdProgram], *args, **kwargs
    ) -> GateModelTaskResult:
        """
        Simulate a circuit using either OpenQASM or Jaqcd.

        Args:
            circuit_ir (Union[OpenQASMProgram, JaqcdProgram]): Circuit specification.
            qubit_count (int, jaqcd-only): Number of qubits.
            shots (int, optional): The number of shots to simulate. Default is 0, which
                performs a full analytical simulation.
            batch_size (int, optional): The size of the circuit partitions to contract,
                if applying multiple gates at a time is desired; see `StateVectorSimulation`.
                Must be a positive integer.
                Defaults to 1, which means gates are applied one at a time without any
                optimized contraction.

        Returns:
            GateModelTaskResult: object that represents the result

        Raises:
            ValueError: If result types are not specified in the IR or sample is specified
                as a result type when shots=0. Or, if StateVector and Amplitude result types
                are requested when shots>0.
        """
        if isinstance(circuit_ir, OpenQASMProgram):
            return self.run_openqasm(circuit_ir, *args, **kwargs)
        return self.run_jaqcd(circuit_ir, *args, **kwargs)

    @property
    @abstractmethod
    def properties(self) -> DeviceCapabilities:
        """simulator properties"""

    @abstractmethod
    def initialize_simulation(self, **kwargs) -> Simulation:
        """Initializes simulation with keyword arguments"""

    def _validate_ir_results_compatibility(
        self, results: List[Results], device_action_type
    ) -> None:
        """
        Validate that requested result types are valid for the simulator.

        Args:
            results (List[Results]): Requested result types.

        Raises:
            TypeError: If any the specified result types are not supported
        """
        if results:
            circuit_result_types_name = [result.__class__.__name__ for result in results]
            supported_result_types = self.properties.action[device_action_type].supportedResultTypes
            supported_result_types_name = [result.name for result in supported_result_types]
            for name in circuit_result_types_name:
                if name not in supported_result_types_name:
                    raise TypeError(
                        f"result type {name} is not supported by {self.__class__.__name__}"
                    )

    @staticmethod
    def _validate_shots_and_ir_results(
        shots: int,
        results: List[Results],
        qubit_count: int,
    ) -> None:
        """
        Validated that requested result types are valid for given shots and qubit count.

        Args:
            shots (int): Shots for the simulation.
            results (List[Results]): Specified result types.
            qubit_count (int): Number of qubits for the simulation.

        Raises:
            ValueError: If any of the requested result types are incompatible with the
                qubit count or number of shots.
        """
        if not shots:
            if not results:
                raise ValueError("Result types must be specified in the IR when shots=0")
            for rt in results:
                if rt.type in ["sample"]:
                    raise ValueError("sample can only be specified when shots>0")
                if rt.type == "amplitude":
                    BaseLocalSimulator._validate_amplitude_states(rt.states, qubit_count)
        elif shots and results:
            for rt in results:
                if rt.type in ["statevector", "amplitude", "densitymatrix"]:
                    raise ValueError(
                        "statevector, amplitude and densitymatrix result "
                        "types not available when shots>0"
                    )

    @staticmethod
    def _validate_amplitude_states(states: List[str], qubit_count: int) -> None:
        """
        Validate states in an amplitude result type are valid.

        Args:
            states (List[str]): List of binary strings representing quantum states.
            qubit_count (int): Number of qubits for the simulation.

        Raises:
            ValueError: If any of the states is not the correct size for the number of qubits.
        """
        for state in states:
            if len(state) != qubit_count:
                raise ValueError(
                    f"Length of state {state} for result type amplitude"
                    f" must be equivalent to number of qubits {qubit_count} in circuit"
                )

    @staticmethod
    def _translate_result_types(results: List[Results]) -> List[ResultType]:
        return [from_braket_result_type(result) for result in results]

    @staticmethod
    def _generate_results(
        results: List[Results],
        result_types: List[ResultType],
        simulation: Simulation,
    ) -> List[ResultTypeValue]:
        return [
            ResultTypeValue.construct(
                type=results[index],
                value=result_types[index].calculate(simulation),
            )
            for index in range(len(results))
        ]

    def _create_results_obj(
        self,
        results: List[Dict[str, Any]],
        openqasm_ir: OpenQASMProgram,
        simulation: Simulation,
    ) -> GateModelTaskResult:
        return GateModelTaskResult.construct(
            taskMetadata=TaskMetadata(
                id=str(uuid.uuid4()),
                shots=simulation.shots,
                deviceId=self.DEVICE_ID,
            ),
            additionalMetadata=AdditionalMetadata(
                action=openqasm_ir,
            ),
            resultTypes=results,
            measurements=self._formatted_measurements(simulation),
            measuredQubits=self._get_measured_qubits(simulation.qubit_count),
        )

    @staticmethod
    def _validate_operation_qubits(operations: List[Operation]) -> None:
        qubits_referenced = {target for operation in operations for target in operation.targets}
        if max(qubits_referenced) >= len(qubits_referenced):
            raise ValueError(
                "Non-contiguous qubit indices supplied; "
                "qubit indices in a circuit must be contiguous."
            )

    @staticmethod
    def _validate_result_types_qubits_exist(
        targeted_result_types: List[TargetedResultType], qubit_count: int
    ) -> None:
        for result_type in targeted_result_types:
            targets = result_type.targets
            if targets and max(targets) >= qubit_count:
                raise ValueError(
                    f"Result type ({result_type.__class__.__name__})"
                    f" references invalid qubits {targets}"
                )

    def _validate_ir_instructions_compatibility(
        self,
        circuit_ir: Union[JaqcdProgram, Circuit],
        device_action_type: DeviceActionType,
    ) -> None:
        """
        Validate that requested IR instructions are valid for the simulator.

        Args:
            circuit_ir (Union[JaqcdProgram, Circuit]): IR for the simulator.

        Raises:
            TypeError: If any the specified result types are not supported
        """
        circuit_instruction_names = [
            instr.__class__.__name__.lower().replace("_", "") for instr in circuit_ir.instructions
        ]
        supported_instructions = frozenset(
            op.lower().replace("_", "")
            for op in self.properties.action[device_action_type].supportedOperations
        )
        no_noise = True
        for name in circuit_instruction_names:
            if name in _NOISE_INSTRUCTIONS:
                no_noise = False
                if name not in supported_instructions:
                    raise TypeError(
                        "Noise instructions are not supported by the state vector simulator "
                        "(by default). You need to use the density matrix simulator: "
                        'LocalSimulator("braket_dm").'
                    )
        if no_noise and _NOISE_INSTRUCTIONS.intersection(supported_instructions):
            warnings.warn(
                "You are running a noise-free circuit on the density matrix simulator. "
                "Consider running this circuit on the state vector simulator: "
                'LocalSimulator("default") for a better user experience.'
            )

    @staticmethod
    def _get_measured_qubits(qubit_count: int) -> List[int]:
        return list(range(qubit_count))

    @staticmethod
    def _tensor_product_index_dict(
        observable: TensorProduct, callable: Callable[[Observable], Any]
    ) -> Dict[int, Any]:
        obj_dict = {}
        i = 0
        factors = list(observable.factors)
        total = len(factors[0].measured_qubits)
        while factors:
            if i >= total:
                factors.pop(0)
                if factors:
                    total += len(factors[0].measured_qubits)
            if factors:
                obj_dict[i] = callable(factors[0])
            i += 1
        return obj_dict

    @staticmethod
    def _observable_hash(observable: Observable) -> Union[str, Dict[int, str]]:
        if isinstance(observable, Hermitian):
            return str(hash(str(observable.matrix.tostring())))
        elif isinstance(observable, TensorProduct):
            # Dict of target index to observable hash
            return BaseLocalSimulator._tensor_product_index_dict(
                observable, BaseLocalSimulator._observable_hash
            )
        else:
            return str(observable.__class__.__name__)

    @staticmethod
    def _formatted_measurements(simulation: Simulation) -> List[List[str]]:
        """Retrieves formatted measurements obtained from the specified simulation.

        Args:
            simulation (Simulation): Simulation to use for obtaining the measurements.

        Returns:
            List[List[str]]: List containing the measurements, where each measurement consists
            of a list of measured values of qubits.
        """
        return [
            list("{number:0{width}b}".format(number=sample, width=simulation.qubit_count))
            for sample in simulation.retrieve_samples()
        ]

    def run_openqasm(
        self,
        openqasm_ir: OpenQASMProgram,
        shots: int = 0,
        *,
        batch_size: int = 1,
    ) -> GateModelTaskResult:
        """Executes the circuit specified by the supplied `circuit_ir` on the simulator.

        Args:
            openqasm_ir (Program): ir representation of a braket circuit specifying the
                instructions to execute.
            shots (int): The number of times to run the circuit.
            batch_size (int): The size of the circuit partitions to contract,
                if applying multiple gates at a time is desired; see `StateVectorSimulation`.
                Must be a positive integer.
                Defaults to 1, which means gates are applied one at a time without any
                optimized contraction.
        Returns:
            GateModelTaskResult: object that represents the result

        Raises:
            ValueError: If result types are not specified in the IR or sample is specified
                as a result type when shots=0. Or, if StateVector and Amplitude result types
                are requested when shots>0.
        """
        is_file = openqasm_ir.source.endswith(".qasm")
        interpreter = Interpreter()
        circuit = interpreter.build_circuit(
            source=openqasm_ir.source,
            inputs=openqasm_ir.inputs,
            is_file=is_file,
        )
        qubit_count = circuit.num_qubits

        self._validate_ir_results_compatibility(
            circuit.results,
            device_action_type=DeviceActionType.OPENQASM,
        )
        self._validate_ir_instructions_compatibility(
            circuit,
            device_action_type=DeviceActionType.OPENQASM,
        )
        BaseLocalSimulator._validate_shots_and_ir_results(shots, circuit.results, qubit_count)

        operations = circuit.instructions
        BaseLocalSimulator._validate_operation_qubits(operations)

        results = circuit.results

        simulation = self.initialize_simulation(
            qubit_count=qubit_count, shots=shots, batch_size=batch_size
        )
        simulation.evolve(operations)

        if not shots:
            result_types = BaseLocalSimulator._translate_result_types(results)
            BaseLocalSimulator._validate_result_types_qubits_exist(
                [
                    result_type
                    for result_type in result_types
                    if isinstance(result_type, TargetedResultType)
                ],
                qubit_count,
            )
            results = BaseLocalSimulator._generate_results(
                circuit.results,
                result_types,
                simulation,
            )
        else:
            simulation.evolve(circuit.basis_rotation_instructions)

        return self._create_results_obj(results, openqasm_ir, simulation)

    def run_jaqcd(
        self,
        circuit_ir: JaqcdProgram,
        qubit_count: int,
        shots: int = 0,
        *,
        batch_size: int = 1,
    ) -> GateModelTaskResult:
        """Executes the circuit specified by the supplied `circuit_ir` on the simulator.

        Args:
            circuit_ir (Program): ir representation of a braket circuit specifying the
                instructions to execute.
            qubit_count (int): The number of qubits to simulate.
            shots (int): The number of times to run the circuit.
            batch_size (int): The size of the circuit partitions to contract,
                if applying multiple gates at a time is desired; see `StateVectorSimulation`.
                Must be a positive integer.
                Defaults to 1, which means gates are applied one at a time without any
                optimized contraction.
        Returns:
            GateModelTaskResult: object that represents the result

        Raises:
            ValueError: If result types are not specified in the IR or sample is specified
                as a result type when shots=0. Or, if StateVector and Amplitude result types
                are requested when shots>0.
        """
        self._validate_ir_results_compatibility(
            circuit_ir.results,
            device_action_type=DeviceActionType.JAQCD,
        )
        self._validate_ir_instructions_compatibility(
            circuit_ir,
            device_action_type=DeviceActionType.JAQCD,
        )
        BaseLocalSimulator._validate_shots_and_ir_results(shots, circuit_ir.results, qubit_count)

        operations = [
            from_braket_instruction(instruction) for instruction in circuit_ir.instructions
        ]

        if shots > 0 and circuit_ir.basis_rotation_instructions:
            for instruction in circuit_ir.basis_rotation_instructions:
                operations.append(from_braket_instruction(instruction))

        BaseLocalSimulator._validate_operation_qubits(operations)

        simulation = self.initialize_simulation(
            qubit_count=qubit_count, shots=shots, batch_size=batch_size
        )
        simulation.evolve(operations)

        results = []

        if not shots and circuit_ir.results:
            result_types = BaseLocalSimulator._translate_result_types(circuit_ir.results)
            BaseLocalSimulator._validate_result_types_qubits_exist(
                [
                    result_type
                    for result_type in result_types
                    if isinstance(result_type, TargetedResultType)
                ],
                qubit_count,
            )
            results = self._generate_results(
                circuit_ir.results,
                result_types,
                simulation,
            )

        return self._create_results_obj(results, circuit_ir, simulation)
