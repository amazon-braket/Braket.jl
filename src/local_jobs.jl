mutable struct LocalJobContainer
    image_uri::String
    container_name::String
    container_code_path::String
    env::Dict{String, String}
    run_log::String
    config::AWSConfig
    function LocalJobContainer(image_uri::String, create_job_args; config::AWSConfig=global_aws_config(), container_name::String="", container_code_path::String="/opt/ml/code", force_update::Bool=false)
        c = new(image_uri, container_name, container_code_path, Dict{String, String}(), "", config)
        c = start_container!(c, force_update)
        return setup_container!(c, create_job_args)
    end
end
name(c::LocalJobContainer) = c.container_name

function get_env_creds(config::AWSConfig)
    creds = AWS.credentials(config)
    if isempty(creds.token)
        @info "Using the long-lived AWS credentials found in session"
        return Dict("AWS_ACCESS_KEY_ID"=>creds.access_key_id, "AWS_SECRET_ACCESS_KEY"=>creds.secret_key)
    end
    @warn "Using the short-lived AWS credentials found in session. They might expire while running."
    return Dict("AWS_ACCESS_KEY_ID"=>creds.access_key_id, "AWS_SECRET_ACCESS_KEY"=>creds.secret_key, "AWS_SESSION_TOKEN"=>creds.token)
end

function get_env_defaults(config::AWSConfig, args)
    job_name = args[:job_name]
    bucket, location = parse_s3_uri(args[:out_conf]["s3Path"])
    return Dict( 
        "AWS_DEFAULT_REGION"=>AWS.region(config),
        "AMZN_BRAKET_JOB_NAME"=>job_name,
        "AMZN_BRAKET_DEVICE_ARN"=>args[:dev_conf]["device"],
        "AMZN_BRAKET_JOB_RESULTS_DIR"=>"/opt/braket/model",
        "AMZN_BRAKET_CHECKPOINT_DIR"=>args[:params]["checkpointConfig"]["localPath"],
        "AMZN_BRAKET_OUT_S3_BUCKET"=>bucket,
        "AMZN_BRAKET_TASK_RESULTS_S3_URI"=>"s3://$bucket/jobs/$job_name/tasks",
        "AMZN_BRAKET_JOB_RESULTS_S3_PATH"=>joinpath(location, job_name, "output"),
       )
end

function get_env_script_mode_config(script_mode::OrderedDict{String, String})
    result = Dict("AMZN_BRAKET_SCRIPT_S3_URI"=>script_mode["s3Uri"], "AMZN_BRAKET_SCRIPT_ENTRY_POINT"=>script_mode["entryPoint"])
    if haskey(script_mode, "compressionType")
        result["AMZN_BRAKET_SCRIPT_COMPRESSION_TYPE"] = script_mode["compressionType"]
    end
    return result
end

get_env_hyperparameters() = Dict("AMZN_BRAKET_HP_FILE"=>"/opt/braket/input/config/hyperparameters.json")
get_env_input_data()      = Dict("AMZN_BRAKET_INPUT_DIR"=>"/opt/braket/input/data")

function copy_hyperparameters(c::LocalJobContainer, args)
    haskey(args[:params], "hyperParameters") || return false
    hyperparameters = args[:params]["hyperParameters"]
    mktempdir() do temp_dir
        file_path = joinpath(temp_dir, "hyperparameters.json")
        write(file_path, JSON3.write(hyperparameters))
        copy_to_container!(c, file_path, "/opt/ml/input/config/hyperparameters.json")
    end
    return true
end

function is_s3_dir(prefix::String, s3_keys)
    endswith(prefix, "/") && return true
    return all(key->startswith(key, prefix * "/"), s3_keys)
end

