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

abstract type Parametrizable end
struct Parametrized end 
struct NonParametrized end 

struct PauliEigenvalues{N}
    coeff::Float64
    PauliEigenvalues{N}(coeff::Float64=1.0) where {N} = new(coeff)
end
PauliEigenvalues(::Val{N}, coeff::Float64=1.0) where {N} = PauliEigenvalues{N}(coeff)
Base.length(p::PauliEigenvalues{N}) where {N} = 2^N
function Base.iterate(p::PauliEigenvalues{N}, ix::Int=1) where {N}
    return ix <= length(p) ? (p[ix], ix+1) : nothing
end

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

"""
    Measure(index) <: QuantumOperator

Represents a measurement operation on targeted qubit, stored in the classical register at `index`.
"""
struct Measure <: QuantumOperator
    index::Int
end
Measure() = Measure(-1)
Parametrizable(m::Measure) = NonParametrized()
chars(::Type{Measure}) = ("M",)
chars(m::Measure) = ("M",)
qubit_count(::Type{Measure}) = 1
ir(m::Measure, target::QubitSet, ::Val{:JAQCD}; kwargs...) = error("measure instructions are not supported with JAQCD.") 
function ir(m::Measure, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
    instructions = Vector{String}(undef, length(target))
    for (idx, qubit) in enumerate(target)
        bit_index = m.index > 0 && length(targets) == 1 ? m.index : idx - 1
        t = format_qubits(qubit, serialization_properties)
        instructions[idx] = "b[$bit_index] = measure $t;"
    end
    return join(instructions, "\n")
end
