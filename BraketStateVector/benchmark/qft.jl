suite["qft"] = BenchmarkGroup()

function qft_circuit(qubit_count::Int)
    qft_circ = Circuit()
    for target_qubit = 0:qubit_count-1
        angle = π / 2
        H(qft_circ, target_qubit)
        for control_qubit = target_qubit+1:qubit_count-1
            CPhaseShift(qft_circ, control_qubit, target_qubit, angle)
            angle /= 2
        end
    end
    return qft_circ
end

function braket_sv_qft(qubit_count::Int)
    qft_ops = []
    for target_qubit in 0:qubit_count-1
        angle = π / 2
        push!(qft_ops, gate_operations.Hadamard([target_qubit]))
        for control_qubit in target_qubit + 1:qubit_count-1
            push!(qft_ops, gate_operations.CPhaseShift([control_qubit, target_qubit], angle))
            angle /= 2
        end
    end
    return qft_ops
end
    
function pl_qft(qubit_count::Int)
    qft_ops = [qml.PauliX(0)]
    push!(qft_ops, qml.QFT(wires=collect(0:qubit_count-1)))
    tape = qml.tape.QuantumTape(qft_ops, [qml.expval(qml.operation.Tensor(qml.PauliZ(0), qml.PauliX(1)))])
    return tape.expand(depth=5)
end

for n_qubits in 4:30
    shots = 100
    suite["qft"][(string(n_qubits), string(shots))] = BenchmarkGroup()
    g = suite["qft"][(string(n_qubits), string(shots))]
    g["Julia"] = @benchmarkable sim(circ, shots=shots) setup = (sim=LocalSimulator("braket_sv"); circ = qft_circuit($n_qubits))
    g["Lightning.Qubit"] = @benchmarkable sim.execute(circ) setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=shots); circ = pl_qft($n_qubits))
    g["Qiskit.Aer"]      = @benchmarkable sim.backend.run(circ, shots=shots).result()  setup = (sim=qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=$n_qubits, shots=shots, statevector_parallel_threshold=8); circ = sim.compile_circuits(pylist([pl_qft($n_qubits)])))
end

for n_qubits in 4:32
    shots = 0
    suite["qft"][(string(n_qubits), string(shots))] = BenchmarkGroup()
    g = suite["qft"][(string(n_qubits), string(shots))]
    g["Julia"] = @benchmarkable sim(circ, shots=shots) setup = (sim=LocalSimulator("braket_sv"); circ = qft_circuit($n_qubits))
    g["Lightning.Qubit"] = @benchmarkable sim.execute(circ) setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=shots); circ = pl_qft($n_qubits))
end
