abstract type CriteriaKey end
struct GateCriteriaKey <: CriteriaKey end
struct QubitCriteriaKey <: CriteriaKey end
struct UnitaryGateCriteriaKey <: CriteriaKey end
struct ObservableCriteriaKey <: CriteriaKey end

abstract type CriteriaKeyResult end
struct KeyResultAll <: CriteriaKeyResult end

abstract type Criteria end
abstract type InitializationCriteria <: Criteria end
abstract type ResultTypeCriteria <: Criteria end
abstract type CircuitInstructionCriteria <: Criteria end
StructTypes.subtypes(::Type{Criteria}) = (GateCriteria=GateCriteria, UnitaryGateCriteria=UnitaryGateCriteria, ObservableCriteria=ObservableCriteria, QubitInitializationCriteria=QubitInitializationCriteria)
Base.keys(c::Criteria, ::Type{<:CriteriaKey}) = Set()
function Base.:(==)(c1::C, c2::C) where {C<:Criteria}
    applicable_key_types(c1) != applicable_key_types(c2) && return false
    !all(keys(c1, kt) == keys(c2, kt) for kt in applicable_key_types(c1)) && return false
    return true
end

function Criteria(d::Dict{String})
    crit_t = StructTypes.subtypes(Criteria)[Symbol(d["type"])]
    return crit_t([d[string(fn)] for fn in fieldnames(crit_t)]...)
end

function _check_target_in_qubits(qubits, target)
    (isnothing(qubits) || isempty(qubits)) && return true
    target_ = Int.(target)
    length(target_) == 1 && return first(target_) ∈ qubits
    return target_ ∈ qubits
end

function _parse_operator_input(ops::Vector)
    isempty(ops) && return []
    qcs = unique(map(qubit_count, ops))
    length(qcs) != 1 && throw(ErrorException("all operators in a criteria must operate on the same number of qubits."))
    return collect(unique(ops))
end
_parse_operator_input(G::Type{<:Operator}) = [G]
_parse_operator_input(::Nothing) = []

function _parse_qubit_input(qubits, expected_qubit_count::Int=0)
    isempty(qubits) && return Int[]
    qubit_count = expected_qubit_count > 0 ? expected_qubit_count : 1
    if (first(qubits) isa Vector || first(qubits) isa QubitSet)
        qubit_count = expected_qubit_count > 0 ? expected_qubit_count : length(first(qubits))
        target_set_all_same = all(length(item) == qubit_count for item in qubits)
        !target_set_all_same && throw(ErrorException("Qubits must all target $qubit_count-qubit operations."))
        qubit_count == 1 && return [first(item) for item in qubits]
        return [collect(item) for item in qubits]
    end
    qubit_count > 1 && return [collect(qubits)]
    return collect(unique(qubits))
end
_parse_qubit_input(q::Int, expected_qubit_count::Int=0) = _parse_qubit_input([q], expected_qubit_count)
_parse_qubit_input(::Nothing, expected_qubit_count::Int=0) = Int[]

struct GateCriteria <: CircuitInstructionCriteria
    gates::Vector{Type{<:Gate}}
    qubits::Vector{Union{Int, Vector{Int}}}
    GateCriteria(gates::Vector{Type{<:Gate}}, qubits::Vector{Union{Int, Vector{Int}}}) = new(gates, qubits)
    function GateCriteria(gates, qubits)
        _gates = _parse_operator_input(gates)
        expected_qc = isempty(_gates) ? 0 : qubit_count(first(_gates))
        _qubit = _parse_qubit_input(qubits, expected_qc)
        new(_gates, _qubit)
    end
end
GateCriteria(gates::Union{Type{<:Gate}, Vector{Type{<:Gate}}}) = GateCriteria(gates, Int[])
GateCriteria() = GateCriteria([], [])
Base.Dict(gc::GateCriteria) = Dict("type"=>"GateCriteria", "gates"=>gc.gates, "qubits"=>gc.qubits)
Base.keys(gc::GateCriteria, ::Type{GateCriteriaKey})  = isempty(gc.gates)  ? KeyResultAll() : gc.gates
Base.keys(gc::GateCriteria, ::Type{QubitCriteriaKey}) = isempty(gc.qubits) ? KeyResultAll() : gc.qubits
applicable_key_types(::Type{GateCriteria}) = [QubitCriteriaKey, GateCriteriaKey]
applicable_key_types(gc::GateCriteria)     = applicable_key_types(GateCriteria)

