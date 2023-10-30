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
