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

from abc import ABC, abstractmethod
from typing import Union

from braket.device_schema import DeviceCapabilities
from braket.ir.annealing import Problem
from braket.ir.jaqcd import Program as JaqcdProgram
from braket.ir.openqasm import Program as OQ3Program
from braket.task_result import AnnealingTaskResult, GateModelTaskResult


class BraketSimulator(ABC):
    """An abstract simulator that locally runs a quantum task.

    The task can be either a circuit-based program or an annealing problem,
    specified by the given IR.

    For users creating their own simulator: to register a simulator so the
    Braket SDK recognizes its name, the name and class must added as an
    entry point for "braket.simulators". This is done by adding an entry to
    entry_points in the simulator package's setup.py:

    >>> entry_points = {
    >>>     "braket.simulators": [
    >>>         "backend_name = <backend_class>"
    >>>     ]
    >>> }
    """

    DEVICE_ID = None

    @abstractmethod
    def run(
        self, ir: Union[JaqcdProgram, OQ3Program, Problem], *args, **kwargs
    ) -> Union[GateModelTaskResult, AnnealingTaskResult]:
        """
        Run the task specified by the given IR.

        Extra arguments will contain any additional information necessary to run the task,
        such as number of qubits.

        Args:
            ir (Union[JaqcdProgram, OQ3Program, Problem]): The IR representation of the program

        Returns:
            Union[GateModelTaskResult, AnnealingTaskResult]: An object representing
            the results of the simulation.
        """

    @property
    @abstractmethod
    def properties(self) -> DeviceCapabilities:
        """DeviceCapabilities: Properties of the device."""
