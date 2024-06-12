const REGIONS = ("us-east-1", "us-west-1", "us-west-2", "eu-west-2")
const DEFAULT_SHOTS_QPU = 1000
const DEFAULT_SHOTS_SIMULATOR = 0
const DEFAULT_MAX_PARALLEL = 10

const _GET_DEVICES_ORDER_BY_KEYS = Set(("arn", "name", "type", "provider_name", "status"))

@enum AwsDeviceType SIMULATOR QPU
const AwsDeviceTypeDict = Dict("SIMULATOR"=>SIMULATOR, "QPU"=>QPU)

"""
    BraketDevice

An abstract type representing one of the devices available on Amazon Braket, which will automatically
generate its ARN when passed to the appropriate function.

# Examples
```jldoctest
julia> d = Braket.SV1();

julia> arn(d)
"arn:aws:braket:::device/quantum-simulator/amazon/sv1"
```
"""
abstract type BraketDevice end
for provider in (:AmazonDevice, :_XanaduDevice, :_DWaveDevice, :OQCDevice, :QuEraDevice, :IonQDevice, :RigettiDevice)
    @eval begin
        abstract type $provider <: BraketDevice end
    end
end
arn(d::BraketDevice) = convert(String, d)

for (d, d_arn) in zip((:SV1, :DM1, :TN1), ("sv1", "dm1", "tn1"))
    @eval begin
        struct $d <: AmazonDevice end
        Base.convert(::Type{String}, d::$d) = "arn:aws:braket:::device/quantum-simulator/amazon/" * $d_arn
    end
end

for (d, d_arn) in zip((:_Advantage1, :_Advantage3, :_Advantage4, :_Advantage6, :_DW2000Q6),
                    ("arn:aws:braket:::device/qpu/d-wave/Advantage_system1",
                     "arn:aws:braket:::device/qpu/d-wave/Advantage_system2",
                     "arn:aws:braket:::device/qpu/d-wave/Advantage_system3",
                     "arn:aws:braket:us-west-2::device/qpu/d-wave/Advantage_system6",
                     "arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6",
                    ))
    @eval begin
        struct $d <: _DWaveDevice end
        Base.convert(::Type{String}, d::$d) = $d_arn
    end
end

struct _Borealis <: _XanaduDevice end
Base.convert(::String, d::_Borealis) = "arn:aws:braket:us-east-1::device/qpu/xanadu/Borealis"

for (d, d_arn) in zip((:Harmony, :Aria1, :Aria2),
                      ("arn:aws:braket:us-east-1::device/qpu/ionq/Harmony",
                       "arn:aws:braket:us-east-1::device/qpu/ionq/Aria-1",
                       "arn:aws:braket:us-east-1::device/qpu/ionq/Aria-2",
                      ))
    @eval begin
        struct $d <: IonQDevice end
        Base.convert(::Type{String}, d::$d) = $d_arn
    end
end

struct Aquila <: QuEraDevice end
Base.convert(::Type{String}, d::Aquila) = "arn:aws:braket:us-east-1::device/qpu/quera/Aquila"

struct Lucy <: OQCDevice end
Base.convert(::Type{String}, d::Lucy) = "arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy"

for (d, d_arn) in zip((:_Aspen8, :_Aspen9, :_Aspen10, :_Aspen11, :_AspenM1, :_AspenM2, :AspenM3),
                      ("arn:aws:braket:::device/qpu/rigetti/Aspen-8",
                       "arn:aws:braket:::device/qpu/rigetti/Aspen-9",
                       "arn:aws:braket:::device/qpu/rigetti/Aspen-10",
                       "arn:aws:braket:::device/qpu/rigetti/Aspen-11",
                       "arn:aws:braket:us-west-1::device/qpu/rigetti/Aspen-M-1",
                       "arn:aws:braket:us-west-1::device/qpu/rigetti/Aspen-M-2",
                       "arn:aws:braket:us-west-1::device/qpu/rigetti/Aspen-M-3",
                      ))
    @eval begin
        struct $d <: RigettiDevice end
        Base.convert(::Type{String}, d::$d) = $d_arn
    end
end

"""
    AwsDevice <: Device

Struct representing an AWS managed device, either simulator or QPU.
"""
Base.@kwdef mutable struct AwsDevice <: Device
    _name::Union{Nothing, String}=nothing
    _status::Union{Nothing, String}=nothing
    _type::Union{Nothing, String}=nothing
    _provider_name::Union{Nothing, String}=nothing
    _properties::Any=nothing
    _topology_graph::Union{Nothing, DiGraph}=nothing
    _arn::Union{Nothing, String}=nothing
    _default_shots::Union{Nothing, Int}=nothing
    _config::AWSConfig=global_aws_config()
