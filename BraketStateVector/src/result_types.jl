function samples(s::AbstractSimulator)
    wv = Weights(probabilities(s))
    n = 2^s.qubit_count
    inds = 0:(n-1)
    ap = s._ap
    alias = s._alias
    StatsBase.make_alias_table!(wv, sum(wv), ap, alias)
    rng = Random.default_rng()
    sampler = Random.Sampler(rng, 1:n)
    for i = 1:s.shots
        j = rand(rng, sampler)
        s.shot_buffer[i] = rand(rng) < ap[j] ? j-1 : alias[j]-1
    end
    return s.shot_buffer
end


calculate(sv::Braket.StateVector, sim::AbstractSimulator) = state_vector(sim)
function calculate(a::Braket.Amplitude, sim::AbstractSimulator)
    state = collect(state_vector(sim))
    rev_states = reverse.(a.states)
    state_ints = [
        sum(tryparse(Int, string(amp_state[k])) * 2^(k - 1) for k = 1:length(amp_state)) for amp_state in rev_states
    ]
    return Dict(
        basis_state => state[state_int+1] for
        (basis_state, state_int) in zip(a.states, state_ints)
    )
end

function marginal_probability(probs::Vector{T}, qubit_count::Int, targets) where {T<:Real}
    unused_qubits = setdiff(collect(0:qubit_count-1), targets)
    endian_unused = qubit_count .- unused_qubits .- 1
    final_probs = zeros(Float64, 2^length(targets))
    q_combos = vcat([Int[]], collect(combinations(endian_unused)))
    Threads.@threads for ix = 0:2^length(targets)-1
        padded_ix = ix
        for pad_q in sort(endian_unused)
            padded_ix = pad_bit(padded_ix, pad_q)
        end
        flipped_inds = Vector{Int64}(undef, length(q_combos))
        for (c_ix, flipped_qs) in enumerate(q_combos)
            flipped_ix = padded_ix
            for flip_q in flipped_qs
                flipped_ix = flip_bit(flipped_ix, flip_q)
            end
            flipped_inds[c_ix] = flipped_ix + 1
        end
        @views begin
            @inbounds sum_val = sum(probs[flipped_inds])
            final_probs[ix+1] = sum_val
        end
    end
    return final_probs
end

function calculate(p::Braket.Probability, sim::AbstractSimulator)
    targets = p.targets
    probs = probabilities(sim)
    qc = qubit_count(sim)
    (isempty(targets) || targets == collect(0:qc-1)) && return probs
    return marginal_probability(probs, qc, targets)
end

function calculate(ex::Braket.Expectation, sim::AbstractSimulator)
    obs = ex.observable
    targets = isnothing(ex.targets) ? collect(0:qubit_count(sim)-1) : ex.targets
    obs_qc = qubit_count(obs)
    length(targets) == obs_qc && return expectation(sim, obs, targets...)
    return [expectation(sim, obs, target) for target in targets]
end
expectation_op_squared(sim, obs::Braket.Observables.StandardObservable, target::Int) = 1.0
expectation_op_squared(sim, obs::Braket.Observables.I, target::Int) = 1.0
function expectation_op_squared(sim, obs::Braket.Observables.TensorProduct, targets::Int...)
    all(
        f isa Braket.Observables.StandardObservable || f isa Braket.Observables.I for
        f in obs.factors
    ) && return 1.0
    sq_factors = map(obs.factors) do f
        (f isa Braket.Observables.StandardObservable || f isa Braket.Observables.I) &&
            return Braket.Observables.I()
        f isa Braket.Observables.HermitianObservable &&
            return Braket.Observables.HermitianObservable(f.matrix * f.matrix)
    end
    sq_tensor_prod = Braket.Observables.TensorProduct(sq_factors)
    return expectation(sim, sq_tensor_prod, targets...)
end
function expectation_op_squared(
    sim,
    obs::Braket.Observables.HermitianObservable,
    targets::Int...,
)
    return expectation(
        sim,
        Braket.Observables.HermitianObservable(obs.matrix * obs.matrix),
        targets...,
    )
end

function apply_observable!(
    observable::Braket.Observables.TensorProduct,
    sv_or_dm::T,
    targets::Int...,
) where {T<:AbstractVecOrMat{<:Complex}}
    target_ix = 1
    for f in observable.factors
        f_n_qubits = qubit_count(f)
        f_targets =
            f_n_qubits == 1 ? targets[target_ix] : targets[target_ix:target_ix+f_n_qubits-1]
        target_ix += f_n_qubits
        sv_or_dm = apply_observable!(f, sv_or_dm, f_targets...)
    end
    return sv_or_dm
end
apply_observable(
    observable::O,
    sv_or_dm,
    target::Int...,
) where {O<:Braket.Observables.Observable} =
    apply_observable!(observable, deepcopy(sv_or_dm), target...)

function calculate(var::Braket.Variance, sim::AbstractSimulator)
    obs = var.observable
    targets = isnothing(var.targets) ? collect(0:qubit_count(sim)-1) : var.targets
    obs_qc = qubit_count(obs)
    if length(targets) == obs_qc
        var2 = expectation_op_squared(sim, obs, targets...)
        mean = expectation(sim, obs, targets...)
        return var2 - mean^2
    else
        return map(collect(targets)) do target
            var2 = expectation_op_squared(sim, obs, target)
            mean = expectation(sim, obs, target)
            return var2 - mean^2
        end
    end
end

function calculate(dm::Braket.DensityMatrix, sim::AbstractSimulator)
    ρ = density_matrix(sim)
    full_qubits = collect(0:sim.qubit_count-1)
    sort(dm.targets) == full_qubits || isempty(dm.targets) && return ρ
    # otherwise must compute a partial trace
    return partial_trace(ρ, dm.targets)
end
