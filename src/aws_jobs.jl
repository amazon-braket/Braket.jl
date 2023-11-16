"""
    AwsQuantumJob

Struct representing an Amazon Braket Hybrid Job.
"""
mutable struct AwsQuantumJob <: Job
    arn::String
    _metadata::Dict
    AwsQuantumJob(arn::String) = new(arn, Dict())
end
"""
    arn(j::AwsQuantumJob)

Returns the ARN identifying the job `j`. This ARN can be used to
reconstruct the job after the session that launched it has exited.
"""
arn(j::AwsQuantumJob)    = j.arn
"""
    name(j::AwsQuantumJob)

Returns the name of the job `j`.
"""
name(j::AwsQuantumJob)   = String(split(arn(j), "job/")[end])
"""
    cancel(j::AwsQuantumJob)

Cancels the job `j`.
"""
cancel(j::AwsQuantumJob) = (r = BRAKET.cancel_job(HTTP.escapeuri(arn(j))); return nothing)

function describe_log_streams(log_group::String, stream_prefix::String, limit::Int=-1, next_token::String="")
    args = Dict{String, Any}("logGroupName"=>log_group, "logStreamNamePrefix"=>stream_prefix, "orderBy"=>"LogStreamName")
    limit > 0 && (args["limit"] = limit)
    !isempty(next_token) && (args["nextToken"] = next_token)
    return CLOUDWATCH_LOGS.describe_log_streams(args) 
end

"""
    log_metric(metric_name::String, value::Union{Float64, Int}; timestamp=time(), iteration_number=nothing)

Within a job script, log a metric with name `metric_name` and value `value` which can later be fetched
*outside the job* with [`metrics`](@ref). A metric might be, for example, the loss of a training algorithm
at each epoch, or similar.
"""
function log_metric(metric_name::String, value::Union{Float64, Int}; timestamp=time(), iteration_number=nothing)
    metric_line = "Metrics - timestamp=$timestamp; $metric_name=$value;"
    if !isnothing(iteration_number)
        metric_line *= " iteration_number=$iteration_number;"
    end
    println(metric_line)
    return
end

function queue_position(j::AwsQuantumJob)
    md =  metadata(j)
    response = md["queueInfo"]
    queue_position = get(response, "position", "None") == "None" ? "" : get(response, "position", "")
    message = get(response, "message", "")
    return HybridJobQueueInfo(queue_position, message)
end

function log_stream(ch::Channel, log_group::String, stream_name::String, start_time::Int=0, skip::Int=0)
    next_token = nothing
    event_count = 1
    while event_count > 0
        response = CLOUDWATCH_LOGS.get_log_events(stream_name, Dict("logGroupName"=>log_group, "startTime"=>start_time, "nextToken"=>next_token, "startFromHead"=>true))
        next_token = response["nextForwardToken"]
        events = response["events"]
        event_count = length(events)
        if event_count > skip
            events = events[skip+1:end]
            skip = 0
        else
            skip = skip - event_count
            events = []
        end
        for ev in events
            put!(ch, ev)
        end
    end
    return
end

function multi_stream(log_group::String, streams::Vector{String}, positions::Dict{String, NamedTuple})
    chs = [Channel(Inf) for _ in 1:length(streams)]
    for (i, s) in enumerate(streams)
        if VERSION >= v"1.7"
            errormonitor(@async log_stream(chs[i], log_group, s, positions[s][:timestamp], positions[s][:skip]))
        else
            @async log_stream(chs[i], log_group, s, positions[s][:timestamp], positions[s][:skip])
        end
    end
    sleep(5) # let the events get populated
    events = Channel() do ch
        while any(isready, chs)
            ex, next_i = findmin(x->(isready(x) ? fetch(x)["timestamp"] : Inf), chs)
            ex = take!(chs[next_i])
            put!(ch, (next_i, ex))
        end
    end
    return events
end

