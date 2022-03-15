const MIN_SIMULATOR_DURATION = Millisecond(3000)
const price_url = "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonBraket/current/index.csv"

mutable struct Pricing
    _price_list::Vector
end
Base.summary(io::IO, p::Pricing) = print(io, "Pricing(" * string(length(p._price_list)) * ")")
function Base.show(io::IO, p::Pricing)
    summary(io, p)
    if length(p._price_list) > 0
        println(io)
        println(io, "Keys:")
        show(io, collect(keys(p._price_list[1])))
        println(io)
        foreach(l->println(io, collect(values(l))), p._price_list)
    end
end

function get_prices!(p::Pricing=Prices[])
    http_response = Downloads.download(price_url)
    csv_file = CSV.File(http_response, skipto=6)
    p._price_list = [OrderedDict(zip(csv_file[1], csv_file[ii])) for ii in 2:length(csv_file)]
    return p
end

function price_search(p::Pricing; kwargs...)
    isempty(p._price_list) && get_prices!(p)
    return filter(p._price_list) do entry
        all(haskey(entry, string(k)) && entry[string(k)] == v for (k, v) in kwargs)
    end
end
price_search(; kwargs...) = price_search(Prices[]; kwargs...)

abstract type TrackingEvent end

struct TaskCreationEvent <: TrackingEvent
    arn::String
    shots::Int
    is_job_task::Bool
    device::String
end

struct TaskCompletionEvent <: TrackingEvent
    arn::String
    status::String
    execution_duration::Union{Nothing, Float64}
end

struct TaskStatusEvent <: TrackingEvent
    arn::String
    status::String
end

mutable struct Tracker
    _resources::Dict{String}
    _context
    function Tracker(_resources::Dict{String}, ctx)
        t = new(_resources, ctx)
        push!(ctx, t)
        return t
    end
end

Base.haskey(t::Tracker, k::String) = haskey(t._resources, k)
tracked_resources(t::Tracker) = collect(keys(t._resources))
context(t::Tracker) = t._context

mutable struct TrackerContext
    _trackers::Set{Tracker}
    TrackerContext(s::Set{Tracker}) = new(s)
end
TrackerContext() = TrackerContext(Set{Tracker}())
Tracker(tc::TrackerContext) = Tracker(Dict{String, Any}(), tc)
Tracker() = Tracker(GlobalTrackerContext[])

Base.length(tc::TrackerContext) = length(tc._trackers)
Base.push!(tc::TrackerContext, t::Tracker) = (push!(tc._trackers, t); return tc)
Base.setdiff!(tc::TrackerContext, t::Tracker) = (setdiff!(tc._trackers, t); return tc)
broadcast_event!(tc::TrackerContext, e::TrackingEvent) = (foreach(t->receive!(t, e), tc._trackers); return tc)
broadcast_event!(e::TrackingEvent) = broadcast_event!(GlobalTrackerContext[], e)

active_trackers(tc::TrackerContext) = t._trackers

function qpu_tasks_cost(t::Tracker)
    total_cost = Dec128(0)
    for (task_arn, details) in Iterators.filter(x->occursin("qpu", x[2]["device"]), t._resources)
        total_cost += _get_qpu_task_cost(task_arn, details)
    end
    return total_cost
end

function simulator_tasks_cost(t::Tracker)
    total_cost = Dec128(0)
    for (task_arn, details) in Iterators.filter(x->occursin("simulator", x[2]["device"]), t._resources)
        total_cost += _get_simulator_task_cost(task_arn, details)
    end
    return total_cost
end

function quantum_task_statistics(t::Tracker)
    stats = Dict{String, Any}()
    for details in values(t._resources)
        device_stats = get(stats, details["device"], Dict{String, Any}())
        shots = get(device_stats, "shots", 0) + details["shots"]
        device_stats["shots"] = shots

        task_states = get(device_stats, "tasks", Dict{String, Any}())
        task_states[details["status"]] = get(task_states, details["status"], 0) + 1
        device_stats["tasks"] = task_states
        if haskey(details, "execution_duration")
            duration = get(device_stats, "execution_duration", Microsecond(0)) + details["execution_duration"]
            billed_duration = get(device_stats, "billed_execution_duration", Microsecond(0)) + details["billed_duration"]
            device_stats["execution_duration"] = duration
            device_stats["billed_execution_duration"] = billed_duration
        end
        stats[details["device"]] = device_stats
    end
    return stats
