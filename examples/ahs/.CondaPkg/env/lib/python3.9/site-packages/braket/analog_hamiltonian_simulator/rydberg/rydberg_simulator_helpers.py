import itertools
import time
from typing import Dict, List, Tuple

import numpy as np
import scipy.sparse
from braket.ir.ahs.atom_arrangement import AtomArrangement
from braket.ir.ahs.program_v1 import Program


def validate_config(config: str, atoms_coordinates: np.ndarray, blockade_radius: float) -> bool:
    """Valid if a given configuration complies with the Rydberg approximation

    Args:
        config (str): The configuration to be validated
        atoms_coordinates (ndarray): The coordinates for atoms in the filled sites
        blockade_radius (float): The Rydberg blockade radius

    Returns:
        bool: True if the configuration complies with the Rydberg approximation,
        False otherwise
    """

    # The indices for the Rydberg atoms in the configuration
    rydberg_atoms = [i for i, item in enumerate(config) if item == "r"]

    for i, rydberg_atom in enumerate(rydberg_atoms[:-1]):
        dists = np.linalg.norm(
            atoms_coordinates[rydberg_atom] - atoms_coordinates[rydberg_atoms[i + 1 :]], axis=1
        )
        if min(dists) <= blockade_radius:
            return False
    return True


def get_blockade_configurations(lattice: AtomArrangement, blockade_radius: float) -> List[str]:
    """Return the lattice configurations complying with the blockade approximation

    Args:
        lattice (AtomArrangement): A lattice with Rydberg atoms and their coordinates
        blockade_radius (float): The Rydberg blockade radius

    Returns:
        List[str]: A list of bit strings, each of them corresponding to a valid
        configuration complying with the blockade approximation. The length of
        each configuration is the same as the number of atoms in the lattice,
        with 'r' and 'g' indicating the Rydberg and ground states, respectively.

        Notes on the indexing: The left-most bit in the configuration corresponds to
        the first atom in the lattice.

        Notes on the algorithm: We start from all possible configurations and get rid of
        those violating the blockade approximation constraint.
    """

    # The coordinates for atoms in the filled sites
    atoms_coordinates = np.array(lattice.sites)[np.where(lattice.filling)]
    min_separation = 1e10  # The minimum separation between atoms, or filled sites
    for i, atom_coord in enumerate(atoms_coordinates[:-1]):
        dists = np.linalg.norm(atom_coord - atoms_coordinates[i + 1 :], axis=1)
        min_separation = min(min_separation, min(dists))

    configurations = [
        "".join(item) for item in itertools.product(["g", "r"], repeat=sum(lattice.filling))
    ]

    if blockade_radius < min_separation:  # no need to consider blockade approximation
        return configurations
    return [
        config
        for config in configurations
        if validate_config(config, atoms_coordinates, blockade_radius)
    ]


def _get_interaction_dict(
    program: Program, rydberg_interaction_coef: float, configurations: List[str]
) -> Dict[Tuple[int, int], float]:
    """Return the dict contains the Rydberg interaction strength for all configurations.

    Args:
        program (Program): An analog simulation program for Rydberg system with the interaction term
        rydberg_interaction_coef (float): The interaction coefficient
        configurations (List[str]): The list of configurations that comply with the blockade
            approximation.

    Returns:
        Dict[Tuple[int, int], float]: The dictionary for the interaction operator
    """

    # The coordinates for atoms in the filled sites
    lattice = program.setup.ahs_register
    atoms_coordinates = np.array(
        [lattice.sites[i] for i in range(len(lattice.sites)) if lattice.filling[i] == 1]
    )

    interactions = {}  # The interaction in the basis of configurations, as a dictionary

    for config_index, config in enumerate(configurations):
        interaction = 0

        # The indices for the Rydberg atoms in the configuration
        rydberg_atoms = [i for i, item in enumerate(config) if item == "r"]

        # Obtain the pairwise distances between the Rydberg atoms, followed by adding their Rydberg
        # interactions
        for ind_1, rydberg_atom_1 in enumerate(rydberg_atoms[:-1]):
            for ind_2, rydberg_atom_2 in enumerate(rydberg_atoms):
                if ind_2 > ind_1:
                    dist = np.linalg.norm(
                        atoms_coordinates[rydberg_atom_1] - atoms_coordinates[rydberg_atom_2]
                    )
                    interaction += rydberg_interaction_coef / (float(dist) ** 6)

        if interaction > 0:
            interactions[(config_index, config_index)] = interaction

    return interactions