function flush_log_streams(log_group::String, stream_prefix::String, stream_names::Vector{String}, positions::Dict{String, NamedTuple}, stream_count::Int, has_streams::Bool; wait::Bool=false)
    while length(stream_names) < stream_count
        streams = describe_log_streams(log_group, stream_prefix, stream_count)
        new_streams = [s["logStreamName"] for s in filter(x->x["logStreamName"]∉stream_names, streams["logStreams"])]
        append!(stream_names, new_streams)
        for s in setdiff(stream_names, keys(positions))
            positions[s] = (timestamp=0, skip=0)
        end
        # TODO fix
        length(stream_names) < stream_count && sleep(5)
        !wait && break
    end
    if length(stream_names) > 0
        if !has_streams
            println()
            has_streams = true
        end
        for (idx, event) in collect(multi_stream(log_group, stream_names, positions))
            Base.printstyled(event["message"]*"\n", color=stream_colors[idx])
            ts, count = positions[stream_names[idx]]
            if event["timestamp"] == ts
                positions[stream_names[idx]] = (timestamp=ts, skip=count+1)
            else
                positions[stream_names[idx]] = (timestamp=event["timestamp"], skip=1)
            end
        end
    else
        print(".")
    end
    return has_streams
end

"""
    logs(j::AwsQuantumJob; wait::Bool=false, poll_interval_seconds::Int=5)

Fetches the logs of job `j`. If `wait` is `true`, blocks until `j` has entered a terminal state
(`"COMPLETED"`, `"FAILED"`, or `"CANCELLED"`). Polls every `poll_interval_seconds` for new log data.
"""
function logs(j::AwsQuantumJob; wait::Bool=false, poll_interval_seconds::Int=5)
    already_done = state(j) ∈ JOB_TERMINAL_STATES
    log_state = (wait && !already_done) ? TAILING : COMPLETE
    log_group = LOG_GROUP
    stream_prefix = name(j) * "/"
    stream_names = String[]
    stream_positions = Dict{String, NamedTuple}()
    instance_count = metadata(j, Val(true))["instanceConfig"]["instanceCount"]
    has_streams = false
    while true
        sleep(poll_interval_seconds)
        has_streams = flush_log_streams(log_group, stream_prefix, stream_names, stream_positions, instance_count, has_streams, wait=(log_state==COMPLETE))
        log_state == COMPLETE && break
        if log_state == JOB_COMPLETE
            log_state = COMPLETE
        elseif state(j) ∈ JOB_TERMINAL_STATES
            log_state = JOB_COMPLETE
        end
    end
end

function _parse_result(result_line)
    msg_ix = findfirst(elem->(elem["field"] == "@message"), result_line)
    isnothing(msg_ix) && return (timestamp="", message="")

    msg = result_line[msg_ix]["value"]
    ts_ix = findfirst(elem->(elem["field"] == "@timestamp"), result_line)
    ts = result_line[ts_ix]["value"]
    return (timestamp=ts, message=msg)
end

function _parse_query_results(results::Vector, metric_type::String=TIMESTAMP, statistic::String="MAX")
    parsed = filter(x->!isempty(x.message), map(_parse_result, results))
    metrics_dict = Dict{String, Vector}()
    sortby = metric_type
    for p in parsed
        parsed_metrics = Dict{String, Any}()
        for m in eachmatch(METRIC_DEFINITIONS, p.message)
            !isempty(p.timestamp) && TIMESTAMP ∉ m.captures && (parsed_metrics[TIMESTAMP] = [p.timestamp])
            ITERATION_NUMBER ∈ m.captures && (parsed_metrics[ITERATION_NUMBER] = [String(m.captures[end])])
            node_match = match(NODE_TAG, p.message)
            !isnothing(node_match) && (parsed_metrics[NODE_ID] = [String(node_match.captures)])
            sorter = get(parsed_metrics, sortby, [getfield(p, Symbol(string(sortby)))])[1]
            parsed_metrics[String(m[1])] = [(sorter, String(m[2]))]
        end
        mergewith!(vcat, metrics_dict, parsed_metrics)
    end
    @debug "results: $results, metrics_dict: $metrics_dict"
    p = sortperm(metrics_dict[sortby])
    expanded_metrics_dict = Dict{String, Vector}(sortby=>metrics_dict[sortby][p])
    for k in filter(k->k!=sortby, keys(metrics_dict))
        expanded_metrics_dict[k] = []
        for ind in expanded_metrics_dict[sortby]
            ix = findfirst(local_ind -> local_ind == ind, first.(metrics_dict[k]))
            val = popat!(metrics_dict[k], ix, (missing,))
            push!(expanded_metrics_dict[k], last(val))
        end
    end
    return expanded_metrics_dict
