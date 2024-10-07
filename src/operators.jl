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
Base.iterate(p::PauliEigenvalues{N}, ix::Int=1) where {N} = ix <= length(p) ? (p[ix], ix+1) : nothing

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
chars(::Measure) = chars(Measure)
qubit_count(::Type{Measure}) = 1
qubit_count(::Measure) = qubit_count(Measure)
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

"""
    Reset() <: QuantumOperator

Represents an active reset operation on targeted qubit.
"""
struct Reset <: QuantumOperator end
Parametrizable(m::Reset) = NonParametrized()
chars(::Type{Reset}) = ("Reset",)
chars(::Reset) = chars(Reset)
label(::Reset) = "reset"
qubit_count(::Type{Reset}) = 1
qubit_count(r::Reset) = qubit_count(Reset)

"""
    Barrier() <: QuantumOperator

Represents a barrier operation on targeted qubit.
"""
struct Barrier <: QuantumOperator end
Parametrizable(b::Barrier) = NonParametrized()
chars(::Type{Barrier}) = ("Barrier",)
chars(r::Barrier) = chars(Barrier)
label(::Barrier) = "barrier"
qubit_count(::Type{Barrier}) = 1
qubit_count(b::Barrier) = qubit_count(Barrier)

"""
    Delay(duration::Period) <: QuantumOperator

Represents a delay operation for `duration` on targeted qubit.
"""
struct Delay <: QuantumOperator
    duration::Dates.Period
end
Parametrizable(m::Delay) = NonParametrized()
chars(d::Delay) = ("Delay($(label(d.duration)))",)
label(d::Delay) = "delay[$(label(d.duration))]"
qubit_count(::Type{Delay}) = 1
qubit_count(d::Delay) = qubit_count(Delay)
Base.:(==)(d1::Delay, d2::Delay) = d1.duration == d2.duration
label(d::Microsecond) = "$(d.value)ms"
label(d::Nanosecond)  = "$(d.value)ns"
label(d::Second)      = "$(d.value)s"

ir(ix::Union{Reset, Barrier, Delay}, target::QubitSet, ::Val{:JAQCD}; kwargs...) = error("$(label(ix)) instructions are not supported with JAQCD.") 
function ir(ix::Union{Reset, Barrier, Delay}, target::QubitSet, v::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
    return join(("$(label(ix)) $(format_qubits(qubit, serialization_properties));" for qubit in target), "\n")
end
