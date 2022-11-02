from decimal import Decimal

from pydantic.main import BaseModel


class CapabilitiesConstants(BaseModel):

    DIMENSIONS = 2
    BOUNDING_BOX_SIZE_X: Decimal
    BOUNDING_BOX_SIZE_Y: Decimal
    MAX_TIME: Decimal
    MIN_DISTANCE: Decimal
    GLOBAL_AMPLITUDE_VALUE_MIN: Decimal
    GLOBAL_AMPLITUDE_VALUE_MAX: Decimal
    GLOBAL_DETUNING_VALUE_MIN: Decimal
    GLOBAL_DETUNING_VALUE_MAX: Decimal

    LOCAL_MAGNITUDE_SEQUENCE_VALUE_MIN: Decimal
    LOCAL_MAGNITUDE_SEQUENCE_VALUE_MAX: Decimal

    MAGNITUDE_PATTERN_VALUE_MIN: Decimal
    MAGNITUDE_PATTERN_VALUE_MAX: Decimal
