mutable struct PyCircuit
    o::Py
    PyCircuit(o::Py) = new(o)
    PyCircuit(v::Vector{Py}) = new(circuit.Circuit(pylist(v)))
    PyCircuit() = new(circuit.Circuit())
end
(c::PyCircuit)(arg::Number; kwargs...)   = PyCircuit(Py(c)(arg; kwargs...))
(c::PyCircuit)(; kwargs...)              = PyCircuit(Py(c)(; kwargs...))
Base.:(==)(c1::PyCircuit, c2::PyCircuit) = PythonCall.pyisTrue(Py(c1) == Py(c2))
Py(c::PyCircuit) = getfield(c, :o)
Base.getproperty(c::PyCircuit, s::Symbol)             = pyconvert(Any, getproperty(Py(c), s))
Base.getproperty(c::PyCircuit, s::AbstractString)     = pyconvert(Any, getproperty(Py(c), s))
Base.setproperty!(c::PyCircuit, s::Symbol, x)         = pyconvert(Any, setproperty!(Py(c), s, x))
Base.setproperty!(c::PyCircuit, s::AbstractString, x) = pyconvert(Any, setproperty!(Py(c), s, x))
function Base.show(io::IO, c::PyCircuit)
    if isempty(c.result_types)
        print(io, "PyCircuit('instructions': $(c.instructions))")
    else
        print(io, "PyCircuit('instructions': $(c.instructions), 'result_types': $(c.result_types))")
    end
end

Py(ix::Instruction) = circuit.Instruction(Py(ix.operator), pylist(ix.target isa Int ? [ix.target] : ix.target))
function Base.convert(::Type{PyCircuit}, c::Circuit)
    addables = vcat(map(Py, c.instructions), map(Py, c.result_types))
    pc = PyCircuit(addables)
    return pc
end
PyCircuit(c::Circuit) = convert(PyCircuit, c)

Py(o::Braket.Observables.HermitianObservable) = braketobs.Hermitian(Py(o.matrix))
Py(o::Braket.Observables.TensorProduct) = o.coefficient * braketobs.TensorProduct(pylist(map(Py, o.factors)))
Py(o::Braket.Observables.Sum) = braketobs.Sum(pylist(map(Py, o.summands)))
Py(o::AdjointGradient) = circuit.result_types.AdjointGradient(Py(o.observable), pylist(o.target), pylist(o.parameters))
Py(o::Expectation)     = circuit.result_types.Expectation(Py(o.observable), pylist(o.targets))
Py(o::Variance)        = circuit.result_types.Variance(Py(o.observable), pylist(o.targets))
Py(o::Sample)          = circuit.result_types.Sample(Py(o.observable), pylist(o.targets))
Py(o::Probability)     = circuit.result_types.Probability(pylist(o.targets))
Py(o::DensityMatrix)   = circuit.result_types.DensityMatrix(pylist(o.targets))
Py(o::Amplitude)       = circuit.result_types.Amplitude(pylist(map(s->Py(s), o.states)))
Py(o::StateVector)     = circuit.result_types.StateVector()

for (typ, py_typ, label) in ((:(Braket.Observables.H), :H, "h"), (:(Braket.Observables.X), :X, "x"), (:(Braket.Observables.Y), :Y, "y"), (:(Braket.Observables.Z), :Z, "z"), (:(Braket.Observables.I), :I, "i"))
    @eval begin
        Py(o::$typ) = o.coefficient * braketobs.$py_typ()
    end
end

Py(p::Braket.FreeParameter) = circuit.FreeParameter(pystr(String(p.name)))
