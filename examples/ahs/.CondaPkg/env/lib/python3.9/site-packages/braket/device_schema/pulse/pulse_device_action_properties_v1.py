from typing import Dict, Optional

from pydantic import Field

from braket.device_schema.pulse.frame_v1 import Frame
from braket.device_schema.pulse.port_v1 import Port
from braket.device_schema.pulse.pulse_function_v1 import PulseFunction
from braket.schema_common import BraketSchemaBase, BraketSchemaHeader


class PulseDeviceActionProperties(BraketSchemaBase):
    """
    Describes the hardware device details and device limitations for pulse control on a given
        quantum device

    Attributes:
        supportedQhpTemplateWaveforms: Pre-defined routine waveform functions available on the
         hardware
        ports: Pre-defined hardware ports available on the hardware
        supportedFunctions:  A dictionary of OpenPulse functions supported in openqasm for the
         hardware
        frames: Pre-defined pulse frames available on the hardware
        supportsLocalPulseElements: Details whether pulse elements may be defined within
         OpenQasm `defcal` blocks
        supportsDynamicFrames: Details whether a device may create frames at runtime from
         `ports` or if it
            must use the frames defined in `frames`

    Examples:
        >>> import json
        >>> input_json = {
        ...         "braketSchemaHeader": {
        ...             "name": "braket.device_schema.pulse.pulse_device_action_properties",
        ...             "version": "1",
        ...         },
        ...         "supportedQhpTemplateWaveforms": {
        ...             "flat": {
        ...                 "templateName": "flat",
        ...                 "args": [
        ...                     ["duration", "float"],
        ...                     ["iq", "float"]
        ...                 ]
        ...             }
        ...         },
        ...         "supportedQhpTemplateWaveforms": {
        ...             "flat": {
        ...                 "functionName": "flat",
        ...                 "arguments": [
        ...                     {"name": "duration", "type": "float"},
        ...                     {"name": "iq", "type": "float"},
        ...                     {"name": "scale", "type": "float", "optional": True},
        ...                     {"name": "phase", "type": "float", "optional": True},
        ...                     {"name": "detuning", "type": "float", "optional": True},
        ...                 ]
        ...             }
        ...         },
        ...         "ports": {
        ...             "q0_rf": {
        ...                 "portId": "q0_rf",
        ...                 "direction": "tx",
        ...                 "portType": "rf",
        ...                 "dt": 1e-9,
        ...             },
        ...             "q1_rf": {
        ...                 "portId": "q1_rf",
        ...                 "direction": "tx",
        ...                 "portType": "rf",
        ...                 "dt": 1e-9,
        ...             },
        ...             "q120_ff": {
        ...                 "portId": "q120_ff",
        ...                 "direction": "tx",
        ...                 "portType": "ff",
        ...                 "dt": 1e-9,
        ...             },
        ...         },
        ...         "frames": {
        ...             "q0_rf_frame": {
        ...                 "frameId": "q0_rf_frame",
        ...                 "portId": "q0_rf",
        ...                 "frequency": 4525620740.86441,
        ...                 "phase": 0.0,
        ...
        ...                 "qubitMappings": [0],
        ...             },
        ...             "q120_q27_frame": {
        ...                 "frameId": "q0_rf_frame",
        ...                 "portId": "q0_rf",
        ...                 "frequency": 4525620740.86441,
        ...                 "phase": 0.0,
        ...                 "associatedGate": "xy",
        ...                 "qubitMappings": [120, 127],
        ...             }
        ...         },
        ...         "supportedFunctions": [
        ...             "newframe",
        ...             "shift_phase",
        ...             "set_phase",
        ...             "shift_frequency",
        ...             "set_frequency",
        ...             "play",
        ...             "capture"
        ...         ],
        ...         "supportedFunctions": {
        ...             "newframe": {
        ...                 "functionName": "newframe",
        ...                 "arguments": [
        ...                     {"name": "frame", "type": "frame"},
        ...                     {"name": "frequency", "type": "float"},
        ...                     {"name": "phase", "type": "float", "optional": True},
        ...                 ]
        ...              },
        ...         },
        ...         "supportsNonNativeGatesWithPulses": False,
        ...         "validationParameters": {
        ...             "MAX_SCALE": 1.0,
        ...             "MAX_AMPLITUDE": 1.0,
        ...             "PERMITTED_FREQUENCY_DIFFERENCE": 1.0,
        ...         }
        ...     }
        >>> PulseDeviceActionProperties.parse_raw_schema(json.dumps(input_json))
    """

    _PROGRAM_HEADER = BraketSchemaHeader(
        name="braket.device_schema.pulse.pulse_device_action_properties", version="1"
    )
    braketSchemaHeader: BraketSchemaHeader = Field(default=_PROGRAM_HEADER, const=_PROGRAM_HEADER)
    supportedQhpTemplateWaveforms: Dict[str, PulseFunction]
    ports: Dict[str, Port]
    supportedFunctions: Dict[str, PulseFunction]
    frames: Optional[Dict[str, Frame]]
    supportsLocalPulseElements: Optional[bool] = True
    supportsDynamicFrames: Optional[bool] = True
    supportsNonNativeGatesWithPulses: Optional[bool] = False
    validationParameters: Optional[Dict[str, float]]
