from braket.ir.ahs.physical_field import PhysicalField
from pydantic.class_validators import root_validator


class PhysicalFieldValidator(PhysicalField):

    # Pattern, if string, must be "uniform"
    @root_validator(pre=True, skip_on_failure=True)
    def pattern_str(cls, values):
        pattern = values["pattern"]
        if isinstance(pattern, str):
            if pattern != "uniform":
                raise ValueError(f'Invalid pattern string ({pattern}); only string: "uniform"')
        return values