def _get_detuning_dict(
    targets: Tuple[int], configurations: List[str]
) -> Dict[Tuple[int, int], float]:
    """Return the dict contains the detuning operators for a set of target atoms.

    Args:
        targets (Tuple[int]): The target atoms of the detuning operator
        configurations (List[str]): The list of configurations that comply with the blockade
            approximation.

    Returns:
        Dict[Tuple[int, int], float]: The dictionary for the detuning operator
    """

    detuning = {}  # The detuning term in the basis of configurations, as a dictionary

    for ind_1, config in enumerate(configurations):
        value = sum([1 for ind_2, item in enumerate(config) if item == "r" and ind_2 in targets])
        if value > 0:
            detuning[(ind_1, ind_1)] = value

    return detuning


def _get_rabi_dict(targets: Tuple[int], configurations: List[str]) -> Dict[Tuple[int, int], float]:
    """Return the dict for the Rabi operators for a set of target atoms.

    Args:
        targets (Tuple[int]): The target atoms of the detuning operator
        configurations (List[str]): The list of configurations that comply with the blockade
            approximation.

    Returns:
        Dict[Tuple[int, int], float]: The dictionary for the Rabi operator

    Note:
        We only save the lower triangular part of the matrix that corresponds
        to the Rabi operator.
    """

    rabi = {}  # The Rabi term in the basis of configurations, as a dictionary

    for ind_1, config_1 in enumerate(configurations):
        for ind_2, config_2 in enumerate(configurations):
            if ind_2 > ind_1:
                # Obtain the indices of the bits where config_1 differ from config_2
                ind_diffs = [
                    ind for ind, (bit1, bit2) in enumerate(zip(config_1, config_2)) if bit1 != bit2
                ]

                # The Rabi term will be nonzero iff the two configurations differ
                # by one and only one bit
                if len(ind_diffs) > 1:
                    continue

                index_diff = ind_diffs[0]  # The index where config_1 differ from config_2

                # If the index_diff is not in the target, then it won't contribute to the
                # Rabi operator
                if index_diff not in targets:
                    continue

                # Only keep the lower triangular part of the Rabi operator
                # In particular, we only add the following component if and only if
                # (config_1[index_diff], config_2[index_diff]) == ("g", "r")
                rabi[(ind_2, ind_1)] = 1
    return rabi


def _get_sparse_from_dict(
    matrix_dict: Dict[Tuple[int, int], float], matrix_dimension: int
) -> scipy.sparse.csr_matrix:
    """Convert a dict to a CSR sparse matrix

    Args:
        matrix_dict (Dict[Tuple[int, int], float]): The dict for the sparse matrix
        matrix_dimension (int): The size of the sparse matrix

    Returns:
        scipy.sparse.csr_matrix: The sparse matrix in CSR format
    """
    rows = [key[0] for key in matrix_dict.keys()]
    cols = [key[1] for key in matrix_dict.keys()]
    return scipy.sparse.csr_matrix(
        tuple([list(matrix_dict.values()), [rows, cols]]),
        shape=(matrix_dimension, matrix_dimension),
    )


def _get_sparse_ops(
    program: Program, configurations: List[str], rydberg_interaction_coef: float
) -> Tuple[
    List[scipy.sparse.csr_matrix],
    List[scipy.sparse.csr_matrix],
    scipy.sparse.csr_matrix,
    List[scipy.sparse.csr_matrix],
]:
    """Returns the sparse matrices for Rabi, detuning, interaction and local detuning detuning
    operators

    Args:
        program (Program): An analog simulation program for Rydberg system
        configurations (List[str]): The list of configurations that comply with the blockade
            approximation.
        rydberg_interaction_coef (float): The interaction coefficient

    Returns:
        Tuple[List[csr_matrix],List[csr_matrix],csr_matrix,List[csr_matrix]]: A tuple containing
        the list of Rabi operators, the list of detuing operators,
        the interaction operator and the list of local detuing operators

    """
    # Get the driving fields as sparse matrices, whose targets are all the atoms in the system
    targets = np.arange(np.count_nonzero(program.setup.ahs_register.filling))
    rabi_dict = _get_rabi_dict(targets, configurations)
    detuning_dict = _get_detuning_dict(targets, configurations)

    # Driving field is an array of operators, which has only one element for now
    rabi_ops = [_get_sparse_from_dict(rabi_dict, len(configurations))]
    detuning_ops = [_get_sparse_from_dict(detuning_dict, len(configurations))]

    # Get the interaction term as a sparse matrix
    interaction_dict = _get_interaction_dict(program, rydberg_interaction_coef, configurations)
    interaction_op = _get_sparse_from_dict(interaction_dict, len(configurations))

    # Get the shifting fields as sparse matrices.
    # Shifting field is an array of operators, which has only one element for now
    local_detuning_ops = []
    for shifting_field in program.hamiltonian.shiftingFields:
        temp = 0
        for site in range(len(shifting_field.magnitude.pattern)):
            strength = shifting_field.magnitude.pattern[site]
            opt = _get_sparse_from_dict(
                _get_detuning_dict((site,), configurations), len(configurations)
            )
            temp += float(strength) * scipy.sparse.csr_matrix(opt, dtype=float)

        local_detuning_ops.append(temp)

    return rabi_ops, detuning_ops, interaction_op, local_detuning_ops


