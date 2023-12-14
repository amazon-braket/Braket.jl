struct LocalQuantumTask
    id::String
    result::AbstractQuantumTaskResult
end
state(b::LocalQuantumTask)  = "COMPLETED"
id(b::LocalQuantumTask)     = b.id
result(b::LocalQuantumTask) = b.result

struct LocalSimulator <: Device
    backend::String
    _delegate::BraketSimulator
    function LocalSimulator(backend::Union{String, BraketSimulator})
        backend_name = String(backend)
        haskey(_simulator_devices[], backend_name) && return new(backend_name, _simulator_devices[][backend_name](0,0))
        !isdefined(Main, Symbol(backend_name)) && throw(ArgumentError("no local simulator with name $backend_name is loaded!"))
        return new(backend_name, Symbol(backend_name)(0, 0))
    end
end
name(s::LocalSimulator) = name(s._delegate)

function (d::LocalSimulator)(task_spec::Union{Circuit, AbstractProgram}, args...; shots::Int=0, inputs::Dict{String, Float64} = Dict{String, Float64}(), kwargs...)
    local_result = _run_internal(d, task_spec, args...; inputs=inputs, shots=shots, kwargs...)
    return LocalQuantumTask(local_result.task_metadata.id, local_result)
end

function (d::LocalSimulator)(task_specs::Union{Circuit, AbstractProgram, Vector}, args...; shots::Int=0, max_parallel::Int=-1, inputs::Union{Vector{Dict{String, Float64}}, Dict{String, Float64}} = Dict{String, Float64}(), kwargs...)
    is_single_task = length(task_specs) == 1 || task_specs isa Union{Circuit, AbstractProgram}
    is_single_input = inputs isa Dict{String, Float64}
    !is_single_task && !is_single_input && length(task_specs) != length(inputs) && throw(ArgumentError("number of inputs ($(length(inputs))) and task specifications ($(length(task_specs))) must be equal."))
    is_single_task && (task_specs = vec(task_specs))
    is_single_input && (inputs = vec(inputs))
    tasks_and_inputs = zip(1:length(task_specs), task_specs, inputs)
    results = Vector{AbstractQuantumTaskResult}(undef, length(task_specs))
    for (ix, spec, input) in tasks_and_inputs
        if spec isa Circuit
            param_names = Set(String(param) for param in parameters(spec))
            unbounded_params = setdiff(param_names, collect(keys(input)))
            !isempty(unbounded_params) && throw(ErrorException("cannot execute circuit with unbound parameters $unbounded_params."))
        end
    end
    Threads.@threads for (ix, spec, input) in tasks_and_inputs
        results[ix] = _run_internal(d, spec, args...; inputs=input, shots=shots, kwargs...)
    end
    return LocalQuantumTaskBatch(results)
end

function _run_internal(d::LocalSimulator, circuit::Circuit, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    simulator = d._delegate
    #=if haskey(properties(simulator).action, "braket.ir.openqasm.program")
        validate_circuit_and_shots(circuit, shots)
        program = ir(circuit, Val(:OpenQASM))
        full_inputs = isnothing(program.inputs) ? inputs : merge(program.inputs, inputs)
        full_program = OpenQasmProgram(program.braketSchemaHeader, program.source, full_inputs) 
        r = simulator(full_program, shots, args...; kwargs...)
        return format_result(r) 
    else=#
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        validate_circuit_and_shots(circuit, shots) 
        program = ir(circuit, Val(:JAQCD))
        qubits = qubit_count(circuit)
        r = simulator(program, qubits, args...; shots=shots, kwargs...)
        return format_result(r) 
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
