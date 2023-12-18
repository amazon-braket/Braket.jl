struct LocalQuantumTask
    id::String
    result::GateModelQuantumTaskResult
end
state(b::LocalQuantumTask)  = "COMPLETED"
id(b::LocalQuantumTask)     = b.id
result(b::LocalQuantumTask) = b.result

struct LocalQuantumTaskBatch
    ids::Vector{String}
    results::Vector{GateModelQuantumTaskResult}
end
results(lqtb::LocalQuantumTaskBatch) = lqtb.results

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
    sim = copy(d._delegate)
    local_result = _run_internal(sim, task_spec, args...; inputs=inputs, shots=shots, kwargs...)
    return LocalQuantumTask(local_result.task_metadata.id, local_result)
end

function (d::LocalSimulator)(task_specs::Union{Circuit, AbstractProgram, AbstractArray}, args...; shots::Int=0, max_parallel::Int=-1, inputs::Union{Vector{Dict{String, Float64}}, Dict{String, Float64}} = Dict{String, Float64}(), kwargs...)
    is_single_task  = length(task_specs) == 1 || task_specs isa Union{Circuit, AbstractProgram}
    is_single_input = inputs isa Dict{String, Float64}
    !is_single_task && !is_single_input && length(task_specs) != length(inputs) && throw(ArgumentError("number of inputs ($(length(inputs))) and task specifications ($(length(task_specs))) must be equal."))
    is_single_task && (task_specs = vec(task_specs))
    is_single_input && (inputs = is_single_task ? [inputs] : fill(inputs, length(task_specs)))
    tasks_and_inputs = zip(1:length(task_specs), task_specs, inputs)
    for (ix, spec, input) in tasks_and_inputs
        if spec isa Circuit
            param_names = Set(String(param) for param in spec.parameters)
            unbounded_params = setdiff(param_names, collect(keys(input)))
            !isempty(unbounded_params) && throw(ErrorException("cannot execute circuit with unbound parameters $unbounded_params."))
        end
    end
    sims = [copy(d._delegate) for ix in 1:length(task_specs)]
    @info "Braket.jl: batch size is $(length(task_specs)). Starting run..."
    Base.GC.enable(false)
    start = time()
    results = Vector{GateModelQuantumTaskResult}(undef, length(task_specs))
    Threads.@threads for (ix, spec, input) in collect(tasks_and_inputs)
        results[ix] = _run_internal(sims[ix], spec, args...; inputs=input, shots=shots, kwargs...)
    end
    Base.GC.enable(true)
    stop = time()
    @info "Braket.jl: batch size is $(length(task_specs)). Time to run internally: $(stop-start)."
    return LocalQuantumTaskBatch([local_result.task_metadata.id for local_result in results], results)
end

function _run_internal(simulator, circuit::Circuit, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    #simulator = d._delegate
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
        qubits  = qubit_count(circuit)
        start   = time()
        r       = simulator(program, qubits, args...; shots=shots, kwargs...)
        stop = time()
        #@info "(Thread $(Threads.threadid())): Simulation duration $(stop-start)"
        start = time()
        fr = format_result(r)
        stop = time()
        @debug "Time to format result: $(stop-start)"
        return fr
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, circuit::Program, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        program = circuit
        qubits  = qubit_count(circuit)
        start   = time()
        r       = simulator(program, qubits, args...; shots=shots, kwargs...)
        stop    = time()
        #@info "(Thread $(Threads.threadid())): Simulation duration $(stop-start)"
        start = time()
        fr = format_result(r)
        stop = time()
        @debug "Time to format result: $(stop-start)"
        return fr
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
