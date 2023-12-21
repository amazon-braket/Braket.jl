module BraketStateVector

using Braket, Braket.Observables, LinearAlgebra, StaticArrays, StatsBase, Combinatorics, UUIDs, JSON3, Random

import Braket: Instruction, X, Y, Z, I, PhaseShift, CNot, CY, CZ, XX, XY, YY, ZZ, CPhaseShift, CCNot, Swap, Rz, Ry, Rx, Ti, T, Vi, V, H, BraketSimulator, Program, OpenQasmProgram

export StateVector, StateVectorSimulator, DensityMatrixSimulator, evolve!, classical_shadow

const StateVector{T}   = Vector{T}
const DensityMatrix{T} = Matrix{T}
const AbstractStateVector{T} = AbstractVector{T}

abstract type AbstractSimulator <: Braket.BraketSimulator end
Braket.name(s::AbstractSimulator) = device_id(s)

include("validation.jl")
    
const OBS_LIST = (Observables.X(), Observables.Y(), Observables.Z())

function parse_program(d::D, program::OpenQasmProgram) where {D<:AbstractSimulator}

end

function _formatted_measurements(d::D) where {D<:AbstractSimulator}
    sim_samples = samples(d)
    formatted   = [reverse(digits(sample, base=2, pad=qubit_count(d))) for sample in sim_samples]
    return formatted
end

_get_measured_qubits(qc::Int) = collect(0:qc-1)
function _bundle_results(results::Vector{Braket.ResultTypeValue}, circuit_ir::Union{Program, OpenQasmProgram}, d::D) where {D<:AbstractSimulator}
    task_mtd = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], string(uuid4()), d.shots, device_id(d), nothing, nothing, nothing, nothing, nothing)
    addl_mtd = Braket.AdditionalMetadata(circuit_ir, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
    formatted_samples = _formatted_measurements(d)
    #measured_qubits   = _get_measured_qubits(qubit_count(circuit_ir))
    measured_qubits   = sort(collect(qubits(circuit_ir)))
    return Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult], formatted_samples, nothing, results, measured_qubits, task_mtd, addl_mtd)
end

function _generate_results(results::Vector{<:Braket.AbstractProgramResult}, result_types::Vector, d::D) where {D<:AbstractSimulator}
    result_values = [calculate(result_type, d) for result_type in result_types]
    result_values = [val isa Matrix ? Braket.complex_matrix_to_ir(val) : val for val in result_values] 
    return [Braket.ResultTypeValue(result, result_value) for (result, result_value) in zip(results, result_values)]
end

function _translate_result_types(results::Vector{Braket.AbstractProgramResult}, qubit_count::Int)
    # results are in IR format
    raw_results = [JSON3.write(r) for r in results]
    # fix missing targets
    for (ri, rr) in enumerate(raw_results)
        if occursin("\"targets\":null", rr)
            raw_results[ri] = replace(rr, "\"targets\":null"=>"\"targets\":$(repr(collect(0:qubit_count-1)))")
        end
    end
    translated_results = [JSON3.read(r, Braket.Result) for r in raw_results]
    return translated_results
end

function classical_shadow(d::LocalSimulator, obs_qubits::Vector{Int}, circuit::Program, shots::Int, seed::Int)
    n_qubits    = length(obs_qubits)
    n_snapshots = shots
    recipes     = rand(Xoshiro(seed), 0:2, (n_snapshots, n_qubits))
    outcomes    = compute_shadows(d._delegate, circuit, recipes, obs_qubits)
    return outcomes, recipes
end
function classical_shadow(d::LocalSimulator, obs_qubits::Vector{Vector{Int}}, circuits::Vector{Program}, shots::Int, seed::Vector{Int})
    all_outcomes = [zeros(Float64, (shots, length(obs_qubits[ix]))) for ix in 1:length(circuits)]
    all_recipes  = [zeros(Int, (shots, length(obs_qubits[ix]))) for ix in 1:length(circuits)]
    Threads.@threads for ix in 1:length(circuits)
        start = time()
        outcomes, recipes = classical_shadow(d, obs_qubits[ix], circuits[ix], shots, seed[ix])
        stop = time()
        @info "(Thread $(Threads.threadid())): Computed classical shadows for circuit $ix/$(length(circuits)) in $(stop-start)."
        @views begin
            all_outcomes[ix] .= outcomes
            all_recipes[ix] .= recipes
        end
        flush(stdout)
    end
    return all_outcomes, all_recipes