end

function _get_metrics_results_sync(query_id::String)
    timeout_time = time() + QUERY_POLL_TIMEOUT_SECONDS
    while time() < timeout_time
        response = CLOUDWATCH_LOGS.get_query_results(query_id)
        query_status = response["status"]
        query_status ∈ ["Failed", "Cancelled"] && throw(ErrorException("Query $query_id failed with status $query_status"))
        query_status == "Complete" && return response["results"]
        sleep(QUERY_POLL_INTERVAL_SECONDS)
    end
    @warn "Timed out waiting for query $query_id"
    return []
end

function _get_metrics_for_job(job_name::String, metric_type::String="TIMESTAMP", statistic::String="MAX", job_start_time=nothing, job_end_time=nothing)
    query_end_time   = isnothing(job_end_time) ? Dates.datetime2unix(Dates.now()) : job_end_time
    query_start_time = isnothing(job_start_time) ? query_end_time - QUERY_DEFAULT_JOB_DURATION : job_start_time
    query    = """fields @timestamp, @message | filter @logStream like /^$job_name\\// | filter @message like /Metrics - /"""
    response = CLOUDWATCH_LOGS.start_query(query_end_time, query, query_start_time, Dict("logGroupName"=>LOG_GROUP, "limit"=>10_000))
    query_id = response["queryId"]
    results  = _get_metrics_results_sync(query_id)
    return isempty(results) ? results : _parse_query_results(results)
end

"""
    metrics(j::AwsQuantumJob; metric_type="timestamp", statistic="max") 

Fetches the metrics for job `j`. Metrics are generated by [`log_metric`](@ref)
within the job script.
"""
function metrics(j::AwsQuantumJob; metric_type="timestamp", statistic="max")
    mtd       = metadata(j, Val(true))
    job_name  = mtd["jobName"]
    job_start = nothing 
    if haskey(mtd, "startedAt")
        job_start = Dates.datetime2unix(DateTime(split(mtd["startedAt"], '.')[1]))
    end
    job_end   = nothing
    if state(j) ∈ JOB_TERMINAL_STATES && haskey(mtd, "endedAt")
        job_end = Dates.datetime2unix(DateTime(split(mtd["endedAt"], '.')[1]))
    end
    return _get_metrics_for_job(job_name, metric_type, statistic, job_start, job_end)
end

"""
    state(j::AwsQuantumJob, ::Val{true})
    state(j::AwsQuantumJob, ::Val{false})
    state(j::AwsQuantumJob)

Fetch the state for job `j`. Possible states are `"CANCELLED"`, `"FAILED"`, `"COMPLETED"`, `"QUEUED"`, and `"RUNNING"`.
If the second argument is `::Val{true}`, use previously cached metadata, if available, otherwise fetch it
from the Braket service. If the second argument is `::Val{false}` (default), do not use previously cached metadata,
and fetch fresh metadata from the Braket service.
"""
state(j::AwsQuantumJob, v) = metadata(j, v)["status"]
state(j::AwsQuantumJob)    = state(j, Val(false))

