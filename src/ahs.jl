import StructTypes

export AtomArrangementItem, AtomArrangement, TimeSeriesItem, TimeSeries, Field, DrivingField
export ShiftingField, Hamiltonian, AnalogHamiltonianSimulation, Pattern, vacant, filled, SiteType, discretize
export LocalDetuning, stitch

"""
    Hamiltonian

Abstract type representing a term in the Hamiltonian to simulate.
"""
abstract type Hamiltonian end

@enum SiteType vacant filled
SiteTypeDict = Dict(string(inst)=>inst for inst in instances(SiteType))
Base.:(==)(x::SiteType, y::String) = string(x) == y
Base.:(==)(x::String, y::SiteType) = string(y) == x

"""
    AtomArrangementItem

Represents a coordinate and filling in a setup for neutral atom simulation.
"""
struct AtomArrangementItem
    coordinate::Tuple{Number, Number}
    site_type::SiteType
end

"""
    AtomArrangementItem(coord::Tuple{Number, Number}, site_type::SiteType=filled)

Create a coordinate with filling `site_type` (either `vacant` or `filled`). Default filling is `filled`.
"""
AtomArrangementItem(coord::Tuple{Number, Number}) = AtomArrangementItem(coord, filled)

"""
    TimeSeriesItem
    TimeSeriesItem(time::Number, value::Number)

Struct representing a `value` in a [`TimeSeries`](@ref) which occurs at `time`.
"""
struct TimeSeriesItem
    time::Number
    value::Number
end
Base.isless(ts1::TimeSeriesItem, ts2::TimeSeriesItem) = ts1.time < ts2.time

"""
    TimeSeries
    TimeSeries()

Struct representing a series of values in a neutral atom simulation.
"""
mutable struct TimeSeries
    series::OrderedDict{Number, TimeSeriesItem}
    sorted::Bool
    largest_time::Int
end
TimeSeries() = TimeSeries(OrderedDict{Number, TimeSeriesItem}(), true, -1)

StructTypes.defaults(::Type{TimeSeries}) = Dict{Symbol, Any}(:sorted => true, :series => OrderedDict{Number, TimeSeriesItem}(), :largest_time => -1)
struct Pattern
    series::Vector{Number}
end
"""
    Field
    Field(time_series::TimeSeries, [pattern::Pattern]) -> Field

Representation of a generic field in a [`Hamiltonian`](@ref).
"""
struct Field
    time_series::TimeSeries
    pattern::Union{Nothing, Pattern}
end
Field(ts::TimeSeries) = Field(ts, nothing) 

StructTypes.defaults(::Type{Field}) = Dict{Symbol, Any}(:pattern => nothing)
const AtomArrangement = Vector{AtomArrangementItem}

"""
    AnalogHamiltonianSimulation

Struct representing instructions for an analog Hamiltonian simulation on a neutral atom device.
"""
struct AnalogHamiltonianSimulation
    register::AtomArrangement
    hamiltonian::Vector{<:Hamiltonian}
end
"""
    AnalogHamiltonianSimulation(register::AtomArrangement, hamiltonian) -> AnalogHamiltonianSimulation

Constructs an `AnalogHamiltonianSimulation` on a specific atom
arrangement `register` and with [`Hamiltonian`](@ref) terms `hamiltonian`.
"""
AnalogHamiltonianSimulation(register::AtomArrangement, hamiltonian::Hamiltonian) = AnalogHamiltonianSimulation(register, [hamiltonian])