end

function (d::AbstractSimulator)(circuit_ir::OpenQasmProgram, args...; shots::Int=0, kwargs...)
    circuit, qubit_count = parse_program(circuit_ir)
    _validate_ir_results_compatibility(d, circuit.results, Val(:OpenQASM))
    _validate_ir_instructions_compatibility(d, circuit, Val(:OpenQASM))
    _validate_input_provided(circuit)
    _validate_shots_and_ir_results(shots, circuit_ir.results, qubit_count)
    operations = circuit.instructions
    _validate_operation_qubits(operations)
    results = circuit.results
    reinit!(d, qubit_count, shots)
    d = evolve!(d, operations)
    if shots == 0
        result_types = _translate_result_types(results, qubit_count)
        _validate_result_types_qubits_exist(result_types, qubit_count)
        results = _generate_results(circuit.results, result_types, d)
    else
        d = evolve!(d, circuit.basis_rotation_instructions)
    end
    return _bundle_results(results, circuit_ir, d)
end

function compute_shadows(d::AbstractSimulator, circuit_ir::Program, recipes, obs_qubits; kwargs...)
    qc = qubit_count(circuit_ir)
    _validate_ir_instructions_compatibility(d, circuit_ir, Val(:JAQCD))
    operations = circuit_ir.instructions
    operations = [Instruction(op) for op in operations]
    _validate_operation_qubits(operations)

    n_snapshots  = size(recipes, 1)
    n_qubits     = size(recipes, 2)
    reinit!(d, qc, n_snapshots)
    d            = evolve!(d, operations)
    snapshot_d   = similar(d, shots=1)
    qubit_inds   = [findfirst(q->q==oq, 0:qubit_count(circuit_ir)-1) for oq in obs_qubits]
    measurements = Matrix{Int}(undef, n_snapshots, n_qubits)
    for s_ix in 1:n_snapshots
        copyto!(snapshot_d, d)
        
        snapshot_rotations = reduce(vcat, [diagonalizing_gates(OBS_LIST[recipes[s_ix, wire_idx] + 1], [wire]) for (wire_idx, wire) in enumerate(obs_qubits)])
        snapshot_d         = evolve!(snapshot_d, snapshot_rotations)
        @views begin
            measurements[s_ix, :] .= _formatted_measurements(snapshot_d)[1][qubit_inds]
        end
    end
    return measurements
end

function (d::AbstractSimulator)(circuit_ir::Program, args...; shots::Int=0, kwargs...)
    qc = qubit_count(circuit_ir) 
    _validate_ir_results_compatibility(d, circuit_ir.results, Val(:JAQCD))
    _validate_ir_instructions_compatibility(d, circuit_ir, Val(:JAQCD))
    _validate_shots_and_ir_results(shots, circuit_ir.results, qc)
    operations = circuit_ir.instructions
    if shots > 0 && !isempty(circuit_ir.basis_rotation_instructions)
        operations = vcat(operations, circuit_ir.basis_rotation_instructions)
    end
    operations = [Instruction(op) for op in operations]
    _validate_operation_qubits(operations)

    reinit!(d, qc, shots)
    d       = evolve!(d, operations)
    results = Braket.ResultTypeValue[]
    if shots == 0 && !isempty(circuit_ir.results)
        result_types = _translate_result_types(circuit_ir.results, qc)
        _validate_result_types_qubits_exist(result_types, qc)
        results = _generate_results(circuit_ir.results, result_types, d)
    end
    return _bundle_results(results, circuit_ir, d) 
end

include("gate_kernels.jl")
include("noise_kernels.jl")
include("observables.jl")
include("result_types.jl")
include("properties.jl")
include("sv_simulator.jl")
include("dm_simulator.jl")

function __init__()
    Braket._simulator_devices[]["braket_dm"] = DensityMatrixSimulator{ComplexF64}
    Braket._simulator_devices[]["braket_sv"] = StateVectorSimulator{ComplexF64}
    Braket._simulator_devices[]["default"]   = StateVectorSimulator{ComplexF64}
end

end # module BraketStateVector
