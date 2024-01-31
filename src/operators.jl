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

struct PauliEigenvalues{N}
    coeff::Float64
    PauliEigenvalues{N}(coeff::Float64=1.0) where {N} = new(coeff)
end
PauliEigenvalues(::Val{N}, coeff::Float64=1.0) where {N} = PauliEigenvalues{N}(coeff)

Base.getindex(p::PauliEigenvalues{1}, i::Int)::Float64 = getindex((p.coeff, -p.coeff), i)
function Base.getindex(p::PauliEigenvalues{N}, i::Int)::Float64 where N
    i_block = div(i-1, 2)
    split = div(2^(N-1)-1, 2)
    if N < 5
        total_evs = 2^N
        is_front = !isodd(mod(i-1, 2))
        ev = is_front ? p.coeff : -p.coeff
        mi = mod(i_block, 2)
        di = div(i_block, 2)
        if i_block <= split
            return isodd(mi) ⊻ isodd(di) ? -ev : ev
        else
            mi = mod(i_block - split - 1, 2)
            di = div(i_block - split - 1, 2)
            return isodd(mi) ⊻ isodd(di) ? ev : -ev
        end
    else
        new_i = i > 2^(N-1) ? i - 2^(N-1) : i
	one_down_pe = PauliEigenvalues(Val(N-1))
	one_down = one_down_pe[new_i]
        return i_block <= split ? one_down : -one_down
    end
end
Base.getindex(p::PauliEigenvalues{N}, ix::Vector{Int}) where {N} = [p[i] for i in ix]