function download_input_data(config::AWSConfig, download_dir, input_data::Dict{String, Any})
    channel_name   = input_data["channelName"]
    s3_uri_prefix  = input_data["dataSource"]["s3DataSource"]["s3Uri"]
    bucket, prefix = parse_s3_uri(s3_uri_prefix)
    s3_keys        = collect(s3_list_keys(bucket, prefix))
    @debug "Channel name: $channel_name, S3 URI: $s3_uri_prefix, S3 keys: $s3_keys, bucket: $bucket, prefix: $prefix, all bucket keys: $(collect(s3_list_keys(bucket)))"
    top_level      = is_s3_dir(prefix, s3_keys) ? prefix : dirname(prefix)
    top_level      = isempty(top_level) ? prefix : top_level
    found_item     = false
    try
        mkdir(joinpath(download_dir, channel_name))
    catch e
        throw(ErrorException("Duplicate channel names not allowed for input data: $channel_name"))
    end
    for s3_key in s3_keys
        relative_key  = relpath(s3_key, top_level)
        relative_key  = relative_key == "." ? basename(prefix) : relative_key
        download_path = joinpath(download_dir, channel_name, relative_key)
        if !endswith(s3_key, "/")
            @debug "Getting file from S3: bucket $bucket, s3_key $s3_key, top level $top_level, relative_key $relative_key, download path $download_path"
            mkpath(dirname(download_path))
            s3_get_file(config, bucket, s3_key, download_path)
            found_item = true
        end
    end
    !found_item && throw(ErrorException("No data found for channel '$channel_name'"))
    return
end

function copy_input_data_list(c::LocalJobContainer, args)
    haskey(args[:params], "inputDataConfig") || return false
    input_data_list = args[:params]["inputDataConfig"]
    @debug "Input data list for copy: $input_data_list"
    mktempdir() do temp_dir
        foreach(input_data->download_input_data(c.config, temp_dir, input_data), input_data_list)
        # add dot to copy temp_dir's CONTENTS
        copy_to_container!(c, temp_dir * "/.", "/opt/ml/input/data/")
    end
    return !isempty(input_data_list)
end

function setup_container!(c::LocalJobContainer, create_job_args)
    @debug "Setting up container..."
    c_name = c.container_name
    # create expected paths for a Braket job to run
    @debug "Setting up container: creating expected paths"
    proc_out, proc_err, code = capture_docker_cmd(`docker exec $c_name mkdir -p /opt/ml/model`)
    local_path = create_job_args[:params]["checkpointConfig"]["localPath"]
    proc_out, proc_err, code = capture_docker_cmd(`docker exec $c_name mkdir -p $local_path`)

    @debug "Setting up container: creating environment variables"
    env_vars = Dict{String, String}()
    merge!(env_vars, get_env_creds(c.config))
    script_mode = create_job_args[:algo_spec]["scriptModeConfig"]
    merge!(env_vars, get_env_script_mode_config(script_mode))
    merge!(env_vars, get_env_defaults(c.config, create_job_args))
    @debug "Setting up container: copying hyperparameters"
    copy_hyperparameters(c, create_job_args) && merge!(env_vars, get_env_hyperparameters())
    @debug "Setting up container: copying input data list"
    copy_input_data_list(c, create_job_args) && merge!(env_vars, get_env_input_data())
    c.env = env_vars
    return c
end

function run_local_job!(c::LocalJobContainer)
    code_path = c.container_code_path
    c_name    = c.container_name
    @debug "Running local job: capturing entry point command"
    entry_point_cmd = `docker exec $c_name printenv SAGEMAKER_PROGRAM`
    entry_program, err, code = capture_docker_cmd(entry_point_cmd)
    (isnothing(entry_program) || isempty(entry_program)) && throw(ErrorException("Start program not found. The specified container is not setup to run Braket Jobs. Please see setup instructions for creating your own containers."))
    env_list  = String.(reduce(vcat, ["-e", k*"="*v] for (k,v) in c.env))
    cmd  = Cmd(["docker", "exec", "-w", String(code_path), env_list..., String(c_name), "python", String(entry_program)])
    @debug "Running local job: running full entry point command"
    proc_out, proc_err, code = capture_docker_cmd(cmd)
    if code == 0
        c.run_log *= proc_out 
    else
        err_str = "Run local job process exited with code: $code"
        c.run_log *= proc_out 
        c.run_log *= err_str * proc_err
    end
    return c
