module Observables

using JSON3, StructTypes, LinearAlgebra

import ..Braket: ir, qubit_count, pauli_eigenvalues, complex_matrix_from_ir, complex_matrix_to_ir, Operator, SerializationProperties, format_qubits, format, format_matrix, OpenQASMSerializationProperties, IRType, QubitSet, Qubit
export Observable, TensorProduct, HermitianObservable

"""
    Observable <: Operator

Abstract type representing an observable to be measured. All `Observable`s
have `eigvals` defined.

See also: [`H`](@ref), [`I`](@ref), [`X`](@ref), [`Y`](@ref), [`Z`](@ref), [`TensorProduct`](@ref), [`HermitianObservable`](@ref).
"""
abstract type Observable <: Operator end

LinearAlgebra.ishermitian(o::Observable) = true

for (typ, label) in ((:H, "h"), (:X, "x"), (:Y, "y"), (:Z, "z"), (:I, "i"))
    @eval begin
        @doc """
            $($typ) <: Observable
            $($typ)() -> $($typ)

        Struct representing a `$($typ)` observable in a measurement.
        """
        struct $typ <: Observable end
        StructTypes.StructType(::Type{$typ}) = StructTypes.CustomStruct()
        StructTypes.lower(x::$typ) = [$label]
        qubit_count(o::$typ) = 1
        qubit_count(::Type{$typ}) = 1
        Base.copy(o::$typ) = $typ()
        ir(o::$typ, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties()) = isempty(target) ? $label * " all" : $label * "(" * format_qubits(target, serialization_properties) * ")"
        ir(o::$typ, target::Nothing, ::Val{:OpenQASM}; kwargs...) = ir(o, QubitSet(),  Val(:OpenQASM); kwargs...)
    end
end
const StandardObservable = Union{H, X, Y, Z}
LinearAlgebra.eigvals(o::I) = [1.0, 1.0]
LinearAlgebra.eigvals(o::StandardObservable) = [1.0, -1.0]

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
struct TensorProduct <: Observable
    factors::Vector{<:Observable}
    function TensorProduct(v::Vector{<:Observable})
        flattened_v = Observable[]
        for o in v
            if o isa TensorProduct
                foreach(o_->push!(flattened_v, o_), o.factors)
            else
                push!(flattened_v, o)
            end
        end
        return new(flattened_v)
    end
end
function TensorProduct(o::Vector{String})
    sts = StructTypes.subtypes(Observable)
    ops = Observable[sts[Symbol(lowercase(oi))]() for oi in o]
    return TensorProduct(ops)
end
function ir(tp::TensorProduct, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    factors = []
    use_qubits = collect(target)
    for obs in tp.factors
        obs_target = QubitSet()
        num_qubits = qubit_count(obs)
        for qi in 0:num_qubits-1
            q = popfirst!(use_qubits)
            union!(obs_target, q)
        end
        push!(factors, ir(obs, obs_target, Val(:OpenQASM), serialization_properties=serialization_properties))
    end
    return join(factors, " @ ")
end
ir(tp::TensorProduct; kwargs...) = ir(tp, Val(IRType[]); kwargs...)

qubit_count(o::TensorProduct) = sum(qubit_count.(o.factors))
StructTypes.StructType(::Type{TensorProduct}) = StructTypes.CustomStruct()
StructTypes.lower(x::TensorProduct) = vcat(StructTypes.lower.(x.factors)...)
Base.:(==)(t1::TensorProduct, t2::TensorProduct) = t1.factors == t2.factors
Base.copy(t::TensorProduct) = TensorProduct(deepcopy(t.factors))
function LinearAlgebra.eigvals(o::TensorProduct)
    all(o_ isa StandardObservable for o_ in o.factors) && return pauli_eigenvalues(length(o.factors))
    evs = mapfoldl(eigvals, kron, o.factors, init=[1.0])
    #=for f in o.factors
        evs = kron(evs, eigvals(f))
    end=#
    return evs
end

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
struct HermitianObservable <: Observable
    matrix::Matrix{<:Complex}
    function HermitianObservable(mat::Matrix{<:Number})
        ishermitian(mat) || throw(ArgumentError("input matrix to HermitianObservable must be Hermitian."))
        new(complex(mat))
    end
end
HermitianObservable(v::Vector{Vector{Vector{T}}}) where {T<:Number} = HermitianObservable(complex_matrix_from_ir(v))
Base.copy(o::HermitianObservable) = HermitianObservable(copy(o.matrix))
StructTypes.StructType(::Type{HermitianObservable}) = StructTypes.CustomStruct()
StructTypes.lower(x::HermitianObservable) = [complex_matrix_to_ir(ComplexF64.(x.matrix))]
Base.:(==)(h1::HermitianObservable, h2::HermitianObservable) = (size(h1.matrix) == size(h2.matrix) && h1.matrix ≈ h2.matrix)
qubit_count(o::HermitianObservable) = convert(Int, log2(size(o.matrix, 1)))
LinearAlgebra.eigvals(o::HermitianObservable) = eigvals(Hermitian(o.matrix))
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
ir(ho::HermitianObservable, target::Nothing, ::Val{:OpenQASM}; kwargs...) = ir(ho, QubitSet(), Val(:OpenQASM); kwargs...)

StructTypes.StructType(::Type{Observable}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Observable}) = (i=I, h=H, x=X, y=Y, z=Z)
StructTypes.constructfrom(::Type{Observable}, obj::String) = StructTypes.subtypes(Observable)[Symbol(obj)]()
function StructTypes.constructfrom(::Type{Observable}, obj::Vector{String})
    length(obj) == 1 && return StructTypes.constructfrom(Observable, obj[1])
    return TensorProduct(obj)
end
StructTypes.constructfrom(::Type{Observable}, obj::Vector{Vector{Vector{T}}}) where {T<:Number} = HermitianObservable(obj)
function StructTypes.constructfrom(::Type{Observable}, obj::Vector{Vector{Vector{Vector{T}}}}) where {T<:Number}
    length(obj) == 1 && return HermitianObservable(obj[1])
    return TensorProduct([HermitianObservable(o) for o in obj])
end

function StructTypes.constructfrom(::Type{Observable}, obj::Vector{Union{String, Vector{Vector{Vector{T}}}}}) where {T<:Number}
    all(o isa String for o in obj) && return StructTypes.constructfrom(Observable, convert(Vector{String}, obj))
    all(o isa Vector{Vector{Vector{T}}} for o in obj) && return StructTypes.constructfrom(Observable, convert(Vector{Vector{Vector{Vector{T}}}}, obj))
    o_list = Observable[]
    for o in obj
        if o isa String
            push!(o_list, StructTypes.constructfrom(Observable, o))
        elseif o isa Vector{Vector{Vector{T}}}
            push!(o_list, HermitianObservable(o))
        else
            throw(ErrorException("invalid observable $o"))
        end
    end
    return TensorProduct(o_list)
end

Base.:(*)(o1::Observable, o2::Observable) = TensorProduct([o1, o2])

end
