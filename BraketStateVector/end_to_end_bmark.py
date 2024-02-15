from braket.circuits import Circuit, Observable
from braket.devices import LocalSimulator
from braket_sv import JuliaLocalSimulator
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

py_sim = LocalSimulator("braket_sv")
jl_sim = JuliaLocalSimulator("braket_sv")

# run once to precompile
jl_sim.run(ghz_circuit(4), shots=100).result()

with cProfile.Profile() as pr:
    for nq in range(4, 24):
        circ = ghz_circuit(nq)
        start = time.time()
        py_sim.run(circ, shots=100).result()
        stop = time.time()
        print(f"Time to execute {nq}-qubit GHZ circuit with Python simulator: {stop-start}.") 
        start = time.time()
        jl_sim.run(circ, shots=100).result()
        stop = time.time()
        print(f"Time to execute {nq}-qubit GHZ circuit with Julia simulator: {stop-start}.") 

    pr.dump_stats('/tmp/tmp.prof')