"""
    metadata(j::AwsQuantumJob, ::Val{true})
    metadata(j::AwsQuantumJob, ::Val{false})
    metadata(j::AwsQuantumJob)

Fetch metadata for job `j`. If the second argument is `::Val{true}`,
use previously cached metadata, if available, otherwise fetch it from
the Braket service. If the second argument is `::Val{false}` (default),
do not use previously cached metadata, and fetch fresh metadata from the Braket service.
"""
metadata(j::AwsQuantumJob, ::Val{false}) = parse(get_job(j))
metadata(j::AwsQuantumJob, ::Val{true})  = !isempty(j._metadata) ? j._metadata : metadata(j, Val(false))
metadata(j::AwsQuantumJob) = metadata(j, Val(false)) 

function _attempt_results_download(j::AwsQuantumJob, output_bucket_uri::String, output_s3_path::String, dl_dir::String)
    bucket, key = parse_s3_uri(output_bucket_uri)
    stream = s3_get(bucket, key, raw=true)
    out_name = joinpath(dl_dir, RESULTS_TAR_FILENAME)
    write(out_name, stream)
    return out_name
end

_extract_tar_file(extract_path::String) = (run(`tar -xf $RESULTS_TAR_FILENAME -C $extract_path`); return extract_path)

"""
    download_result(j::AwsQuantumJob; kwargs...)

Download and extract the results of job `j`. Valid `kwargs` are:
  - `extract_to::String` - the local folder to extract the results to. Default is the current working directory.
  - `poll_timeout_seconds::Int` - the maximum number of seconds to wait while polling for results. Default: $JOB_DEFAULT_RESULTS_POLL_TIMEOUT
  - `poll_interval_seconds::Int` - how many seconds to wait between download attempts. Default: $JOB_DEFAULT_RESULTS_POLL_INTERVAL
"""
function download_result(j::AwsQuantumJob; extract_to=pwd(), poll_timeout_seconds::Int=JOB_DEFAULT_RESULTS_POLL_TIMEOUT, poll_interval_seconds::Int=JOB_DEFAULT_RESULTS_POLL_INTERVAL)
    timeout_time = time() + poll_timeout_seconds
    job_response = metadata(j, Val(true))
    while time() < timeout_time
        job_response = metadata(j, Val(true))
        job_state = state(j)
        if job_state ∈ JOB_TERMINAL_STATES
            output_s3_path = job_response["outputDataConfig"]["s3Path"]
            output_s3_uri  = output_s3_path * "/output/model.tar.gz"
            _attempt_results_download(j, output_s3_uri, output_s3_path, extract_to)
            ex_to = joinpath(extract_to, job_response["jobName"])
            !ispath(ex_to) && mkdir(ex_to)
            ex_path = cd(extract_to) do
                _extract_tar_file(job_response["jobName"])
            end
            return joinpath(extract_to, ex_path)
        else
            sleep(poll_interval_seconds)
        end
    end
    return ""
end

function _read_and_deserialize_results(j::AwsQuantumJob, loc::String)
    try
        open(joinpath(loc, RESULTS_FILENAME), "r") do f
            f_dat = read(f, String)
            persisted_data = parse_raw_schema(f_dat)
            deserialized_data = deserialize_values(persisted_data.dataDictionary, persisted_data.dataFormat)
            return deserialized_data
        end
    catch e
        e isa SystemError && return []
        throw(e)
    end
end

"""
    result(j::AwsQuantumJob; kwargs...)

Download, extract, and deserialize the results of job `j`. Valid `kwargs` are:
  - `poll_timeout_seconds::Int` - the maximum number of seconds to wait while polling for results. Default: $JOB_DEFAULT_RESULTS_POLL_TIMEOUT
  - `poll_interval_seconds::Int` - how many seconds to wait between download attempts. Default: $JOB_DEFAULT_RESULTS_POLL_INTERVAL
"""
function result(j::AwsQuantumJob; poll_timeout_seconds::Int=JOB_DEFAULT_RESULTS_POLL_TIMEOUT, poll_interval_seconds::Int=JOB_DEFAULT_RESULTS_POLL_INTERVAL)
    mktempdir() do d
        try
            fn = download_result(j, extract_to=d, poll_timeout_seconds=poll_timeout_seconds, poll_interval_seconds=poll_interval_seconds)
            return _read_and_deserialize_results(j, fn)
        catch e
            e isa AWS.AWSException && e.cause.status == 404 && return Dict() 
            throw(e)
        end
    end
