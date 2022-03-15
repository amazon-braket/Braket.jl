using Dates, NamedTupleTools, AxisArrays, DataStructures
import StructTypes

abstract type AbstractQuantumTaskResult <: BraketSchemaBase end

@enum AnalogHamiltonianSimulationShotStatus success partial_success failure
AnalogHamiltonianSimulationShotStatusDict = Dict(string(inst)=>inst for inst in instances(AnalogHamiltonianSimulationShotStatus))
Base.:(==)(x::AnalogHamiltonianSimulationShotStatus, y::String) = string(x) == y
Base.:(==)(x::String, y::AnalogHamiltonianSimulationShotStatus) = string(y) == x
struct ShotResult <: BraketSchemaBase
    status::AnalogHamiltonianSimulationShotStatus
    pre_sequence::Union{Nothing, Array}
    post_sequence::Union{Nothing, Array}
end
StructTypes.StructType(::Type{ShotResult}) = StructTypes.UnorderedStruct()

StructTypes.defaults(::Type{ShotResult}) = Dict{Symbol, Any}(:pre_sequence => nothing, :post_sequence => nothing)
Base.:(==)(r1::ShotResult, r2::ShotResult) = all(getproperty(r1, fn) == getproperty(r2, fn) for fn in fieldnames(ShotResult))
struct AnalogHamiltonianSimulationQuantumTaskResult <: AbstractQuantumTaskResult
    task_metadata::TaskMetadata
    measurements::Union{Nothing, Vector{ShotResult}}
end
StructTypes.StructType(::Type{AnalogHamiltonianSimulationQuantumTaskResult}) = StructTypes.UnorderedStruct()

StructTypes.defaults(::Type{AnalogHamiltonianSimulationQuantumTaskResult}) = Dict{Symbol, Any}(:measurements => nothing)
Base.:(==)(r1::AnalogHamiltonianSimulationQuantumTaskResult, r2::AnalogHamiltonianSimulationQuantumTaskResult) = all(getproperty(r1, fn) == getproperty(r2, fn) for fn in fieldnames(AnalogHamiltonianSimulationQuantumTaskResult))
struct AnnealingQuantumTaskResult <: AbstractQuantumTaskResult
    record_array::AxisArray
    variable_count::Int
    problem_type::ProblemType
    task_metadata::TaskMetadata
    additional_metadata::AdditionalMetadata
end
StructTypes.StructType(::Type{AnnealingQuantumTaskResult}) = StructTypes.UnorderedStruct()

Base.:(==)(r1::AnnealingQuantumTaskResult, r2::AnnealingQuantumTaskResult) = all(getproperty(r1, fn) == getproperty(r2, fn) for fn in fieldnames(AnnealingQuantumTaskResult))
struct GateModelQuantumTaskResult <: AbstractQuantumTaskResult
    task_metadata::TaskMetadata
    additional_metadata::AdditionalMetadata
    result_types::Union{Nothing, Vector{ResultTypeValue}}
    values::Union{Nothing, Vector{Any}}
    measurements::Union{Nothing, Array}
    measured_qubits::Union{Nothing, Vector{Int}}
    measurement_counts::Union{Nothing, Accumulator}
    measurement_probabilities::Union{Nothing, Dict{String, Float64}}
    measurements_copied_from_device::Union{Nothing, Bool}
    measurement_counts_copied_from_device::Union{Nothing, Bool}
    measurement_probabilities_copied_from_device::Union{Nothing, Bool}
    _result_types_indices::Union{Nothing, Dict{String, Int}}
end
StructTypes.StructType(::Type{GateModelQuantumTaskResult}) = StructTypes.UnorderedStruct()

StructTypes.defaults(::Type{GateModelQuantumTaskResult}) = Dict{Symbol, Any}(:values => nothing, :measurements => nothing, :measurement_counts => nothing, :measured_qubits => nothing, :measurement_probabilities => nothing, :measurement_counts_copied_from_device => nothing, :measurement_probabilities_copied_from_device => nothing, :measurements_copied_from_device => nothing, :result_types => nothing, :_result_types_indices => nothing)
Base.:(==)(r1::GateModelQuantumTaskResult, r2::GateModelQuantumTaskResult) = all(getproperty(r1, fn) == getproperty(r2, fn) for fn in fieldnames(GateModelQuantumTaskResult))
struct PhotonicModelQuantumTaskResult <: AbstractQuantumTaskResult
    task_metadata::TaskMetadata
    additional_metadata::AdditionalMetadata
    measurements::Union{Nothing, Array}
end
StructTypes.StructType(::Type{PhotonicModelQuantumTaskResult}) = StructTypes.UnorderedStruct()

StructTypes.defaults(::Type{PhotonicModelQuantumTaskResult}) = Dict{Symbol, Any}(:measurements => nothing)
Base.:(==)(r1::PhotonicModelQuantumTaskResult, r2::PhotonicModelQuantumTaskResult) = all(getproperty(r1, fn) == getproperty(r2, fn) for fn in fieldnames(PhotonicModelQuantumTaskResult))
type_dict["braket.task_result.gate_model_quantum_task_result_v1"] = GateModelQuantumTaskResult
type_dict["braket.task_result.annealing_quantum_task_result_v1"] = AnnealingQuantumTaskResult
type_dict["braket.task_result.photonic_model_quantum_task_result_v1"] = PhotonicModelQuantumTaskResult
header_dict[GateModelQuantumTaskResult] = braketSchemaHeader("braket.task_result.gate_model_quantum_task_result", "1")
header_dict[AnnealingQuantumTaskResult] = braketSchemaHeader("braket.task_result.annealing_quantum_task_result", "1")
header_dict[PhotonicModelQuantumTaskResult] = braketSchemaHeader("braket.task_result.photonic_model_quantum_task_result", "1")
