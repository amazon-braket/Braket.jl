from braket.circuits import Circuit, Observable
from braket.devices import LocalSimulator
from braket_sv import JuliaLocalSimulator
import numpy as np
import time
import cProfile

def ghz_circuit(n_qubits):
    # instantiate circuit object
    circuit = Circuit()

    # add Hadamard gate on first qubit
    circuit.h(0)

    # apply series of CNOT gates
    for ii in range(0, n_qubits-1):
        circuit.cnot(control=ii, target=ii+1)
    return circuit

def qft_circuit(n_qubits):
    # instantiate circuit object
    circuit = Circuit()

    for target_qubit in range(n_qubits):
        angle = np.pi / 2
        circuit.h(target_qubit)
        for control_qubit in range(target_qubit + 1, n_qubits):
            circuit.cphaseshift(control=control_qubit, target=target_qubit, angle=angle)
            angle /= 2
    return circuit

py_sim = LocalSimulator("braket_sv")
jl_sim = JuliaLocalSimulator("braket_sv")

# run once to precompile
jl_sim.run(ghz_circuit(4), shots=100).result()
jl_sim.run(qft_circuit(4), shots=100).result()
print("Begin profiling run...", flush=True)
with cProfile.Profile() as pr:
    for nq in range(30, 31):
        for (circ_fn, fn_str) in ((ghz_circuit, "GHZ"), (qft_circuit, "QFT")):
            circ = circ_fn(nq)
            start = time.time()
            py_sim.run(circ, shots=100).result()
            stop = time.time()
            print(f"Time to execute {nq}-qubit {fn_str} circuit with Python simulator: {stop-start}.") 
            start = time.time()
            jl_sim.run(circ, shots=100).result()
            stop = time.time()
            print(f"Time to execute {nq}-qubit {fn_str} circuit with Julia simulator: {stop-start}.") 

    pr.dump_stats('/tmp/tmp.prof')
