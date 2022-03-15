@enum QubitReferenceType VIRTUAL PHYSICAL
import Dates: format

abstract type SerializationProperties end
"""
    OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL)

Contains information about how to serialize qubits when outputting
to OpenQASM IR. The `qubit_reference_type` argument may be one of
`VIRTUAL` or `PHYSICAL`.
"""
Base.@kwdef struct OpenQASMSerializationProperties <: SerializationProperties
    qubit_reference_type::QubitReferenceType=VIRTUAL
end

format(target::Int, sps::OpenQASMSerializationProperties) = sps.qubit_reference_type == VIRTUAL ? "q[$target]" : "\$$target"
format(target::Qubit, sps::OpenQASMSerializationProperties) = sps.qubit_reference_type == VIRTUAL ? "q[$target]" : "\$$target"
format_qubits(qubits, sps::OpenQASMSerializationProperties) = chop(prod(map(q->format(q, sps), vcat(qubits...)) .* ", "), tail=2)
function format_complex(n::Number)
    iszero(real(n)) && iszero(imag(n)) && return 0
    isreal(n) && return real(n)
    iszero(real(n)) && return """$(imag(n))im"""
    return n
end

function format_matrix(m::Matrix{<:ComplexF64})
    m_strs = format_complex.(m)
    arr_strs = ["[" * join(map(n->n isa String ? n : repr(n), m_strs[:, i]), ", ") * "]" for i in 1:size(m_strs, 2)]
    return "["*join(arr_strs, ", ")*"]"
end