end

function login_to_ecr(account_id::String, ecr_uri::String, config::AWSConfig)
    @debug "Attempting to log in to ECR..."
    @debug "Getting authorization token"
    authorization_data_result = EcR.get_authorization_token(Dict("registryIds"=>[account_id]), aws_config=config)
    isnothing(authorization_data_result) && throw(ErrorException("unable to get permissions to access ECR in order to log in to docker. Please pull down the container before proceeding."))
    raw_token = base64decode(authorization_data_result["authorizationData"][1]["authorizationToken"])
    token = String(raw_token)
    token = replace(token, "AWS:"=>"")
    @debug "Performing docker login"
    proc_out, proc_err, code = capture_docker_cmd(`docker login -u AWS -p $token $ecr_uri`)
    @debug "docker login complete"
    code != 0 && throw(ErrorException("Unable to docker login to ECR with error $proc_err"))
    return
end

function pull_image(image_uri::String, config::AWSConfig)
    m = match(ECR_URI_PATTERN, image_uri)
    isnothing(m) && throw(ErrorException("The URI $image_uri is not available locally and does not seem to be a valid AWS ECR URI. Please pull down the container or specify a valid ECR URI before proceeding."))
    ecr_uri    = String(m[1])
    account_id = String(m[2])
    login_to_ecr(account_id, ecr_uri, config)
    @warn "Pulling docker image $image_uri. This may take a while."
    proc_out, proc_err, code = capture_docker_cmd(`docker pull $image_uri`)
    code != 0 && error(proc_err)
    return
end

function capture_docker_cmd(cmd::Cmd)
    out = Pipe()
    err = Pipe()
    proc = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
    close(out.in)
    close(err.in)
    proc_out = String(read(out))
    proc_err = String(read(err))
    return chomp(proc_out), chomp(proc_err), proc.exitcode
end

function start_container!(c::LocalJobContainer, force_update::Bool)
    image_uri = c.image_uri
    get_image_name(image_uri) = capture_docker_cmd(`docker images -q $image_uri`)[1]
    @debug "Acquiring docker image for container start"
    image_name = get_image_name(image_uri)
    if isempty(image_name) || isnothing(image_name)
        try
            pull_image(image_uri, c.config)
            image_name = get_image_name(image_uri)
            (isempty(image_name) || isnothing(image_name)) && throw(ErrorException("The URI $(c.image_uri) is not available locally and cannot be pulled from Amazon ECR. Please pull down the container before proceeding."))
        catch ex
            throw(ErrorException("The URI $(c.image_uri) is not available locally and cannot be pulled from Amazon ECR due to $ex. Please pull down the container before proceeding."))
        end
    elseif force_update
        try
            pull_image(image_uri, c.config)
            image_name = get_image_name(image_uri)
        catch e
            @warn "Unable to update $(c.image_uri) with error $e"
        end
    end
    @debug "Launching container with docker run"
    container_name, err, code = capture_docker_cmd(`docker run -d --rm $image_name tail -f /dev/null`)
    code == 0 || throw(ErrorException(err))
    c.container_name = container_name
    return c 
end

function stop_container!(c::LocalJobContainer)
    # check that the container is still running
    cmd = `docker container ls -q`
    c_list, c_err, code = capture_docker_cmd(cmd)
    if code == 0 && occursin(first(c.container_name, 10), c_list)
        stop_out, stop_err, stop_code = capture_docker_cmd(Cmd(["docker", "stop", c.container_name]))
        if stop_code != 0
            error("unable to stop docker container $(c.contianer_name)! Error: $stop_err")
        end
    else
        error("unable to read docker container list! Error: $c_err")
    end
    return
end

function copy_from_container!(c::LocalJobContainer, src::String, dst::String)
    c_name = c.container_name
    cmd = `docker cp $c_name:$src $dst`
    proc_out, proc_err, code = capture_docker_cmd(cmd)
    if code == 0
        c.run_log *= proc_out
    else
        c.run_log *= proc_err
        throw(ErrorException(proc_err))
    end
    return c
end

