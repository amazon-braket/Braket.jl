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
        backend_name = device_id(backend)
        haskey(_simulator_devices[], backend_name) && return new(backend_name, _simulator_devices[][backend_name](0,0))
        !isdefined(Main, Symbol(backend_name)) && throw(ArgumentError("no local simulator with name $backend_name is loaded!"))
        return new(backend_name, Symbol(backend_name)(0, 0))
    end
end
name(s::LocalSimulator) = name(s._delegate)
device_id(s::String) = s

function (d::LocalSimulator)(task_spec::Union{Circuit, AbstractProgram}, args...; shots::Int=0, inputs::Dict{String, Float64} = Dict{String, Float64}(), kwargs...)
    sim = copy(d._delegate)
    local_result = _run_internal(sim, task_spec, args...; inputs=inputs, shots=shots, kwargs...)
    sim = nothing
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
            param_names = Set(string(param.name) for param in spec.parameters)
            unbounded_params = setdiff(param_names, collect(keys(input)))
            !isempty(unbounded_params) && throw(ErrorException("cannot execute circuit with unbound parameters $unbounded_params."))
        end
    end
    results = Vector{GateModelQuantumTaskResult}(undef, length(task_specs))
    # let each thread pick up an idle simulator
    sims     = Channel(Threads.nthreads())
    foreach(i -> put!(sims, copy(d._delegate)), 1:Threads.nthreads())
    max_qc   = maximum(qubit_count, task_specs)
    do_chunk = max_qc <= 20 && length(task_specs) > Threads.nthreads()
    @info "Braket.jl: batch size is $(length(task_specs)). Chunking? $do_chunk. Starting run..."
    start = time()
    @profile begin
        stats = @timed begin
            if do_chunk
                chunks = collect(Iterators.partition(tasks_and_inputs, div(length(tasks_and_inputs), Threads.nthreads())))
                Threads.@threads for c_ix in 1:length(chunks)
                    sim = take!(sims)
                    for (ix, spec, input) in chunks[c_ix]
                        results[ix] = _run_internal(sim, spec, args...; inputs=input, shots=shots, kwargs...)
                    end
                    put!(sims, sim)
                end
            else
                Threads.@threads for (ix, spec, input) in collect(tasks_and_inputs)
                    sim = take!(sims)
                    println("Thread $(Threads.threadid()) beginning task $ix.")
                    results[ix] = _run_internal(sim, spec, args...; inputs=input, shots=shots, kwargs...)
                    println("Thread $(Threads.threadid()) completed task $ix.")
                    put!(sims, sim)
                end
            end
        end
        @info "Braket.jl: batch size is $(length(task_specs)). Time to run internally: $(stats.time). GC time: $(stats.gctime)."
    end
    stop = time()
    return LocalQuantumTaskBatch([local_result.task_metadata.id for local_result in results], results)
end

function _run_internal(simulator, circuit::Circuit, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
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
        r       = simulator(program, qubits, args...; shots=shots, inputs=inputs, kwargs...)
        return format_result(r)
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, circuit::Program, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        program = circuit
        qubits  = qubit_count(circuit)
        r       = simulator(program, qubits, args...; shots=shots, kwargs...)
	fr = format_result(r)
	return fr
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