function instruction_matches(gc::GateCriteria, ix::Instruction)
    ix.operator isa Gate || return false
    !isempty(gc.gates) && typeof(ix.operator) ∉ gc.gates && return false
    target_in = _check_target_in_qubits(gc.qubits, ix.target)
    return target_in
end

struct UnitaryGateCriteria <: CircuitInstructionCriteria
    unitary::Unitary
    qubits::Vector
    function UnitaryGateCriteria(unitary::Unitary, qubits)
        _qubit = _parse_qubit_input(qubits, qubit_count(unitary))
        new(unitary, _qubit)
    end
end
Base.Dict(ugc::UnitaryGateCriteria) = Dict("type"=>"UnitaryGateCriteria", "unitary"=>ugc.unitary, "qubits"=>ugc.qubits)
Base.keys(gc::UnitaryGateCriteria, ::Type{UnitaryGateCriteriaKey}) = gc.unitary.matrix
Base.keys(gc::UnitaryGateCriteria, ::Type{QubitCriteriaKey})       = isempty(gc.qubits) ? KeyResultAll() : gc.qubits
applicable_key_types(::Type{UnitaryGateCriteria}) = [QubitCriteriaKey, UnitaryGateCriteriaKey]
applicable_key_types(gc::UnitaryGateCriteria)     = applicable_key_types(UnitaryGateCriteria)

function instruction_matches(ugc::UnitaryGateCriteria, ix::Instruction)
    !(ix.operator isa Unitary) && return false
    ix.operator != ugc.unitary && return false
    return _check_target_in_qubits(ugc.qubits, ix.target) 
end

struct QubitInitializationCriteria <: InitializationCriteria
    qubits::Vector{Int}
    QubitInitializationCriteria(qubits) = new(_parse_qubit_input(qubits))
end
applicable_key_types(::Type{QubitInitializationCriteria}) = [QubitCriteriaKey]
applicable_key_types(qi::QubitInitializationCriteria)     = applicable_key_types(QubitInitializationCriteria)
Base.keys(qi::QubitInitializationCriteria, ::Type{QubitCriteriaKey}) = isempty(qi.qubits) ? KeyResultAll() : collect(unique(qi.qubits))
qubit_intersection(qi::QubitInitializationCriteria, qubits) = isempty(qi.qubits) ? qubits : collect(intersect(qi.qubits, qubits))

struct ObservableCriteria <: ResultTypeCriteria
    observables::Vector
    qubits::Vector
    function ObservableCriteria(observables, qubits)
        _observables = _parse_operator_input(observables)
        _qubit = _parse_qubit_input(qubits, 1)
        new(_observables, _qubit)
    end
end
Base.Dict(oc::ObservableCriteria) = Dict("type"=>"ObservableCriteria", "observables"=>oc.observables, "qubits"=>oc.qubits)
applicable_key_types(::Type{ObservableCriteria}) = [ObservableCriteriaKey, QubitCriteriaKey]
applicable_key_types(qi::ObservableCriteria)     = applicable_key_types(ObservableCriteria)
Base.keys(oc::ObservableCriteria, ::Type{ObservableCriteriaKey}) = isempty(oc.observables) ? KeyResultAll() : oc.observables
Base.keys(oc::ObservableCriteria, ::Type{QubitCriteriaKey}) = isempty(oc.qubits) ? KeyResultAll() : oc.qubits
function result_type_matches(oc::ObservableCriteria, rt::Result)
    rt isa ObservableResult || return false
    !isempty(oc.observables) && typeof(rt.observable) ∉ oc.observables && return false
    isempty(oc.qubits) && return true
    isempty(rt.targets) && return true
    targs = [rt.targets]
    first(targs) ⊆ oc.qubits && return true
end

struct NoiseModelInstruction
    noise::Noise
    criteria::Criteria
end
function NoiseModelInstruction(d::Dict{String})
    n = StructTypes.construct(Noise, d["noise"])
    c = StructTypes.construct(Criteria, d["criteria"])
    return NoiseModelInstruction(n, c)
end

struct NoiseModelInstructions
    initialization_noise::Vector{NoiseModelInstruction}
    gate_noise::Vector{NoiseModelInstruction}
    readout_noise::Vector{NoiseModelInstruction}
end

mutable struct NoiseModel
    instructions::Vector{NoiseModelInstruction}
    NoiseModel(ixs::Vector{NoiseModelInstruction}) = new(ixs)