end

function _generate_default_job_name(image_uri::String="")
    job_type = "-default"
    if !isempty(image_uri)
        re1 = r"/amazon-braket-(.*)-jobs:"
        re2 = r"/amazon-braket-([^:/]*)"
        job_type_match = isnothing(match(re1, image_uri)) ? match(re2, image_uri) : match(re1, image_uri)
        job_type = isnothing(job_type_match) ? "" : "-$(job_type_match[1])"
    end
    t = convert(Int, trunc(time()*1000))
    return "braket-job" * job_type * "-" * string(t)
end

function _process_s3_source_module(source_module::String, entry_point::String, code_location::String)
    isempty(entry_point) && throw(ArgumentError("if source_module ($source_module) is an S3 URI, entry_point must be provided."))
    !endswith(lowercase(source_module), ".tar.gz") && throw(ArgumentError("if source_module ($source_module) is an S3 URI, it must point to a tar.gz file."))
    src_bucket, src_path = parse_s3_uri(source_module)
    dst_bucket, dst_path = parse_s3_uri(code_location * "/source.tar.gz")
    s3_copy(src_bucket, src_path, to_bucket=dst_bucket, to_path=dst_path)
    return
end

function _validate_entry_point_python(source_module_path::String, entry_point::String)
    importable, method = occursin(":", entry_point) ? split(entry_point, ":") : (entry_point, "main")
    return 
end

function _validate_entry_point_julia(source_module_path::String, entry_point::String)
    # check that entry_point parses as valid Julia
    # this will raise an error if there is a syntax issue
    path =  isfile(source_module_path) ? source_module_path : joinpath(source_module_path, entry_point)
    Meta.parse(join(["quote", read(path, String), "end"], ";"))
    return
end

function _process_local_source_module(source_module::String, entry_point::String, code_location::String)
    ispath(source_module) || throw(ArgumentError("source_module ($source_module) not found."))
    if isempty(entry_point)
        entry_point = splitdir(abspath(source_module))[end]
        if !endswith(entry_point, "jl")
            entry_point = String(splitext(entry_point)[1])
        end
    end
    if splitext(source_module)[end] == ".jl" || splitext(entry_point)[end] == ".jl"
        _validate_entry_point_julia(abspath(source_module), entry_point)
    else
        _validate_entry_point_python(abspath(source_module), entry_point)
    end
    _tar_and_upload(abspath(source_module), code_location)
    return entry_point
end

function _tar_and_upload(source_module_path::String, code_location::String)
    mktempdir() do d
        loc = joinpath(d, "source.tar.gz")
        Tar.create(dirname(source_module_path), pipeline(`gzip -9`, loc))
        upload_to_s3(loc, code_location * "/source.tar.gz")
    end
    return
end

function _process_input_data(input_data::Dict, job_name::String)
    @debug "_process_input_data Input data: $input_data"
    processed_input_data = Dict{String, Any}()
    for (k, v) in filter(x->!(x.second isa S3DataSourceConfig), input_data)
        processed_input_data[k] = _process_channel(v, job_name, k)
    end
    return [merge(Dict("channelName"=>k), v.config) for (k,v) in processed_input_data] 
end
_process_input_data(input_data, job_name::String) = _process_input_data(Dict{String, Any}("input_data"=>input_data), job_name)

function _process_channel(loc::String, job_name::String, channel_name::String)
    is_s3_uri(loc) && return S3DataSourceConfig(loc)
    loc_name = splitdir(loc)[2]
    s3_prefix = construct_s3_uri(default_bucket(), "jobs", job_name, "data", channel_name, loc_name)
    @debug "Uploading input data for channel $channel_name from $loc to s3 $s3_prefix with loc_name $loc_name"
    upload_local_data(loc, s3_prefix)
    suffixed_prefix = isdir(loc) ? s3_prefix * "/" : s3_prefix
    return S3DataSourceConfig(suffixed_prefix)
