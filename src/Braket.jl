module Braket

export Circuit, QubitSet, Qubit, Device, AwsDevice, AwsQuantumTask, AwsQuantumTaskBatch
export metadata, status, Observable, Result, FreeParameter, FreeParameterExpression, Job, AwsQuantumJob, LocalQuantumJob, LocalSimulator, subs
export Tracker, simulator_tasks_cost, qpu_tasks_cost
export arn, cancel, state, result, results, name, download_result, id, ir, isavailable, search_devices, get_devices
export provider_name, properties, type
export apply_gate_noise!, apply
export logs, log_metric, metrics, @hybrid_job
export depth, qubit_count, qubits, ir, IRType, OpenQASMSerializationProperties
export OpenQasmProgram, Measure, measure
export simulate
export QueueDepthInfo, QueueType, Normal, Priority, queue_depth, queue_position

export AdjointGradient, Expectation, Sample, Variance, Amplitude, Probability, StateVector, DensityMatrix, Result

using AWSS3
using AWS
using AWS: @service, AWSConfig, global_aws_config, apply
import AWS.Mocking: apply
@service BRAKET use_response_type=true
@service IAM use_response_type=true
@service EcR use_response_type=true
@service CLOUDWATCH_LOGS use_response_type=true

using Base64
using Compat
using CSV
using Dates
using Downloads
using DecFP
using Graphs
using HTTP
using StaticArrays
using Symbolics
using SymbolicUtils
using JSON3, StructTypes
using LinearAlgebra
using DataStructures
using NamedTupleTools
using OrderedCollections
using Tar

# Operator overloading for FreeParameterExpression
import Base: +, -, *, /, ^, ==

include("utils.jl")
"""
    IRType

A `Ref{Symbol}` which records which IR output format to use by default.
Currently, two formats are supported:
  - `:JAQCD`, the Amazon Braket IR
  - `:OpenQASM`, the OpenQASM3 representation

By default, `IRType` is initialized to use `:OpenQASM`, although this may change
in the future. The current default value can be checked by calling `IRType[]`.
To change the default IR format, set `IRType[]`.

# Examples
```jldoctest
julia> IRType[]
:OpenQASM

julia> IRType[] = :JAQCD;

julia> IRType[]
:JAQCD

julia> IRType[] = :OpenQASM;
```
"""
const IRType = Ref{Symbol}()
include("tracker.jl")
const Prices = Ref{Pricing}()
const GlobalTrackerContext = Ref{TrackerContext}()
abstract type AbstractBraketSimulator end

"""
    _simulator_devices

A `Ref{Dict}` which records the `id`s of registered
[`LocalSimulator`](@ref) backends so that they can be
retrieved by this `id`. A new simulator backend
should register itself in `_simulator_devices`
in its module's `__init__` function.
"""
const _simulator_devices = Ref{Dict}()

function __init__()
    downloader = Downloads.Downloader()
    downloader.easy_hook = (easy, info) -> Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_LOW_SPEED_TIME, 60)
    AWS.DEFAULT_BACKEND[] = AWS.DownloadsBackend()
    AWS.AWS_DOWNLOADER[] = downloader
    IRType[] = :OpenQASM
    Prices[] = Pricing([])
    GlobalTrackerContext[] = TrackerContext()
    _simulator_devices[] = Dict()
end

qubit_count(o) = throw(MethodError(qubit_count, (o,)))

"""
    Device

Abstract type representing a generic device which tasks (local or managed) may be run on.
"""
abstract type Device end


#qubit_count(t) = throw(MethodError(qubit_count, t))
chars(t) = (string(t),) 

include("qubit_set.jl")
include("raw_schema.jl")
ir(p::Union{AHSProgram, BlackbirdProgram, OpenQasmProgram}) = p
using .IR
include("raw_jobs_config.jl")
include("raw_task_result_types.jl")
include("operators.jl")
include("irtypes.jl")
ir(x, ::Val{:JAQCD}; kwargs...) = StructTypes.lower(x)
ir(x) = ir(x, Val(IRType[]))
include("observables.jl")
using .Observables
"""
    FreeParameter
    FreeParameter(name::Symbol) -> FreeParameter

Struct representing a free parameter, which may be used to initialize
to a parametrized [`Gate`](@ref) or [`Noise`](@ref) and then given a
fixed value later by supplying a mapping to a [`Circuit`](@ref).
"""
struct FreeParameter
    name::Symbol
    FreeParameter(name::Symbol) = new(name)
    FreeParameter(name::String) = new(Symbol(name))
end
Base.copy(fp::FreeParameter) = fp
Base.show(io::IO, fp::FreeParameter) = print(io, string(fp.name))

"""
    FreeParameterExpression
    FreeParameterExpression(expr::Union{FreeParameterExpression, Number, Symbolics.Num, String})

Struct representing a [`FreeParameterExpression`](@ref), which can be used in symbolic computations. 
Instances of [`FreeParameterExpression`](@ref) can represent symbolic expressions involving [`FreeParameter`](@ref), 
such as mathematical expressions with undetermined values.

This type is often used in combination with [`FreeParameter`](@ref), which represents individual [`FreeParameter`](@ref)s.

### Examples
```jldoctest
julia> α = FreeParameter(:alpha)
alpha

julia> θ = FreeParameter(:theta)
theta

julia> gate = FreeParameterExpression("α + 2*θ")
α + 2θ

julia> gsub = subs(gate, Dict(:α => 2.0, :θ => 2.0))
6.0

julia> gate + gate
2α + 4θ

julia> gate * gate
(α + 2θ)^2

julia> gate₁ = FreeParameterExpression("phi + 2*gamma")
2gamma + phi
```
"""
struct FreeParameterExpression
    expression::Symbolics.Num
    FreeParameterExpression(expr::Symbolics.Num) = new(expr)
