"""
    LocalQuantumTask(id::String, result::Union{GateModelQuantumTaskResult, AnalogHamiltonianSimulationQuantumTaskResult})

A quantum task which has been run *locally* using a [`LocalSimulator`](@ref).
The `state` of a `LocalQuantumTask` is always `"COMPLETED"` as the task object
is only created once the loca simulation has finished.
"""
struct LocalQuantumTask
    id::String
    result::Union{GateModelQuantumTaskResult, AnalogHamiltonianSimulationQuantumTaskResult}
end
state(b::LocalQuantumTask)  = "COMPLETED"
id(b::LocalQuantumTask)     = b.id
result(b::LocalQuantumTask) = b.result

"""
    LocalQuantumTaskBatch(ids::Vector{String}, results::Vector{GateModelQuantumTaskResult})

A *batch* of quantum tasks which has been run *locally* using a
[`LocalSimulator`](@ref). 
"""
struct LocalQuantumTaskBatch
    ids::Vector{String}
    results::Vector{GateModelQuantumTaskResult}
end
results(lqtb::LocalQuantumTaskBatch) = lqtb.results

"""
    LocalSimulator(backend::Union{String, AbstractBraketSimulator})

A quantum simulator which runs *locally* rather than sending the circuit(s)
to the cloud to be executed on-demand. A `LocalSimulator` must be created with
a backend -- either a handle, in the form of a `String`, which uniquely identifies
a simulator backend registered in [`_simulator_devices`](@ref Braket._simulator_devices), or an already instantiated
simulator object.

`LocalSimulator`s should implement their own method for [`simulate`](@ref) if needed. They
can process single tasks or task batches.
"""
struct LocalSimulator <: Device
    backend::String
    _delegate
    function LocalSimulator(backend)
        backend_name = device_id(backend)
        haskey(_simulator_devices[], backend_name) && return new(backend_name, _simulator_devices[][backend_name](0,0))
        !isdefined(Main, Symbol(backend_name)) && throw(ArgumentError("no local simulator with name $backend_name is loaded!"))
        return new(backend_name, Symbol(backend_name)(0, 0))
    end
end
name(s::LocalSimulator) = name(s._delegate)
device_id(s::String) = s

"""
    simulate(d::LocalSimulator, task_spec::Union{Circuit, AbstractProgram}, args...; shots::Int=0, inputs::Dict{String, Float64} = Dict{String, Float64}(), kwargs...)

Simulate the execution of `task_spec` using the backend of [`LocalSimulator](@ref) `d`.
`args` are additional arguments to be provided to the backend. `inputs` is used to set
the value of any [`FreeParameter`](@ref) in `task_spec` and will override the existing
`inputs` field of an `OpenQasmProgram`. Other `kwargs` will be passed to the backend
simulator. Returns a [`LocalQuantumTask`](@ref Braket.LocalQuantumTask).
"""
function simulate(d::LocalSimulator, task_spec::Union{Circuit, AnalogHamiltonianSimulation, AbstractProgram}, args...; shots::Int=0, inputs::Dict{String, Float64} = Dict{String, Float64}(), kwargs...)
    sim = d._delegate
    local_result = _run_internal(sim, task_spec, args...; inputs=inputs, shots=shots, kwargs...)
    return LocalQuantumTask(local_result.task_metadata.id, local_result)
end

"""
    simulate(d::LocalSimulator, task_specs::Vector{T}, args...; kwargs...) where {T}

Simulate the execution of a *batch* of tasks specified by `task_specs`
using the backend of [`LocalSimulator](@ref) `d`.
`args` are additional arguments to be provided to the backend.

`kwargs` used by the `LocalSimulator` are:
  - `shots::Int` - the number of shots to run for all tasks in `task_specs`. Default is `0`.
  - `max_parallel::Int` - the maximum number of simulations to execute simultaneously. Default is `32`.
  - `inputs::Union{Vector{Dict{String, Float64}}, Dict{String, Float64}}` - used to set
    the value of any [`FreeParameter`](@ref) in each task specification. It must either be a
    `Dict` or a single-element `Vector` (in which case the same parameter values are used for
    all elements of `task_specs` *or* of the same length as `task_specs` (in which case the `i`-th 
    specification is paired with the `i`-th input dictionary). Default is an empty dictionary. 

Other `kwargs` are passed through to the backend simulator. Returns a [`LocalQuantumTaskBatch`](@ref Braket.LocalQuantumTaskBatch).

!!! note
    Because Julia uses dynamic threading and `Task`s can migrate between threads, each simulation is a `Task`
    which itself can spawn many more `Task`s, as the internal implementation of [`LocalSimulator`](@ref)'s backend
    may use threading where appropriate. On systems with many CPU cores, spawning too many `Task`s may overwhelm
    the Julia scheduler and degrade performance. "Too many" depends on the particulars of your hardware, so on
    many-core systems you may need to tune this value for best performance.
"""
function simulate(d::LocalSimulator, task_specs::Vector{T}, args...; shots::Int=0, max_parallel::Int=-1, inputs::Union{Vector{Dict{String, Float64}}, Dict{String, Float64}} = Dict{String, Float64}(), kwargs...) where {T}
    is_single_task  = length(task_specs) == 1
    is_single_input = inputs isa Dict{String, Float64} || length(inputs) == 1
    if is_single_input
        if is_single_task
            inputs = inputs isa Vector ? first(inputs) : inputs
            results = [d(task_specs[1], args...; shots=shots, inputs=inputs, kwargs...)]

            return LocalQuantumTaskBatch([local_result.result.task_metadata.id for local_result in results], results)
        elseif inputs isa Dict{String, Float64}
            inputs = [deepcopy(inputs) for ix in 1:length(task_specs)]
        else
            inputs = [deepcopy(inputs[1]) for ix in 1:length(task_specs)]
        end
    end
    !is_single_task && !is_single_input && length(task_specs) != length(inputs) && throw(ArgumentError("number of inputs ($(length(inputs))) and task specifications ($(length(task_specs))) must be equal."))
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
    return LocalQuantumTaskBatch([local_result.result.task_metadata.id for local_result in results], results)
end
(d::LocalSimulator)(args...; kwargs...) = simulate(d, args...; kwargs...)

function _run_internal(simulator, circuit::Circuit, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.openqasm.program")
        validate_circuit_and_shots(circuit, shots)
        program      = ir(circuit, Val(:OpenQASM))
        full_inputs  = isnothing(program.inputs) ? inputs : merge(program.inputs, inputs)
        full_program = OpenQasmProgram(program.braketSchemaHeader, program.source, full_inputs) 
        r            = simulate(simulator, full_program, shots; kwargs...)
        return format_result(r) 
    elseif haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        validate_circuit_and_shots(circuit, shots)
        program = ir(circuit, Val(:JAQCD))
        qubits  = qubit_count(circuit)
        r       = simulate(simulator, program, qubits, shots; inputs=inputs, kwargs...)
        return format_result(r)
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, program::OpenQasmProgram, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.openqasm.program")
        r = simulate(simulator, program, shots; inputs=inputs, kwargs...)
        return format_result(r)
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
function _run_internal(simulator, program::Program, args...; shots::Int=0, inputs::Dict{String, Float64}=Dict{String, Float64}(), kwargs...)
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        qubits  = qubit_count(program)
        r = simulate(simulator, program, qubits, shots; inputs=inputs, kwargs...)
        return format_result(r)
    else
        throw(ErrorException("$(typeof(simulator)) does not support qubit gate-based programs."))
    end
end
