import warnings

from braket.analog_hamiltonian_simulator.rydberg.constants import MIN_BLOCKADE_RADIUS


def validate_blockade_radius(blockade_radius: float) -> float:
    """Validate the Blockade radius

    Args:
        blockade_radius (float): The user-specified blockade radius

    Returns:
        float: The validated blockade radius

    Raises:
        ValueError: If blockade_radius < 0
    """
    blockade_radius = float(blockade_radius)
    if blockade_radius < 0:
        raise ValueError("`blockade_radius` needs to be non-negative.")

    if 0 < blockade_radius and blockade_radius < MIN_BLOCKADE_RADIUS:
        warnings.warn(
            f"Blockade radius {blockade_radius} meter is smaller than the typical value "
            f"({MIN_BLOCKADE_RADIUS} meter). "
            "The blockade radius should be specified in SI units."
        )

    return blockade_radius
