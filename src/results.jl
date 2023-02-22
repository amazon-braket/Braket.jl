"""
    Result

Abstract type representing a measurement to perform on
a [`Circuit`](@ref).

See also: [`Expectation`](@ref), [`Variance`](@ref),
[`Sample`](@ref), [`Probability`](@ref),
[`DensityMatrix`](@ref), and [`Amplitude`](@ref).
"""
abstract type Result end

union_obs_typ = @NamedTuple{observable::IRObservable, targets::Vector{Int}, type::String}

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
        StructTypes.lower(x::$typ) = $ir_typ(StructTypes.lower(x.observable), (isempty(x.targets) ? nothing : Int.(x.targets)), $label)
        StructTypes.lowertype(::Type{$typ}) = union_obs_typ
        function ir(r::$typ, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
            obs_ir = ir(r.observable, r.targets, Val(:OpenQASM); serialization_properties=serialization_properties)
            return "#pragma braket result " * $label * " $obs_ir"
        end
        $typ(x::union_obs_typ) = $typ(StructTypes.constructfrom(Observables.Observable, x.observable), x.targets)
        chars(x::$typ) = (uppercasefirst($label) * "(" * chars(x.observable)[1] * ")",) 
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
        chars(x::$typ) = (uppercasefirst($label),) 
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
    AdjointGradient <: Result

Struct which represents a gradient computation using the adjoint differentiation method on a [`Circuit`](@ref). 
"""
struct AdjointGradient <: Result
    observable::Observable
    targets::Vector{QubitSet}
    parameters::Vector{String}
    function AdjointGradient(observable::Observable, targets::Vector{QubitSet}, parameters::Vector{String}=["all"])
        if observable isa Sum
            length(targets) == length(observable) || throw(DimensionMismatch("length of targets ($(length(targets))) must be the same as number of summands ($(length(observable)))."))
            all(length(term_target) == qubit_count(summand) for (term_target, summand) in zip(targets, observable.summands)) || throw(DimensionMismatch("each target must be the same size as the qubit count of its corresponding term."))
        else
            (length(targets) == 1 && length(targets[1]) == qubit_count(observable)) || throw(DimensionMismatch("targets $targets must have only one element if adjoint gradient observable is not a Sum."))
        end
        new(observable, targets, parameters)
    end
end

"""
    AdjointGradient(o::Observable, targets, parameters::Vector) -> AdjointGradient
    AdjointGradient(o::Observable, targets) -> AdjointGradient

Constructs an `AdjointGradient` with respect to the expectation value of
an observable `o` on qubits `targets`. The gradient will be calculated by
computing partial derivatives with respect to `parameters`. If `parameters`
is not present, is empty, or is `["all"]`, all parameters in the circuit
will be used. 

`targets` may be one of:
  - A [`QubitSet`](@ref)
  - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
  - An `Int` or `Qubit`

`AdjointGradient` supports using [`Sum`](@ref) observables. If `o` is a `Sum`,
`targets` should be a nested vector of target qubits, such that the `n`-th term of
`targets` has the same length as the `n`-th term of `o`.

# Examples
```jldoctest
julia> α = FreeParameter(:alpha);

julia> c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)]);

julia> op = 2.0 * Braket.Observables.X() * Braket.Observables.X();

julia> c = AdjointGradient(c, op, [QubitSet(0, 1)], [α]);
```

Using a `Sum`:

```jldoctest
julia> α = FreeParameter(:alpha);

julia> c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)]);

julia> op1 = 2.0 * Braket.Observables.X() * Braket.Observables.X();

julia> op2 = -3.0 * Braket.Observables.Y() * Braket.Observables.Y();

julia> c = AdjointGradient(c, op1 + op2, [QubitSet(0, 1), QubitSet(0, 2)], [α]);
```
"""
function AdjointGradient(observable::Observable, targets::Vector{QubitSet}, parameters::Vector)
    isempty(parameters) && return AdjointGradient(observable, targets, ["all"])
    return AdjointGradient(observable, targets, string.(parameters))
end
AdjointGradient(observable::Observable, targets::QubitSet, parameters) = AdjointGradient(observable, [targets], parameters)
AdjointGradient(observable::Observable, targets::Vector{Vector{T}}, args...) where {T} = AdjointGradient(observable, [QubitSet(t) for t in targets], args...)
AdjointGradient(observable::Observable, targets::Vector{<:IntOrQubit}, args...) = AdjointGradient(observable, [QubitSet(targets)], args...)
AdjointGradient(observable::Observable, targets::IntOrQubit, args...) = AdjointGradient(observable, [QubitSet(targets)], args...)

function ir(ag::AdjointGradient, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    isempty(ag.parameters) && (ag.parameters = ["all"])
    if ag.observable isa Sum
        obs_str = ir(ag.observable, ag.targets, Val(:OpenQASM), serialization_properties=serialization_properties)
    else
        obs_str = ir(ag.observable, first(ag.targets), Val(:OpenQASM), serialization_properties=serialization_properties)
    end
    term_str = replace(obs_str, "+ -"=>"- ")
    return "#pragma braket result adjoint_gradient expectation($term_str) $(join(ag.parameters, ", "))"
end
StructTypes.StructType(::Type{AdjointGradient}) = StructTypes.CustomStruct()
function StructTypes.lower(x::AdjointGradient)
    lowered_obs = ir(x.observable, Val(:JAQCD))
    lowered_targets = (isempty(x.targets) ? nothing : convert(Vector{Vector{Int}}, x.targets))
    Braket.IR.AdjointGradient(x.parameters, lowered_obs, lowered_targets, "adjoint_gradient")
end
StructTypes.lowertype(::Type{AdjointGradient}) = @NamedTuple{parameters::Union{Nothing, Vector{String}}, observable::IRObservable, targets::Union{Nothing, Vector{Vector{Int}}}, type::String}
function AdjointGradient(x::@NamedTuple{parameters::Union{Nothing, Vector{String}}, observable::IRObservable, targets::Union{Nothing, Vector{Vector{Int}}}, type::String})
    params = isnothing(x.parameters) || isempty(x.parameters) ? ["all"] : x.parameters
    obs = StructTypes.constructfrom(Observables.Observable, x.observable)
    targets = isnothing(x.targets) || isempty(x.targets) ? QubitSet[] : [QubitSet(t) for t in x.targets]
    return AdjointGradient(obs, targets, parameters)
end
chars(x::AdjointGradient) = ("AdjointGradient(H)",) 


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
chars(x::Amplitude) = ("Amplitude(" * join(x.states, ", ") * ")",)

"""
    StateVector <: Result

Struct which represents a state vector measurement on a [`Circuit`](@ref). 
"""
struct StateVector <: Result end
ir(s::StateVector, ::Val{:OpenQASM}; kwargs...) = "#pragma braket result state_vector"
Base.:(==)(sv1::StateVector, sv2::StateVector) = true
chars(x::StateVector) = ("StateVector",)

const ObservableResult = Union{Expectation, Variance, Sample}
const ObservableParameterResult = Union{AdjointGradient,}

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

function Base.getindex(r::GateModelQuantumTaskResult, rt::AdjointGradient)
    # only one AdjointGradient result per circuit
    ix = findfirst(rt_->rt_.type isa IR.AdjointGradient, r.result_types)
    isnothing(ix) && throw(KeyError(rt))
    return r.values[ix]
end

function Base.getindex(r::GateModelQuantumTaskResult, rt::Result)
    ix = findfirst(rt_->rt_.type==ir(rt, Val(:JAQCD)), r.result_types)
    isnothing(ix) && throw(KeyError(rt))
    return r.values[ix]
end
