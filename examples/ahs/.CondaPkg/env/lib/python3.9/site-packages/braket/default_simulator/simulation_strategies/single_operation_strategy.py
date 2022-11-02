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

from typing import List

import numpy as np

from braket.default_simulator.linalg_utils import multiply_matrix
from braket.default_simulator.operation import GateOperation


def apply_operations(
    state: np.ndarray, qubit_count: int, operations: List[GateOperation]
) -> np.ndarray:
    """Applies operations to a state vector one at a time.

    Args:
        state (np.ndarray): The state vector to apply the given operations to, as a type
            (num_qubits, 0) tensor
        qubit_count (int): Unused parameter; in signature for backwards-compatibility
        operations (List[GateOperation]): The operations to apply to the state vector

    Returns:
        np.ndarray: The state vector after applying the given operations, as a type
        (qubit_count, 0) tensor
    """
    for operation in operations:
        matrix = operation.matrix
        targets = operation.targets
        state = multiply_matrix(state, matrix, targets)
    return state
