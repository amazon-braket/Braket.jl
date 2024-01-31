import time
import socket
import copy
import pickle
import logging
from collections import Counter
from typing import FrozenSet, Union, Iterable, Optional
import juliapkg
import argparse
import pennylane as qml
import numpy as np
import pennylane.qchem as qchem
import pennylane.numpy as pnp
import json
import os

from braket.circuits.noise_model import (
    GateCriteria,
    NoiseModel,
    ObservableCriteria,
    QubitInitializationCriteria,
)
from braket.circuits.noises import (
    AmplitudeDamping,
    BitFlip,
    Depolarizing,
    PauliChannel,
    PhaseDamping,
    PhaseFlip,
    TwoQubitDepolarizing,
)

from braket_sv import JuliaQubitDevice, init_julia

def noise_model():
    m = NoiseModel()
    m.add_noise(Depolarizing(1 - 0.9981), GateCriteria())
    m.add_noise(TwoQubitDepolarizing(1 - 0.9311), GateCriteria(gates=Gate.CNot))
    m.add_noise(BitFlip(1 - 0.99752), ObservableCriteria(observables=Observable.Z))
    return m

def get_julia_device(n_wires: int, shots, noise: bool = False):
    default_dev = "braket_dm" if noise else "braket_sv"
    nm = noise_model() if noise else None
    return JuliaQubitDevice(n_wires, default_dev, shots=shots, noise_model=nm)

def get_python_device(n_wires: int, shots, noise: bool = False):
    default_dev = "braket_dm" if noise else "braket_sv"
    nm = noise_model() if noise else None
    return qml.device("braket.local.qubit", backend=default_dev, wires=n_wires, shots=shots, noise_model=nm)

def get_lightning_device(n_wires: int, shots, noise: bool = False):
    return qml.device("lightning.qubit", wires=n_wires, shots=shots)

def get_touched_qubits(ex):
    return set().union(ex)