function copy_to_container!(c::LocalJobContainer, src::String, dst::String)
    c_name = c.container_name
    dir_name = dirname(dst)
    cmd = `docker exec $c_name mkdir -p $dir_name`
    proc_out, proc_err, code = capture_docker_cmd(cmd) 
    if code == 0
        c.run_log *= proc_out 
    else
        c.run_log *= proc_err
        throw(ErrorException(proc_err))
    end
    cmd = `docker cp $src $c_name:$dst`
    proc_out, proc_err, code = capture_docker_cmd(cmd) 
    if code == 0
        c.run_log *= proc_out 
    else
        c.run_log *= proc_err
        throw(ErrorException(proc_err))
    end
    return c
end

"""
    LocalQuantumJob <: Job

Struct representing a Local Job.
"""
mutable struct LocalQuantumJob <: Job
    arn::String
    name::String
    run_log::String
    function LocalQuantumJob(arn::String; run_log::String="")
        !startswith(arn, "local:job/") && throw(ArgumentError("arn $arn is not a valid local job arn."))
        name = String(split(arn, "job/")[end])
        isempty(run_log) && !ispath(name) && throw(ErrorException("unable to find local job results for $name."))
        new(arn, name, run_log)
    end
end

function LocalQuantumJob(
    device::String,
    source_module::String,
    j_opts::JobsOptions;
    force_update::Bool=false,
    config::AWSConfig=global_aws_config()
    )
    image_uri = isempty(j_opts.image_uri) ? retrieve_image(BASE, config) : j_opts.image_uri
    args      = prepare_quantum_job(device, source_module, j_opts)
    algo_spec = args[:algo_spec]
    job_name  = args[:job_name]
    ispath(job_name) && throw(ErrorException("a local directory called $job_name already exists. Please use a different job name."))
    image_uri = haskey(algo_spec, "containerImage") ? algo_spec["containerImage"]["uri"] : retrieve_image(BASE, config)

    run_log = ""
    let local_job_container=LocalJobContainer(image_uri, args, force_update=force_update)
        local_job_container = run_local_job!(local_job_container)
        # copy results out
        copy_from_container!(local_job_container, "/opt/ml/model", job_name)
        !ispath(job_name) && mkdir(job_name)
        write(joinpath(job_name, "log.txt"), local_job_container.run_log)
        if haskey(args, :params) && haskey(args[:params], "checkpointConfig") && haskey(args[:params]["checkpointConfig"], "localPath")
            checkpoint_path = args[:params]["checkpointConfig"]["localPath"]
            copy_from_container!(local_job_container, checkpoint_path, joinpath(job_name, "checkpoints"))
        end
        run_log = local_job_container.run_log
        stop_container!(local_job_container)
    end
    return LocalQuantumJob("local:job/$job_name", run_log=run_log)
end