# 
"""
    DrivingField <: Hamiltonian
    DrivingField(amplitude::Union{Field, TimeSeries}, phase::Union{Field, TimeSeries}, detuning::Union{Field, TimeSeries}) -> DrivingField

Represents a driving field in a [`Hamiltonian`](@ref) which coherently transfers atoms
from the ground state to the Rydberg state in an [`AnalogHamiltonianSimulation`](@ref).


```math
H_{df}(t) = \\frac{1}{2} \\Omega(t)\\exp(i \\phi(t)) \\sum_k \\left( | g_k \\rangle\\langle r_k | + h.c.\\right) - \\Delta(t) \\sum_k| r_k \\rangle\\langle r_k |
```

Where ``\\left| g_k \\right\\rangle`` is the ground state of atom ``k`` and ``\\left| r_k \\right\\rangle`` is the Rydberg state of atom ``k``.

# Arguments
  - `amplitude` represents the global amplitude ``\\Omega(t)``. The time is in units of seconds, and the value is in radians/second.
  - `phase` represents the global phase ``\\phi(t)``. The time is in units of seconds, and the value is in radians/second.
  - `detuning` represents the global detuning ``\\Delta(t)``. The time is in units of seconds, and the value is in radians/second.
"""
struct DrivingField <: Hamiltonian
    amplitude::Field
    phase::Field
    detuning::Field
end
DrivingField(t1::TimeSeries, t2::TimeSeries, t3::TimeSeries) = DrivingField(Field(t1), Field(t2), Field(t3))

"""
    ShiftingField <: Hamiltonian
    ShiftingField(magnitude::Union{Field, TimeSeries}) -> ShiftingField

Represents a shifting field in a [`Hamiltonian`](@ref) which changes the energy of the Rydberg level in 
an [`AnalogHamiltonianSimulation`](@ref).

```math
H_{sf}(t) = - \\Delta(t) \\sum_k h_k \\left| r_k \\right\\rangle\\left\\langle r_k \\right|
```

Where ``\\left| r_k \\right\\rangle`` is the Rydberg state of atom ``k``, and ``h_k`` is the local pattern of
unitless real numbers between 0 and 1.

The argument `magnitude` represents the global magnitude time series ``\\Delta(t)``, where time is in units of seconds
and values are in units of radians / second.
"""
struct ShiftingField <: Hamiltonian
    magnitude::Field
end

Base.push!(aa::AtomArrangement, coord::Tuple{Number, Number}, site_type::SiteType=filled) = push!(aa, AtomArrangementItem(coord, site_type))

Base.issorted(ts::TimeSeries) = ts.sorted
function times(ts::TimeSeries)
    sort!(ts)
    return [t.time for t in values(ts.series)]
end

function Base.values(ts::TimeSeries)
    sort!(ts)
    return [t.value for t in values(ts.series)]
end

function Base.sort!(ts::TimeSeries)
    if !ts.sorted
        ts.series = OrderedDict(sort!(collect(ts.series)))
        ts.sorted = true
    end
    return ts
end

function Base.setindex!(ts::TimeSeries, value::Number, time::Number)
    if !haskey(ts.series, time) && time <= maximum(keys(ts.series), init=-1e7)
        ts.sorted = false
    end
    ts.series[time] = TimeSeriesItem(time, value)
    return ts    
end

StructTypes.StructType(::Type{TimeSeries}) = StructTypes.UnorderedStruct()
StructTypes.StructType(::Type{Field}) = StructTypes.UnorderedStruct()
StructTypes.StructType(::Type{H}) where {H<:Hamiltonian} = StructTypes.UnorderedStruct()
"""
    ir(ahs::AnalogHamiltonianSimulation)

Generate IR from an [`AnalogHamiltonianSimulation`](@ref) which can be run on
a neutral atom simulator or quantum device.
"""
ir(ahs::AnalogHamiltonianSimulation; kwargs...) = AHSProgram(header_dict[AHSProgram], IR.Setup(ir(ahs.register)), ir(ahs.hamiltonian))
ir(aa::AtomArrangement) = IR.AtomArrangement([collect(site.coordinate) for site in aa], [site.site_type == filled ? 1 : 0 for site in aa])
function ir(h::Vector{<:Hamiltonian})
    h_dict = Dict("drivingFields"=>[], "shiftingFields"=>[])
    for f in h
        f isa DrivingField  && push!(h_dict["drivingFields"],  ir(f))
        f isa ShiftingField && push!(h_dict["shiftingFields"], ir(f))
    end
    return IR.Hamiltonian(h_dict["drivingFields"], h_dict["shiftingFields"])
end

