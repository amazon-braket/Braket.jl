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

from pydantic import BaseModel

from braket.ir.ahs.driving_field import DrivingField
from braket.ir.ahs.shifting_field import ShiftingField


class Hamiltonian(BaseModel):
    """
    Specifies the Hamiltonian

    Attributes:
        driving_fileds: An externally controlled force
            that drives coherent transitions between selected levels of certain atom types
        shifting_fields: An externally controlled polarizing force
            the effect of which is accurately described by a frequency shift of certain levels.

    Examples:
        >>> Hamiltonian(driving_fields=[DrivingField],shifting_fields=[ShiftingField])
    """

    drivingFields: List[DrivingField]
    shiftingFields: List[ShiftingField]