end
NoiseModel(d::Dict{String}) = NoiseModel([NoiseModelInstruction(ix) for ix in d["instructions"]])
NoiseModel() = NoiseModel(NoiseModelInstruction[])
Base.Dict(nmi::NoiseModelInstruction) = Dict("noise"=>Dict(nmi.noise), "criteria"=>Dict(nmi.criteria))
Base.Dict(nm::NoiseModel) = Dict("instructions"=>Dict.(nm.instructions))

add_noise!(nm::NoiseModel, noise::Noise, criteria::Criteria) = (push!(nm.instructions, NoiseModelInstruction(noise, criteria)); return nm)
insert_noise!(nm::NoiseModel, ix::Int, noise::Noise, criteria::Criteria) = insert!(nm.instructions, ix, NoiseModelInstruction(noise, criteria))
remove_noise!(nm::NoiseModel, ix::Int) = deleteat!(nm.instructions, ix)

function from_filter(noise_model::NoiseModel; qubit=nothing, gate=nothing, noise=nothing)
    new_model = NoiseModel()
    for ix in noise_model.instructions
        !isnothing(noise) && !(ix.noise isa noise) && continue
        if !isnothing(gate)
            gate_keys = keys(ix.criteria, GateCriteriaKey)
            gate_keys != KeyResultAll() && gate ∉ gate_keys && continue
        end
        if !isnothing(qubit)
            qubit_keys = keys(ix.criteria, QubitCriteriaKey)
            qubit_keys != KeyResultAll() && qubit ∉ qubit_keys && continue
        end
        add_noise!(new_model, ix.noise, ix.criteria)
    end
    return new_model
end

function instructions_by_type(nm::NoiseModel)
    init_noise = filter(ix->ix.criteria isa InitializationCriteria, nm.instructions)
    gate_noise = filter(ix->ix.criteria isa CircuitInstructionCriteria, nm.instructions)
    rout_noise = filter(ix->ix.criteria isa ResultTypeCriteria, nm.instructions)
    return NoiseModelInstructions(init_noise, gate_noise, rout_noise)
end

function apply_gate_noise!(c::Circuit, ixs::Vector{NoiseModelInstruction})
    n_c = Circuit()
    for c_ix in c.instructions
        n_c = add_instruction!(n_c, c_ix)
        t_qs = c_ix.target isa Int ? [c_ix.target] : c_ix.target
        for ix in ixs
            if instruction_matches(ix.criteria, c_ix)
                if qubit_count(ix.noise) == length(t_qs)
                    add_instruction!(n_c, Instruction(ix.noise, t_qs))
                else
                    for q in t_qs
                        add_instruction!(n_c, Instruction(ix.noise, q))
                    end
                end
            end
        end
    end
    for rt in c.result_types
        add_result_type!(n_c, rt)
    end
    return n_c
end

function apply_initialization_noise!(c::Circuit, ixs::Vector{NoiseModelInstruction})
    isempty(ixs) && return c
    for ix in ixs
        qubits = qubit_intersection(ix.criteria, 0:qubit_count(c)-1)
        length(qubits) > 0 && apply_initialization_noise!(c, ix.noise, collect(qubits))
    end
    return c
end

function apply_readout_noise!(c::Circuit, ixs::Vector{NoiseModelInstruction})
    isempty(ixs) && return c
    rts = c.result_types
    noise_to_apply = Dict{Int, Vector{Int}}()
    for rt in rts
        if rt isa ObservableResult
            target_qubits = rt.targets isa Int ? [rt.targets] : rt.targets
            for (iix, ix) in enumerate(ixs)
                if result_type_matches(ix.criteria, rt)
                    for target_qubit in target_qubits
                        if haskey(noise_to_apply, target_qubit)
                            push!(noise_to_apply[target_qubit], iix)
                        else
                            noise_to_apply[target_qubit] = [iix]
                        end
                    end
                end
            end
        end
    end
    for (qubit, v) in noise_to_apply
        for noise_iix in unique(v)
            ix = ixs[noise_iix]
            apply_readout_noise!(c, ix.noise, [qubit])
        end
    end
    return c
end

function apply(nm::NoiseModel, c::Circuit)
    ixs = instructions_by_type(nm)
    n_c = apply_gate_noise!(c, ixs.gate_noise)
    n_c = apply_initialization_noise!(n_c, ixs.initialization_noise)
    n_c = apply_readout_noise!(n_c, ixs.readout_noise)
    return n_c
end
(c::Circuit)(nm::NoiseModel) = apply(nm, c)
