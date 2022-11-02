module PyBraket
    using PythonCall
    using DataStructures
    using Braket
    import Braket: Instruction
    using Braket.IR
    import Braket.IR: TimeSeries, AtomArrangement, DrivingField, PhysicalField, ShiftingField, Setup, Hamiltonian, AHSProgram
    export LocalSimulator, LocalJob, PyCircuit
    import PythonCall: Py

    const awsbraket   = PythonCall.pynew()
    const braketobs   = PythonCall.pynew()
    const local_sim   = PythonCall.pynew()
    const tasks       = PythonCall.pynew()
    const circuit     = PythonCall.pynew()
    const pyjaqcd     = PythonCall.pynew()
    const pyahs       = PythonCall.pynew()
    const pyopenqasm  = PythonCall.pynew()
    const pygates     = PythonCall.pynew()
    const pynoises    = PythonCall.pynew()
    const local_job   = PythonCall.pynew()
    const collections = PythonCall.pynew()

    function __init__()
        # must set these when this code is actually loaded
        PythonCall.pycopy!(awsbraket,   pyimport("braket.aws"))
        PythonCall.pycopy!(braketobs,   pyimport("braket.circuits.observables"))
        PythonCall.pycopy!(local_sim,   pyimport("braket.devices.local_simulator"))
        PythonCall.pycopy!(circuit,     pyimport("braket.circuits"))
        PythonCall.pycopy!(pygates,     pyimport("braket.circuits.gates"))
        PythonCall.pycopy!(pynoises,    pyimport("braket.circuits.noises"))
        PythonCall.pycopy!(pyjaqcd,     pyimport("braket.ir.jaqcd"))
        PythonCall.pycopy!(pyopenqasm,  pyimport("braket.ir.openqasm"))
        PythonCall.pycopy!(pyahs,       pyimport("braket.ir.ahs"))
        PythonCall.pycopy!(tasks,       pyimport("braket.tasks"))
        PythonCall.pycopy!(local_job,   pyimport("braket.jobs.local.local_job"))
        PythonCall.pycopy!(collections, pyimport("collections"))
        PythonCall.pyconvert_add_rule("collections:Counter", Accumulator, counter_to_acc)
    end
    function counter_to_acc(::Type{Accumulator}, x::Py)
        return counter((pyconvert(Any, el) for el in  x.elements()))
    end
    function conv_multilevel_vec(v::Vector{T}) where {T}
        isbitstype(T) && return pylist(v)
        T == String && return pylist(pystr.(v))
        return pylist(conv_multilevel_vec.(v))
    end
    conv_multilevel_vec(t::String) = pystr(t)
    conv_multilevel_vec(t::IR.PhysicalField) = Py(t)
    conv_multilevel_vec(t::IR.DrivingField)  = Py(t)
    conv_multilevel_vec(t::IR.ShiftingField) = Py(t)

    function arg_gen(x::T, fns) where {T}
        args = map(fns) do fn
            val = getproperty(x, fn)
            isnothing(val) && return fn=>pybuiltins.None
            typeof(val) <: Vector{<:Number} && return fn=>pylist(Py(val))
            typeof(val) == Vector{String} && return fn=>pylist(pystr.(val))
            typeof(val) == Vector{Braket.IR.PhysicalField} && return fn=>pylist(Py.(val))
            typeof(val) == Vector{Braket.IR.DrivingField} && return fn=>pylist(Py.(val))
            typeof(val) <: Vector && return fn=>conv_multilevel_vec(val)
            typeof(val) <: Dict && return fn=>pydict(val)
            typeof(val) == String && return fn=>pystr(val)
            return fn=>Py(val)
        end
        return args
    end
        
    for (irT, pyT) in ((:(Braket.IR.Expectation), :(pyjaqcd.Expectation)),
                       (:(Braket.IR.Variance), :(pyjaqcd.Variance)),
                       (:(Braket.IR.Sample), :(pyjaqcd.Sample)),
                       (:(Braket.IR.Amplitude), :(pyjaqcd.Amplitude)),
                       (:(Braket.IR.StateVector), :(pyjaqcd.StateVector)),
                       (:(Braket.IR.Probability), :(pyjaqcd.Probability)),
                       (:(Braket.IR.DensityMatrix), :(pyjaqcd.DensityMatrix)))
        @eval begin
            Py(o::$irT) = $pyT(;arg_gen(o, fieldnames($irT))...) 
        end
    end
    
    include("pyahs.jl")
    include("pygates.jl")
    include("pynoises.jl")
    include("pyschema.jl")
    using .PySchema
    include("pycircuit.jl")
    include("local_simulator.jl")
    include("local_job.jl")
end
