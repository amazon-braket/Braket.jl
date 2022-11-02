import time
from typing import List

import numpy as np
from braket.ir.ahs.program_v1 import Program

from braket.analog_hamiltonian_simulator.rydberg.rydberg_simulator_helpers import (
    _get_hamiltonian,
    _get_ops_coefs,
    _print_progress_bar,
)

# define the Butcher tableau
_ORDER = 6
_A = [
    [5 / 36, 2 / 9 - 1 / np.sqrt(15), 5 / 36 - np.sqrt(15) / 30],
    [5 / 36 + np.sqrt(15) / 24, 2 / 9, 5 / 36 - np.sqrt(15) / 24],
    [5 / 36 + np.sqrt(15) / 30, 2 / 9 + 1 / np.sqrt(15), 5 / 36],
]
_B = [5 / 18, 4 / 9, 5 / 18]
_C = [1 / 2 - np.sqrt(15) / 10, 1 / 2, 1 / 2 + np.sqrt(15) / 10]

_STAGES = int(_ORDER / 2)

_EIGVALS_A, _EIGVECS_A = np.linalg.eig(_A)
_INV_EIGVECS_A = np.linalg.inv(_EIGVECS_A)


def rk_run(
    program: Program,
    configurations: List[str],
    simulation_times: List[float],
    rydberg_interaction_coef: float,
    progress_bar: bool = False,
) -> np.ndarray:
    """
    Implement the implicit Runge-Kutta method of order 6 for solving the schrodinger equation

    Args:
        program (Program): An analog simulation program for a Rydberg system
        configurations (List[str]): The list of configurations that comply with the
            blockade approximation.
        simulation_times (List[float]): The list of time points
        rydberg_interaction_coef (float): The interaction coefficient
        progress_bar (bool): If true, a progress bar will be printed during the simulation.
            Default: False

    Returns:
        ndarray: The list of all the intermediate states in the simulation.

    Notes on the algorithm: For more details, please refer to
        https://en.wikipedia.org/wiki/Gauss-Legendre_method
    """

    operators_coefficients = _get_ops_coefs(
        program, configurations, rydberg_interaction_coef, simulation_times
    )

    # Define the initial state for the simulation
    size_hilbert_space = len(configurations)
    state = np.zeros(size_hilbert_space)
    state[0] = 1

    states = [state]  # The history of all intermediate states

    if len(simulation_times) == 1:
        return states

    dt = simulation_times[1] - simulation_times[0]  # The time step for the simulation
    start_time = 0
    for index_time, _ in enumerate(simulation_times[1:]):

        if progress_bar:  # print a lightweight progress bar
            start_time = time.time()
            _print_progress_bar(len(simulation_times), index_time, start_time)

        x = states[-1]
        hamiltonian = _get_hamiltonian(index_time, operators_coefficients)

        # The start of implicit RK method for updating the state
        # For more details of the algorithm, see the reference above

        # Define k0,...,ks
        x1 = -1j * hamiltonian.dot(x)
        x2 = -1j * hamiltonian.dot(x1)
        x3 = -1j * hamiltonian.dot(x2)

        kk = [x1 + _C[i] * dt * x2 for i in range(_STAGES)]

        kx = [
            kk[i]
            - x1
            - dt * np.sum([_A[i][j] * (x2 + _C[j] * dt * x3) for j in range(_STAGES)], axis=0)
            for i in range(_STAGES)
        ]

        dk_tilde = [
            np.linalg.solve(
                np.eye(size_hilbert_space) + 1j * dt * _EIGVALS_A[i] * hamiltonian,
                np.sum([_INV_EIGVECS_A[i][j] * kx[j] for j in range(_STAGES)], axis=0),
            )
            for i in range(_STAGES)
        ]

        dk = [
            np.sum([_EIGVECS_A[i][j] * dk_tilde[j] for j in range(_STAGES)], axis=0)
            for i in range(_STAGES)
        ]

        kk = np.array(kk) - dk

        delta_state = dt * np.array(_B).dot(kk)  # The update of the state

        # The end of the implicit RK method for updating the state

        # Update the state, and save it
        state = x + delta_state
        states.append(state)

    return states
