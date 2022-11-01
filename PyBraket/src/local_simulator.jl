struct LocalQuantumTask
    id::String
    result::Braket.AbstractQuantumTaskResult
end
Braket.state(b::LocalQuantumTask)  = "COMPLETED"
Braket.id(b::LocalQuantumTask)     = b.id
Braket.result(b::LocalQuantumTask) = b.result


struct LocalSimulator <: Braket.Device
    o::Py
    LocalSimulator() = new(local_sim.LocalSimulator())
    LocalSimulator(backend::String) = new(local_sim.LocalSimulator(backend))
end
Braket.name(ls::LocalSimulator) = pyconvert(String, ls.name)

function Base.run(d::LocalSimulator, task_spec::Braket.IR.AHSProgram; shots::Int=0, kwargs...)
    py_ir = Py(task_spec)
    py_raw_result = d._delegate.run(py_ir, shots; kwargs...)
    jl_raw_result = pyconvert(Braket.AnalogHamiltonianSimulationTaskResult, py_raw_result)
    res = Braket.format_result(jl_raw_result)
    id = res.task_metadata.id
    LocalQuantumTask(id, res)
end
Base.run(d::LocalSimulator, task_spec::Braket.AnalogHamiltonianSimulation; shots::Int=0, kwargs...) = run(d, ir(task_spec); shots=shots, kwargs...)

function Base.run(d::LocalSimulator, task_spec::Braket.OpenQasmProgram; shots::Int=0, inputs::Dict{String, Float64}=Dict{String,Float64}(), kwargs...)
    py_inputs = pydict(pystr(k)=>v for (k,v) in inputs)
    py_ts = pyopenqasm.Program(source=pystr(task_spec.source), inputs=py_inputs)
    py_raw_result = d._delegate.run_openqasm(py_ts, shots, kwargs...)
    jl_result = pyconvert(Braket.GateModelTaskResult, py_raw_result)
    t_id = jl_result.taskMetadata.id
    res = Braket.format_result(jl_result)
    LocalQuantumTask(t_id, res)
end

function Base.run(d::LocalSimulator, task_spec::PyCircuit; shots::Int=0, inputs::Dict{String, Float64}=Dict{String,Float64}(), kwargs...)
    jaqcd_ir = task_spec.to_ir(ir_type=circuit.serialization.IRType.JAQCD)
    py_raw_result = d._delegate.run(jaqcd_ir, task_spec.qubit_count, shots, kwargs...)
    jl_result = pyconvert(Braket.GateModelTaskResult, py_raw_result)
    t_id = jl_result.taskMetadata.id
    res = Braket.format_result(jl_result)
    LocalQuantumTask(t_id, res)
end
Base.run(d::LocalSimulator, task_spec::Circuit; kwargs...) = run(d, PyCircuit(task_spec); kwargs...)

(ls::LocalSimulator)(task_spec; kwargs...) = run(ls, task_spec; kwargs...)

Py(d::LocalSimulator) = getfield(d, :o)
Base.getproperty(d::LocalSimulator, s::Symbol)             = getproperty(Py(d), s)
Base.getproperty(d::LocalSimulator, s::AbstractString)     = getproperty(Py(d), s)
Base.setproperty!(d::LocalSimulator, s::Symbol, x)         = setproperty!(Py(d), s, x)
Base.setproperty!(d::LocalSimulator, s::AbstractString, x) = setproperty!(Py(d), s, x)