end
arn(d::AwsDevice) = d._arn
name(d::AwsDevice) = d._name
DataStructures.status(d::AwsDevice) = d._status
provider_name(d::AwsDevice) = d._provider_name
type(d::AwsDevice) = d._type
properties(d::AwsDevice) = d._properties

Base.convert(::Type{String}, d::AwsDevice) = d._arn
Base.show(io::IO, d::AwsDevice) = print(io, "AwsDevice(arn="*d._arn*")")
function (d::AwsDevice)(task_spec::Union{Circuit, AnalogHamiltonianSimulation, AbstractProgram}; s3_destination_folder=default_task_bucket(), shots=nothing, poll_timeout_seconds::Int=DEFAULT_RESULTS_POLL_TIMEOUT, poll_interval_seconds::Int=DEFAULT_RESULTS_POLL_INTERVAL, inputs=Dict{String, Float64}(), kwargs...)
    shots_ = isnothing(shots) ? d._default_shots : shots
    return AwsQuantumTask(d._arn, task_spec, s3_destination_folder=s3_destination_folder, shots=shots_, poll_timeout_seconds=poll_timeout_seconds, poll_interval_seconds=poll_interval_seconds, inputs=inputs, config=d._config, kwargs...)
end

# currently no batch support for AHS
function (d::AwsDevice)(task_specs::Vector{<:Union{Circuit, AbstractProgram}}; s3_destination_folder=default_task_bucket(), shots=nothing, max_parallel=nothing, poll_timeout_seconds::Int=DEFAULT_RESULTS_POLL_TIMEOUT, poll_interval_seconds::Int=DEFAULT_RESULTS_POLL_INTERVAL, inputs=Dict{String, Float64}(), config=d._config, kwargs...)
    shots_ = isnothing(shots) ? d._default_shots : shots
    return AwsQuantumTaskBatch(d._arn, task_specs; s3_destination_folder=s3_destination_folder, shots=shots_, poll_timeout_seconds=poll_timeout_seconds, poll_interval_seconds=poll_interval_seconds, inputs=inputs, config=config, kwargs...)
end

function _construct_topology_graph(d::AwsDevice)
    fns = fieldnames(typeof(d._properties))
    :paradigm ∉ fns && :provider ∉ fns && return nothing
    if :paradigm ∈ fns && d._properties.paradigm isa GateModelQpuParadigmProperties
        para = d._properties.paradigm
        para.connectivity.fullyConnected && return complete_digraph(para.qubitCount)
        adjacency_lists = para.connectivity.connectivityGraph
        edges = Edge[]
        for (i, js) in adjacency_lists
            append!(edges, [Edge(tryparse(Int, string(i)), tryparse(Int, j)) for j in js])
        end
        return SimpleDiGraphFromIterator(edges)
    elseif :provider ∈ fns && d._properties.provider isa DwaveProviderProperties
        edges = [Edge(i, j) for (i,j) in d._properties.provider.couplers]
        return SimpleDiGraphFromIterator(edges)
    end
end

"""
    queue_depth(d::AwsDevice)
"""
function queue_depth(d::AwsDevice)
    dev_name  = d._arn
    metadata  = parse(BRAKET.get_device(HTTP.escapeuri(dev_name), aws_config=d._config))
    queue_metadata = get(metadata, "deviceQueueInfo", nothing)
    queue_info = Dict{String, Any}()
    for response in queue_metadata
        queue_name = get(response, "queue", "")
        queue_priority = get(response, "queuePriority", "")
        queue_size = get(response, "queueSize", "")
        if queue_name == "QUANTUM_TASKS_QUEUE"
            priority_enum = QueueType(queue_priority)
            !haskey(queue_info, "quantum_tasks") && (queue_info["quantum_tasks"] = Dict{QueueType, String}())
            queue_info["quantum_tasks"][priority_enum] = queue_size
        else
            queue_info["jobs"] = queue_size
        end
    end
    return QueueDepthInfo(get(queue_info, "quantum_tasks", Dict{QueueType, String}()), get(queue_info, "jobs", ""))
end

"""
    refresh_metadata!(d::AwsDevice)

Refreshes information contained in the [`AwsDevice`](@ref) struct, for example
whether the device is currently online.
"""
function refresh_metadata!(d::AwsDevice)
    dev_name  = d._arn
    metadata  = parse(BRAKET.get_device(HTTP.escapeuri(dev_name), aws_config=d._config))
    d._name   = metadata["deviceName"]
    d._status = metadata["deviceStatus"]
    d._type   = metadata["deviceType"]
    d._provider_name = metadata["providerName"]
    qpu_properties = get(metadata, "deviceCapabilities", nothing)
    readable_qpu_props = qpu_properties isa String ? qpu_properties : JSON3.write(qpu_properties)
    d._properties = !isnothing(qpu_properties) ? parse_raw_schema(readable_qpu_props) : nothing
    d._topology_graph = _construct_topology_graph(d)
