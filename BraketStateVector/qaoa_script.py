import time
import copy
import pickle
import logging
import networkx as nx
from collections import Counter
from typing import FrozenSet, Union, Iterable, Optional

import argparse
import pennylane as qml
import numpy as np
import pennylane.numpy as pnp
import json
import os
from braket_sv import JuliaQubitDevice, init_julia

from braket.tracking import Tracker
t = Tracker().start()
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

jl = init_julia()
#juliapkg.add("Braket", "19504a0f-b47d-4348-9127-acc6cc69ef67", dev=True, path="/Users/hyatkath/.julia/dev/Braket")
#juliapkg.add("BraketStateVector", "4face768-c059-465f-83fa-0d546ea16c1e", dev=True, path="/Users/hyatkath/.julia/dev/Braket/BraketStateVector")
jl.seval('using Pkg; Pkg.activate("."); Pkg.resolve()')
jl.seval('using Braket, BraketStateVector, JSON3, PythonCall')
jl.seval('Braket.IRType[] = :JAQCD')

parser = argparse.ArgumentParser(description='Options for QAOA circuit simulation.')
parser.add_argument("--shot", type=int, default=100)
parser.add_argument("--protocol", type=str, default='qwc')
parser.add_argument("--nv", type=int, default=8)
parser.add_argument('--noise', dest='noise', action='store_true')
parser.add_argument('--no-noise', dest='noise', action='store_false')
parser.add_argument('--use-python', dest='use_python', action='store_true')
parser.set_defaults(noise=False)
parser.set_defaults(use_python=False)
args = parser.parse_args()

n_iter = 20
spsa_iter = 10
diff_method = "parameter-shift"

shot = args.shot
protocol = args.protocol
nv = args.nv
noise = args.noise
use_python = args.use_python
#output_file = args.output
p = 0.5
n_layers = 4

seed = 42
g = nx.erdos_renyi_graph(nv, p=p, seed=seed)
cost_h, mixer_h = qml.qaoa.max_clique(g, constrained=False)

coeffs, obs = cost_h.coeffs, cost_h.ops
cost_h_qwc = qml.Hamiltonian(coeffs, obs, grouping_type="qwc")
n_groups = len(cost_h_qwc.grouping_indices)
if protocol == "qwc":
    cost_h = cost_h_qwc
    scaled_shot = shot
else: # figure out how many groups there are and scale shots
    cost_h.grouping_indices = []
    scaled_shot = shot * n_groups

qubits = nv

print(f"Number of qubits: {qubits}")
print(f"Running with protocol {protocol}, nv {nv}, shots {scaled_shot}, noise {noise}, n_qubits {qubits}:")
dev = get_lightning_device(qubits, scaled_shot, noise=noise) if use_python else get_julia_device(qubits, scaled_shot, noise=noise)
opt = qml.SPSAOptimizer(maxiter=spsa_iter)

def qaoa_layer(gamma, alpha):
    qml.qaoa.cost_layer(gamma, cost_h)
    qml.qaoa.mixer_layer(alpha, mixer_h)

@qml.qnode(dev, diff_method=diff_method)
def shadow_circuit(params):
    for i in range(qubits):  # Prepare an equal superposition over all qubits
        qml.Hadamard(wires=i)

    qml.layer(qaoa_layer, n_layers, params[0], params[1])
    return qml.shadow_expval(cost_h)

@qml.qnode(dev, diff_method=diff_method)
def qwc_circuit(params):
    for i in range(qubits):  # Prepare an equal superposition over all qubits
        qml.Hadamard(wires=i)

    qml.layer(qaoa_layer, n_layers, params[0], params[1])
    return qml.expval(cost_h)

params = np.random.uniform(size=[2, n_layers])
circ = shadow_circuit if protocol == 'shadows' else qwc_circuit
key = {'nv': nv, 'noise': noise, 'shots': shot}

start = time.time()
for opt_iter in range(n_iter):
    params = opt.step(circ, params)
    cost = circ(params)
    print(f"Completed iteration {opt_iter} with cost {cost}")

stop = time.time()
print(f'Simulation total duration: {stop-start}.')

print("Task Summary")
print(t.quantum_tasks_statistics())
print('Note: Charges shown are estimates based on your Amazon Braket simulator and quantum processing unit (QPU) task usage. Estimated charges shown may differ from your actual charges. Estimated charges do not factor in any discounts or credits, and you may experience additional charges based on your use of other services such as Amazon Elastic Compute Cloud (Amazon EC2).')
print(f"Estimated cost to run this example: {t.qpu_tasks_cost() + t.simulator_tasks_cost():.3f} USD")

#key = key.update({"results": result})
with open(os.path.join(os.getenv("HOME"), f"qaoa_{nv}_{shot}_{noise}_sv1.pickle"), 'wb') as fi:
    pickle.dump(key, fi)
