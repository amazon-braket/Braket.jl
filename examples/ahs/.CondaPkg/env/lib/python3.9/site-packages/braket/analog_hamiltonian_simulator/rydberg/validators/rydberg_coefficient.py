import warnings

from braket.analog_hamiltonian_simulator.rydberg.constants import RYDBERG_INTERACTION_COEF


def validate_rydberg_interaction_coef(rydberg_interaction_coef: float) -> float:
    """Validate the Rydberg interaction coefficient

    Args:
        rydberg_interaction_coef (float): The Rydberg interaction strength

    Returns:
        float: The rydberg_interaction_coef

    Raises:
        ValueError: If rydberg_interaction_coef < 0
    """
    rydberg_interaction_coef = float(rydberg_interaction_coef)
    if rydberg_interaction_coef <= 0:
        raise ValueError("`rydberg_interaction_coef` needs to be positive.")

    if not (
        RYDBERG_INTERACTION_COEF / 10 < rydberg_interaction_coef < RYDBERG_INTERACTION_COEF * 10
    ):
        warnings.warn(
            f"Rydberg interaction coefficient {rydberg_interaction_coef} meter^6/second is not in "
            f"the same scale as the typical value ({RYDBERG_INTERACTION_COEF} meter^6/second). "
            "The Rydberg interaction coefficient should be specified in SI units."
        )

    return rydberg_interaction_coef