def run_adapt(
    circ,
    excitation_pool,
    opt,
    E,
    cutoff: float,
    n_wires: int,
    max_adapt_iter: int,
    max_opt_iter: int,
    key: dict,
    previous_progress: dict = {},
    drain_pool: bool = False,
):
    selected_excitations = previous_progress.get("excitations", [])
    selected_params = previous_progress.get("params", [])
    adapt_iter = previous_progress.get("adapt_iter", 0)
    prev_E_estimate = 1e5
    E_estimate = 1e6
    gradient_circ = qml.grad(circ, argnum=0)
    progress_tracker = {}
    mol = key["mol"]
    protocol = key["protocol"]
    shot = key["shots"]
    noise = key["noise"]
    while adapt_iter < max_adapt_iter and len(excitation_pool) > 0:
        # compute initial gradients
        progress_tracker[adapt_iter] = {} 
        params = [0.0]*len(excitation_pool)
        start = time.time()
        print(f"Compute gradients for {key} at iter {adapt_iter}", flush=True)
        ex_grad = gradient_circ(params, excitation_pool, selected_params, selected_excitations)
        #ex_grad = [0.0]*len(excitation_pool)
        #for ix in range(len(excitation_pool)):
        #    g_start = time.time()
        #    ex_grad[ix] = gradient_circ([params[ix]], [excitation_pool[ix]], selected_params, selected_excitations)
        #    g_stop = time.time()
        #    print(f"Done computing {ix}-th gradient. Duration: {g_stop-g_start}.", flush=True)
        stop = time.time()
        print(f"Done computing gradients. Duration: {stop-start}.", flush=True)
        exit(1)
        grads = [
            -abs(ex_grad[ix].numpy())
            if isinstance(ex_grad[ix], pnp.tensor)
            else -abs(ex_grad[ix])
            for ix in range(len(ex_grad))
        ]

        # sort excitations by gradient magnitude
        sorted_inds = pnp.argsort(grads)
        select_this_round = [sorted_inds[0].numpy()]
        progress_tracker[adapt_iter]["largest_grad"] = abs(grads[sorted_inds[0]])
        # need to handle qubits properly here!
        touched_qubits = get_touched_qubits(excitation_pool[select_this_round[0]])
        progress_tracker[adapt_iter]["touched_qubits"] = touched_qubits
        opt_ex = [excitation_pool[ix] for ix in select_this_round]
        opt_params = [0.0 for ix in select_this_round]
        start = time.time()
        print(f"Begin optimization for {key} at iter {adapt_iter}")
        # do one round of optimization
        for n in range(max_opt_iter):
            opt_params_tensor = pnp.tensor(opt_params)
            opt_params_tensor = opt.step(
                circ,
                opt_params_tensor,
                opt_ex,
                selected_params,
                selected_excitations,
            )
            opt_params = opt_params_tensor[0].numpy().tolist()
        stop = time.time()
        print(f"Complete optimization for {key} at iter {adapt_iter}. Duration: {stop-start}.")
        # get final energy from this optimization round
        E_estimate = circ(opt_params, opt_ex, selected_params, selected_excitations)
        # now add selected excitations to the Ansatz
        selected_excitations.extend([excitation_pool[ix] for ix in select_this_round])
        selected_params.extend(opt_params)
        print(f"Largest grad: {grads[select_this_round[0]]}, E_estimate: {E_estimate}, Error: {np.abs(E_estimate-E)} at iteration {adapt_iter} for {key}")
        progress_tracker[adapt_iter]["E_estimate"] = E_estimate 
        progress_tracker[adapt_iter]["E_error"] = abs(E_estimate-E)

        qsm = circ.tape.to_openqasm()
        progress_tracker[adapt_iter]["circuit_qasm"] = qsm
        progress_tracker[adapt_iter]["params"] = selected_params
        progress_tracker[adapt_iter]["excitations"] = selected_excitations 

        with open(os.path.join(os.getenv("HOME"), f"vqe_{mol}_{protocol}_{shot}_{noise}_{adapt_iter}.pickle"), 'wb') as fi:
            pickle.dump(progress_tracker[adapt_iter], fi)
        if abs(grads[sorted_inds[0]]) <= cutoff:
            break
        prev_E_estimate = E_estimate
        adapt_iter += 1

    return progress_tracker

jl = init_julia()
juliapkg.add("Braket", "19504a0f-b47d-4348-9127-acc6cc69ef67", dev=True, path=os.getenv("HOME") + "/.julia/dev/Braket")
juliapkg.add("BraketStateVector", "4face768-c059-465f-83fa-0d546ea16c1e", dev=True, path=os.getenv("HOME") + "/.julia/dev/Braket/BraketStateVector")
jl.seval('using Pkg; Pkg.activate("."); Pkg.resolve()')
jl.seval('using Braket, BraketStateVector, JSON3, PythonCall')
jl.seval('Braket.IRType[] = :JAQCD')

parser = argparse.ArgumentParser(description='Options for VQE circuit simulation.')
parser.add_argument("--shot", type=int, default=100)
parser.add_argument("--protocol", type=str, default="shadows")
parser.add_argument("--mol", type=str, default="H6")
parser.add_argument('--noise', dest='noise', action='store_true')
parser.add_argument('--no-noise', dest='noise', action='store_false')
parser.add_argument('--prevprog', type=str, default="")
parser.add_argument('--use-python', dest='use_python', action='store_true')
parser.set_defaults(noise=False)
parser.set_defaults(use_python=False)
args = parser.parse_args()

previous_progress = {}
if args.prevprog:
    with open(args.prevprog, 'rb') as fi:
        prev_data = pickle.load(fi)

    file_name = os.path.basename(args.prevprog)

    previous_progress['excitations'] = prev_data['excitations']
    previous_progress['params'] = prev_data['params']
    # figure out adapt_iter
    suffix = file_name.split('_')[-1]
    adapt_iter = int(suffix.split('.')[0]) + 1
    previous_progress['adapt_iter'] = adapt_iter

