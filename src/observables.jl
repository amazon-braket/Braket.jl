module Observables

using JSON3, StructTypes, LinearAlgebra

import ..Braket: ir, qubit_count, complex_matrix_from_ir, complex_matrix_to_ir, Operator, SerializationProperties, format_qubits, format, format_matrix, OpenQASMSerializationProperties, IRType, QubitSet, Qubit, IntOrQubit, IRObservable, chars, PauliEigenvalues
export Observable, TensorProduct, HermitianObservable, Sum

"""
    Observable <: Operator

Abstract type representing an observable to be measured. All `Observable`s
have `eigvals` defined.

See also: [`H`](@ref), [`I`](@ref), [`X`](@ref), [`Y`](@ref), [`Z`](@ref), [`TensorProduct`](@ref), [`HermitianObservable`](@ref).
"""
abstract type Observable <: Operator end
abstract type NonCompositeObservable <: Observable end
abstract type StandardObservable <: NonCompositeObservable end

LinearAlgebra.ishermitian(o::Observable) = true

coef(o::O) where {O<:Observable} = o.coefficient

for (typ, label, super) in ((:H, "h", :StandardObservable), (:X, "x", :StandardObservable), (:Y, "y", :StandardObservable), (:Z, "z", :StandardObservable), (:I, "i", :NonCompositeObservable))
    @eval begin
        @doc """
            $($typ) <: Observable
            $($typ)([coeff::Float64]) -> $($typ)

        Struct representing a `$($typ)` observable in a measurement. The observable
        may be scaled by `coeff`.
        """
        struct $typ <: $super
            coefficient::Float64
            $typ(coef::Float64=1.0) = new(coef)
        end
        StructTypes.StructType(::Type{$typ}) = StructTypes.CustomStruct()
        StructTypes.lower(x::$typ) = [$label]
        qubit_count(o::$typ) = 1
        qubit_count(::Type{$typ}) = 1
        unscaled(o::$typ) = $typ()
        Base.copy(o::$typ) = $typ(o.coefficient)
        function ir(o::$typ, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
            target_str = isempty(target) ? " all" : "(" * format_qubits(target, serialization_properties) * ")"
            coef_str = isone(o.coefficient) ? "" : string(o.coefficient) * " * "
            return coef_str * $label * target_str 
        end
        ir(o::$typ, target::Nothing, ::Val{:OpenQASM}; kwargs...) = ir(o, QubitSet(),  Val(:OpenQASM); kwargs...)
        Base.:(*)(o::$typ, n::Real) = $typ(Float64(n*o.coefficient))
        Base.:(==)(o1::$typ, o2::$typ) = (o1.coefficient ≈ o2.coefficient)
        Base.show(io::IO, o::$typ) = print(io, (isone(o.coefficient) ? "" : string(o.coefficient) * " * ") * uppercase($label))
        chars(o::$typ) = (uppercase($label),)
    end
end
LinearAlgebra.eigvals(o::I) = [o.coefficient, o.coefficient]
LinearAlgebra.eigvals(o::StandardObservable) = [o.coefficient, -o.coefficient]

"""
    HermitianObservable <: Observable
    HermitianObservable(matrix::Matrix) -> HermitianObservable

Struct representing an observable of an arbitrary complex Hermitian matrix.

# Examples
```jldoctest
julia> ho = Braket.Observables.HermitianObservable([0 1; 1 0])
Braket.Observables.HermitianObservable(Complex{Int64}[0 + 0im 1 + 0im; 1 + 0im 0 + 0im])
```
"""
struct HermitianObservable <: NonCompositeObservable
    matrix::Matrix{<:Complex}
    coefficient::Float64
    function HermitianObservable(mat::Matrix{<:Number})
        ishermitian(mat) || throw(ArgumentError("input matrix to HermitianObservable must be Hermitian."))
        new(complex(mat), 1.0)
    end
end
HermitianObservable(v::Vector{Vector{Vector{T}}}) where {T<:Number} = HermitianObservable(complex_matrix_from_ir(v))
Base.copy(o::HermitianObservable) = HermitianObservable(copy(o.matrix))
StructTypes.StructType(::Type{HermitianObservable}) = StructTypes.CustomStruct()
StructTypes.lower(x::HermitianObservable) = Union{String, Vector{Vector{Vector{Float64}}}}[complex_matrix_to_ir(ComplexF64.(x.matrix))]
Base.:(==)(h1::HermitianObservable, h2::HermitianObservable) = (size(h1.matrix) == size(h2.matrix) && h1.matrix ≈ h2.matrix)
qubit_count(o::HermitianObservable) = convert(Int, log2(size(o.matrix, 1)))
LinearAlgebra.eigvals(o::HermitianObservable) = eigvals(Hermitian(o.matrix))
unscaled(o::HermitianObservable) = o
function ir(ho::HermitianObservable, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
    function c_str(x::Number)
        iszero(real(x)) && iszero(imag(x)) && return "0im"
        iszero(real(x)) && return string(imag(x))*"im"
        iszero(imag(x)) && return string(real(x))*"+0im"
        imag_sign = imag(x) < 0 ? "" : "+"
        return string(real(x)) * imag_sign * string(imag(x)) * "im"
    end
    m = "[" * join(["["*join(c_str.(ho.matrix[i, :]), ", ")*"]" for i in 1:size(ho.matrix, 1)], ", ") * "]"
    t = isempty(target) ? "all" : format_qubits(target, serialization_properties)
    return "hermitian($m) $t"
end
Base.:(*)(o::HermitianObservable, n::Real) = HermitianObservable(Float64(n) .* o.matrix)
Base.show(io::IO, ho::HermitianObservable) = print(io, "HermitianObservable($(size(ho.matrix)))")
ir(ho::HermitianObservable, target::Nothing, ::Val{:OpenQASM}; kwargs...) = ir(ho, QubitSet(), Val(:OpenQASM); kwargs...)
chars(o::HermitianObservable) = ("Hermitian",)

"""
    TensorProduct <: Observable
    TensorProduct(factors::Vector{<:Observable}) -> TensorProduct
    TensorProduct(factors::Vector{String}) -> TensorProduct

Struct representing a tensor product of smaller observables.

# Examples
```jldoctest
julia> Braket.Observables.TensorProduct(["x", "h"])
Braket.Observables.TensorProduct(Braket.Observables.Observable[Braket.Observables.X(), Braket.Observables.H()])

julia> ho = Braket.Observables.HermitianObservable([0 1; 1 0]);

julia> Braket.Observables.TensorProduct([ho, Braket.Observables.Z()])
Braket.Observables.TensorProduct(Braket.Observables.Observable[Braket.Observables.HermitianObservable(Complex{Int64}[0 + 0im 1 + 0im; 1 + 0im 0 + 0im]), Braket.Observables.Z()])
```
"""
struct TensorProduct{O} <: Observable where {O<:Observable}
    factors::Vector{O}
    coefficient::Float64
    function TensorProduct{O}(v::Vector{O}, coefficient::Float64=1.0) where {O<:NonCompositeObservable}
        coeff = coefficient
        flattened_v = Vector{O}(undef, length(v))
        for (oi, o) in enumerate(v)
            flattened_v[oi] = unscaled(o)
            coeff *= coef(o)
        end
        return new(flattened_v, coeff)
    end
    function TensorProduct{O}(v::Vector{O}, coefficient::Float64=1.0) where {O<:Observable}
        any(v_->v_ isa Sum, v) && throw(ArgumentError("Sum observable not allowed in TensorProduct."))
        coeff = prod(coef, v, init=coefficient)
        flattened_v = Iterators.flatmap(v) do o 
            if o isa TensorProduct
                return (unscaled(o) for o in o.factors)
            else
                return (unscaled(o),)
            end
        end
        flat_v = collect(flattened_v)
        return new(flat_v, coeff)
    end
end
TensorProduct(o::Vector{T}, coefficient::Float64=1.0) where {T} = TensorProduct{T}(o, coefficient)
function TensorProduct(o::Vector{String}, coefficient::Float64=1.0)
    return TensorProduct([StructTypes.constructfrom(Observable, s) for s in o], coefficient)
end

Base.:(*)(o::TensorProduct, n::Real) = TensorProduct(deepcopy(o.factors), Float64(n*o.coefficient))
function ir(tp::TensorProduct, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    factors = []
    use_qubits = collect(target)
    coef_str = isone(tp.coefficient) ? "" : "$(tp.coefficient) * "
    for obs in tp.factors
        obs_target = QubitSet()
        num_qubits = qubit_count(obs)
        for qi in 0:num_qubits-1
            q = popfirst!(use_qubits)
            union!(obs_target, q)
        end
        push!(factors, ir(obs, obs_target, Val(:OpenQASM), serialization_properties=serialization_properties))
    end
    return coef_str * join(factors, " @ ")
end
ir(tp::TensorProduct; kwargs...) = ir(tp, Val(IRType[]); kwargs...)
unscaled(o::TensorProduct) = TensorProduct(o.factors, 1.0)
qubit_count(o::TensorProduct) = sum(qubit_count.(o.factors))
StructTypes.StructType(::Type{TensorProduct{O}}) where {O<:Observable} = StructTypes.CustomStruct()
StructTypes.lower(x::TensorProduct{O}) where {O<:Observable} = Union{String, Vector{Vector{Vector{Float64}}}}[convert(Union{String, Vector{Vector{Vector{Float64}}}}, o) for o in mapreduce(StructTypes.lower, vcat, x.factors)]
Base.:(==)(t1::TensorProduct, t2::TensorProduct) = t1.factors == t2.factors && t1.coefficient ≈ t2.coefficient
Base.copy(t::TensorProduct) = TensorProduct(deepcopy(t.factors), t.coefficient)
_evs(os::Vector{O}, coeff::Float64=1.0) where {O<:StandardObservable} = PauliEigenvalues(Val(length(os)), coeff)
_evs(os::Vector{O}, coeff::Float64=1.0) where {O<:Observable} = mapfoldl(eigvals, kron, os, init=[coeff])::Vector{Float64}
LinearAlgebra.eigvals(o::TensorProduct{O}) where {O} = return _evs(o.factors, o.coefficient)
function Base.show(io::IO, o::TensorProduct)
    coef_str = isone(o.coefficient) ? "" : string(o.coefficient) * " * "
    print(io, coef_str)
    for f in o.factors[1:end-1]
        print(io, f)
        print(io, " @ ")
    end
    print(io, o.factors[end])
    return
end
chars(o::TensorProduct) = (sprint(show, o),)


"""
    Sum <: Observable
    Sum(summands::Vector{<:Observable}) -> Sum 

Struct representing the sum of observables.

# Examples
```jldoctest
julia> o1 = 2.0 * Observables.I() @ Observables.Z();

julia> o2 = 3.0 * Observables.X() @ Observables.X();

julia> o = o1 + o2
Braket.Observables.Sum()
```
"""
struct Sum <: Observable
    summands::Vector{Observable}
    coefficient::Float64
    function Sum(v)
        flattened_v = Iterators.flatmap(v) do obs
            if obs isa Sum
                return obs.summands
            else
                return (obs,)
            end
        end
        new(collect(flattened_v), 1.0)
    end
end
Base.length(s::Sum) = length(s.summands)
Base.:(*)(s::Sum, n::Real) = Sum(Float64(n) .* deepcopy(s.summands))
function Base.:(==)(s1::Sum, s2::Sum)
    length(s1) != length(s2) && return false
    are_eq = true
    for (summand1, summand2) in zip(s1.summands, s2.summands)
        are_eq &= (summand1 == summand2)
        are_eq || return false
    end
    return true
end
function Base.:(==)(s::Sum, o::Observable)
    length(s) == 1 || return false
    return first(s.summands) == o
end
Base.:(==)(o::Observable, s::Sum) = s == o
function Base.show(io::IO, s::Sum)
    print(io, "Sum(")
    for summand in s.summands[1:end-1]
        print(io, summand)
        print(io, ", ")
    end
    print(io, s.summands[end])
    print(io, ")")
    return
end
StructTypes.lower(s::Sum) = [StructTypes.lower(summand) for summand in s.summands]
ir(s::Sum, target::Vector{QubitSet}, ::Val{:JAQCD}; kwargs...) = throw(ErrorException("Sum observables are not supported in JAQCD."))
ir(s::Sum, target::Vector{<:IntOrQubit}, ::Val{:JAQCD}; kwargs...) = throw(ErrorException("Sum observables are not supported in JAQCD."))
function ir(s::Sum, target::Vector{QubitSet}, ::Val{:OpenQASM}; kwargs...)
    length(s.summands) == length(target) || throw(DimensionMismatch("number of summands ($(length(s.summands))) must match length of targets vector ($(length(targets)))."))
    for (ii, (term, term_target)) in enumerate(zip(s.summands, target))
        length(term_target) == qubit_count(term) || throw(DimensionMismatch("qubit count of term $ii ($(qubit_count(term))) must match number of targets ($(length(term_target)))."))
    end
    summands_irs = [ir(obs, targ, Val(:OpenQASM); kwargs...) for (obs, targ) in zip(s.summands, target)]
    sum_str = replace(join(summands_irs, " + "), "+ -"=>"- ")
    return sum_str
end
ir(s::Sum, target::Vector{Vector{T}}, ::Val{:OpenQASM}; kwargs...) where {T} = ir(s, [QubitSet(t) for t in target], Val(:OpenQASM); kwargs...)
chars(s::Sum) = ("Sum",)


StructTypes.StructType(::Type{Observable}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Observable}) = (i=I, h=H, x=X, y=Y, z=Z)
StructTypes.lowertype(::Type{O}) where {O<:Observable} = IRObservable
function StructTypes.constructfrom(::Type{Observable}, obj::String)
    (obj == "i" || obj == "I") && return I()
    (obj == "x" || obj == "X") && return X()
    (obj == "y" || obj == "Y") && return Y()
    (obj == "z" || obj == "Z") && return Z()
    (obj == "h" || obj == "H") && return H()
    throw(ArgumentError("Observable of type \"$obj\" provided, only \"i\", \"x\", \"y\", \"z\", and \"h\" are valid."))
end
StructTypes.constructfrom(::Type{Observable}, obj::Vector{String}) = length(obj) == 1 ? StructTypes.constructfrom(Observable, first(obj)) : TensorProduct(obj)
StructTypes.constructfrom(::Type{Observable}, obj::Vector{Vector{Vector{Float64}}}) = HermitianObservable(obj)
StructTypes.constructfrom(::Type{Observable}, obj::Vector{Vector{Vector{Vector{Float64}}}}) = length(obj) == 1 ? HermitianObservable(obj[1]) : TensorProduct(obj)
function StructTypes.constructfrom(::Type{Observable}, obj::Vector{T}) where {T}
    length(obj) == 1 && return StructTypes.constructfrom(Observable, obj[1])
    return TensorProduct([StructTypes.constructfrom(Observable, o) for o in obj])
end

Base.:(*)(o1::O1, o2::O2) where {O1<:Observable, O2<:Observable} = TensorProduct([o1, o2], 1.0)
Base.:(*)(n::Real, o::Observable) = o*n 
Base.:(+)(o1::Observable, o2::Observable) = Sum([o1, o2])
Base.:(-)(o1::Observable, o2::Observable) = Sum([o1, -1.0 * o2])

end
