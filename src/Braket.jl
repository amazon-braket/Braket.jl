module Braket

export Circuit, QubitSet, Qubit, Device, AwsDevice, AwsQuantumTask, AwsQuantumTaskBatch
export metadata, status, Observable, Result, FreeParameter, AwsQuantumJob, Tracker, simulator_tasks_cost, qpu_tasks_cost
export arn, cancel, state, result, results, name, download_result, id, ir, isavailable, search_devices, get_devices
export provider_name, properties, type
export apply_gate_noise!
export logs, log_metric, metrics
export depth, qubit_count, qubits, ir, IRType, OpenQASMSerializationProperties
export OpenQasmProgram

export Expectation, Sample, Variance, Amplitude, Probability, StateVector, DensityMatrix, Result

using AWSS3
using AWS
using AWS: @service, AWSConfig, global_aws_config
@service BRAKET use_response_type=false
@service IAM 
@service CLOUDWATCH_LOGS

using Compat
using CSV
using Dates
using Downloads
using DecFP
using Graphs
using HTTP
using JSON3, StructTypes
using LinearAlgebra
using DataStructures

using NamedTupleTools
using OrderedCollections

include("utils.jl")
"""
    IRType

A `Ref{Symbol}` which records which IR output format to use by default.
Currently, two formats are supported:
  - `:JAQCD`, the Amazon Braket IR
  - `:OpenQASM`, the OpenQASM3 representation

By default, `IRType` is initialized to use `:JAQCD`, although this may change
in the future. The current default value can be checked by calling `IRType[]`.
To change the default IR format, set `IRType[]`.

# Examples
```jldoctest
julia> IRType[]
:JAQCD

julia> IRType[] = :OpenQASM;

julia> IRType[]
:OpenQASM

julia> IRType[] = :JAQCD;
```
"""
const IRType = Ref{Symbol}()
include("tracker.jl")
const Prices = Ref{Pricing}()
const GlobalTrackerContext = Ref{TrackerContext}()

function __init__()
    AWS.DEFAULT_BACKEND[] = AWS.DownloadsBackend()
    IRType[] = :JAQCD
    Prices[] = Pricing([])
    GlobalTrackerContext[] = TrackerContext()
end

qubit_count(t) = throw(MethodError(qubit_count, t))

include("qubit_set.jl")
include("raw_schema.jl")
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
end
Base.show(io::IO, fp::FreeParameter) = print(io, string(fp.name))

include("compiler_directive.jl")
include("gates.jl")
include("noises.jl")
include("results.jl")
include("schemas.jl")
include("moments.jl")
include("circuit.jl")
include("noise_model.jl")
include("device.jl")
include("raw_ahs.jl")
include("gate_applicators.jl")
include("noise_applicators.jl")
include("jobs.jl")
include("task.jl")
include("task_batch.jl")

end # module