function ir(df::DrivingField)
    return IR.DrivingField(ir(df.amplitude), ir(df.phase), ir(df.detuning))
end

function ir(sf::ShiftingField)
    return IR.ShiftingField(ir(sf.magnitude))
end

function ir(f::Field)
    pat = isnothing(f.pattern) ? "uniform" : convert(Vector{Dec128}, f.pattern.series)
    return IR.PhysicalField(IR.TimeSeries(values(f.time_series), times(f.time_series)), pat)
end

struct DiscretizationProperties
    lattice
    rydberg
end

function discretize(aa::AtomArrangement, properties::DiscretizationProperties)
    position_res = properties.lattice.geometry.positionResolution
    discretized_arrangement = map(aa) do site
        new_coordinates = map(c->(round(Dec128(c) / position_res) * position_res), site.coordinate)
        return AtomArrangementItem(new_coordinates, site.site_type)
    end
    return discretized_arrangement
end

discretize(p::Pattern, resolution::Dec128) = Pattern(map(x->round(Dec128(x) / resolution) * resolution, p.series))

function discretize(ts::TimeSeries, time_resolution::Dec128, value_resolution::Dec128)
    discretized_ts = TimeSeries()
    for val in values(ts.series)
        d_tsi = round(Dec128(val.time) / time_resolution) * time_resolution
        d_val = round(Dec128(val.value) / value_resolution) * value_resolution
        discretized_ts[d_tsi] = d_val
    end
    return discretized_ts
end

function discretize(f::Field, time_resolution::Dec128, value_resolution::Dec128, pattern_resolution::Union{Nothing, Dec128}=nothing)
    discretized_time_series = discretize(f.time_series, time_resolution, value_resolution)
    !isnothing(f.pattern) && isnothing(pattern_resolution) && throw(ErrorException("$(f.pattern) is defined but has no pattern_resolution defined."))
    discretized_pattern = isnothing(f.pattern) ? nothing : discretize(f.pattern, pattern_resolution)
    return Field(discretized_time_series, discretized_pattern)
end

function discretize(sf::ShiftingField, properties::DiscretizationProperties)
    shifting_parameters = properties.rydberg.rydbergLocal
    discretized_magnitude = discretize(sf.magnitude,
        Dec128(shifting_parameters.timeResolution),
        Dec128(shifting_parameters.commonDetuningResolution),
        Dec128(shifting_parameters.localDetuningResolution),
    )
    return ShiftingField(discretized_magnitude)
end

function discretize(df::DrivingField, properties::DiscretizationProperties)
    driving_parameters    = properties.rydberg.rydbergGlobal
    time_resolution       = Dec128(driving_parameters.timeResolution)
    discretized_amplitude = discretize(df.amplitude, time_resolution, Dec128(driving_parameters.rabiFrequencyResolution))
    discretized_phase     = discretize(df.phase, time_resolution, Dec128(driving_parameters.phaseResolution))
    discretized_detuning  = discretize(df.detuning, time_resolution, Dec128(driving_parameters.detuningResolution))
    return DrivingField(discretized_amplitude, discretized_phase, discretized_detuning)
end

"""
    discretize(ahs::AnalogHamiltonianSimulation, device::Device)

Creates a new [`AnalogHamiltonianSimulation`](@ref) with all numerical values represented
as `Dec128` objects with fixed precision based on the capabilities of the `device`.
"""
function discretize(ahs::AnalogHamiltonianSimulation, device::Device)
    required_action_schema = "braket.ir.ahs.program"
    if !haskey(device._properties.action, required_action_schema) || device._properties.action[required_action_schema].actionType != required_action_schema
        throw(ErrorException("AwsDevice $device does not accept $required_action_schema action schema."))
    end
    properties = DiscretizationProperties(device._properties.paradigm.lattice, device._properties.paradigm.rydberg)
    return AnalogHamiltonianSimulation(
        discretize(ahs.register, properties), map(h->discretize(h, properties), ahs.hamiltonian)
    )
end

