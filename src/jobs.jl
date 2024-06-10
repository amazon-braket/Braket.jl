using Base64
using Pickle

const JOB_DEFAULT_RESULTS_POLL_TIMEOUT = 864000
const JOB_DEFAULT_RESULTS_POLL_INTERVAL = 5
const JOB_TERMINAL_STATES = ["COMPLETED", "FAILED", "CANCELLED"]
const RESULTS_FILENAME = "results.json"
const RESULTS_TAR_FILENAME = "model.tar.gz"
const LOG_GROUP = "/aws/braket/jobs"
const stream_colors = [34, 35, 32, 36, 33]
const QUERY_DEFAULT_JOB_DURATION = 3 * 60 * 60
const QUERY_POLL_TIMEOUT_SECONDS = 10
const QUERY_POLL_INTERVAL_SECONDS = 1
const METRIC_DEFINITIONS = r"(\w+)\s*=\s*([^;]+)\s*;"
const TIMESTAMP = "timestamp"
const ITERATION_NUMBER = "iteration_number"
const NODE_ID = "node_id"
const NODE_TAG = r"^\[([^\]]*)\]"
const ECR_URI_PATTERN = r"^((\d+)\.dkr\.ecr\.([^.]+)\.[^/]*)/([^:]*):(.*)$"

@enum LogState TAILING JOB_COMPLETE COMPLETE
@enum Framework BASE PL_TENSORFLOW PL_PYTORCH

"""
    Job

Abstract type representing a Braket Job.
"""
abstract type Job end

get_job(j::Job) = get_job(arn(j))
get_job(arn::String) = startswith(arn, "local") ? LocalQuantumJob(arn) : BRAKET.get_job(HTTP.escapeuri(arn) * "?additionalAttributeNames=QueueInfo")

config_fname(f::Framework) = joinpath(@__DIR__, "image_uri_config", lowercase(string(f))*".json")
config_for_framework(f::Framework) = JSON3.read(read(config_fname(f), String), Dict)

function registry_for_region(config::Dict{String, Any}, region::String)
    registry_config = config["registries"]
    haskey(registry_config, region) || throw(ErrorException("unsupported region $region. You may need to update your SDK version for newer regions. Supported regions: $(collect(keys(registry_config)))."))
    return registry_config[region]
end

function retrieve_image(f::Framework, config::AWSConfig)
    aws_region = AWS.region(config)
    conf = config_for_framework(f)
    framework_version = maximum(version for version in keys(conf["versions"]))
    version_config = conf["versions"][framework_version]
    registry = registry_for_region(version_config, aws_region)
    tag = if f == BASE
        string(version_config["repository"]) * ":" * "latest"
    elseif f == PL_TENSORFLOW
        string(version_config["repository"]) * ":" * "latest"
    elseif f == PL_PYTORCH
        string(version_config["repository"]) * ":" * "latest"
    end
    return string(registry) * ".dkr.ecr.$aws_region.amazonaws.com/$tag"
end

function get_input_data_dir(channel::String="input")
    input_dir = get(ENV, "AMZN_BRAKET_INPUT_DIR", ".")
    return input_dir == "." ? input_dir : joinpath(input_dir, channel)
end
get_job_name() = get(ENV, "AMZN_BRAKET_JOB_NAME", "")
get_job_device_arn() = get(ENV, "AMZN_BRAKET_DEVICE_ARN", "local:none/none")
get_results_dir() = get(ENV, "AMZN_BRAKET_JOB_RESULTS_DIR", ".")
get_checkpoint_dir() = get(ENV, "AMZN_BRAKET_CHECKPOINT_DIR", ".")
function get_hyperparameters()
    haskey(ENV, "AMZN_BRAKET_HP_FILE") || return Dict{String, Any}()
    return JSON3.read(read(ENV["AMZN_BRAKET_HP_FILE"], String), Dict{String, Any}) 
end

function serialize_values(data_dictionary::Dict{String, Any}, data_format::PersistedJobDataFormat)
    data_format == pickled_v4 && return Dict(k => base64encode(Pickle.stores(v)) for (k, v) in data_dictionary)
    return data_dictionary
end

function deserialize_values(data_dictionary::Dict{String, Any}, data_format::PersistedJobDataFormat)
    data_format == plaintext && return data_dictionary
    return Dict(k => Pickle.loads(base64decode(v)) for (k, v) in data_dictionary)
end
deserialize_values(data_dictionary::Dict{String, Any}, data_format::String) = deserialize_values(data_dictionary, PersistedJobDataFormatDict[data_format])

function _load_persisted_data(filename::String="")
    isempty(filename) && (filename = joinpath(get_results_dir(), "results.json"))
    try    
        return JSON3.read(read(filename, String), Dict{String, Any})
    catch
        return PersistedJobData(header_dict[PersistedJobData], Dict{String, Any}(), plaintext)
    end
end

function save_job_result(result_data::Dict{String, Any}, data_format::PersistedJobDataFormat=plaintext)
    # can't handle pickled data yet
    current_persisted_data = _load_persisted_data()
    current_results = deserialize_values(current_persisted_data.dataDictionary, current_persisted_data.dataFormat)
    updated_results = merge(current_results, result_data)
    result_path = joinpath(get_results_dir(), "results.json")
    serialized_data = serialize_values(updated_results, data_format)
    persisted_data = PersistedJobData(header_dict[PersistedJobData], serialized_data, data_format)
    write(result_path, JSON3.write(persisted_data))
    return
end
save_job_result(result_data, data_format::PersistedJobDataFormat=plaintext) = save_job_result(Dict{String, Any}("result"=>result_data), data_format)

Base.@kwdef mutable struct JobsOptions
    entry_point::String=""
    image_uri::String=""
    job_name::String=_generate_default_job_name(image_uri)
    code_location::String=construct_s3_uri(default_bucket(), "jobs", job_name, "script")
    role_arn::String=get(ENV, "BRAKET_JOBS_ROLE_ARN", _get_default_jobs_role())
    wait_until_complete::Bool=false
    hyperparameters::Dict{String, <:Any}=Dict{String, Any}()
    input_data::Union{String, Dict} = Dict()
    instance_config::InstanceConfig = InstanceConfig()
    distribution::String=""
    stopping_condition::StoppingCondition = StoppingCondition()
    output_data_config::OutputDataConfig = OutputDataConfig(job_name=job_name)
    copy_checkpoints_from_job::String=""
    checkpoint_config::CheckpointConfig = CheckpointConfig(job_name)
    tags::Dict{String, String}=Dict{String, String}()
end
