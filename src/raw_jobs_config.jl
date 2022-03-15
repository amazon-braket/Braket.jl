import StructTypes

struct CheckpointConfig
    localPath::Union{Nothing, String}
    s3Uri::Union{String, Nothing}
end
StructTypes.StructType(::Type{CheckpointConfig}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CheckpointConfig})   = Dict{Symbol, Any}(:s3Uri => nothing, :localPath => "/opt/jobs/checkpoints")
function CheckpointConfig(job_name::String="")
    local_path = StructTypes.defaults(CheckpointConfig)[:localPath]
    isempty(job_name) && return CheckpointConfig(local_path, nothing)
    s3Uri = construct_s3_uri(default_bucket(), "jobs", job_name, "checkpoints")
    return CheckpointConfig(local_path, s3Uri)
end

struct DeviceConfig
    device::String
end
StructTypes.StructType(::Type{DeviceConfig}) = StructTypes.UnorderedStruct()

struct InstanceConfig
    instanceType::Union{Nothing, String}
    volumeSizeInGb::Union{Nothing, Int}
    instanceCount::Union{Nothing, Int}
end
StructTypes.StructType(::Type{InstanceConfig}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{InstanceConfig})   = Dict{Symbol, Any}(:instanceType => "ml.m5.large", :instanceCount => 1, :volumeSizeInGb => 30)
InstanceConfig() = InstanceConfig((StructTypes.defaults(InstanceConfig)[fn] for fn in fieldnames(InstanceConfig))...)


struct OutputDataConfig
    s3Path::Union{String, Nothing}
end
StructTypes.StructType(::Type{OutputDataConfig}) = StructTypes.UnorderedStruct()
function OutputDataConfig(; job_name::String="")
    isempty(job_name) && return OutputDataConfig(nothing)
    return OutputDataConfig(construct_s3_uri(default_bucket(), "jobs", job_name, "data"))
end

struct S3DataSourceConfig
    config::Dict
end
StructTypes.StructType(::Type{S3DataSourceConfig}) = StructTypes.UnorderedStruct()


struct StoppingCondition
    maxRuntimeInSeconds::Union{Nothing, Int}
end
StructTypes.StructType(::Type{StoppingCondition}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{StoppingCondition})   = Dict{Symbol, Any}(:maxRuntimeInSeconds => 432000)
StoppingCondition() = StoppingCondition((StructTypes.defaults(StoppingCondition)[fn] for fn in fieldnames(StoppingCondition))...)


function S3DataSourceConfig(s3_data::String, content_type::String="")
    config = Dict{String, Any}("dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>s3_data)))
    if !isempty(content_type)
        config["contentType"] = content_type
    end
    return S3DataSourceConfig(config)
end
Base.Dict(x::CheckpointConfig) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(CheckpointConfig))
Base.Dict(x::DeviceConfig) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(DeviceConfig))
Base.Dict(x::InstanceConfig) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(InstanceConfig))
Base.Dict(x::OutputDataConfig) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(OutputDataConfig))
Base.Dict(x::S3DataSourceConfig) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(S3DataSourceConfig))
Base.Dict(x::StoppingCondition) = Dict{String, Any}(string(fn)=>getproperty(x, fn) for fn in fieldnames(StoppingCondition))
