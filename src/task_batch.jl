const MAX_RETRIES = 3
const CONCURRENT_TASK_LIMIT = 100

"""
    AwsQuantumTaskBatch

Struct representing a batch of tasks run concurrently on an Amazon-managed device.
"""
mutable struct AwsQuantumTaskBatch
    _tasks::Vector{AwsQuantumTask}
    _results::Union{Nothing, Vector}
    _unsuccessful::Set{String}
    _device_arn::String
    _task_specifications::Vector{<:Union{Circuit, Program, OpenQasmProgram}}
    _s3_destination_folder::Tuple{String, String}
    _shots::Int
    _poll_timeout_seconds::Int
    _poll_interval_seconds::Int
    function AwsQuantumTaskBatch(tasks, results, unsuccessful, device_arn, task_specs, s3_dest, shots, timeout, interval)
        length(tasks) != length(task_specs) && throw(ArgumentError("number of quantum tasks ($(length(tasks))) and task specifications ($(length(task_specs))) must be equal!"))
        new(tasks, results, unsuccessful, device_arn, task_specs, s3_dest, shots, timeout, interval)
    end
    @doc """
        AwsQuantumTaskBatch(device_arn::String, task_specs::Vector{<:Union{AbstractProgram, Circuit}}; kwargs...) -> AwsQuantumTaskBatch
    
    Launches a batch of concurrent tasks specified by `task_specs` on `device_arn`.

    Valid `kwargs` are:
      - `s3_destination_folder::Tuple{String, String}` - s3 bucket and prefix in which to store results. Default: `default_task_bucket()`
      - `shots::Int` - the number of shots to run each task with. Default: $DEFAULT_SHOTS
      - `poll_timeout_seconds::Int` - maximum number of seconds to wait while polling for results. Default: $DEFAULT_RESULTS_POLL_TIMEOUT
      - `poll_interval_seconds::Int` - default number of seconds to wait between attempts while polling for results. Default: $DEFAULT_RESULTS_POLL_INTERVAL
    """
    function AwsQuantumTaskBatch(device_arn::String, task_specs::Vector{<:Union{AbstractProgram, Circuit}}; s3_destination_folder::Tuple{String, String}=default_task_bucket(), shots::Int=DEFAULT_SHOTS, poll_timeout_seconds::Int=DEFAULT_RESULTS_POLL_TIMEOUT, poll_interval_seconds=DEFAULT_RESULTS_POLL_INTERVAL)
        tasks = launch_batch(device_arn, task_specs; s3_destination_folder=s3_destination_folder, shots=shots, poll_interval_seconds=poll_interval_seconds)
        new(tasks, nothing, Set(), device_arn, task_specs, s3_destination_folder, shots, poll_timeout_seconds, poll_interval_seconds) 
    end
end

function launch_batch(device_arn::String, task_specs::Vector{<:Union{AbstractProgram, Circuit}}; disable_qubit_rewiring::Bool=false, kwargs...)
    tasks = Vector{AwsQuantumTask}(undef, length(task_specs))
    s3_folder  = haskey(kwargs, :s3_destination_folder) ? kwargs[:s3_destination_folder] : default_task_bucket()
    shots      = get(kwargs, :shots, DEFAULT_SHOTS)
    device_params = get(kwargs, :device_params, Dict{String, Any}())
    input = [prepare_task_input(ts, device_arn, s3_folder, shots, device_params, disable_qubit_rewiring; kwargs...) for ts in task_specs]
    to_launch = Threads.Atomic{Int}(length(task_specs))
    tasks = Vector{AwsQuantumTask}(undef, length(task_specs))
    Threads.@threads for ii in 1:length(task_specs)
        tasks[ii] = AwsQuantumTask(input[ii])
        Threads.atomic_sub!(to_launch, 1)
        while to_launch[] > 0
            state(tasks[ii]) ∈ ["FAILED", "CANCELLED", "COMPLETED"] && break
            sleep(kwargs[:poll_interval_seconds])
        end
    end
    return tasks
end

function _retrieve_results(tasks::Vector{AwsQuantumTask})
    res_ = Vector{Any}(undef, length(tasks))
    Threads.@threads for ii in 1:length(tasks)
        res_[ii] = result(tasks[ii])
    end
    return res_
end

tasks(b::AwsQuantumTaskBatch) = b._tasks
Base.length(b::AwsQuantumTaskBatch) = length(b._tasks)

"""
    results(b::AwsQuantumTaskBatch; kwargs)

Valid `kwargs` are:
  - `fail_unsuccessful::Bool` - whether to throw an error if any tasks in the batch are unsuccessful after retries. Default: `false`
  - `max_retries::Int` - maximum number of times to retry a failed task. Default: $MAX_RETRIES
  - `use_cached_value::Bool` - whether to reuse previously downloaded results for tasks or download all results fresh. Default: `true`

Blocks and waits while retrieving results for every task in `b`.
"""
function results(b::AwsQuantumTaskBatch; fail_unsuccessful::Bool=false, max_retries::Int=MAX_RETRIES, use_cached_value::Bool=true)
    if isnothing(b._results) || !use_cached_value
        b._results = _retrieve_results(b._tasks)
        b._unsuccessful = Set(id(task) for task in findall(isnothing, Dict(zip(b._tasks, b._results))))
    end

    retries = 0
    while length(b._unsuccessful) > 0 && retries < max_retries
        retry_unsuccessful_tasks(b)
        retries += 1
    end
    fail_unsuccessful && length(b._unsuccessful) > 0 && throw(ErrorException("$(length(b._unsuccessful)) tasks failed to complete after $max_retries retries."))
    return b._results
end

function retry_unsuccessful_tasks(b::AwsQuantumTaskBatch)
    isnothing(b._results) && throw(ErrorException("results() should be called before attempting to retry"))

    unsuccessful_inds = findall(isnothing, b._results)
    isempty(unsuccessful_inds) && return

    retried_tasks = launch_batch(b._device_arn, b._task_specifications[unsuccessful_inds], s3_destination_folder=b._s3_destination_folder, shots=b._shots)
    b._tasks[unsuccessful_inds] = retried_tasks[:]
    retried_results = _retrieve_results(retried_tasks)
    b._results[unsuccessful_inds] = retried_results[:]
    b._unsuccessful = Set(id(task) for task in findall(isnothing, Dict(zip(b._tasks, b._results))))
    return
end

function unfinished(b::AwsQuantumTaskBatch)
    statuses = Vector{String}(undef, length(b))
    Threads.@threads for ii in 1:length(b)
        statuses[ii] = state(b._tasks[ii])
    end
    ts_pairs = Dict(zip(b._tasks, statuses))
    b._unsuccessful = Set(id(task) for task in findall(x->x∈["FAILED", "CANCELLED"], ts_pairs))
    unfinished = Set(id(task) for task in findall(x->x∈["QUEUED", "RUNNING"], ts_pairs))
    return unfinished
end

unsuccessful(b::AwsQuantumTaskBatch) = b._unsuccessful