end

"""
    AwsDevice(device_arn::String; config::AWSConfig=global_aws_config()) -> AwsDevice

Encapsulates an AWS managed device with arn `device_arn` and
refreshes its metadata (see [`refresh_metadata!](@ref)) right away.
"""
function AwsDevice(device_arn::String; config::AWSConfig=global_aws_config())
    d = AwsDevice(_arn=device_arn)
    dev_region = String(split(device_arn, ":")[4])
    if isempty(dev_region)
        current_region = AWS.region(config)
        try
            refresh_metadata!(d)
            return d
        catch e
            e isa AWS.AWSExceptions.AWSException || e isa Downloads.RequestError || throw(e)
            !occursin("qpu", device_arn) && throw(ErrorException("Simulator $device_arn not found in '$current_region'"))

            for new_region in setdiff(REGIONS, current_region)
                try
                    region_config = AWSConfig(config.credentials, new_region, config.output)
                    d._config = region_config
                    refresh_metadata!(d)
                    return d
                catch e 
                    e isa AWS.AWSExceptions.AWSException || e isa Downloads.RequestError || throw(e)
                end
            end
            throw(ErrorException("QPU $device_arn not found"))
        end
    else
        conf = dev_region == AWS.region(config) ? config : AWSConfig(config.credentials, dev_region, config.output)
        d._config = conf
        refresh_metadata!(d)
        return d
    end
end
AwsDevice(d::BraketDevice; kwargs...) = AwsDevice(convert(String, d); kwargs...)

"""
    isavailable(d::AwsDevice) -> Bool

Is device `d` currently available to run tasks on.
"""
function isavailable(d::AwsDevice)
    d._status != "ONLINE" && return false

    is_available_result = false
    current_datetime = Dates.now(UTC)
    for execution_window in d._properties.service.executionWindows
        weekday = dayofweek(current_datetime)
        current_time_utc = current_datetime
        if hour(current_time_utc) < hour(execution_window.windowEndHour) < hour(execution_window.windowStartHour)
            weekday = mod(weekday - 1, 7)
        end
       
        execution_day = ExecutionDayDict[lowercase(execution_window.executionDay)]
        matched_day = execution_day == everyday
        matched_day = matched_day || (execution_day == weekdays && weekday < 5)
        matched_day = matched_day || (execution_day == weekends && weekday > 4)
        ordered_days = ( 
                monday,
                tuesday,
                wednesday,
                thursday,
                friday,
                saturday,
                sunday,
               )

        matched_day = matched_day || (execution_day in ordered_days && findfirst(execution_day, ordered_days) == weekday)
        matched_time = (
            execution_window.windowStartHour < execution_window.windowEndHour
            && hour(execution_window.windowStartHour) <= hour(current_time_utc) <= hour(execution_window.windowEndHour)
        ) || (
            execution_window.windowEndHour < execution_window.windowStartHour
            && (
                hour(current_time_utc) >= hour(execution_window.windowStartHour)
                || hour(current_time_utc) <= hour(execution_window.windowEndHour)
            )
        )
        is_available_result = is_available_result || (matched_day && matched_time)
    end
    return is_available_result
end

"""
    search_devices(; kwargs...) -> Vector{Dict{String, Any}}

Search all AWS managed devices and filter the results using `kwargs`.

Valid `kwargs` are:
  - `arns::Vector{String}`: ARNs of devices to search for.
  - `names::Vector{String}`: Names of devices to search for.
  - `types::Vector{String}`: Types of devices (e.g. QPU or simulator) to search for.
  - `statuses::Vector{String}`: Statuses of devices (e.g. `"ONLINE"` or `"OFFLINE"`) to search for.
  - `provider_names::Vector{String}`: Providers of devices to search for.
"""
function search_devices(; arns::Vector{String}=String[], names::Vector{String}=String[], types::Vector{String}=String[], statuses::Vector{String}=String[], provider_names::Vector{String}=String[], config::AWSConfig=global_aws_config())
    results  = []
    filters = Dict{String, Any}[]
    !isempty(arns) && push!(filters, Dict("name"=>"deviceArn", "values"=>arns))
    response = BRAKET.search_devices(filters, Dict("maxResponses"=>100), aws_config=config)
    for result in response["devices"]
        !isempty(names) && result["deviceName"] ∉ names && continue
        !isempty(types) && result["deviceType"] ∉ types && continue
        !isempty(statuses) && result["deviceStatus"] ∉ statuses && continue
        !isempty(provider_names) && result["providerName"] ∉ provider_names && continue
        # do some post-processing on result
        if haskey(result, "deviceCapabilities") && !isnothing(result["deviceCapabilities"]) && !isempty(result["deviceCapabilities"])
            result["deviceCapabilities"] = parse_raw_schema(result["deviceCapabilities"])
        end
        push!(results, result)
    end
    return results