end

function _get_qpu_task_cost(arn::String, details::Dict{String})
    details["status"] ∈ ("FAILED", "CANCELLED") && return Dec128(0)

    task_region = String(split(arn, ':')[4])
    search_dict = Dict(Symbol("Region Code")=>task_region)

    device_name = uppercasefirst(String(split(details["device"], '/')[end]))
    occursin("2000Q", device_name) && (device_name = "2000Q")
    occursin("Advantage_system", device_name) && (device_name = "Advantage_system")
    
    search_dict[Symbol("Device name")] = device_name
    if details["job_task"]
        shot_product_family = "Braket Managed Jobs QPU Task Shot"
        task_product_family = "Braket Managed Jobs QPU Task"
    else
        shot_product_family = "Quantum Task-Shot"
        task_product_family = "Quantum Task"
    end
    search_dict[Symbol("Product Family")] = shot_product_family
    shot_prices = price_search(; namedtuple(search_dict)...)
    search_dict[Symbol("Product Family")] = task_product_family
    task_prices = price_search(; namedtuple(search_dict)...)
    length(shot_prices) != 1 && throw(ErrorException("found $(length(shot_prices)) products matching $search_dict"))
    length(task_prices) != 1 && throw(ErrorException("found $(length(task_prices)) products matching $search_dict"))

    shot_price = first(shot_prices)
    task_price = first(task_prices)
    for price in (shot_price, task_price)
        price["Currency"] != "USD" && throw(ErrorException("expected USD, found currency $(price["Currency"])"))
    end
    shot_cost = Dec128(shot_price["PricePerUnit"]) * details["shots"]
    task_cost = Dec128(task_price["PricePerUnit"]) * 1
    return shot_cost + task_cost
end

const duration_dict = Dict("minutes"=>Minute, "seconds"=>Second, "hours"=>Hour, "milliseconds"=>Millisecond, "microsecond"=>Microsecond)

function _get_simulator_task_cost(arn::String, details::Dict{String})
    (!haskey(details, "billed_duration") || iszero(details["billed_duration"])) && return Dec128(0)

    task_region = String(split(arn, ':')[4])

    device_name = uppercase(String(split(details["device"], '/')[end]))
    
    search_dict= Dict(Symbol("Device name")=>device_name)
    if details["job_task"]
        product_family = "Braket Managed Jobs Simulator Task"
        operation = "Managed-Jobs"
    else
        product_family = "Simulator Task"
        operation = "CompleteTask"
        details["status"] == "FAILED" && device_name == "TN1" && (operation = "FailedTask")
    end
    search_dict = Dict(Symbol("Region Code")=>task_region, :Version=>device_name, Symbol("Product Family")=>product_family, :operation=>operation)
    duration_prices = price_search(; namedtuple(search_dict)...)
    length(duration_prices) != 1 && throw(ErrorException("found $(length(duration_prices)) products matching $search_dict"))
    duration_price = first(duration_prices)
    duration_price["Currency"] != "USD" && throw(ErrorException("expected USD, found currency $(duration_price["Currency"])"))
    ppu                     = Dec128(duration_price["PricePerUnit"])
    duration_in_millis      = Dec128(@compat details["billed_duration"] / Millisecond(1))
    unit_duration_in_millis = Dec128(@compat duration_dict[duration_price["Unit"]](1) / Millisecond(1))
    duration_cost = ppu * (duration_in_millis / unit_duration_in_millis)
    return duration_cost 
end

function receive!(t::Tracker, e::TaskCreationEvent)
    t._resources[e.arn] = Dict("shots"=>e.shots, "device"=>e.device, "status"=>"CREATED", "job_task"=>e.is_job_task)
    return t
end

function receive!(t::Tracker, e::TaskStatusEvent)
    haskey(t._resources, e.arn) && setindex!(t._resources[e.arn], e.status, "status")
    return t
end

function receive!(t::Tracker, e::TaskCompletionEvent)
    if haskey(t._resources, e.arn)
        t._resources[e.arn]["status"] = e.status
        if !isnothing(e.execution_duration)
            duration = Millisecond(e.execution_duration)
            t._resources[e.arn]["execution_duration"] = duration
            t._resources[e.arn]["billed_duration"] = max(duration, MIN_SIMULATOR_DURATION)
        end
    end
    return t
end
