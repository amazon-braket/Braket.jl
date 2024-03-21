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
    _delegate::AbstractBraketSimulator
    function LocalSimulator(backend::Union{String, AbstractBraketSimulator})
        backend_name = device_id(backend)
        haskey(_simulator_devices[], backend_name) && return new(backend_name, _simulator_devices[][backend_name](0,0))
        !isdefined(Main, Symbol(backend_name)) && throw(ArgumentError("no local simulator with name $backend_name is loaded!"))
        return new(backend_name, Symbol(backend_name)(0, 0))
    end
end
name(s::LocalSimulator) = name(s._delegate)
device_id(s::String) = s

function (d::LocalSimulator)(task_spec::Union{Circuit, AbstractProgram}, args...; shots::Int=0, inputs::Dict{String, Float64} = Dict{String, Float64}(), kwargs...)
    sim = d._delegate
    @debug "Single task. Starting run..."
    stats = @timed _run_internal(sim, task_spec, args...; inputs=inputs, shots=shots, kwargs...)
    @debug "Single task. Time to run internally: $(stats.time). GC time: $(stats.gctime)."
    local_result = stats.value
    return LocalQuantumTask(local_result.task_metadata.id, local_result)
end

function (d::LocalSimulator)(task_specs::Vector{T}, args...; shots::Int=0, max_parallel::Int=-1, inputs::Union{Vector{Dict{String, Float64}}, Dict{String, Float64}} = Dict{String, Float64}(), kwargs...) where {T}
    is_single_task  = length(task_specs) == 1
    is_single_input = inputs isa Dict{String, Float64} || length(inputs) == 1
    if is_single_input
        if is_single_task 
            return d(task_specs[1], args...; shots=shots, inputs=inputs, kwargs...)
        elseif inputs isa Dict{String, Float64}
            inputs = [deepcopy(inputs) for ix in 1:length(task_specs)]
        else
            inputs = [deepcopy(inputs[1]) for ix in 1:length(task_specs)]
        end
    end
    !is_single_task && !is_single_input && length(task_specs) != length(inputs) && throw(ArgumentError("number of inputs ($(length(inputs))) and task specifications ($(length(task_specs))) must be equal."))
    # let each thread pick up an idle simulator
    #sims     = Channel(Inf)
    #foreach(i -> put!(sims, copy(d._delegate)), 1:Threads.nthreads())

    tasks_and_inputs = zip(1:length(task_specs), task_specs, inputs)
    # is this actually faster?
    todo_tasks_ch = Channel(length(tasks_and_inputs))
    for (ix, spec, input) in tasks_and_inputs
        if spec isa Circuit
            param_names = Set(string(param.name) for param in spec.parameters)
            unbounded_params = setdiff(param_names, collect(keys(input)))
            !isempty(unbounded_params) && throw(ErrorException("cannot execute circuit with unbound parameters $unbounded_params."))
        end
        put!(todo_tasks_ch, (ix, spec, input))
    end
    @debug "batch size is $(length(task_specs)). Starting run..."
    n_task_threads = 32
    stats = @timed begin
	    done_tasks_ch = Channel(length(tasks_and_inputs)) do ch
		function task_processor(input_tup)
		    ix, spec, input = input_tup
		    sim = copy(d._delegate)
		    res = _run_internal(sim, spec, args...; inputs=input, shots=shots, kwargs...)
		    put!(ch, (ix, res))
		end
		Threads.foreach(task_processor, todo_tasks_ch, ntasks=n_task_threads)
	    end
	    r_ix = 1
	    results = Vector{GateModelQuantumTaskResult}(undef, length(task_specs))
	    while r_ix <= length(task_specs)
                ix, res = take!(done_tasks_ch)
		results[ix] = res
		r_ix += 1
	    end
    end
    @debug "batch size is $(length(task_specs)). Time to run internally: $(stats.time). GC time: $(stats.gctime)."
    return LocalQuantumTaskBatch([local_result.task_metadata.id for local_result in results], results)
end

function _run_internal(simulator, circuit::Circuit, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.openqasm.program")
        validate_circuit_and_shots(circuit, shots)
        program      = ir(circuit, Val(:OpenQASM))
        full_inputs  = isnothing(program.inputs) ? inputs : merge(program.inputs, inputs)
        full_program = OpenQasmProgram(program.braketSchemaHeader, program.source, full_inputs) 
        r = simulator(full_program, args...; shots=shots, kwargs...)
        return format_result(r) 
    elseif haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        validate_circuit_and_shots(circuit, shots) 
        program = ir(circuit, Val(:JAQCD))
        qubits  = qubit_count(circuit)
        r       = simulator(program, qubits, args...; shots=shots, inputs=inputs, kwargs...)
        return format_result(r)
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, program::OpenQasmProgram, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.openqasm.program")
        stats = @timed begin
            simulator(program; shots=shots, inputs=inputs, kwargs...)
        end
        @debug "Time to invoke simulator: $(stats.time)"
        r     = stats.value
        stats = @timed format_result(r)
        @debug "Time to format results: $(stats.time)"
        return stats.value
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, program::Program, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        stats   = @timed qubit_count(program)
        @debug "Time to get qubit count: $(stats.time)"
        qubits  = stats.value
        stats = @timed begin
            simulator(program, qubits, args...; shots=shots, inputs=inputs, kwargs...)
        end
        @debug "Time to invoke simulator: $(stats.time)"
        r     = stats.value
        stats = @timed format_result(r)
        @debug "Time to format results: $(stats.time)"
        return stats.value
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