end

FreeParameterExpression(expr::FreeParameterExpression) = FreeParameterExpression(expr.expression)
FreeParameterExpression(expr::Number) = FreeParameterExpression(Symbolics.Num(expr))
FreeParameterExpression(expr) = throw(ArgumentError("Unsupported expression type"))

# Function to validate the input expression string
function validate_expr(expr::String)
    allowed_chars = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-*/^()αβγδεζηθικλμνξοπρςστυφχψωϐϑϕϖϘϙϚϛϜϝϞϟϠϡϰϱϴϵ϶ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ ")
    for char in expr
        if !(char in allowed_chars)
            throw(ArgumentError("Unsupported character '$char' in expression. Only ASCII letters (a-z, A-Z), digits (0-9), Greek letters (α-϶, Α-Ω), space( ), and basic mathematical symbols (+ - * / ^ ()) are allowed."))
        end
    end
    return expr
end

# Function to create FreeParameterExpression from a validated string
function FreeParameterExpression(expr::String)
    validated_expr = validate_expr(expr)
    parsed_expr = parse_expr_to_symbolic(Meta.parse(validated_expr), @__MODULE__)
    return FreeParameterExpression(parsed_expr)
end

Base.show(io::IO, fpe::FreeParameterExpression) = print(io, fpe.expression)
Base.copy(fp::FreeParameterExpression) = fp

function subs(fpe::FreeParameterExpression, parameter_values::Dict{Symbol, <:Number})
    param_values_num = Dict(Symbolics.variable(string(k); T=Real) => v for (k, v) in parameter_values)
    subbed_expr = Symbolics.substitute(fpe.expression, param_values_num)
    if isempty(Symbolics.get_variables(subbed_expr))
	    subbed_expr = Symbolics.value(subbed_expr)
        if Symbolics.symtype(subbed_expr) <: Irrational
            return Symbolics.symtype(subbed_expr)()
        else
            return subbed_expr
        end
    else
        subbed_expr = Symbolics.value(subbed_expr)
        return FreeParameterExpression(subbed_expr)
    end 
end

Base.:+(fpe1::FreeParameterExpression, fpe2::Union{FreeParameterExpression, Number, Symbolics.Num}) = 
    FreeParameterExpression((fpe1 isa FreeParameterExpression ? fpe1.expression : fpe1) + 
                            (fpe2 isa FreeParameterExpression ? fpe2.expression : fpe2))

Base.:+(fpe1::Union{Number, Symbolics.Num}, fpe2::FreeParameterExpression) = fpe2 + fpe1
Base.:*(fpe1::FreeParameterExpression, fpe2::Union{FreeParameterExpression, Number, Symbolics.Num}) = 
    FreeParameterExpression((fpe1 isa FreeParameterExpression ? fpe1.expression : fpe1) * 
                            (fpe2 isa FreeParameterExpression ? fpe2.expression : fpe2))
Base.:*(fpe1::Union{Number, Symbolics.Num}, fpe2::FreeParameterExpression) = fpe2 * fpe1

Base.:-(fpe1::FreeParameterExpression, fpe2::Union{FreeParameterExpression, Number, Symbolics.Num}) = 
    FreeParameterExpression((fpe1 isa FreeParameterExpression ? fpe1.expression : fpe1) - 
                            (fpe2 isa FreeParameterExpression ? fpe2.expression : fpe2))
Base.:-(fpe1::Union{Number, Symbolics.Num}, fpe2::FreeParameterExpression) = -1 * fpe2 + fpe1
Base.:-(fpe::FreeParameterExpression) = -1 * fpe

Base.:/(fpe1::FreeParameterExpression, fpe2::Union{FreeParameterExpression, Number, Symbolics.Num}) = 
    FreeParameterExpression((fpe1 isa FreeParameterExpression ? fpe1.expression : fpe1) /
                            (fpe2 isa FreeParameterExpression ? fpe2.expression : fpe2))

Base.:/(fpe1::Union{Number, Symbolics.Num}, fpe2::FreeParameterExpression) = 1/(fpe2 / fpe1)

Base.:^(fpe1::FreeParameterExpression, fpe2::Union{FreeParameterExpression, Number, Symbolics.Num}) = 
    FreeParameterExpression((fpe1 isa FreeParameterExpression ? fpe1.expression : fpe1) ^
                            (fpe2 isa FreeParameterExpression ? fpe2.expression : fpe2))

Base.:^(fpe1::Union{Number, Symbolics.Num}, fpe2::FreeParameterExpression) = fpe1^FreeParameterExpression(fpe2)

Base.:(==)(fpe1::FreeParameterExpression, fpe2::FreeParameterExpression) = isequal(fpe1.expression, fpe2.expression)
Base.:(==)(fpe::FreeParameterExpression, sym_num::Symbolics.Num) = isequal(fpe.expression, sym_num)
Base.:(==)(num::Union{Symbolics.Num, Number}, fpe::FreeParameterExpression) = (fpe == num)
Base.:!=(fpe1::FreeParameterExpression, fpe2::FreeParameterExpression) = !(isequal(fpe1, fpe2))

include("compiler_directive.jl")
include("gates.jl")
include("noises.jl")
include("error_mitigation.jl")
include("results.jl")
include("schemas.jl")
include("moments.jl")
include("circuit.jl")
include("noise_model.jl")
include("ahs.jl")
include("queue_information.jl")
include("device.jl")
include("local_simulator.jl")
include("gate_applicators.jl")
include("noise_applicators.jl")
include("jobs.jl")
include("job_macro.jl")
include("aws_jobs.jl")
include("local_jobs.jl")
include("task.jl")
include("task_batch.jl")
end # module