grad_cutoff = 1e-5
stepsize = 0.5
n_iter = 20
spsa_iter = 10
adapt_iter = 1
cutoff = 1e-3
diff_method = "parameter-shift"
encoding = "jordan_wigner"
bond_lengths = {"H2": 0.7, "H4": 0.8, "H6": 0.8, "H8": 0.8, "H10": 1.0, "LiH": 1.71}

shot = args.shot
protocol = args.protocol
mol = args.mol
noise = args.noise
use_python = args.use_python
#output_file = args.output

datasets = qml.data.load("qchem", molname=mol, basis="STO-3G", bondlength=bond_lengths[mol])
dset = datasets[0]
E = dset.fci_energy
molecule = dset.molecule
n_electrons = molecule.n_electrons
n_orbitals = molecule.n_orbitals
H = dset.hamiltonian
#H, qubits = qml.qchem.molecular_hamiltonian(
#    molecule.symbols,
#    molecule.coordinates,
#    basis=molecule.basis_name,
#    active_electrons=n_electrons,
#    active_orbitals=n_orbitals,
#    mapping=encoding,
#    method="pyscf",
#)
qubits = len(H.wires)
hf_state = dset.hf_state
print(hf_state, flush=True)
scaled_shot = shot
coeffs, obs = H.coeffs, H.ops
H_qwc = qml.Hamiltonian(coeffs, obs, grouping_type="qwc")
#H.grouping_indices = dset.qwc_groupings
#H_qwc = H
n_groups = len(H_qwc.grouping_indices)
all_exs = []
# number of up- and down-spin electrons
singles, doubles = qchem.excitations(n_electrons, qubits)
all_exs = doubles + singles

if protocol == "qwc":
    H = H_qwc 
else: # figure out how many groups there are and scale shots
    scaled_shot = shot * n_groups
            
print("FCI energy:", dset.fci_energy, " VQE energy: ", dset.vqe_energy)
print(f"Number of qubits: {qubits}, number of groups: {n_groups}, number of excitations: {len(all_exs)}")
print(f"Running with protocol {protocol}, encoding {encoding}, molecule {mol}, shots {scaled_shot}, noise {noise}, n_qubits {qubits}:", flush=True)
#dev = get_python_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
dev = get_lightning_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
opt = qml.SPSAOptimizer(maxiter=n_iter)
                
@qml.qnode(dev, diff_method=diff_method)
def shadow_circuit(
    params, excitations, params_select, gates_select
):
    qml.BasisState(hf_state, wires=range(qubits))

    for i, gate in enumerate(gates_select):
        if len(gate) == 4:
            qml.DoubleExcitation(params_select[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params_select[i], wires=gate)

    for i, gate in enumerate(excitations):
        if len(gate) == 4:
            qml.DoubleExcitation(params[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params[i], wires=gate)
    return qml.shadow_expval(H)

@qml.qnode(dev, diff_method=diff_method)
def qwc_circuit(
    params, excitations, params_select, gates_select
):
    qml.BasisState(hf_state, wires=range(qubits))
    for i, gate in enumerate(gates_select):
        if len(gate) == 4:
            qml.DoubleExcitation(params_select[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params_select[i], wires=gate)

    for i, gate in enumerate(excitations):
        if len(gate) == 4:
            qml.DoubleExcitation(params[i], wires=gate)
        elif len(gate) == 2:
            qml.SingleExcitation(params[i], wires=gate)
    return qml.expval(H)

circ = shadow_circuit if protocol == 'shadows' else qwc_circuit
key = {'mol': mol, 'noise': noise, 'protocol': protocol, 'shots': shot}

start = time.time()
result = run_adapt(
                    circ,
                    copy.deepcopy(all_exs),
                    opt,
                    E,
                    cutoff,
                    qubits,
                    adapt_iter,
                    n_iter,
                    key,
                    previous_progress,
                )

stop = time.time()
print(f'Simulation total duration: {stop-start}.')

key = key.update({"results": result})
with open(os.path.join(os.getenv("HOME"), f"vqe_{mol}_{protocol}_{shot}_{noise}.pickle"), 'wb') as fi:
    pickle.dump(key, fi)
