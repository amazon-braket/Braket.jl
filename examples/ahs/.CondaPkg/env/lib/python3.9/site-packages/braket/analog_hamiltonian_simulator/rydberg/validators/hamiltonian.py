from braket.ir.ahs.hamiltonian import Hamiltonian
from pydantic import root_validator


class HamiltonianValidator(Hamiltonian):
    @root_validator(pre=True, skip_on_failure=True)
    def max_one_driving_field(cls, values):
        driving_fields = values["drivingFields"]
        if len(driving_fields) > 1:
            raise ValueError(
                f"At most one driving field should be specified; {len(driving_fields)} are given."
            )
        return values

    @root_validator(pre=True, skip_on_failure=True)
    def max_one_shifting_field(cls, values):
        shifting_fields = values["shiftingFields"]
        if len(shifting_fields) > 1:
            raise ValueError(
                f"At most one shifting field should be specified; {len(shifting_fields)} are given."
            )
        return values

    @root_validator(pre=True, skip_on_failure=True)
    def all_sequences_in_driving_and_shifting_fields_have_the_same_last_timepoint(cls, values):
        d_field_names = {"amplitude", "phase", "detuning"}
        s_field_names = {"magnitude"}
        end_times = {}
        for index, field in enumerate(values["drivingFields"]):
            for name in d_field_names:
                end_times[f"{name} of driving field {index}"] = field[name]["time_series"]["times"][
                    -1
                ]
        for index, field in enumerate(values["shiftingFields"]):
            for name in s_field_names:
                end_times[f"{name} of shifting field {index}"] = field[name]["time_series"][
                    "times"
                ][-1]

        if len(set(end_times.values())) > 1:
            raise ValueError("The timepoints for all the sequences are not equal.")
        return values