end

"""
    get_devices(; kwargs...) -> Vector{AwsDevice}

Return all AWS Devices satisfying the filters in `kwargs`. The devices
have their properties populated and a region-appropriate `AWSConfig` attached.

Valid `kwargs` are:
  - `arns::Vector{String}`: ARNs of devices to search for.
  - `names::Vector{String}`: Names of devices to search for.
  - `types::Vector{String}`: Types of devices (e.g. QPU or simulator) to search for.
  - `statuses::Vector{String}`: Statuses of devices (e.g. `"ONLINE"` or `"OFFLINE"`) to search for.
  - `provider_names::Vector{String}`: Providers of devices to search for.
  - `order_by::String`: property used to sort the devices. Default is `"name"`.
"""
function get_devices(; arns::Vector{String}=String[], names::Vector{String}=String[], types::Vector{String}=collect(keys(AwsDeviceTypeDict)), statuses::Vector{String}=String[], provider_names::Vector{String}=String[], order_by::String="name")
    order_by ∉ _GET_DEVICES_ORDER_BY_KEYS && throw(ArgumentError("order_by $order_by must be in $_GET_DEVICES_ORDER_BY_KEYS"))
    device_map = Dict{String, AwsDevice}()
    global_config = global_aws_config()
    current_region = AWS.region(global_config)
    search_regions = types == ["SIMULATOR"] ? (current_region,) : REGIONS
    
    for region in search_regions
        config_for_region = region == current_region ? global_config : AWSConfig(global_config.credentials, region, global_config.output)
        # Simulators are only instantiated in the same region as the AWS session
        types_for_region = string.(sort(region == current_region ? types : setdiff(types, "SIMULATOR")))
        types_for_region = isnothing(types_for_region) ? Vector[] : types_for_region
        region_devices = search_devices(arns=arns, names=names,
                                        types=types_for_region,
                                        statuses=statuses,
                                        provider_names=provider_names,
                                        config=config_for_region
                                        )
        region_device_arns = [dev["deviceArn"] for dev in region_devices]
        add_arns = filter(arn->!haskey(device_map, arn), region_device_arns)
        merge!(device_map, Dict(arn=>AwsDevice(arn, config=config_for_region) for arn in add_arns))
    end
    return sort(collect(values(device_map)), by=(x->getproperty(x, Symbol("_"*order_by))))
end

"""
    DirectReservation(device::Union{Device, String, Nothing}, reservation_arn::Union{String, Nothing})

A context manager that adjusts AwsQuantumTasks generated within the context to utilize a reservation ARN
for all tasks targeting the designated device. Notably, this manager permits only one reservation
at a time.

[Reservations](https://docs.aws.amazon.com/braket/latest/developerguide/braket-reservations.html)
are specific to AWS accounts and devices. Only the AWS account that initiated the reservation 
can utilize the reservation ARN. Moreover, the reservation ARN is solely valid on the
reserved device within the specified start and end times.

Arguments:
- device (Device | string | Nothing): The Braket device for which you possess a reservation ARN, or
  alternatively, the device ARN.
- reservation_arn (str | Nothing): The Braket Direct reservation ARN to be implemented for all
  quantum tasks executed within the startreservation and stopreservation
"""
mutable struct DirectReservation
    device_arn::String
    reservation_arn::String
    is_active::Bool
end

DirectReservation(device_arn::String, reservation_arn::String) = DirectReservation(device_arn, reservation_arn, false)

# Start reservation function
function start_reservation!(state::DirectReservation)
    if state.is_active
        error("Another reservation is already active.")
    end
    state.is_active = true
    ENV["AMZN_BRAKET_RESERVATION_DEVICE_ARN"] = state.device_arn
    ENV["AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN"] = state.reservation_arn
end

# Stop reservation function
function stop_reservation!(state::DirectReservation)
    if !state.is_active
        @warn "Reservation is not active."
    end
    state.is_active = false
    delete!(ENV, "AMZN_BRAKET_RESERVATION_DEVICE_ARN")
    delete!(ENV, "AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN")
end

function direct_reservation(reservation::DirectReservation, func::Function)
    env_vars = Dict(
        "AMZN_BRAKET_RESERVATION_DEVICE_ARN" => reservation.device_arn,
        "AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN" => reservation.reservation_arn
    )
    withenv(pairs(env_vars)...) do
        start_reservation!(reservation)
        try
            func()
        catch e
            error("Error during reservation with device ARN $(reservation.device_arn): $(e)")
        finally
            stop_reservation!(reservation)
        end
    end
end