"""
    LocalQuantumJob(device::Union{String, BraketDevice}, source_module::String; kwargs...)

Create and launch a `LocalQuantumJob` which will use device `device` (a managed simulator, a QPU, or an [embedded simulator](https://docs.aws.amazon.com/braket/latest/developerguide/pennylane-embedded-simulators.html))
and will run the code (either a single file, or a Julia package, or a Python module) located at `source_module`. `device` can be either the device's ARN as a `String`, or a [`BraketDevice`](@ref). 
A *local* job
runs *locally* on your computational resource by launching the Job container locally using `docker`. The job will block
until it completes, replicating the `wait_until_complete` behavior of [`AwsQuantumJob`](@ref).

The keyword arguments `kwargs` control the launch configuration of the job.

# Keyword Arguments
  - `entry_point::String` - the function to run in `source_module` if `source_module` is a Python module/Julia package. Defaults to an empty string, in which case
    the behavior depends on the code language. In Python, the job will attempt to find a function called `main` in `source_module` and run it. In Julia,
    `source_module` will be loaded and run with Julia's [`include`](https://docs.julialang.org/en/v1/base/base/#Base.include).
  - `image_uri::String` - the URI of the Docker image in ECR to run the Job on. Defaults to an empty string, in which case the [base container](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-script-environment.html)
    is used.
  - `job_name::String` - the name for the job, which will be displayed in the [jobs console](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-first.html).
    The default is a combination of the container image name and the current time.
  - `code_location::String` - the S3 prefix URI to which code will be uploaded. The default is `default_bucket()/jobs/<job_name>/script`
  - `role_arn::String` - not used for `LocalQuantumJob`s.
  - `hyperparameters::Dict{String, Any}` - hyperparameters to provide to the job which will be available from an environment variable when the job is run.
    See the [Amazon Braket documentation](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-hyperparameters.html) for more.
  - `input_data::Union{String, Dict}` - information about the training/input data to provide to the job.
    A `Dict` should map channel names to local paths or S3 URIs. Contents found at any local paths encoded as `String`s will be uploaded to S3 at
    `s3://{default_bucket_name}/jobs/{job_name}/data/{channel_name}`. If a local path or S3 URI is provided, it will be given a default
    channel name `"input"`. The default is `Dict()`.
  - `instance_config::InstanceConfig` - not used for `LocalQuantumJob`s.
  - `distribution::String` - not used for `LocalQuantumJob`s.
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
LocalQuantumJob(device::String, source_module::String; force_update::Bool=false, config::AWSConfig=global_aws_config(), kwargs...) = LocalQuantumJob(device, source_module, JobsOptions(; kwargs...); force_update=force_update, config=config)
LocalQuantumJob(device::BraketDevice, source_module::String; kwargs...) = LocalQuantumJob(convert(String, device), source_module; kwargs...)

"""
    arn(j::LocalQuantumJob)

Returns the ARN identifying the job `j`. This ARN can be used to
reconstruct the job after the session that launched it has exited.
"""
arn(j::LocalQuantumJob)      = j.arn
"""
    name(j::LocalQuantumJob)

Returns the name of the job `j`.
"""
name(j::LocalQuantumJob)     = j.name
run_log(j::LocalQuantumJob)  = j.run_log
"""
    state(j::LocalQuantumJob, ::Val{true})
    state(j::LocalQuantumJob, ::Val{false})
    state(j::LocalQuantumJob)

Fetch the state for job `j`. Local jobs block until they
complete, the `state` is always `"COMPLETED"`.
"""
state(j::LocalQuantumJob, v) = "COMPLETED"
state(j::LocalQuantumJob)    = "COMPLETED"
cancel(j::LocalQuantumJob)   = nothing
metadata(j::LocalQuantumJob, v) = nothing
metadata(j::LocalQuantumJob)    = nothing
download_result(j::LocalQuantumJob)    = nothing
"""
    logs(j::LocalQuantumJob; kwargs...)

Fetches the logs of job `j`.
"""
logs(j::LocalQuantumJob; kwargs...) = println(j.run_log)

"""
    metrics(j::LocalQuantumJob, metric_type=TIMESTAMP, statistic="MAX") 

Fetches the metrics for job `j`. Metrics are generated by [`log_metric`](@ref)
within the job script.
"""
function metrics(j::LocalQuantumJob; metric_type=TIMESTAMP, statistic="MAX")
    results = String.(filter(line -> startswith(line, "Metrics - "), split(j.run_log, "\n")))
    parsed_results = map(results) do r
        [Dict("field"=>"@timestamp", "value"=>time()),
         Dict("field"=>"@message", "value"=>String(r))]
    end
    return _parse_query_results(parsed_results, metric_type, statistic)
end

"""
    result(j::LocalQuantumJob; kwargs...)

Copy, extract, and deserialize the results of local job `j`.
"""
function result(j::LocalQuantumJob; kwargs...)
    try
        raw = read(joinpath(name(j), "results.json"), String)
        persisted_data    = parse_raw_schema(raw)
        @debug "Persisted data format: $(persisted_data.dataFormat)"
        deserialized_data = deserialize_values(persisted_data.dataDictionary, persisted_data.dataFormat)
        return deserialized_data
    catch
        throw(ErrorException("unable to find results in the local job directory $(name(j))."))
    end
end
