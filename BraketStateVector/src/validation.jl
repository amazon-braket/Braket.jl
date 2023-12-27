function _validate_amplitude_states(states::Vector{String}, qubit_count::Int)
    !all(length(state) == qubit_count for state in states) && throw(ErrorException())
    return
end

function _validate_ir_results_compatibility(d::D, results, ::Val{:OpenQASM}) where {D<:AbstractSimulator}
    isempty(results) && return

    circuit_result_types_name = [string(typeof(rt)) for rt in results]
    supported_result_types = properties(d).action["braket.ir.openqasm.program"].supportedResultTypes
    supported_result_types_names = [string(srt) for srt in supported_result_types]
    for name in circuit_result_types_name
        name ∉ supported_result_types_names && throw(ErrorException("result type $name not supported by $D"))
    end
    return
end

function _validate_ir_results_compatibility(d::D, results, ::Val{:JAQCD}) where {D<:AbstractSimulator}
    isempty(results) && return

    circuit_result_types_name = [rt.type for rt in results]
    supported_result_types = properties(d).action["braket.ir.jaqcd.program"].supportedResultTypes
    supported_result_types_names = [lowercase(srt.name) for srt in supported_result_types]
    for name in circuit_result_types_name
        name ∉ supported_result_types_names && throw(ErrorException("result type $name not supported by $D"))
    end
    return
end
    
function _validate_shots_and_ir_results(shots::Int, results, qubit_count::Int)
    if shots == 0
        isempty(results) && error("Result types must be specified in the IR when shots=0")
        for rt in results
            rt.type == "sample" && error("sample can only be specified when shots>0")
            rt.type == "amplitude" && _validate_amplitude_states(rt.states, qubit_count)
        end
    elseif shots > 0 && !isempty(results)
        for rt in results
            rt.type ∈ ["statevector", "amplitude", "densitymatrix"] && throw("statevector, amplitude and densitymatrix result types not available when shots>0")
        end
    end
end
function _validate_input_provided(circuit::Circuit)
    for instruction in circuit.instructions
        possible_parameters = Symbol("_angle"), Symbol("_angle_1"), Symbol("_angle_2")
        for parameter_name in possible_parameters
            if parameter_name ∈ propertynames(instruction.op)
                try
                    Float64(param)
                catch ex
                    throw("Missing input variable '$param'.")
                end
            end
        end
    end
    return
end
function _validate_ir_instructions_compatibility(d::D, circuit::Union{Program, Circuit}, ::Val{:OpenQASM}) where {D<:AbstractSimulator}
end

function _validate_ir_instructions_compatibility(d::D, circuit::Union{Program, Circuit}, ::Val{:JAQCD}) where {D<:AbstractSimulator}
end

function _validate_result_types_qubits_exist(result_types::Vector, qubit_count::Int)
    for rt in result_types
        (!hasfield(typeof(rt), :targets) || isnothing(rt.targets) || isempty(rt.targets)) && continue
        targets = rt.targets
        if rt isa AdjointGradient
            targets = reduce(vcat, targets)
        end
        !isempty(targets) && maximum(targets) > qubit_count && throw("Result type $rt references invalid qubits $targets. Maximum qubit number is $(qubit_count-1).")
    end
    return
end

function _validate_operation_qubits(operations::Vector{Instruction})
    all_targets       = [collect(op.target) for op in operations]
    qubits_referenced = unique(reduce(vcat, all_targets))
    maximum(qubits_referenced) >= length(qubits_referenced) && throw("Non-contiguous qubit indices supplied; qubit indices in a circuit must be contiguous. Qubits referenced: $qubits_referenced")
    return
end
