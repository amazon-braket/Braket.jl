from braket.ir.ahs.program_v1 import Program
from pydantic import root_validator

from braket.analog_hamiltonian_simulator.rydberg.validators.capabilities_constants import (
    CapabilitiesConstants,
)


class ProgramValidator(Program):
    capabilities: CapabilitiesConstants

    # The pattern of the shifting field must have the same length as the lattice_sites
    @root_validator(pre=True, skip_on_failure=True)
    def shifting_field_pattern_has_the_same_length_as_atom_array_sites(cls, values):
        num_sites = len(values["setup"]["ahs_register"]["sites"])
        for idx, shifting_field in enumerate(values["hamiltonian"]["shiftingFields"]):
            pattern_size = len(shifting_field["magnitude"]["pattern"])
            if num_sites != pattern_size:
                raise ValueError(
                    f"The length of pattern ({pattern_size}) of shifting field {idx} must equal "
                    f"the number of atom array sites ({num_sites})."
                )
        return values