end

function _get_default_jobs_role()
    params = Dict("PathPrefix"=>"/service-role/")
    global_conf = global_aws_config()
    response = IAM.list_roles(params, aws_config=AWS.AWSConfig(creds=global_conf.credentials, region="us-east-1", output=global_conf.output))
    roles = response["ListRolesResult"]["Roles"]["member"]
    for role in roles
        startswith(role["RoleName"], "AmazonBraketJobsExecutionRole") && return role["Arn"]
    end
    throw(ErrorException("No default jobs roles found. Please create a role using the Amazon Braket console or supply a custom role."))
end

function prepare_quantum_job(device::String, source_module::String, j_opts::JobsOptions)
    hyperparams     = Dict(zip(keys(j_opts.hyperparameters), map(string, values(j_opts.hyperparameters))))
    @debug "Job input data: $(j_opts.input_data)"
    @debug "\n\n"
    input_data_list = _process_input_data(j_opts.input_data, j_opts.job_name)
    entry_point = j_opts.entry_point
    if is_s3_uri(source_module)
        _process_s3_source_module(source_module, j_opts.entry_point, j_opts.code_location)
    else
        entry_point = _process_local_source_module(source_module, j_opts.entry_point, j_opts.code_location)
    end
    algo_spec = Dict("scriptModeConfig"=>OrderedDict("entryPoint"=>entry_point,
                                                     "s3Uri"=>j_opts.code_location*"/source.tar.gz",
                                                     "compressionType"=>"GZIP"))

    !isempty(j_opts.image_uri) && setindex!(algo_spec, Dict("uri"=>j_opts.image_uri), "containerImage")
    if !isempty(j_opts.copy_checkpoints_from_job)
        checkpoints_to_copy = get_job(j_opts.copy_checkpoints_from_job)["checkpointConfig"]["s3Uri"]
        copy_s3_directory(checkpoints_to_copy, j_opts.checkpoint_config.s3Uri)
    end
    if j_opts.distribution == "data_parallel"
        merge!(hyperparams, Dict("sagemaker_distributed_dataparallel_enabled"=>"true",
                                 "sagemaker_instance_type"=>j_opts.instance_config.instanceType))
    end

    params = OrderedDict(
                  "checkpointConfig"=>Dict(j_opts.checkpoint_config),
                  "hyperParameters"=>hyperparams,
                  "inputDataConfig"=>input_data_list,
                  "stoppingCondition"=>Dict(j_opts.stopping_condition),
                  "tags"=>j_opts.tags,
                 )
    token     = string(uuid1())
    dev_conf  = Dict(DeviceConfig(device))
    inst_conf = Dict(j_opts.instance_config)
    out_conf  = Dict(j_opts.output_data_config)
    return (algo_spec=algo_spec, token=token, dev_conf=dev_conf, inst_conf=inst_conf, job_name=j_opts.job_name, out_conf=out_conf, role_arn=j_opts.role_arn, params=params)
end

function AwsQuantumJob(device::String, source_module::String, job_opts::JobsOptions)
    args      = prepare_quantum_job(device, source_module, job_opts)
    algo_spec = args[:algo_spec]
    token     = args[:token]
    dev_conf  = args[:dev_conf]
    inst_conf = args[:inst_conf]
    job_name  = args[:job_name]
    out_conf  = args[:out_conf]
    role_arn  = args[:role_arn]
    params    = args[:params]
    response  = BRAKET.create_job(algo_spec, token, dev_conf, inst_conf, job_name, out_conf, role_arn, params)
    job       = AwsQuantumJob(response["jobArn"])
    job_opts.wait_until_complete && logs(job, wait=true)
    return job
end

