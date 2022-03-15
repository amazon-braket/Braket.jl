"""
    Result

Abstract type representing a measurement to perform on
a [`Circuit`](@ref).

See also: [`Expectation`](@ref), [`Variance`](@ref),
[`Sample`](@ref), [`Probability`](@ref),
[`DensityMatrix`](@ref), and [`Amplitude`](@ref).
"""
abstract type Result end

union_obs_typ = @NamedTuple{observable::Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, targets::Vector{Int}, type::String}

for (typ, ir_typ, label) in ((:Expectation, :(Braket.IR.Expectation), "expectation"), (:Variance, :(Braket.IR.Variance), "variance"), (:Sample, :(Braket.IR.Sample), "sample"))
    @eval begin
        @doc """
            $($typ) <: Result
        
        Struct which represents a $($label) measurement on a [`Circuit`](@ref). 
        """
        struct $typ <: Result
            observable::Observables.Observable
            targets::QubitSet
            $typ(observable::Observables.Observable, targets::QubitSet) = new(observable, targets)
        end
        @doc """
            $($typ)(o, targets) -> $($typ)
            $($typ)(o) -> $($typ)
        
        Constructs a $($typ) of an observable `o` on qubits `targets`.
        
        `o` may be one of:
          - Any [`Observable`](@ref Braket.Observables.Observable)
          - A `String` corresponding to an `Observable` (e.g. `\"x\"``)
          - A `Vector{String}` in which each element corresponds to an `Observable`

        `targets` may be one of:
          - A [`QubitSet`](@ref)
          - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
          - An `Int` or `Qubit`
          - Absent, in which case the observable `o` will be applied to all qubits provided it is a single qubit observable.
        """ $typ(o, targets) = $typ(o, QubitSet(targets))
        $typ(o::String, targets::QubitSet) = $typ(Observables.TensorProduct([o for ii in 1:length(targets)]), targets)
        $typ(o::Vector{String}, targets::QubitSet) = $typ(Observables.TensorProduct(o), targets)
        $typ(o) = $typ(o, QubitSet())
        Base.:(==)(e1::$typ, e2::$typ) = (e1.observable == e2.observable && e1.targets == e2.targets)
        StructTypes.StructType(::Type{$typ}) = StructTypes.CustomStruct()
        StructTypes.lower(x::$typ) = $ir_typ(ir(x.observable), (isempty(x.targets) ? nothing : Int.(x.targets)), $label)
        StructTypes.lowertype(::Type{$typ}) = union_obs_typ
        function ir(r::$typ, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
            obs_ir = ir(r.observable, r.targets, Val(:OpenQASM); serialization_properties=serialization_properties)
            return "#pragma braket result " * $label * " $obs_ir"
        end
        $typ(x::union_obs_typ) = $typ(StructTypes.constructfrom(Observables.Observable, x.observable), x.targets)
    end
end


for (typ, ir_typ, label) in ((:Probability, :(Braket.IR.Probability), "probability"), (:DensityMatrix, :(Braket.IR.DensityMatrix), "densitymatrix"))
    @eval begin
        @doc """
            $($typ) <: Result
        
        Struct which represents a $($label) measurement on a [`Circuit`](@ref). 
        """
        struct $typ <: Result
            targets::QubitSet
            $typ(targets::QubitSet) = new(targets)
        end
        Base.:(==)(p1::$typ, p2::$typ) = (p1.targets == p2.targets)
        $typ()  = $typ(QubitSet())
        @doc """
            $($typ)(targets) -> $($typ)
            $($typ)() -> $($typ)

        Constructs a $($typ) on qubits `targets`.

        `targets` may be one of:
          - A [`QubitSet`](@ref)
          - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
          - An `Int` or `Qubit`
          - Absent, in which case the measurement will be applied to all qubits.
        """ $typ(targets) = $typ(QubitSet(targets))
        $typ(targets::Vararg{IntOrQubit}) = $typ(QubitSet(targets...))
        StructTypes.StructType(::Type{$typ}) = StructTypes.CustomStruct()
        StructTypes.lower(x::$typ) = $ir_typ(isempty(x.targets) ? nothing : Int.(x.targets), $label)
        StructTypes.lowertype(::Type{$typ}) = @NamedTuple{targets::Union{Nothing, Vector{Int}}, type::String}
        $typ(x::@NamedTuple{targets::Union{Nothing, Vector{Int}}, type::String}) = $typ(x.targets)
    end
end

function ir(p::Probability, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    (isnothing(p.targets) || isempty(p.targets)) && return "#pragma braket result probability all"
    t = format_qubits(p.targets, serialization_properties)
    return "#pragma braket result probability $t"
end
function ir(dm::DensityMatrix, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    isempty(dm.targets) && return "#pragma braket result density_matrix"
    t = format_qubits(dm.targets, serialization_properties)
    return "#pragma braket result density_matrix $t"
end
"""
    Amplitude <: Result

Struct which represents an amplitude measurement on a [`Circuit`](@ref). 
"""
struct Amplitude <: Result
    states::Vector{String}
end
"""
    Amplitude(states) -> Amplitude

Constructs an Amplitude measurement of `states`.

`states` may be one of:
  - A `Vector{String}`
  - A `String`
All elements of `states` must be `'0'` or `'1'`.
"""
Amplitude(s::String) = Amplitude([s])
Base.:(==)(a1::Amplitude, a2::Amplitude) = (a1.states == a2.states)
function ir(a::Amplitude, ::Val{:OpenQASM}; kwargs...)
    states = join(repr.(a.states), ", ")
    return "#pragma braket result amplitude $states"
end

"""
    StateVector <: Result

Struct which represents a state vector measurement on a [`Circuit`](@ref). 
"""
struct StateVector <: Result end
ir(s::StateVector, ::Val{:OpenQASM}; kwargs...) = "#pragma braket result state_vector"
Base.:(==)(sv1::StateVector, sv2::StateVector) = true

const ObservableResult = Union{Expectation, Variance, Sample}

remap(rt::R, mapping::Dict{<:Integer, <:Integer}) where {R<:ObservableResult} = R(copy(rt.observable), [mapping[q] for q in rt.targets])
remap(rt::R, mapping::Dict{<:Integer, <:Integer}) where {R<:Result} = R([mapping[q] for q in rt.targets])
remap(rt::R, target) where {R<:ObservableResult} = R(copy(rt.observable), QubitSet(target[ii] for ii in 1:length(rt.targets)))
remap(rt::R, target) where {R<:Result} = R(QubitSet(target[ii] for ii in 1:length(rt.targets)))

StructTypes.StructType(::Type{Amplitude}) = StructTypes.CustomStruct()
StructTypes.lower(x::Amplitude) = Braket.IR.Amplitude(x.states, "amplitude")
StructTypes.lowertype(::Type{Amplitude}) = @NamedTuple{states::Vector{String}, type::String}
Amplitude(x::@NamedTuple{states::Vector{String}, type::String}) = Amplitude(x.states)


StructTypes.StructType(::Type{StateVector}) = StructTypes.CustomStruct()
StructTypes.lower(x::StateVector) = Braket.IR.StateVector("statevector")
StructTypes.lowertype(::Type{StateVector}) = @NamedTuple{type::String}
StateVector(x::@NamedTuple{type::String}) = StateVector()

ir(r::Result, ::Val{:JAQCD}; kwargs...) = StructTypes.lower(r)
ir(r::Result; kwargs...) = ir(r, Val(IRType[]); kwargs...)
StructTypes.StructType(::Type{Result}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Result}) = (amplitude=Amplitude, expectation=Expectation, probability=Probability, statevector=StateVector, variance=Variance, sample=Sample, densitymatrix=DensityMatrix)

function StructTypes.constructfrom(::Type{R}, obj) where {R<:Result}
    return R((getproperty(obj, fn) for fn in fieldnames(R))...)
end

function StructTypes.constructfrom(::Type{R}, obj) where {R<:ObservableResult}
    obs = StructTypes.constructfrom(Observables.Observable, obj.observable)
    return R(obs, obj.targets)
end

function StructTypes.constructfrom(::Type{Result}, r::Braket.IR.AbstractProgramResult)
    typ = StructTypes.subtypes(Result)[Symbol(r.type)]
    StructTypes.constructfrom(typ, r)
end

function Base.getindex(r::GateModelQuantumTaskResult, rt::Result)
    ix = findfirst(rt_->rt_.type==ir(rt, Val(:JAQCD)), r.result_types)
    isnothing(ix) && throw(KeyError(rt))
    return r.values[ix]
end