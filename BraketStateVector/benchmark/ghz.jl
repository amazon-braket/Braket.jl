suite["ghz"] = BenchmarkGroup()

function ghz_circuit(qubit_count::Int)
    ghz_circ = Circuit()
    H(ghz_circ, 0)
    for target_qubit = 1:qubit_count-1
        CNot(ghz_circ, 0, target_qubit)
    end
    return ghz_circ 
end

function braket_sv_ghz(qubit_count::Int)
    ghz_ops = []
    push!(ghz_ops, gate_operations.Hadamard([0]))
    for target_qubit in 1:qubit_count-1
        push!(ghz_ops, gate_operations.CNot([0, target_qubit]))
    end
    return ghz_ops
end

function pl_ghz(qubit_count::Int)
    ops = [qml.Hadamard(0)]
    for target_qubit in 1:qubit_count -1
        push!(ops, qml.CNOT([0, target_qubit]))
    end
    return qml.tape.QuantumTape(ops, [qml.sample()])
end

for n_qubits in 4:30
    shots = 100
    suite["ghz"][(string(n_qubits), string(shots))] = BenchmarkGroup()
    g = suite["ghz"][(string(n_qubits), string(shots))]
    g["Julia"]           = @benchmarkable sim(circ, shots=shots) setup = (sim=LocalSimulator("braket_sv"); circ = ghz_circuit($n_qubits))
    g["Lightning.Qubit"] = @benchmarkable sim.execute(circ) setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=shots); circ = pl_ghz($n_qubits))
    g["Qiskit.Aer"]      = @benchmarkable sim.backend.run(circ, shots=shots).result()  setup = (sim=qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=$n_qubits, shots=shots, statevector_parallel_threshold=8); circ = sim.compile_circuits(pylist([pl_ghz($n_qubits)])))
end

for n_qubits in 4:32
    shots = 0
    suite["ghz"][(string(n_qubits), string(shots))] = BenchmarkGroup()
    g = suite["ghz"][(string(n_qubits), string(shots))]
    g["Julia"]           = @benchmarkable sim(circ, shots=shots) setup = (sim=LocalSimulator("braket_sv"); circ = ghz_circuit($n_qubits))
    g["Lightning.Qubit"] = @benchmarkable sim.execute(circ) setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=shots); circ = pl_ghz($n_qubits))
end