""" 
	LocalDetuning <: Hamiltonian 

Struct representing a Hamiltonian term `H_{shift}` representing the [local detuning](https://aws.amazon.com/blogs/quantum-computing/local-detuning-now-available-on-queras-aquila-device-with-braket-direct/) that changes the energy of the Rydberg level in an AnalogHamiltonianSimulation.


```math
H_{shift} (t) := -\\Delta(t) \\sum_k h_k | r_k \\rangle \\langle r_k |
```

where:

- ``\\Delta(t)`` is the magnitude of the frequency shift in rad/s,
- ``h_k`` is the site coefficient of atom ``k``, a dimensionless real number between 0 and 1,
- ``|r_k \\rangle`` is the Rydberg state of atom ``k``.

The sum ``\\sum_k`` is taken over all target atoms.

Fields:
- `magnitude::Field`: Field containing the global magnitude time series Delta(t),
  where time is measured in seconds (s) and values are measured in rad/s, and the
  local pattern h_k of dimensionless real numbers between 0 and 1.

```julia
julia> magnitude = Field(TimeSeries(OrderedDict([0 => TimeSeriesItem(0, 1), 1 => TimeSeriesItem(1, 2)]), true, -1))
julia> local_detuning = LocalDetuning(magnitude)
```
"""
struct LocalDetuning <: Hamiltonian
    magnitude::Field
end

"""
	LocalDetuning(times::Vector{<:Number}, values::Vector{<:Number}, pattern::Vector{<:Number})

```julia 
julia> times₁ = [0, 0.1, 0.2, 0.3];
julia> glob_amplitude₁ = [0.5, 0.8, 0.9, 1.0];
julia> pattern₁ = [0.3, 0.7, 0.6, -0.5, 0, 1.6];
julia> s₁ = LocalDetuning(times₁, glob_amplitude₁, pattern₁)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.0, 0.5), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, -1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))
```
"""
function LocalDetuning(times::Vector{<:Number}, values::Vector{<:Number}, pattern::Vector{<:Number})
    if length(times) != length(values)
        throw(ArgumentError("The length of the times and values lists must be equal."))
    end

    time_series = TimeSeries()
    for (t, v) in zip(times, values)
        time_series[t] = v
    end

    field = Field(time_series, Pattern(pattern))
    LocalDetuning(field)
end


ir(ld::LocalDetuning) = IR.LocalDetuning(ir(ld.magnitude))
"""
	stitch(ld1::LocalDetuning, ld2::LocalDetuning; boundary::Symbol="mean") -> LocalDetuning

Stitches two LocalDetuning terms based on the TimeSeries.stitch method.
The time points of the second LocalDetuning are shifted such that the first time point of
the second LocalDetuning coincides with the last time point of the first LocalDetuning.
The boundary point value is handled according to the boundary argument value.

# Arguments:
    ld1::LocalDetuning: The first LocalDetuning to be stitched.
    ld2::LocalDetuning: The second LocalDetuning to be stitched.
    boundary::Symbol="mean": The boundary point handler. Possible options are "mean", "left", "right".
"""
function stitch(ld1::LocalDetuning, ld2::LocalDetuning, boundary::Symbol=:mean)
    if ld1.magnitude.pattern.series != ld2.magnitude.pattern.series
        throw(ArgumentError("The LocalDetuning pattern for both fields must be equal."))
    end

    new_ts = stitch(ld1.magnitude.time_series, ld2.magnitude.time_series, boundary)
    LocalDetuning(Field(new_ts, ld1.magnitude.pattern))
end

