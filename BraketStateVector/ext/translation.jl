for (qml_type, braket_type) in ((Val{:Identity}, :I),
                                (Val{:PauliX}, :X),
                                (Val{:PauliY}, :Y),
                                (Val{:PauliZ}, :Z),
                                (Val{:Hadamard}, :H),
                                (Val{:ECR}, :ECR),
                                (Val{:S}, :S),
                                (Val{:AdjS}, :Si),
                                (Val{:T}, :T),
                                (Val{:AdjT}, :Ti),
                                (Val{:SX}, :V),
                                (Val{:AdjSX}, :Vi),
                                (Val{:CNOT}, :CNot),
                                (Val{:CY}, :CY),
                                (Val{:CZ}, :CZ),
                                (Val{:SWAP}, :Swap),
                                (Val{:ISWAP}, :ISwap),
                                (Val{:Toffoli}, :CCNot),
                               )
    @eval begin
        _translate_operation(parameters, qubits, d::AbstractSimulator, ::$qml_type) = Instruction($braket_type(), [qubits...])
    end
end
for (qml_type, braket_type) in ((Val{:RX}, :Rx),
                                (Val{:RY}, :Ry),
                                (Val{:RZ}, :Rz),
                                (Val{:QubitUnitary}, :Unitary),
                                (Val{:IsingXX}, :XX),
                                (Val{:IsingXY}, :XY),
                                (Val{:IsingYY}, :YY),
                                (Val{:IsingZZ}, :ZZ),
                                (Val{:PSWAP}, :PSwap),
                                (Val{:PhaseShift}, :PhaseShift),
                                (Val{:ControlledPhaseShift}, :CPhaseShift),
                                (Val{:CPhaseShift00}, :CPhaseShift00),
                                (Val{:CPhaseShift01}, :CPhaseShift01),
                                (Val{:CPhaseShift10}, :CPhaseShift10),
                               )
    @eval begin
        _translate_operation(parameters, qubits, d::AbstractSimulator, ::$qml_type) = Instruction($braket_type(parameters[1]), [qubits...])
    end
end

function pytype_to_symbol(o::Py)
    o_name = pyconvert(String, pytype(o).__name__)
    o_name == "AdjointOperation" && (o_name = "Adj"*pyconvert(String, pytype(o.base).__name__))
    return Symbol(o_name)
end

function _translate_parameters(py_params, parameter_names::Vector{String}, ::Val{true})
    isempty(py_params) && return Float64[]
    param_names          = isempty(parameter_names) ? fill("", length(py_params)) : parameter_names
    length(param_names) != length(py_params) && throw(ErrorException("Parameter names list must be equal to number of operation parameters"))
    parameters = map(zip(param_names, py_params)) do (param_name, param)
        # PennyLane passes any non-keyword argument in the operation.parameters list.
        # In some cases, like the unitary gate or qml.QubitChannel (Kraus noise), these
        # parameter can be matrices. Braket only supports parameterization of numeric parameters
        # (so far, these are all angle parameters), so non-numeric parameters are handled
        # separately.
        param_name != "" && return BraketStateVector.Braket.FreeParameter(param_name)
        pyisinstance(param, pennylane.numpy.tensor) && return pyconvert(Array, param.numpy())
        return pyconvert(Float64, param)
    end
    return parameters
end

function _translate_parameters(py_params, parameter_names::Vector{String}, ::Val{false})
    return [pyisinstance(p, pennylane.numpy.tensor) ? pyconvert(Array, p.numpy()) : pyconvert(Float64, p) for p in py_params]
end

function translate_operation(op::Py, qubits::NTuple{N, Int}, d::AbstractSimulator; use_unique_parameters::Bool=false, parameter_names::Vector{String}=String[]) where {N}
    jl_params = _translate_parameters(op.parameters, parameter_names, Val(use_unique_parameters))
    return (jl_params, qubits, d, Val(pytype_to_symbol(op)))
end

_translate_observable(::Val{:PauliX})   = "x"
_translate_observable(::Val{:PauliY})   = "y"
_translate_observable(::Val{:PauliZ})   = "z"
_translate_observable(::Val{:Hadamard}) = "h"
_translate_observable(::Val{:Identity}) = "i"
_translate_observable(mat::Matrix{ComplexF64}, ::Val{:Hermitian}) = BraketStateVector.Braket.complex_matrix_to_ir(mat)

