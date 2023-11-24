calculate(sv::Braket.StateVector,   sim::AbstractSimulator) = state_vector(sim)  
calculate(dm::Braket.DensityMatrix, sim::AbstractSimulator, targets=[]) = density_matrix(sim, targets)
function calculate(a::Braket.Amplitude, sim::AbstractSimulator)
    state = state_vector(sim)
    state_ints = [sum(tryparse(Int, string(amp_state[k]))*2^(k-1) for k=1:length(amp_state)) for amp_state in a.states]
    return Dict(basis_state=>state[state_int+1] for (basis_state, state_int) in zip(a.states, state_ints))
end

function marginal_probability(probs::Vector, qubit_count::Int, targets)
    unused_qubits = setdiff(collect(0:qubit_count-1), targets)
    probs_as_tensor = reshape(probs, fill(2, qubit_count)...)
    # must fix endian-ness!
    endian_unused = qubit_count .- unused_qubits 
    summed = dropdims(mapslices(sum, probs_as_tensor; dims=endian_unused); dims=tuple(endian_unused...))
    perm = indexin(sort(targets), collect(targets)) 
    return vec(permutedims(summed, perm))
end

function calculate(p::Braket.Probability, sim::AbstractSimulator, targets=[])
    probs = probabilities(sim)
    qc = qubit_count(sim)
    (isempty(targets) || targets == collect(0:qc-1)) && return probs
    return marginal_probability(probs, qc, targets)
end

calculate(ex::Braket.Expectation, sim::AbstractSimulator) = expectation(sim, ex.observable, ex.targets)
function calculate(var::Braket.Variance, sim::AbstractSimulator)
    var2 = expectation(sim, var.observable * var.observable, var.targets)
    mean = expectation(sim, var.observable, var.targets)
    return var2 - mean^2
end