"""
    stitch(ts1::TimeSeries, ts2::TimeSeries; boundary::Symbol="mean")

[`stitch`](@ref) two shifting fields based on the `TimeSeries.stitch` method.
The time points of the second `TimeSeries` are shifted such that the first time point of
the second `TimeSeries` coincides with the last time point of the first `TimeSeries`.
The boundary point value is handled according to the `boundary` argument value.

# Arguments:
- `ts1::TimeSeries`: The first `TimeSeries` to be stitched.
- `ts2::TimeSeries`: The second `TimeSeries` to be stitched.
- `boundary::Symbol="mean"`: The boundary point handler. Possible options are "mean", "left", "right".

# Examples:

```julia 
julia> times₁ = [0, 0.1, 0.2, 0.3];
julia> glob_amplitude₁ = [0.5, 0.8, 0.9, 1.0];
julia> pattern₁ = [0.3, 0.7, 0.6, -0.5, 0, 1.6];

julia> times₂ = [0, 0.1, 0.2, 0.3];
julia> glob_amplitude₂ = [0.5, 0.8, 0.9, 1.0];
julia> pattern₂ = pattern₁;

julia> s₂ = LocalDetuning(times₂, glob_amplitude₂, pattern₂)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.0, 0.5), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, -1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))

julia> s₁ = LocalDetuning(times₁, glob_amplitude₁, pattern₁)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.0, 0.5), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, -1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))

julia> stitchedₗ = stitch(s₁, s₂, :mean)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.0, 0.75), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, 1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))

julia> stitchedₗ = stitch(s₁, s₂, :left)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.3, 1.0), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, 1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))

julia> stitchedₗ = stitch(s₁, s₂, :right)
LocalDetuning(Field(TimeSeries(OrderedCollections.OrderedDict{Number, TimeSeriesItem}(0.0 => TimeSeriesItem(0.0, 0.5), 0.1 => TimeSeriesItem(0.1, 0.8), 0.2 => TimeSeriesItem(0.2, 0.9), 0.3 => TimeSeriesItem(0.3, 1.0)), true, 1), Pattern(Number[0.3, 0.7, 0.6, -0.5, 0.0, 1.6])))
```
"""
function stitch(ts1::TimeSeries, ts2::TimeSeries, boundary::Symbol)
    merged_series = deepcopy(ts1.series)
    first_time_ts2 = first(collect(keys(ts2.series)))
    last_time_ts1 = last(collect(keys(ts1.series)))

    if boundary == :mean
        merged_value = (ts1.series[last_time_ts1].value + ts2.series[first_time_ts2].value) / 2
        merged_series[first_time_ts2] = TimeSeriesItem(first_time_ts2, merged_value)
    elseif boundary == :left
        merged_series[first_time_ts2] = ts1.series[last_time_ts1]
    elseif boundary == :right
        merged_series[first_time_ts2] = ts2.series[first_time_ts2]
    else
        throw(ArgumentError("Invalid boundary condition: $boundary"))
    end

    for (t, v) in ts2.series
        if t != first_time_ts2
            merged_series[t] = v
        end
    end

    largest_time = maximum(keys(merged_series))
    if largest_time isa Float64
        largest_time = Int(ceil(largest_time))
    end

    TimeSeries(merged_series, true, largest_time)
end
"""
    discretize(ld::LocalDetuning, properties::DiscretizationProperties) -> LocalDetuning

Creates a discretized version of the `LocalDetuning`.

# Arguments:
- `ld::LocalDetuning`: The `LocalDetuning` to discretize.
- `properties::DiscretizationProperties`: Capabilities of a device that represent the
  resolution with which the device can implement the parameters.
"""
function discretize(ld::LocalDetuning, properties::DiscretizationProperties)
    local_detuning_parameters = properties.rydberg.rydbergLocal
    time_resolution = local_detuning_parameters.timeResolution
    value_resolution = local_detuning_parameters.commonDetuningResolution
    pattern_resolution = local_detuning_parameters.localDetuningResolution

    discretized_magnitude = discretize(ld.magnitude, time_resolution, value_resolution, pattern_resolution)
    LocalDetuning(discretized_magnitude)
end

function discretize(ld::LocalDetuning, properties::DiscretizationProperties)
	local_detuning_parameters = properties.rydberg.rydbergLocal
	time_resolution = Dec128(local_detuning_parameters.timeResolution)
	value_resolution = Dec128(local_detuning_parameters.commonDetuningResolution)
	pattern_resolution = Dec128(local_detuning_parameters.localDetuningResolution)
	discretized_magnitude = discretize(ld.magnitude, time_resolution, value_resolution, pattern_resolution)
	LocalDetuning(discretized_magnitude)
end
