from enum import Enum
from typing import Any, Dict, List, Optional, Set

from pydantic import BaseModel


class Direction(Enum):
    """
    Specifies the direction of port.
    """

    tx = "tx"
    rx = "rx"


class Port(BaseModel):
    """
    Represents a hardware port that may be used for pulse control. For more details on ports
    refer to the OpenQasm/OpenPulse documentation

    Attributes:
        portId: The id of the associated hardware port the frame uses
        direction: The directionality of the port
        portType: The port type of the control hardware
        dt: The smallest time step that may be used on the control hardware

    """

    portId: str
    direction: Direction
    portType: str
    dt: float
    qubitMappings: Optional[List[int]]
    centerFrequencies: Optional[Set[float]]
    qhpSpecificProperties: Optional[Dict[str, Any]]
