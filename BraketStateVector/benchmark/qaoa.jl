suite["qaoa"] = BenchmarkGroup()

p    = 0.5
seed = 42
# Aer only supports up to 31 qubits
for n_qubits in 4:30, n_layers in 1:4
    suite["qaoa"][(string(n_qubits), string(n_layers))] = BenchmarkGroup()
    γ = 0.2
    α = 0.4
    g = nx.erdos_renyi_graph(n_qubits, p=p, seed=seed)
    cost_h, mixer_h = qml.qaoa.max_clique(g, constrained=false)
    ops = [qml.Hadamard(i) for i in 0:n_qubits-1]
    for layer in 1:n_layers
        cl_op = qml.templates.ApproxTimeEvolution(cost_h, γ, 1)
        push!(ops, cl_op)
        ml_op = qml.templates.ApproxTimeEvolution(mixer_h, α, 1)
        push!(ops, ml_op)
    end
    measurements   = [qml.expval(o) for (c,o) in zip(cost_h.coeffs, cost_h.ops)]
    tapes          = [qml.tape.QuantumTape(ops, measurements)]
    qiskit_tapes   = []
    qiskit_sim     = qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=n_qubits, shots=100, statevector_parallel_threshold=8)
    wider_tapes    = [t.expand(depth=5) for t in tapes]
    qiskit_tapes   = qiskit_sim.compile_circuits(wider_tapes)
    
    suite["qaoa"][(string(n_qubits), string(n_layers))]["Julia"]    = @benchmarkable sim(pylist($wider_tapes), input_dict, shots=100)   setup = (sim=LocalSimulator("braket_sv"); input_dict=pylist([pydict(Dict())]))
    suite["qaoa"][(string(n_qubits), string(n_layers))]["Lightning.Qubit"] = @benchmarkable sim.batch_execute($wider_tapes)       setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=100))
    suite["qaoa"][(string(n_qubits), string(n_layers))]["Qiskit.Aer"] = @benchmarkable sim.backend.run($qiskit_tapes, shots=100).result()  setup = (sim=qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=$n_qubits, shots=100, statevector_parallel_threshold=8))
    #suite["qaoa"][(string(n_qubits), string(n_layers))]["BraketSV"] = @benchmarkable sim.batch_execute($expanded_tapes)        setup = (sim=qml.device("braket.local.qubit", wires=$n_qubits, shots=100))
end
