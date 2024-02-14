suite["vqe"] = BenchmarkGroup()

for n_electrons in 4:2:4
    @show n_electrons
    mol = "H"*string(n_electrons)
    suite["vqe"][mol] = BenchmarkGroup()
    
    n_qubits    = 2*n_electrons
    hf_state    = qml.qchem.hf_state(n_electrons, n_qubits)
    symbols     = ["H" for ix in 1:n_electrons]
    jl_coords   = zeros(Float64, 3*n_electrons)
    for e in 1:n_electrons
        jl_coords[3*e] = (e-1) * 0.8
    end
    coordinates = np.array(jl_coords)
    H, qubits   = qml.qchem.molecular_hamiltonian(symbols, coordinates, method="pyscf")
    coeffs, obs = H.coeffs, H.ops
    H           = qml.Hamiltonian(coeffs, obs, grouping_type="qwc")
    println("Computed H with grouping indices...")
    flush(stdout)
    singles, doubles = qml.qchem.excitations(n_electrons, qubits)
    all_exs = singles + doubles
    #ops = [qml.BasisState(hf_state, wires=collect(0:n_qubits-1))]
    ops = [qml.PauliX(q) for q in 0:n_electrons-1]
    for (i, gate) in enumerate(all_exs)
        if length(gate) == 4
            push!(ops, qml.DoubleExcitation(pnp.tensor(0.0, requires_grad=true), wires=gate))
        elseif length(gate) == 2
            push!(ops, qml.SingleExcitation(pnp.tensor(0.0, requires_grad=true), wires=gate))
        end
    end
    tapes          = []
    expanded_tapes = []
    qiskit_tapes   = []
    qiskit_sim     = qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=n_qubits, shots=100, statevector_parallel_threshold=8)
    for inds in H.grouping_indices
        c = [H.coeffs[i] for i in inds]
        o = [H.ops[i] for i in inds]
        measurements  = [qml.expval(o[i]) for i in 1:length(inds)]
        tape          = qml.tape.QuantumTape(ops, measurements)
        grad_tapes, _ = qml.gradients.param_shift(tape)
        append!(tapes, [t for t in grad_tapes])
        wider_tapes = [t.expand(depth=5) for t in grad_tapes]
        append!(expanded_tapes, wider_tapes)
        println("\tCompiling qiskit tapes for inds $inds.")
        compiled_tapes = qiskit_sim.compile_circuits(wider_tapes)
        append!(qiskit_tapes, compiled_tapes)
    end
    println("Ready to actually launch benchmarks...")
    flush(stdout)
    suite["vqe"][mol]["Julia"]           = @benchmarkable sim(pylist($tapes), input_dict, shots=100)         setup = (sim=LocalSimulator("braket_sv"); input_dict=pylist([pydict(Dict())]))
    suite["vqe"][mol]["Lightning.Qubit"] = @benchmarkable sim.batch_execute($tapes)                          setup = (sim=qml.device("lightning.qubit", wires=$n_qubits, shots=100))
    suite["vqe"][mol]["Qiskit.Aer"]      = @benchmarkable sim.backend.run($qiskit_tapes, shots=100).result() setup = (sim=qml.device("qiskit.aer", backend="aer_simulator_statevector", wires=$n_qubits, shots=100, statevector_parallel_threshold=8))
    #suite["vqe"][mol]["BraketSV"] = @benchmarkable sim.batch_execute($expanded_tapes)        setup = (sim=qml.device("braket.local.qubit", wires=$n_qubits, shots=100))
end
