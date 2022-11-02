from typing import Any, Dict, List, Optional

from pydantic import BaseModel


class Frame(BaseModel):
    """
    Defines the pre-built frames for the given hardware.  For more details on frames
    refer to the OpenQasm/OpenPulse documentation

    Attributes:
        frameId: The id name of the frame that may be loaded in OpenQasm
        portId: The id of the associated hardware port the frame uses
        frequency: The initial frequency of the frame
        phase: The initial phase of the frame
        associatedGate: Optional detail if the frame is associated with a gate
        qubitMappings:  Optional list of associated qubits for the frame

    """

    frameId: str
    portId: str
    frequency: float
    centerFrequency: Optional[float]
    phase: float
    associatedGate: Optional[str]
    qubitMappings: Optional[List[int]]
    qhpSpecificProperties: Optional[Dict[str, Any]]
