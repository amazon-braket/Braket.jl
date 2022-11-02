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

from decimal import Decimal
from typing import Tuple

from pydantic import BaseModel, Field

from braket.schema_common import BraketSchemaBase, BraketSchemaHeader


class Area(BaseModel):
    """
    The area of the FOV
    Attributes:
        width (Decimal): Largest allowed difference between x
            coordinates of any two sites (measured in meters)
        height (Decimal): Largest allowed difference between y
            coordinates of any two sites (measured in meters)
    """

    width: Decimal
    height: Decimal


class Geometry(BaseModel):
    """
    Spacing or number of sites or rows
    Attributes:
        spacingRadialMin (Decimal): Minimum radial spacing between any
            two sites in the lattice (measured in meters)
        spacingVerticalMin (Decimal): Minimum spacing between any two
            rows in the lattice (measured in meters)
        positionResolution (Decimal): Resolution with which site positions
            can be specified (measured in meters)
        numberSitesMax (int): Maximum number of sites that can be placed
            in the lattice
    """

    spacingRadialMin: Decimal
    spacingVerticalMin: Decimal
    positionResolution: Decimal
    numberSitesMax: int


class Lattice(BaseModel):
    """
    Spacing or number of sites or rows
    Attributes:
        area : The rectangular area available for arranging atomic sites
        geometry : Limitations of atomic site arrangements
    """

    area: Area
    geometry: Geometry


class RydbergGlobal(BaseModel):
    """
    Parameters determining the limitations on the driving field that drives the
        ground-to-Rydberg transition uniformly on all atoms
    Attributes:
        rabiFrequencyRange (Tuple[Decimal,Decimal]): Achievable Rabi frequency
            range for the global Rydberg drive waveform (measured in rad/s)
        rabiFrequencyResolution (Decimal): Resolution with which global Rabi
            frequency amplitude can be specified (measured in rad/s)
        rabiFrequencySlewRateMax (Decimal): Maximum slew rate for changing the
            global Rabi frequency (measured in (rad/s)/s)
        detuningRange(Tuple[Decimal,Decimal]): Achievable detuning range for
            the global Rydberg pulse (measured in rad/s)
        detuningResolution(Decimal): Resolution with which global detuning can
            be specified (measured in rad/s)
        detuningSlewRateMax (Decimal): Maximum slew rate for detuning (measured in (rad/s)/s)
        phaseRange(Tuple[Decimal,Decimal]): Achievable phase range for the global
            Rydberg pulse (measured in rad)
        phaseResolution(Decimal): Resolution with which global Rabi frequency phase
            can be specified (measured in rad)
        timeResolution(Decimal): Resolution with which times for global Rydberg drive
            parameters can be specified (measured in s)
        timeDeltaMin(Decimal): Minimum time step with which times for global Rydberg
            drive parameters can be specified (measured in s)
        timeMin (Decimal): Minimum duration of Rydberg drive (measured in s)
        timeMax (Decimal): Maximum duration of Rydberg drive (measured in s)
    """

    rabiFrequencyRange: Tuple[Decimal, Decimal]
    rabiFrequencyResolution: Decimal
    rabiFrequencySlewRateMax: Decimal
    detuningRange: Tuple[Decimal, Decimal]
    detuningResolution: Decimal
    detuningSlewRateMax: Decimal
    phaseRange: Tuple[Decimal, Decimal]
    phaseResolution: Decimal
    timeResolution: Decimal
    timeDeltaMin: Decimal
    timeMin: Decimal
    timeMax: Decimal


class Rydberg(BaseModel):
    """
    Parameters determining the limitations of the Rydberg Hamiltonian
    Attributes:
        c6Coefficient (Decimal): Rydberg-Rydberg C6 interaction
            coefficient (measured in (rad/s)*m^6)
        rydbergGlobal: Rydberg Global
    """

    c6Coefficient: Decimal
    rydbergGlobal: RydbergGlobal