function _translate_observable(obs::Py)
    if pyisinstance(obs, pennylane.Hamiltonian)
        return [(_translate_observable(term), pyconvert(Vector{Int}, term.wires)) for term in obs.ops]
    elseif pyisinstance(obs, pennylane.operation.Tensor)
        raw_ops = reduce(vcat, [_translate_observable(term) for term in obs.obs])
        ops     = [op[1] for op in raw_ops]
        qubits  = reduce(vcat, [op[2] for op in raw_ops])
        return [(ops, qubits)]
    elseif pyisinstance(obs, pennylane.Hermitian)
        jl_mat = pyconvert(Matrix{ComplexF64}, pennylane.matrix(obs))
        return [(_translate_observable(jl_mat, Val(:Hermitian)), pyconvert(Vector{Int}, obs.wires))]
    else
        return [(_translate_observable(Val(pytype_to_symbol(obs))), pyconvert(Vector{Int}, obs.wires))]
    end
end

for (ir_typ, pl_mp, braket_symbol, braket_name) in ((:(BraketStateVector.Braket.IR.Expectation), Val{:ExpectationMP}, Val{:expectation}, "expectation"),
                                                    (:(BraketStateVector.Braket.IR.Variance), Val{:VarianceMP}, Val{:variance}, "variance"),
                                                    (:(BraketStateVector.Braket.IR.Sample), Val{:SampleMP}, Val{:sample}, "sample"),) 
    @eval begin
        _translate_result(obs, qubits, ::$braket_symbol) = $ir_typ(obs, qubits, $braket_name)
        _translate_result(op::Py, d::AbstractSimulator, ::$pl_mp) = [tuple(jl_obs..., $braket_symbol()) for jl_obs in _translate_observable(op.obs)]
    end
end

_translate_result(op::Py, d::AbstractSimulator) = _translate_result(op, d, Val(pytype_to_symbol(op)))
function _translate_parameter_names(n_params::Int, param_index::Int, trainable_indices::Set{Int}, use_unique_parameters::Bool, ::Val{false})
    n_params == 0 && return String[], param_index
    parameter_names = fill("", n_params)
    ix = 1
    for p in 1:n_params
        if param_index ∈ trainable_indices || use_unique_parameters
            parameter_names[ix] = "p_$param_index"
            ix += 1
        end
        param_index += 1
    end
    return parameter_names, param_index
end

function _translate_parameter_names(n_params::Int, param_index::Int, trainable_indices::Set{Int}, use_unique_parameters::Bool, ::Val{true})
    return fill("", n_params), param_index + n_params
end

function _translate_from_python(circuit::Tuple{PyList, PyList}, d::D, ::Val{:pennylane}) where {D<:AbstractSimulator}
    # circuit noise and gates
    use_unique_params  = false
    trainable_indices  = Set{Int}()
    param_index        = 1
    time_in_params     = 0.0
    time_in_ops        = 0.0
    time_in_rts        = 0.0
    py_instructions    = circuit[1]
    py_measurements    = circuit[2]
    translate_ops_args = Vector{Tuple}(undef, length(py_instructions))
    translate_rts_args = []
    use_unique_parameters = (isempty(trainable_indices) || use_unique_params)
    for (ix, op) in enumerate(py_instructions)
        start = time()
        n_params   = pyconvert(Int, op.num_params)
        is_channel = pyisinstance(op, pennylane.operation.Channel)
        parameter_names, param_index = _translate_parameter_names(n_params, param_index, trainable_indices, use_unique_params, Val(is_channel))
        stop = time()
        time_in_params += stop-start

        start = time()
        dev_wires = tuple((pyconvert(Int, wire) for wire in op.wires)...)
        translate_ops_args[ix] = translate_operation(op, dev_wires, d, use_unique_parameters=use_unique_parameters, parameter_names=parameter_names)
        stop = time()

        time_in_ops += stop-start
    end
    for (ix, op) in enumerate(py_measurements)
        start = time()
        rt    = _translate_result(op, d)
        append!(translate_rts_args, rt)
        stop  = time()
        time_in_rts += stop-start
    end
    #@info "\tTime to translate parameter names: $time_in_params"
    #@info "\tTime to translate operations: $time_in_ops"
    #@info "\tTime to translate result types: $time_in_rts"
    return (instructions_args=translate_ops_args, results_args=translate_rts_args) 
end

function _translate_from_python(circuit::Py, d::AbstractSimulator, ::Val{:braket})
    throw(MethodError("not implemented yet!"))
end

function _translate_from_python(circuit::Tuple{PyList, PyList}, d::AbstractSimulator)
    # first detect if circuit is Braket or PennyLane
    is_pennylane = true #pyisinstance(circuit, pennylane.tape.qscript.QuantumScript)
    is_pennylane && return _translate_from_python(circuit, d, Val(:pennylane))
    is_braket    = pyisinstance(circuit, braket.circuits.Circuit)
    is_braket    && return _translate_from_python(circuit, d, Val(:braket))
    throw(ArgumentError("Python circuit is of untranslateable type! Must be either a PennyLane QuantumTape or a Braket Circuit."))
end
