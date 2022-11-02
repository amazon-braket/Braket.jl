from braket.ir.ahs.shifting_field import ShiftingField
from pydantic.class_validators import root_validator

from braket.analog_hamiltonian_simulator.rydberg.validators.capabilities_constants import (
    CapabilitiesConstants,
)
from braket.analog_hamiltonian_simulator.rydberg.validators.field_validator_util import (
    validate_value_range_with_warning,
)


class ShiftingFieldValidator(ShiftingField):
    capabilities: CapabilitiesConstants

    @root_validator(pre=True, skip_on_failure=True)
    def magnitude_pattern_is_not_uniform(cls, values):
        magnitude = values["magnitude"]
        pattern = magnitude["pattern"]
        if isinstance(pattern, str):
            raise ValueError(f"Pattern of shifting field must be not be a string - {pattern}")
        return values

    @root_validator(pre=True, skip_on_failure=True)
    def magnitude_pattern_within_bounds(cls, values):
        magnitude = values["magnitude"]
        capabilities = values["capabilities"]
        pattern = magnitude["pattern"]
        for index, pattern_value in enumerate(pattern):
            if (pattern_value < capabilities.MAGNITUDE_PATTERN_VALUE_MIN) or (
                pattern_value > capabilities.MAGNITUDE_PATTERN_VALUE_MAX
            ):
                raise ValueError(
                    f"magnitude pattern value {index} is {pattern_value}; it must be between "
                    f"{capabilities.MAGNITUDE_PATTERN_VALUE_MIN} and "
                    f"{capabilities.MAGNITUDE_PATTERN_VALUE_MAX} (inclusive)."
                )
        return values

    @root_validator(pre=True, skip_on_failure=True)
    def magnitude_values_within_range(cls, values):
        magnitude = values["magnitude"]
        capabilities = values["capabilities"]
        magnitude_values = magnitude["time_series"]["values"]
        validate_value_range_with_warning(
            magnitude_values,
            capabilities.LOCAL_MAGNITUDE_SEQUENCE_VALUE_MIN,
            capabilities.LOCAL_MAGNITUDE_SEQUENCE_VALUE_MAX,
            "magnitude",
        )
        return values
