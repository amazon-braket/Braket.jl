struct PyLocalSimulator <: Braket.AbstractBraketSimulator
    o::Py
    PyLocalSimulator() = new(local_sim.LocalSimulator())
    PyLocalSimulator(backend::String) = new(local_sim.LocalSimulator(backend))
end
(ls::PyLocalSimulator)(nq::Int, shots::Int) = ls
Braket.name(ls::PyLocalSimulator) = pyconvert(String, ls.name)
Braket.device_id(ls::PyLocalSimulator) = pyconvert(String, ls._delegate.DEVICE_ID)
Braket.properties(ls::PyLocalSimulator) = ls.properties
function Braket.simulate(d::PyLocalSimulator, task_spec::Braket.IR.AHSProgram; shots::Int=0, kwargs...)
    py_ir = Py(task_spec)
    py_raw_result = d._delegate.run(py_ir, shots; kwargs...)
    return pyconvert(Braket.AnalogHamiltonianSimulationTaskResult, py_raw_result)
end
Braket.simulate(d::PyLocalSimulator, task_spec::Braket.AnalogHamiltonianSimulation; shots::Int=0, kwargs...) = simulate(d, ir(task_spec); shots=shots, kwargs...)

function Braket.simulate(d::PyLocalSimulator, task_spec::Braket.OpenQasmProgram; shots::Int=0, inputs::Dict{String, Float64}=Dict{String,Float64}(), kwargs...)
    py_inputs = pydict(pystr(k)=>v for (k,v) in inputs)
    py_ts = pyopenqasm.Program(source=pystr(task_spec.source), inputs=py_inputs)
    py_raw_result = d._delegate.run_openqasm(py_ts, shots, kwargs...)
    return pyconvert(Braket.GateModelTaskResult, py_raw_result)
end

function Braket.simulate(d::PyLocalSimulator, task_spec::PyCircuit; shots::Int=0, inputs::Dict{String, Float64}=Dict{String,Float64}(), kwargs...)
    jaqcd_ir = task_spec.to_ir(ir_type=circuit.serialization.IRType.JAQCD)
    py_raw_result = d._delegate.run(jaqcd_ir, task_spec.qubit_count, shots, kwargs...)
    return pyconvert(Braket.GateModelTaskResult, py_raw_result)
end
Braket.simulate(d::PyLocalSimulator, task_spec::Circuit; kwargs...) = simulate(d, PyCircuit(task_spec); kwargs...)

function Braket._run_internal(simulator::PyLocalSimulator, task_spec::AnalogHamiltonianSimulation, args...; kwargs...)
    raw_py_result = simulator._run_internal(Py(ir(task_spec)), args...; kwargs...)
    jl_task_metadata = pyconvert(Braket.TaskMetadata, raw_py_result.task_metadata) 
    jl_measurements = map(raw_py_result.measurements) do m
        jl_status = pyconvert(String, pystr(m.status))
        status = if jl_status == "Success"
                     Braket.success
                 elseif jl_status == "Partial_success"
                     Braket.partial_success
                 else
                     Braket.failure
                 end
        Braket.ShotResult(status,
                          pyconvert(Any, m.pre_sequence),
                          pyconvert(Any, m.post_sequence)
                         )
    end
    return Braket.AnalogHamiltonianSimulationQuantumTaskResult(jl_task_metadata, jl_measurements) 
end

(ls::PyLocalSimulator)(task_spec; kwargs...) = simulate(ls, task_spec; kwargs...)

Py(d::PyLocalSimulator) = getfield(d, :o)
Base.getproperty(d::PyLocalSimulator, s::Symbol)             = getproperty(Py(d), s)
Base.getproperty(d::PyLocalSimulator, s::AbstractString)     = getproperty(Py(d), s)
Base.setproperty!(d::PyLocalSimulator, s::Symbol, x)         = setproperty!(Py(d), s, x)
Base.setproperty!(d::PyLocalSimulator, s::AbstractString, x) = setproperty!(Py(d), s, x)
