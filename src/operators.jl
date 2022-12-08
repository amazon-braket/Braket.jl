"""
    Operator

Abstract type representing operations that can be applied to a [`Circuit`](@ref).
Subtypes include [`Gate`](@ref), [`Noise`](@ref), [`Observable`](@ref Braket.Observables.Observable),
and [`CompilerDirective`](@ref).
"""
abstract type Operator end

"""
    QuantumOperator < Operator

Abstract type representing *quantum* operations that can be applied to a [`Circuit`](@ref).
Subtypes include [`Gate`](@ref) and [`Noise`](@ref).
"""
abstract type QuantumOperator <: Operator end
ir(o::Operator, t::Vector{T}, ::Val{V}; kwargs...) where {T<:IntOrQubit, V} = ir(o, QubitSet(t), Val(V); kwargs...)
ir(o::Operator, t::Vector{T}; kwargs...) where {T<:IntOrQubit} = ir(o, QubitSet(t), Val(IRType[]); kwargs...)
ir(o::Operator, t::QubitSet; kwargs...)  = ir(o, t, Val(IRType[]); kwargs...)
ir(o::Operator, t::IntOrQubit; kwargs...)          = ir(o, QubitSet(t), Val(IRType[]); kwargs...)
ir(o::Operator, t::IntOrQubit, args...; kwargs...) = ir(o, QubitSet(t), args...; kwargs...)

function pauli_eigenvalues(n::Int)
    n == 1 && return [1.0, -1.0]
    return reduce(vcat, [pauli_eigenvalues(n - 1), -1 .* pauli_eigenvalues(n - 1)])
end
