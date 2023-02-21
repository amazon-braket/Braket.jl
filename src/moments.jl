
@enum MomentType_enum mtGate mtCompilerDirective mtInitializationNoise mtGateNoise mtNoise mtReadoutNoise
const MomentType_tostr = LittleDict{MomentType_enum, String}(mtCompilerDirective=>"compiler_directive", mtGate=>"gate", mtNoise=>"noise", mtInitializationNoise=>"initialization_noise", mtGateNoise=>"gate_noise", mtReadoutNoise=>"readout_noise")
const MomentType_toenum = LittleDict(zip(values(MomentType_tostr), keys(MomentType_tostr)))

struct MomentKey
    time::Int
    qubits::QubitSet
    moment_type::MomentType_enum
    noise_index::Int
end
Base.:(==)(k1::MomentKey, k2::MomentKey) = (k1.time == k2.time && k1.qubits == k2.qubits && k1.moment_type == k2.moment_type && k1.noise_index == k2.noise_index)

mutable struct Moments <: AbstractDict{MomentKey,Instruction}
    _moments::OrderedDict{MomentKey, Instruction}
    _max_times::Dict{Int, Int}
    _qubits::QubitSet
    _depth::Int
    _time_all_qubits::Int
    Moments() = new(OrderedDict{MomentKey, Instruction}(), Dict{Int, Int}(), QubitSet(), 0, -1)
end
Base.get(m::Moments, mk::MomentKey, default) = get(m._moments, mk, default)

function Moments(ixs::Vector)
    m = Moments()
    foreach(ix->push!(m, ix), ixs)
    return m
end

Base.keys(m::Moments)   = keys(m._moments)
Base.values(m::Moments) = values(m._moments)
Base.length(m::Moments) = m._depth

function Base.show(io::IO, m::Moments)
    println(io, "Circuit moments:")
    println(io, "Max times: ", m._max_times)
end

function Base.push!(m::Moments, ix::Instruction, mt::MomentType_enum=mtGateNoise, noise_index::Int=0)
    op = ix.operator
    if op isa CompilerDirective
        qubits = QubitSet(keys(m._max_times))
        time   = _update_qubit_time!(m, qubits)
        key    = MomentKey(time, QubitSet(), mtCompilerDirective, 0)
        m._moments[key] = ix
        m._depth = max(m._depth, time+1)
        m._time_all_qubits = time
    elseif op isa Noise
        add_noise!(m, ix, "noise", noise_index)
    else # it's a Gate
        qubits = QubitSet(ix.target)
        time   = _update_qubit_time!(m, qubits)
        key    = MomentKey(time, qubits, mtGate, noise_index)
        m._moments[key] = ix
        union!(m._qubits, qubits)
        m._depth = max(m._depth, time+1)
    end
    return m
end
Base.push!(m::Moments, ixs::Vector{Instruction}, mt::MomentType_enum=mtGateNoise, noise_index::Int=0) = (foreach(ix->push!(m, ix, mt, noise_index), ixs); return m)

function add_noise!(m::Moments, ix::Instruction, input_type::String="noise", noise_index::Int=0)
    qubits = QubitSet(ix.target)
    time = max(0, prod(get(m._max_times, q, -1) for q in qubits))
    if MomentType_toenum[input_type] == mtInitializationNoise
        time = 0
    end
    search_key = MomentKey(time, qubits, MomentType_toenum[input_type], noise_index)
    while any(k == search_key for k in keys(m._moments)) # cannot use haskey because of hashing! 
        noise_index += 1
        search_key = MomentKey(time, qubits, MomentType_toenum[input_type], noise_index)
    end
    key = MomentKey(time, qubits, MomentType_toenum[input_type], noise_index)
    m._moments[key] = ix
    union!(m._qubits, qubits)
    return m
end

function _update_qubit_time!(m::Moments, qubits::QubitSet)
    current_max_times = vcat([get!(m._max_times, q, -1) for q in qubits], m._time_all_qubits)
    time = maximum(current_max_times) + 1
    for q in qubits
        m._max_times[q] = time
    end
    return time
end

function sort_moments!(m::Moments)
    moment_copy    = OrderedDict{MomentKey, Instruction}()
    sorted_moments = OrderedDict{MomentKey, Instruction}()
    readout_keys   = MomentKey[]
    init_keys      = MomentKey[]
    # GATE, NOISE, GATE_NOISE
    noise_keys     = MomentKey[]
    for (key, ix) in m._moments
        if key.moment_type == mtInitializationNoise
            push!(init_keys, key)
        elseif key.moment_type == mtReadoutNoise
            push!(readout_keys, key)
        else
            push!(noise_keys, key)
        end
        moment_copy[key] = ix
    end
    for key in init_keys
        sorted_moments[key] = moment_copy[key]
    end
    for key in noise_keys
        sorted_moments[key] = moment_copy[key]
    end
    max_time = max(length(m) - 1, 0)
    for key in readout_keys
        new_key = MomentKey(max_time, key.qubits, mtReadoutNoise, key.noise_index)
        sorted_moments[new_key] = moment_copy[key]
    end
    m._moments = sorted_moments
    return m
end

function time_slices(m::Moments)
    m = sort_moments!(m)
    time_slices = OrderedDict{Int, Vector{Instruction}}()
    for (k, ix) in m._moments
        ixs = get!(time_slices, k.time, [])
        push!(ixs, ix)
        time_slices[k.time] = ixs
    end
    return time_slices
end
