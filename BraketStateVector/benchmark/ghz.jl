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
    suite["ghz"][string(n_qubits)] = BenchmarkGroup()
    suite["ghz"][string(n_qubits)]["Julia"]           = @benchmarkable sim(circ, shots=100) setup = (sim=LocalSimulator("braket_sv"); circ = ghz_circuit($n_qubits))
    suite["ghz"][string(n_qubits)]["Lightning.Qubit"] = @benchmarkable sim.execute(circ) setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=100); circ = pl_ghz($n_qubits))
    suite["ghz"][string(n_qubits)]["Qiskit.Aer"]      = @benchmarkable sim.backend.run(circ, shots=100).result()  setup = (sim=qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=$n_qubits, shots=100, statevector_parallel_threshold=8); circ = sim.compile_circuits(pylist([pl_ghz($n_qubits)])))
    #suite["ghz"][string(n_qubits)]["BraketSV"] = @benchmarkable py_sv.evolve(py_ghz_ops) setup = (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1); py_ghz_ops = braket_sv_ghz($n_qubits))
end
