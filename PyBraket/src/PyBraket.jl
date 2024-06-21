module PyBraket
    using PythonCall
    using DataStructures
    using Braket
    import Braket: Instruction
    using Braket.IR
    import Braket.IR: TimeSeries, AtomArrangement, DrivingField, PhysicalField, ShiftingField, Setup, Hamiltonian, AHSProgram
    export PyLocalSimulator
    import PythonCall: Py

    const awsbraket   = PythonCall.pynew()
    const local_sim   = PythonCall.pynew()
    const default_sim = PythonCall.pynew()
    const tasks       = PythonCall.pynew()
    const pyahs       = PythonCall.pynew()
    const pyopenqasm  = PythonCall.pynew()
    const collections = PythonCall.pynew()

    function __init__()
        # must set these when this code is actually loaded
        PythonCall.pycopy!(awsbraket,   pyimport("braket.aws"))
        PythonCall.pycopy!(local_sim,   pyimport("braket.devices.local_simulator"))
        PythonCall.pycopy!(default_sim, pyimport("braket.default_simulator"))
        PythonCall.pycopy!(pyopenqasm,  pyimport("braket.ir.openqasm"))
        PythonCall.pycopy!(pyahs,       pyimport("braket.ir.ahs"))
        PythonCall.pycopy!(tasks,       pyimport("braket.tasks"))
        PythonCall.pycopy!(collections, pyimport("collections"))
        PythonCall.pyconvert_add_rule("collections:Counter", Accumulator, counter_to_acc)
        Braket._simulator_devices[]["braket_ahs"] = PyLocalSimulator("braket_ahs") 
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
            typeof(val) <: NTuple{1} && return fn=>Py(val[1])
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
    include("pyahs.jl")
    include("pyschema.jl")
    using .PySchema
    include("local_simulator.jl")
end