class PerformanceLattice(BaseModel):
    """
    Uncertainties of atomic site arrangements
    Attributes:
        positionErrorAbs (Decimal): Error between target and actual site
            position (measured in meters)
    """

    positionErrorAbs: Decimal


class PerformanceRydbergGlobal(BaseModel):
    """
    Parameters determining the limitations of the global driving field
    Attributes:
        rabiFrequencyErrorRel (Decimal): random error in the Rabi frequency, relative (unitless)
    """

    rabiFrequencyErrorRel: Decimal


class PerformanceRydberg(BaseModel):
    """
    Parameters determining the limitations the Rydberg simulator
    Attributes:
        rydbergGlobal: Performance of Rydberg Global
    """

    rydbergGlobal: PerformanceRydbergGlobal


class Performance(BaseModel):
    """
    Parameters determining the limitations of the QuEra device
    Attributes:
        performanceLattice: Uncertainties of atomic site arrangements
        performanceRydberg : Parameters determining the limitations the Rydberg simulator
    """

    lattice: PerformanceLattice
    rydberg: PerformanceRydberg


class QueraAhsParadigmProperties(BraketSchemaBase):
    """
    This defines the properties common to ahs Quera devices.

    Attributes:
        area: the area of the FOV
        geometry: spacing or number of sites or rows
        qubits: the number of qubits
        rydberg: the constraint of rydberg
        performance: the performance of rydberg or atom detection
    Examples:
        >>> import json
        >>> input_json = {
        ...     "braketSchemaHeader": {
        ...         "name": "braket.device_schema.quera.quera_ahs_paradigm_properties",
        ...         "version": "1",
        ...     },
        ...     "qubitCount": 256,
        ...     "lattice":{
        ...         "area": {
        ...             "width": 100.0e-6,
        ...             "height": 100.0e-6,
        ...         },
        ...         "geometry": {
        ...             "spacingRadialMin": 4.0e-6,
        ...             "spacingVerticalMin": 2.5e-6,
        ...             "positionResolution": 1e-7,
        ...             "numberSitesMax": 256,
        ...         }
        ...     },
        ...     "rydberg": {
        ...         "c6Coefficient": 2*math.pi(3.14) *862690,
        ...         "rydbergGlobal": {
        ...             "rabiFrequencyRange": [0, 2*math.pi(3.14) *4.0e6],
        ...             "rabiFrequencyResolution": 400
        ...             "rabiFrequencySlewRateMax": 2*math.pi(3.14) *4e6/100e-9,
        ...             "detuningRange": [-2*math.pi(3.14) *20.0e6,2*math.pi(3.14) *20.0e6],
        ...             "detuningResolution": 0.2,
        ...             "detuningSlewRateMax": 2*math.pi(3.14) *40.0e6/100e-9,
        ...             "phaseRange": [-99,99],
        ...             "phaseResolution": 5e-7,
        ...             "timeResolution": 1e-9,
        ...             "timeDeltaMin": 1e-8,
        ...             "timeMin": 0,
        ...             "timeMax": 4.0e-6,
        ...         },
        ...     },
        ...     "performance": {
        ...         "lattice":{
        ...             "positionErrorAbs": 0.025e-6,
        ...         },
        ...         "performanceRydberg":{
        ...             "performanceRydbergGlobal":{
        ...                 "rabiFrequencyErrorRel:": 0.01,
        ...             },
        ...         },
        ...     },
        ... }
        >>> QueraAhsParadigmProperties.parse_raw_schema(json.dumps(input_json))
    """

    _PROGRAM_HEADER = BraketSchemaHeader(
        name="braket.device_schema.quera.quera_ahs_paradigm_properties", version="1"
    )
    braketSchemaHeader: BraketSchemaHeader = Field(default=_PROGRAM_HEADER, const=_PROGRAM_HEADER)
    qubitCount: int
    lattice: Lattice
    rydberg: Rydberg
    performance: Performance
