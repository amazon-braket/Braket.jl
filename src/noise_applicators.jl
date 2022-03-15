for (N, IRN) in zip((:Kraus, :BitFlip, :PhaseFlip, :PauliChannel, :AmplitudeDamping, :PhaseDamping, :Depolarizing, :TwoQubitDephasing, :TwoQubitDepolarizing, :GeneralizedAmplitudeDamping), (:(IR.Kraus), :(IR.BitFlip), :(IR.PhaseFlip), :(IR.PauliChannel), :(IR.AmplitudeDamping), :(IR.PhaseDamping), :(IR.Depolarizing), :(IR.TwoQubitDephasing), :(IR.TwoQubitDepolarizing), :(IR.GeneralizedAmplitudeDamping)))
    @eval begin
        $N(c::Circuit, args...) = apply_noise!(IR.Target($IRN), IR.ProbabilityCount($IRN), $N, c, args...)
        apply_noise!(::Type{$N}, c::Circuit, args...) = apply_noise!(IR.Target($IRN), IR.ProbabilityCount($IRN), $N, c, args...)
    end
end
apply_noise!(::IR.SingleTarget, ::IR.SingleProbability, ::Type{N}, c::Circuit, arg::IntOrQubit, prob::Float64) where {N<:Noise} = add_instruction!(c, Instruction(N(prob), arg))
apply_noise!(::IR.SingleTarget, ::IR.DoubleProbability, ::Type{N}, c::Circuit, arg::IntOrQubit, prob_a::Float64, prob_b::Float64) where {N<:Noise} = add_instruction!(c, Instruction(N(prob_a, prob_b), arg))
apply_noise!(::IR.SingleTarget, ::IR.TripleProbability, ::Type{N}, c::Circuit, arg::IntOrQubit, prob_a::Float64, prob_b::Float64, prob_c::Float64) where {N<:Noise} = add_instruction!(c, Instruction(N(prob_a, prob_b, prob_c), arg))
apply_noise!(::IR.SingleTarget, ::IR.DoubleProbability, ::Type{N}, c::Circuit, arg::IntOrQubit, probs::Vector{Float64}) where {N<:Noise} = add_instruction!(c, Instruction(N(probs...), arg))
apply_noise!(::IR.SingleTarget, ::IR.TripleProbability, ::Type{N}, c::Circuit, arg::IntOrQubit, probs::Vector{Float64}) where {N<:Noise} = add_instruction!(c, Instruction(N(probs...), arg))
apply_noise!(::IR.SingleTarget, ::IR.ProbabilityCount, ::Type{N}, c::Circuit, probs::Vector{Float64}) where {N<:Noise} = (foreach(q->add_instruction!(c, Instruction(N(probs...), q)), qubits(c)); return c)
apply_noise!(::IR.SingleTarget, ::IR.ProbabilityCount, ::Type{N}, c::Circuit, probs::Vararg{Float64}) where {N<:Noise} = (foreach(q->add_instruction!(c, Instruction(N(probs...), q)), qubits(c)); return c)
apply_noise!(::IR.DoubleTarget, ::IR.SingleProbability, ::Type{N}, c::Circuit, targ_a::IntOrQubit, targ_b::Int, prob::Float64) where {N<:Noise} = add_instruction!(c, Instruction(N(prob), [targ_a, targ_b]))
apply_noise!(::IR.DoubleTarget, ::IR.SingleProbability, ::Type{N}, c::Circuit, args...) where {N<:Noise} = add_instruction!(c, Instruction(N(args[end]), args[1:end-1]))
apply_noise!(::IR.MultiTarget, ::IR.MultiProbability, ::Type{N}, c::Circuit, args...) where {N<:Noise} = add_instruction!(c, Instruction(N(args[end]), args[1:end-1]))