def _interpolate_time_series(
    t: float, times: List[float], values: List[float], method: str = "piecewise_linear"
) -> float:
    """Interpolates the value of a series of time-value pairs at the given time via linear
        interpolation.

    Args:
        t (float): The given time point
        times (List[float]): The list of time points
        values (List[float]): The list of values
        method (str): The method for interpolation, either "piecewise_linear" or
            "piecewise_constant." Default: "piecewise_linear"

    Returns:
        float: The interpolated value of the time series at t
    """

    times = [float(time) for time in times]
    values = [float(value) for value in values]

    if method == "piecewise_linear":
        return np.interp(t, times, values)
    elif method == "piecewise_constant":
        index = np.searchsorted(times, t, side="right") - 1
        return values[index]
    else:
        raise ValueError("`method` can only be `piecewise_linear` or `piecewise_constant`.")


def _get_coefs(
    program: Program, simulation_times: List[float]
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Returns the coefficients for the Rabi operators, detuning operators and local detuning
    operators for all the time points in the analog simulation program.

    Args:
        program (Program): An analog simulation program for Rydberg system
        simulation_times (List[float]): The list of time points

    Returns:
        Tuple[ndarray, ndarray, ndarray]: A tuple containing
        the list of Rabi frequencies, the list of global detuings and
        the list of local detunings
    """
    rabi_coefs, detuning_coefs = [], []

    for driving_field in program.hamiltonian.drivingFields:
        amplitude = driving_field.amplitude.time_series
        phase = driving_field.phase.time_series
        detuning = driving_field.detuning.time_series

        # Get the Rabi part. We use the convention: Omega * exp(1j*phi) * |r><g| + h.c.
        rabi_coef = np.array(
            [
                _interpolate_time_series(
                    t, amplitude.times, amplitude.values, method="piecewise_linear"
                )
                * np.exp(
                    1j
                    * _interpolate_time_series(
                        t, phase.times, phase.values, method="piecewise_constant"
                    )
                )
                for t in simulation_times
            ],
            dtype=complex,
        )
        rabi_coefs.append(rabi_coef)

        # Get the detuning part
        detuning_coef = np.array(
            [
                _interpolate_time_series(
                    t, detuning.times, detuning.values, method="piecewise_linear"
                )
                for t in simulation_times
            ],
            dtype=complex,
        )
        detuning_coefs.append(detuning_coef)

    # add shifting fields
    local_detuing_coefs = []
    for shifting_field in program.hamiltonian.shiftingFields:
        magnitude = shifting_field.magnitude.time_series

        local_detuing_coef = np.array(
            [
                _interpolate_time_series(
                    t, magnitude.times, magnitude.values, method="piecewise_linear"
                )
                for t in simulation_times
            ],
            dtype=complex,
        )
        local_detuing_coefs.append(local_detuing_coef)

    return np.array(rabi_coefs), np.array(detuning_coefs), np.array(local_detuing_coefs)


def _get_ops_coefs(
    program: Program,
    configurations: List[str],
    rydberg_interaction_coef: float,
    simulation_times: List[float],
) -> Tuple[
    List[scipy.sparse.csr_matrix],
    List[scipy.sparse.csr_matrix],
    List[scipy.sparse.csr_matrix],
    np.ndarray,
    np.ndarray,
    np.ndarray,
    scipy.sparse.csr_matrix,
]:
    """Returns the sparse matrices and coefficients for the Rabi terms, detuning terms and
    the local detuining terms, together with the interaction operator in the given analog
    simulation program for Rydberg systems.

    Args:
        program (Program): An analog simulation program for Rydberg system
        configurations (List[str]): The list of configurations that comply to the
            blockade approximation.
        rydberg_interaction_coef (float): The interaction coefficient
        simulation_times (List[float]): The list of time points

    Returns:
        Tuple[
            List[csr_matrix],
            List[csr_matrix],
            List[csr_matrix],
            ndarray,
            ndarray,
            ndarray,
            csr_matrix
        ]: A tuple containing the list of Rabi operators, the list of detuing operators,
        the list of local detuing operators, the list of Rabi frequencies, the list of global
        detuings, the list of local detunings and the interaction operator.
    """

    rabi_ops, detuning_ops, interaction_op, local_detuning_ops = _get_sparse_ops(
        program, configurations, rydberg_interaction_coef
    )
    rabi_coefs, detuning_coefs, local_detuing_coefs = _get_coefs(program, simulation_times)

    return (
        rabi_ops,
        detuning_ops,
        local_detuning_ops,
        rabi_coefs,
        detuning_coefs,
        local_detuing_coefs,
        interaction_op,
    )


def sample_state(state: np.ndarray, shots: int) -> np.ndarray:
    """Sample measurement outcomes from the quantum state `state`

    Args:
        state (ndarray): A state vector
        shots (int): The number of samples

    Returns:
        ndarray: The array for the sample results
    """

    weights = (np.abs(state) ** 2).flatten()
    weights /= sum(weights)
    sample = np.random.multinomial(shots, weights)
    return sample


def _print_progress_bar(num_time_points: int, index_time: int, start_time: float) -> None:
    """Print a lightweight progress bar

    Args:
        num_time_points (int): The total number of time points
        index_time (int): The index of the current time point
        start_time (float): The starting time for the simulation

    """
    if index_time == 0:
        print("0% finished, elapsed time = NA, ETA = NA", flush=True, end="\r")
    else:
        current_time = time.time()
        estimate_time_arrival = (
            (current_time - start_time) / (index_time + 1) * (num_time_points - (index_time + 1))
        )
        print(
            f"{100 * (index_time+1)/num_time_points}% finished, "
            f"elapsed time = {(current_time-start_time)} seconds, "
            f"ETA = {estimate_time_arrival} seconds ",
            flush=True,
            end="\r",
        )


def _get_hamiltonian(
    index_time: int,
    operators_coefficients: Tuple[
        List[scipy.sparse.csr_matrix],
        List[scipy.sparse.csr_matrix],
        List[scipy.sparse.csr_matrix],
        np.ndarray,
        np.ndarray,
        np.ndarray,
        scipy.sparse.csr_matrix,
    ],
) -> scipy.sparse.csr_matrix:
    """Get the Hamiltonian at a given time point

    Args:
        index_time (int): The index of the current time point
        operators_coefficients (Tuple[
            List[csr_matrix],
            List[csr_matrix],
            List[csr_matrix],
            ndarray,
            ndarray,
            ndarray,
            csr_matrix
        ]): A tuple containing the list of Rabi operators, the list of detuing operators,
        the list of local detuing operators, the list of Rabi frequencies, the list of global
        detuings, the list of local detunings and the interaction operator.

    Returns:
        (scipy.sparse.csr_matrix): The Hamiltonian at the given time point as a sparse matrix
    """
    (
        rabi_ops,
        detuning_ops,
        local_detuning_ops,
        rabi_coefs,
        detuning_coefs,
        local_detuing_coefs,
        interaction_op,
    ) = operators_coefficients

    index_time = int(index_time)
    hamiltonian = interaction_op

    # Add the driving fields
    for rabi_op, rabi_coef, detuning_op, detuning_coef in zip(
        rabi_ops, rabi_coefs, detuning_ops, detuning_coefs
    ):
        hamiltonian += (
            rabi_op * rabi_coef[index_time] / 2
            + (rabi_op.T.conj() * np.conj(rabi_coef[index_time]) / 2)
            - detuning_op * detuning_coef[index_time]
        )

    # Add the shifting fields
    for local_detuning_op, local_detuning_coef in zip(local_detuning_ops, local_detuing_coefs):
        hamiltonian -= local_detuning_op * local_detuning_coef[index_time]

    return hamiltonian
