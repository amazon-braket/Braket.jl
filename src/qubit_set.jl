using OrderedCollections

"""
    Qubit <: Integer

Wrapper `struct` representing a qubit.

# Examples
```jldoctest
julia> q = Qubit(0)
Qubit(0)

julia> q == 0
true
```
"""
struct Qubit <: Integer
    index::Int
    Qubit(q::Integer) = new(q)
    Qubit(q::AbstractFloat) = new(Int(q))
    Qubit(q::DecFP.DecimalFloatingPoint) = new(Int(q))
    Qubit(q::BigFloat) = new(Int(q))
end
Qubit(q::Qubit) = q
Base.:(==)(q::Qubit, i::T) where {T<:Integer} = q.index==i
Base.:(==)(i::T, q::Qubit) where {T<:Integer} = q.index==i
Base.:(==)(i::BigInt, q::Qubit) = big(q.index)==i
Base.:(==)(q::Qubit, i::BigInt) = big(q.index)==i
Base.:(==)(q1::Qubit, q2::Qubit) = q1.index==q2.index
# ambiguity fix
Base.:(==)(q::Qubit, cvi::CSV.SentinelArrays.ChainedVectorIndex) = (q.index == civ.i)
Base.:(==)(cvi::CSV.SentinelArrays.ChainedVectorIndex, q::Qubit) = (q.index == civ.i)

Base.convert(::Type{Int}, q::Qubit) = q.index
Base.Int(q::Qubit) = q.index
Base.hash(q::Qubit, h::UInt) = hash(q.index, h)
Base.show(io::IO, q::Qubit) = print(io, "Qubit($(q.index))")
const IntOrQubit    = Union{Int, Qubit}

"""
    QubitSet

An `OrderedSet`-like object which represents the qubits a
[`Circuit`](@ref), [`Instruction`](@ref), or [`Result`](@ref)
acts on and their ordering.
Elements may be `Int`s or [`Qubit`](@ref)s.

# Examples
```jldoctest
julia> QubitSet(1, Qubit(0))
QubitSet with 2 elements:
  1
  Qubit(0)

julia> QubitSet([2, 1])
QubitSet with 2 elements:
  2
  1

julia> QubitSet()
QubitSet()

julia> QubitSet(QubitSet(5, 1))
QubitSet with 2 elements:
  5
  1
```
"""
struct QubitSet <: AbstractSet{Int}
    dict::OrderedDict{IntOrQubit, Nothing}
    QubitSet()   = new(OrderedDict{IntOrQubit, Nothing}())
    QubitSet(xs) = (v = foldl(vcat, xs, init=Int[]); return union!(new(OrderedDict{IntOrQubit,Nothing}()), v))
    QubitSet(qs::Vararg{IntOrQubit}) = QubitSet(collect(qs))
    QubitSet(qs::QubitSet) = qs
    QubitSet(::Nothing) = QubitSet()
end
Base.convert(::Type{Vector{Int}}, qs::QubitSet) = convert.(Int, collect(qs))
Base.length(qs::QubitSet)   = length(qs.dict)
Base.lastindex(qs::QubitSet) = length(qs)
Base.isempty(qs::QubitSet)  = isempty(qs.dict)
Base.in(q, qs::QubitSet)    = haskey(qs.dict, q)
Base.push!(qs::QubitSet, q) = (qs.dict[q] = nothing; qs)
Base.copy(qs::QubitSet)     = QubitSet(qs[ii] for ii in 1:length(qs))
Base.popfirst!(qs::QubitSet) = (q = popfirst!(qs.dict); return q[1])
function Base.iterate(qs::QubitSet)::Union{Nothing, Tuple{IntOrQubit, Int}}
    qs.dict.ndel > 0 && OrderedCollections.rehash!(qs.dict)
    length(qs.dict.keys) < 1 && return nothing
    return (qs.dict.keys[1], 2)
end
function Base.iterate(qs::QubitSet, i)::Union{Nothing, Tuple{IntOrQubit, Int}}
    length(qs.dict.keys) < i && return nothing
    return (qs.dict.keys[i], i+1)
end
Base.:(==)(q1::QubitSet, q2::QubitSet) = (length(q1) == length(q2)) && all(q1[ii] == q2[ii] for ii in 1:length(q1))

function Base.getindex(qs::QubitSet, i::Int)
    qs.dict.ndel > 0 && OrderedCollections.rehash!(qs.dict)
    return qs.dict.keys[i]
end
Base.getindex(qs::QubitSet, ui::UnitRange) = QubitSet([qs[ii] for ii in ui])

function Base.intersect(qs1::QubitSet, qs2::QubitSet)
    qs = QubitSet()
    for q in qs1
        (q in qs2) && union!(qs, q)
    end
    return qs
end

function Base.show(io::IO, qs::QubitSet)
    print(io, "QubitSet(")
    print(io, join([sprint(show, q) for q in qs], ", "))
    print(io, ")")
end
Base.convert(::Type{QubitSet}, q::Integer) = QubitSet(q)
Base.convert(::Type{QubitSet}, v::Vector{<:Integer}) = QubitSet(v)
Base.sort(qs::QubitSet; kwargs...) = QubitSet(sort(collect(qs); kwargs...))

const VecOrQubitSet = Union{Vector, QubitSet}
