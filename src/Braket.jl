module Braket

export Circuit, QubitSet, Qubit, Device, AwsDevice, AwsQuantumTask, AwsQuantumTaskBatch
export metadata, status, Observable, Result, FreeParameter, Job, AwsQuantumJob, LocalQuantumJob, LocalSimulator
export Tracker, simulator_tasks_cost, qpu_tasks_cost
export arn, cancel, state, result, results, name, download_result, id, ir, isavailable, search_devices, get_devices
export provider_name, properties, type
export apply_gate_noise!, apply
export logs, log_metric, metrics, @hybrid_job
export depth, qubit_count, qubits, ir, IRType, OpenQASMSerializationProperties
export OpenQasmProgram
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

using Profile
using Base64
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
using StaticArrays
using NamedTupleTools
using OrderedCollections
using Tar

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
abstract type BraketSimulator end

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

"""
    Device

Abstract type representing a generic device which tasks (local or managed) may be run on.
"""
abstract type Device end


qubit_count(t) = throw(MethodError(qubit_count, t))
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