"""
    AwsQuantumJob(device::Union{String, BraketDevice}, source_module::String; kwargs...)

Create and launch an `AwsQuantumJob` which will use device `device` (a managed simulator, a QPU, or an [embedded simulator](https://docs.aws.amazon.com/braket/latest/developerguide/pennylane-embedded-simulators.html))
and will run the code (either a single file, or a Julia package, or a Python module) located at `source_module`. The keyword arguments
`kwargs` control the launch configuration of the job. `device` can be either the device's ARN as a `String`, or a [`BraketDevice`](@ref). 

# Keyword Arguments
  - `entry_point::String` - the function to run in `source_module` if `source_module` is a Python module/Julia package. Defaults to an empty string, in which case
    the behavior depends on the code language. In Python, the job will attempt to find a function called `main` in `source_module` and run it. In Julia,
    `source_module` will be loaded and run with Julia's [`include`](https://docs.julialang.org/en/v1/base/base/#Base.include).
  - `image_uri::String` - the URI of the Docker image in ECR to run the Job on. Defaults to an empty string, in which case the [base container](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-script-environment.html)
    is used.
  - `job_name::String` - the name for the job, which will be displayed in the [jobs console](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-first.html).
    The default is a combination of the container image name and the current time.
  - `code_location::String` - the S3 prefix URI to which code will be uploaded. The default is `default_bucket()/jobs/<job_name>/script`
  - `role_arn::String` - the IAM role ARN to use to run the job. The default is to use the default jobs role.
  - `wait_until_complete::Bool` - whether to block until the job is complete, displaying log information as
    it arrives (`true`) or to run the job asynchronously (`false`, default).
  - `hyperparameters::Dict{String, Any}` - hyperparameters to provide to the job which will be available from an environment variable when the job is run.
    See the [Amazon Braket documentation](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-hyperparameters.html) for more.
  - `input_data::Union{String, Dict}` - information about the training/input data to provide to the job.
    A `Dict` should map channel names to local paths or S3 URIs. Contents found at any local paths encoded as `String`s will be uploaded to S3 at
    `s3://{default_bucket_name}/jobs/{job_name}/data/{channel_name}`. If a local path or S3 URI is provided, it will be given a default
    channel name `"input"`. The default is `Dict()`.
  - `instance_config::InstanceConfig` - the instance configuration to use to run the job. See the [Amazon Braket documentation](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-configure-job-instance-for-script.html)
    for more information about available instance types. The default is `InstanceConfig("ml.m5.large", 1, 30)`.
  - `distribution::String` - specifies how the job should be distributed. If set to `"data_parallel"`, the hyperparameters
    for the job will be set to use data parallelism features for PyTorch or TensorFlow.
  - `stopping_condition::StoppingCondition` - the maximum length of time, in seconds, that a job
    can run before being forcefully stopped. The default is `StoppingCondition(5 * 24 * 60 * 60)`.
  - `output_data_config::OutputDataConfig` - specifies the location for the output of the job.
    Any data stored here will be available to [`download_result`](@ref) and [`results`](@ref). The default is
    `OutputDataConfig("s3://{default_bucket_name}/jobs/{job_name}/data")`.
  - `copy_checkpoints_from_job::String` - specifies the job ARN whose checkpoint is to be used in the current job.
    Specifying this value will copy over the checkpoint data from `use_checkpoints_from_job`'s `checkpoint_config`
    S3 URI to the current job's `checkpoint_config` S3 URI, making it available at `checkpoint_config.localPath` during
    the job execution. The default is not to copy any checkpoints (an empty string).
  - `checkpoint_config::CheckpointConfig` - specifies the location where
    checkpoint data for *this* job is to be stored.
    The default is `CheckpointConfig("/opt/jobs/checkpoints", "s3://{default_bucket_name}/jobs/{job_name}/checkpoints")`.
  - `tags::Dict{String, String}` - specifies the key-value pairs for tagging this job.
"""
AwsQuantumJob(device::String, source_module::String; kwargs...) = AwsQuantumJob(device, source_module, JobsOptions(; kwargs...))
AwsQuantumJob(device::BraketDevice, source_module::String; kwargs...) = AwsQuantumJob(convert(String, device), source_module, JobsOptions(; kwargs...))
