
function _check_annotations(node::OpenQASM3.Statement)
    if length(node.annotations) > 0
        @warn "Unsupported annotations $(node.annotations) at $(node.span)."
    end
    return nothing
end
_check_annotations(node) = nothing

struct WalkerOutput
    ixs::Vector{Instruction}
    results::Vector{Braket.Result}
    WalkerOutput() = new(Instruction[], Braket.AbstractProgramResult[])
end

abstract type AbstractQASMContext end

const ExternDef = OpenQASM3.ExternDeclaration

# We use `ConstOnlyVis` to prevent subroutines and defcals seeing non-const global QASM variables
@enum OpenQASMGlobalVisibility DefaultVis ConstOnlyVis
@enum ClassicalVarKind ClassicalVar ClassicalConst ClassicalInput

mutable struct ClassicalDef{T, S}
    value::T
    valtype::S
    kind::ClassicalVarKind
end

mutable struct SubroutineDef{T, S, F, C}
    args::Vector{T}
    body_gen::F
    return_type::S
    ctx::C
end

struct QubitDef{T <: Union{Int, Nothing}}
    size::T
end
const QASMDefinition = Union{ClassicalDef, QubitDef, ExternDef, SubroutineDef}

Base.length(def::QubitDef) = def.size
Base.length(def::QASMDefinition) = length(def.value)

"""
    QASMGlobalContext{W}(;[ ext_lookup,])

The top-level context, which hold variables that live in the global QASM scope.
In addition to global variable definitions, this structure holds externally
defined input scalars, waveforms, and ports. These can be made accessible
to the OpenQASM program via `input` or `extern` statements.

Finally, there is a `visiblity` field that determines whether non-const
definitions should be hidden or visible. This is used to hide non-const global
variables when processing subroutines, which can only refer to
outer-scope variables if they are global constants.

See also [`QASMBlockContext`](@ref).
"""
mutable struct QASMGlobalContext{W, F} <: AbstractQASMContext
    definitions::Dict{String, QASMDefinition}
    qubit_mapping::Dict{Union{String, Tuple{String, Int}}, Union{Int, Vector{Int}}}
    n_qubits::Int
    ext_lookup::F
    visiblity::OpenQASMGlobalVisibility
    output::WalkerOutput
end

function QASMGlobalContext{W}(ext_lookup::F=nothing) where {W, F}
    ctx = QASMGlobalContext{W, F}(
        Dict{String, QASMDefinition}(),
        Dict{Union{String, Tuple{String, Int}}, Union{Int, Vector{Int}}}(),
        0,
        ext_lookup,
        DefaultVis,
        WalkerOutput()
    )
    return ctx
end

"""
    QASMBlockContext(parent)

Data for tracking variables in a local QASM block scope, such as inside
if-else or loop blocks.

See also [`QASMGlobalContext`](@ref).
"""
struct QASMBlockContext{P <: AbstractQASMContext} <: AbstractQASMContext
    parent::P
    qubit_mapping::Dict{Union{String, Tuple{String, Int}}, Union{Int, Vector{Int}}}
    definitions::Dict{String, QASMDefinition}
    function QASMBlockContext(parent::P) where {P <: AbstractQASMContext}
        ctx = new{P}(parent, parent.qubit_mapping, Dict{String, QASMDefinition}())
        return ctx
    end
end

"""
    QASMSubroutineContext(parent)

Data for tracking variables in a QASM subroutine scope.

See also [`QASMGlobalContext`](@ref).
"""
mutable struct QASMSubroutineContext{P <: AbstractQASMContext} <: AbstractQASMContext
    parent::P
    qubit_mapping::Dict{Union{String, Tuple{String, Int}}, Union{Int, Vector{Int}}}
    definitions::Dict{String, QASMDefinition}
    function QASMSubroutineContext(parent::P) where {P <: AbstractQASMContext}
        ctx = new{P}(parent, Dict{String, Int}(), Dict{String, QASMDefinition}())
        return ctx
    end
end

Base.push!(ctx::AbstractQASMContext, ix::Braket.Instruction) = push!(output(ctx).ixs, ix)
Base.push!(ctx::AbstractQASMContext, rt::Braket.Result)      = push!(output(ctx).results, rt)

output(ctx::QASMGlobalContext)     = ctx.output
output(ctx::AbstractQASMContext)   = output(parent(ctx))

Base.parent(ctx::AbstractQASMContext) = ctx.parent
Base.parent(::QASMGlobalContext)      = nothing

const NumberLiteral = Union{OpenQASM3.IntegerLiteral, OpenQASM3.FloatLiteral, OpenQASM3.BooleanLiteral, OpenQASM3.BitstringLiteral}

Base.convert(::Type{Int},     v::OpenQASM3.IntegerLiteral) = v.value
Base.convert(::Type{T},       v::OpenQASM3.IntegerLiteral) where {T<:Real} = convert(T, v.value)
Base.convert(::Type{Float64}, v::OpenQASM3.FloatLiteral) = Float64(v.value)
Base.convert(::Type{Float32}, v::OpenQASM3.FloatLiteral) = Float32(v.value)
Base.convert(::Type{Float16}, v::OpenQASM3.FloatLiteral) = Float16(v.value)

is_defined(name::String, ctx::AbstractQASMContext; local_only=false) = return haskey(ctx.definitions, name) || (!local_only && is_defined(name, parent(ctx)))
is_defined(name::String, ::Nothing; kwargs...) = false

function interpret!(output::WalkerOutput, node::T) where {T}
    @error "Unsupported instruction at $(node.span): $T"
    return nothing
end

_check_type(::Type{T}, val::T, name::String, span) where {T} = val
_check_type(::Type{T}, val::V, name::String, span) where {T, V} = error("Expected `$name` to be type $T but got $V, at $span.")

"""
    lookup_def(::Type, name, context::AbstractQASMContext; span)

Lookup a definition by recursing through the hierarchy of contexts. If an
identifier is not defined in the context for the current scope, try the parent.
"""
function lookup_def(::Type{T}, name::String, def::D, ctx::QASMGlobalContext; span=()) where {T, D<:QASMDefinition}
    ctx.visiblity == ConstOnlyVis && !_is_global_const(def) && error("Attempt to use non-const global `$name` in subroutine or defcal.")
    return _check_type(T, def, name, span)
end
lookup_def(::Type{T}, name::String, def::D, ctx::AbstractQASMContext; span=()) where {T, D<:QASMDefinition} = return _check_type(T, def, name, span)
lookup_def(::Type{T}, name::String, ctx::AbstractQASMContext; span=()) where {T} = lookup_def(T, name, get(ctx.definitions, name, nothing), ctx, span=span)
lookup_def(::Type{T}, name::String, def::Nothing, ctx::AbstractQASMContext; span=()) where {T} = lookup_def(T, name, parent(ctx); span=span)
lookup_def(::Type,    name::String, ::Nothing; span=()) = nothing

id(node::OpenQASM3.Identifier)            = node.name
id(node::OpenQASM3.QASMNode)              = id(node.name)
id(node::OpenQASM3.IndexExpression)       = id(node.collection)
id(node::OpenQASM3.IODeclaration)         = id(node.identifier)
id(node::OpenQASM3.ExternDeclaration)     = id(node.identifier)
id(node::OpenQASM3.ClassicalDeclaration)  = id(node.identifier)
id(node::OpenQASM3.ClassicalAssignment)   = id(node.lvalue)
id(node::OpenQASM3.QubitDeclaration)      = id(node.qubit)
id(node::OpenQASM3.ConstantDeclaration)   = id(node.identifier)
id(node::OpenQASM3.ForInLoop)             = id(node.identifier)
id(node::OpenQASM3.UnaryOperator)         = node.name
id(node::OpenQASM3.BinaryOperator)        = node.name
id(node::Tuple{String, <:Any})            = node[1]
id(node::String)                          = node

(ctx::AbstractQASMContext)(node::T) where {T<:NumberLiteral} = node.value
(ctx::AbstractQASMContext)(node::T) where {T<:Number} = node
_check_def_value(def::Nothing, name::String, span) = error("'$name' referenced in $span, but not defined.")
_check_def_value(def, name::String, span) = ismissing(def.value) ? error("Uninitialized variable `$name` used in $span.") : nothing

(ctx::AbstractQASMContext)(::Nothing) = nothing
function (ctx::AbstractQASMContext)(node::OpenQASM3.SizeOf)
    target = ctx(node.target)
    dim    = ctx(node.index)
    d      = isnothing(dim) ? 1 : dim
    return size(target, d)
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.Identifier)
    name = id(node)
    name == "pi"    || name == "π" && return π
    name == "euler" || name == "ℇ" && return ℯ 
    def  = lookup_def(ClassicalDef, name, ctx; span=node.span)
    _check_def_value(def, name, node.span)
    # TODO: Maybe return a wrapper to track OpenQASM types, const status, etc.
    return ctx(def.value)
end
(ctx::AbstractQASMContext)(node::OpenQASM3.ArrayLiteral) = map(ctx, node.values)
(ctx::AbstractQASMContext)(node::OpenQASM3.DiscreteSet)  = map(ctx, node.values)

function (ctx::AbstractQASMContext)(node::OpenQASM3.RangeDefinition)
    start = ctx(node.start)
    stop  = ctx(node.stop)
    stop < 0 && error("Range end $stop cannot be less than 0.") 
    step  = isnothing(node.step) ? 1 : ctx(node.step)
    return range(start, step=step, stop=stop)
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.RangeDefinition, len::Int)
    start = ctx(node.start)
    stop  = ctx(node.stop)
    stop < 0 && (stop = len + stop)
    step  = isnothing(node.step) ? 1 : ctx(node.step)
    return range(start, step=step, stop=stop)
end

function _get_indices(node::OpenQASM3.RangeDefinition, name::AbstractString, ctx::AbstractQASMContext)
    def = lookup_def(QASMDefinition, name, ctx)
    return ctx(node, length(def))
end
_get_indices(node::Vector{OpenQASM3.RangeDefinition}, name::AbstractString, ctx::AbstractQASMContext) = _get_indices(node[1], name, ctx)
_get_indices(node, name::AbstractString, ctx::AbstractQASMContext) = ctx(node)

function _lookup_name(node::OpenQASM3.IndexExpression, ctx::AbstractQASMContext)
    name    = id(node)
    indices = _get_indices(node.index, name, ctx)
    return (name, [index for index in indices])
end
_lookup_name(node, ctx) = id(node)

_generate_elements_from_obj(obj::QASMDefinition, name::String, inds) = obj.value[inds .+ 1]
_generate_elements_from_obj(obj::QubitDef, name::String, inds)       = [(name, inds)]
function (ctx::AbstractQASMContext)(node::OpenQASM3.IndexExpression)
    names    = _lookup_name(node, ctx)
    obj_name = names[1]
    mapped_pairs = map(names[2]) do obj_inds
        obj = lookup_def(QASMDefinition, obj_name, ctx; span=node.span)
        return _generate_elements_from_obj(obj, obj_name, obj_inds)
    end
    return collect(Iterators.flatten(mapped_pairs))
end

#=function (ctx::AbstractQASMContext)(node::OpenQASM3.ExpressionStatement)
    _check_annotations(node)
    ctx(node.expression)
    return
end=#

function (ctx::AbstractQASMContext)(node::OpenQASM3.BinaryExpression)
    left   = ctx(node.lhs)
    right  = ctx(node.rhs)
    opname = id(node.op)
    opname == "+" && return left + right
    opname == "*" && return left * right
    opname == "-" && return left - right
    opname == "/" && return left / right
    opname == "<" && return left < right
    opname == ">" && return left > right
    opname == "==" && return left == right
    opname == ">=" && return left >= right
    opname == "<=" && return left <= right
    return error("Binary op $(node.op) not yet implemented.")
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.UnaryExpression)
    operand = ctx(node.expression)
    opname = id(node.op)
    opname != "-" && error("Unary op $(node.op) not yet implemented.")
    return -operand
end
(ctx::AbstractQASMContext)(nodes::Vector{T}) where {T} = map(ctx, nodes)

# FIXME: These do not enforce widths yet.
scalar_matches_type(::Type{OpenQASM3.FloatType}, val::T, err_str::String) where {T<:Real}      = return
scalar_matches_type(::Type{OpenQASM3.ComplexType}, val::T, err_str::String) where {T<:Complex} = return
scalar_matches_type(::Type{OpenQASM3.IntType}, val::T, err_str::String) where {T<:Integer}     = return
scalar_matches_type(::Type{OpenQASM3.BitType}, val::T, err_str::String) where {T<:Integer}     = return
scalar_matches_type(::Type{OpenQASM3.BoolType}, val::Bool, err_str::String)                    = return
scalar_matches_type(::Type{OpenQASM3.UintType}, val::T, err_str::String) where {T<:Unsigned}   = return
# FIXME: OpenQASM3.jl should not be putting unsigned ints into Ints.
scalar_matches_type(::Type{O}, val::T, err_str::String) where {O<:OpenQASM3.UintType,T<:Integer}    = (val >= 0 && error(err_str * " $T"); return)
scalar_matches_type(::Type{T}, val::V, err_str::String) where {T, V} = error(err_str * " $V, $T")
scalar_matches_type(t::T, val::V, err_str::String) where {T, V} = scalar_matches_type(T, val, err_str * " $V")

scalar_matches_type(t::OpenQASM3.ArrayType, val::Vector{V}, err_str::String) where {V} = foreach(v->scalar_matches_type(t.base_type, v, err_str), val)

# FIXME: should check actual size
scalar_matches_type(::Type{OpenQASM3.FloatType}, val::OpenQASM3.FloatLiteral, err_str::String) = return
scalar_matches_type(::Type{OpenQASM3.IntType}, val::OpenQASM3.IntegerLiteral, err_str::String) = return

scalar_cast(::Type{OpenQASM3.FloatType}, val) = real(1.0 * val)
scalar_cast(::Type{OpenQASM3.ComplexType}, val) = complex(val)
scalar_cast(::Type{OpenQASM3.IntType}, val) = Int(val)
scalar_cast(::Type{OpenQASM3.UintType}, val) = UInt(val)
scalar_cast(::Type{OpenQASM3.BoolType}, val) = Bool(val)

_new_inner_scope(ctx::AbstractQASMContext) = QASMBlockContext(ctx)
_new_subroutine_scope(ctx::AbstractQASMContext) = QASMSubroutineContext(ctx)

function get_pragma_arg(body::String)
    match_arg = match(r"\(([^\)]+)\)", body)
    stripped_body = replace(body, r"\(([^\)]+)\)"=>"")
    arg = isnothing(match_arg) ? nothing : match_arg.match 
    return stripped_body, arg
end
get_pragma_arg(body) = get_pragma_arg(String(body))
function (ctx::AbstractQASMContext)(::Val{:adjoint_gradient}, body::AbstractString)

end

function (ctx::AbstractQASMContext)(::Val{:amplitude}, body::AbstractString)
    chopped_body = replace(chopprefix(body, "amplitude "), "\""=>"")
    states       = split(chopped_body, " ")
    push!(ctx, Braket.Amplitude([String(replace(s, ","=>"")) for s in states]))
    return
end

function (ctx::AbstractQASMContext)(::Val{:state_vector}, body::AbstractString)
    push!(ctx, Braket.StateVector())
    return
end

function (ctx::AbstractQASMContext)(::Val{:density_matrix}, body::AbstractString)
    chopped_body = chopprefix(body, "density_matrix")
    targets = ctx(Val(:pragma), Val(:qubits), chopped_body)
    push!(ctx, Braket.DensityMatrix(targets))
    return
end

function (ctx::AbstractQASMContext)(::Val{:probability}, body::AbstractString)
    chopped_body = chopprefix(body, "probability ")
    targets = ctx(Val(:pragma), Val(:qubits), chopped_body)
    push!(ctx, Braket.Probability(targets))
    return
end

function parse_hermitian(arg)
    clean_arg = chop(arg, head=2, tail=2) # get rid of brackets on either side
    vecs      = split(replace(clean_arg, "["=>""), "],")
    h_mat     = Matrix{ComplexF64}(undef, length(vecs), length(vecs))
    for (i, v) in enumerate(vecs)
        for (j, elem) in enumerate(split(v, ","))
            h_mat[i,j] = tryparse(ComplexF64, elem)
        end
    end
    mat = Braket.Observables.HermitianObservable(h_mat)
    return mat
end

function parse_individual_op(op_str::AbstractString, ctx::AbstractQASMContext)
    head_chop = startswith(op_str, ' ') ? 1 : 0
    tail_chop = endswith(op_str, ' ') ? 1 : 0
    clean_op  = chop(op_str, head=head_chop, tail=tail_chop)
    stripped_op, arg = get_pragma_arg(clean_op)
    clean_arg        = isnothing(arg) ? nothing : replace(arg, "("=>"", ")"=>"")
    is_hermitian     = startswith(stripped_op, "hermitian")
    op = is_hermitian ? parse_hermitian(clean_arg) : Braket.StructTypes.constructfrom(Braket.Observables.Observable, string(stripped_op[1]))
    qubits = nothing
    if is_hermitian || !isnothing(arg)
        qubit_str = is_hermitian ? replace(stripped_op, "hermitian "=>"") : clean_arg
        qubits    = ctx(Val(:pragma), Val(:qubits), qubit_str)
    end
    return op, qubits
end

function (ctx::AbstractQASMContext)(::Val{:operator}, op_str::String)
    is_tensor_prod = occursin('@', op_str)
    if is_tensor_prod
        op = Braket.Observables.Observable[]
        qubits = Int[]
        for op_ in split(op_str, '@')
            this_op, this_qubits = parse_individual_op(op_, ctx)
            push!(op, this_op)
            append!(qubits, this_qubits)
        end
        return Braket.Observables.TensorProduct(op), qubits
    else
        return parse_individual_op(op_str, ctx)
    end
end

function (ctx::AbstractQASMContext)(::Val{:pragma}, ::Val{:qubits}, body::AbstractString)
    (body == "all" || isempty(body)) && return nothing
    has_brakets = occursin('[', body)
    if has_brakets # more complicated...
        qubits = Int[]
        segment_start = 1
        segment_end   = findnext(']', body, segment_start)
        while !isnothing(segment_end)
            raw_chunk = chopprefix(String(body[segment_start:segment_end]), ",")
            oq3_chunk = raw_chunk * ";\n"
            parsed_chunk = OpenQASM3.parse(oq3_chunk)
            for node in parsed_chunk.statements
                append!(qubits, [ctx.qubit_mapping[q] for q in ctx(node.expression)])
            end
            segment_start = segment_end + 1
            !isnothing(segment_start) && (segment_start += 1)
            segment_end = !isnothing(segment_start) && segment_start <= length(body) ? findnext(']', body, segment_start) : nothing
        end
    else
        qubits = map(split(body, ",")) do q_name
            clean_name = String(replace(q_name, " "=>""))
            return [ctx.qubit_mapping[q] for q in resolve_qubit(clean_name, ctx)]
        end
    end
    targets    = collect(Iterators.flatten(qubits))
    return targets
end

for (tag, type, type_str) in ((Val{:expectation}, :(Braket.Expectation), "expectation"), (Val{:variance}, :(Braket.Variance), "variance"), (Val{:sample}, :(Braket.Sample), "sample"))
    @eval begin
        function (ctx::AbstractQASMContext)(::$tag, body::AbstractString)
            chopped_body = String(chopprefix(body, $type_str * " "))
            op_str       = chopped_body
            op, targets  = ctx(Val(:operator), op_str)
            rt           = $type(op, targets)
            push!(output(ctx).results, rt)
            return
        end
    end
end

function (ctx::AbstractQASMContext)(::Val{:result}, body::String)
    chopped_body = chopprefix(body, "result ")
    result_type  = Val(Symbol(split(chopped_body, " ")[1]))
    ctx(result_type, chopped_body)
    return
end

function get_noise_arg(::Val{:kraus}, arg::AbstractString)
    stripped_arg = replace(arg, ")"=>"]", "("=>"[")
    raw_arg      = eval(Meta.parse(stripped_arg))
    noise_arg    = map(a->reduce(hcat, a), raw_arg)
    return noise_arg
end
function get_noise_arg(::Val{:noise}, arg::AbstractString)
    args = map(split(arg, ",")) do arg_str
        return tryparse(Float64, replace(arg_str, " "=>"", ")"=>"", "("=>""))
    end
    return args
end
function (ctx::AbstractQASMContext)(::Val{:noise}, body::String)
    stripped_body, arg = get_pragma_arg(String(chopprefix(body, "noise ")))
    split_body         = filter(!isempty, split(stripped_body, " "))
    raw_op             = split_body[1]
    rebuilt_qubits     = join(split_body[2:end], " ")
    targets            = ctx(Val(:pragma), Val(:qubits), rebuilt_qubits)
    noise_id           = Symbol(raw_op)
    noise_type         = Braket.StructTypes.subtypes(Noise)[noise_id]
    if raw_op == "kraus"
        noise_arg = get_noise_arg(Val(:kraus), arg)
        op        = Kraus(noise_arg)
    else
        args = get_noise_arg(Val(:noise), arg)
        op   = noise_type(args...)
    end
    push!(ctx, Instruction(op, targets))
    return
end

function (ctx::AbstractQASMContext)(::Val{:unitary}, body::String)
    stripped_body, arg = get_pragma_arg(String(chopprefix(body, "unitary ")))
    split_body         = filter(!isempty, split(stripped_body, " "))
    rebuilt_qubits     = join(split_body[2:end], " ")
    targets            = ctx(Val(:pragma), Val(:qubits), rebuilt_qubits)
    cleaned_arg        = replace(arg, "("=>"", ")"=>"")
    raw_arg            = eval(Meta.parse(cleaned_arg))
    gate_arg           = reduce(hcat, raw_arg)
    op                 = Unitary(gate_arg)
    push!(output(ctx).ixs, Instruction(op, targets))
    return
end

function (ctx::AbstractQASMContext)(::Val{:pragma}, cmd::String)
    !startswith(cmd, "braket ") && error("pragma `$cmd` must begin with `braket `")
    occursin("verbatim", cmd) && return
    pragma_body = String(chopprefix(cmd, "braket "))
    end_char    = if occursin(' ', pragma_body) && occursin('(', pragma_body)
                      min(findfirst(' ', pragma_body)-1, findfirst('(', pragma_body)-1)
                  elseif occursin(' ', pragma_body) && !occursin('(', pragma_body)
                      findfirst(' ', pragma_body)-1
                  elseif !occursin(' ', pragma_body) && occursin('(', pragma_body)
                      findfirst('(', pragma_body)-1
                  end
    pragma_type = pragma_body[1:end_char]
    op_type     = Val(Symbol(pragma_type))
    ctx(op_type, pragma_body)
    return
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.Box)
    foreach(ctx, node.body)
    return nothing
end
(ctx::AbstractQASMContext)(node::OpenQASM3.Pragma) = ctx(Val(:pragma), node.command)

# NOTE: `node.type` cannot be inferred. Could avoid runtime dispatch here
#       by branching on allowed types (i.e. manual dispatch).
(ctx::AbstractQASMContext)(node::OpenQASM3.ClassicalDeclaration) = ctx(node, node.type)
(ctx::AbstractQASMContext)(node::OpenQASM3.ConstantDeclaration) = ctx(node, node.type)

function _lookup_ext_scalar(name, ctx::QASMGlobalContext)
    val = ctx.ext_lookup[name]
    isnothing(val) || val isa Number || error("QASM program expects '$name' to be a scalar. Got '$val'.")
    return val
end
_lookup_ext_scalar(name, ctx::AbstractQASMContext) = _lookup_ext_scalar(name, parent(ctx))

function (ctx::AbstractQASMContext)(node::N, args...) where {N <: OpenQASM3.QASMNode}
    _check_annotations(node)
    name = id(node)
    _check_undefined(node, name, ctx)
    return ctx(node, name, args...)
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.IODeclaration, name::String)
    if node.io_identifier == OpenQASM3.IOKeyword.input
        if node.type isa OpenQASM3.ClassicalType
            val = _lookup_ext_scalar(name, ctx)
            isnothing(val) && error("Input variable $name was not supplied at $(node.span).")
            scalar_matches_type(node.type, val, "Input variable $name at $(node.span): type does not match ")
            ctx.definitions[name] = ClassicalDef(val, node.type, ClassicalInput)
            return nothing
        end
        error("Unsupported input type at $(node.span).")
    elseif node.io_identifier == OpenQASM3.IOKeyword.output
        error("Output not supported.")
    end
    error("IO type $(node.io_identifier) not supported at $(node.span).")
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.ExternDeclaration, name::String)
    ctx.definitions[name] = node
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.QuantumPhase)
    _check_annotations(node)
    resolved_qubits = [resolve_qubit(q, ctx) for q in node.qubits]
    gate_qubits     = _get_qubits_from_mapping(Iterators.flatten(resolved_qubits), ctx)
    gate_mods       = node.modifiers
    gate_arg        = convert(Float64, ctx(node.argument))
    braket_gate_type = MultiQubitPhaseShift{length(gate_qubits)}
    braket_gate      = braket_gate_type(gate_arg...)
    push!(ctx, Instruction(braket_gate, gate_qubits))
    return
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.QuantumGate)
    _check_annotations(node)
    gate_name        = id(node)
    resolved_qubits  = [resolve_qubit(q, ctx) for q in node.qubits]
    gate_mods        = node.modifiers
    gate_args        = (convert(Float64, a) for a in Iterators.map(ctx, node.arguments))
    braket_gate_type = Braket.StructTypes.subtypes(Braket.Gate)[Symbol(gate_name)]
    braket_gate      = braket_gate_type(gate_args...)
    if qubit_count(braket_gate) == 1
        gate_qubits = _get_qubits_from_mapping(Iterators.flatten(resolved_qubits), ctx)
        foreach(q->push!(ctx, Instruction(braket_gate, q)), gate_qubits)
    else
        length(resolved_qubits) == qubit_count(braket_gate) || error("Gate of type $braket_gate_type has qubit count $(qubit_count(braket_gate)) but $gate_qubits were provided.")
        # handle splatting
        if !all(length(qubits) == length(resolved_qubits[1]) for qubits in resolved_qubits)
            for r_ix in 1:length(resolved_qubits)
                if length(resolved_qubits[r_ix]) == 1
                    resolved_qubits[r_ix] = [resolved_qubits[r_ix][1] for _ in 1:maximum(length, resolved_qubits)]
                end
            end
        end
        for gate_qubits in zip(resolved_qubits...)
            qubits = _get_qubits_from_mapping(gate_qubits, ctx)
            push!(ctx, Instruction(braket_gate, qubits))
        end
    end
    return
end

function (ctx::QASMSubroutineContext)(node::QuantumArgument, name::String, ix::Int)
    n_qubits = isnothing(node.size) ? 1 : ctx(node.size)
    ctx.definitions[name]   = QubitDef(n_qubits)
    ctx.qubit_mapping[name] = n_qubits == 1 ? ix : collect(ix:ix+n_qubits-1)
    ix += n_qubits
    return ix
end

function (ctx::QASMSubroutineContext)(node::ClassicalArgument, name::String, ix::Int)
    ctx.definitions[name] = ClassicalDef(undef, node.type, ClassicalVar) 
    return ix
end

function _map_arguments_back(::Val{true}, arg_passed::IndexExpression, arg_defined::OpenQASM3.ClassicalArgument, fn_ctx)
    outer_id = id(arg_passed)
    inner_id = id(arg_defined)
    ctx       = parent(fn_ctx)
    outer_arg = ctx.definitions[outer_id]
    name, inds = _lookup_name(arg_passed, ctx)
    for (aix, ind) in enumerate(inds)
        ctx.definitions[name].value[ind+1] = fn_ctx.definitions[inner_id].value[aix]
    end
    return
end
function _map_arguments_back(::Val{true}, arg_passed::Identifier, arg_defined::OpenQASM3.ClassicalArgument, fn_ctx)
    outer_id = id(arg_passed)
    inner_id = id(arg_defined)
    ctx      = parent(fn_ctx)
    ctx.definitions[outer_id] = fn_ctx.definitions[inner_id]
    return
end
_map_arguments_back(::Val{false}, arg_passed, arg_defined::OpenQASM3.ClassicalArgument, fn_ctx) = return
function _map_arguments_back(arg_passed::T, arg_defined::OpenQASM3.ClassicalArgument, fn_ctx) where {T<:Union{OpenQASM3.Identifier, OpenQASM3.IndexExpression}}
    is_mutable = !(arg_defined.access == OpenQASM3.AccessControl.readonly)
    _map_arguments_back(Val(is_mutable), arg_passed, arg_defined, fn_ctx)
    return
end
_map_arguments_back(arg_passed, arg_defined, fn_ctx) = return

function _map_arguments_forward(arg_passed, arg_defined::OpenQASM3.ClassicalArgument, qubit_alias::Dict, fn_ctx)
    ctx       = parent(fn_ctx)
    arg_type  = arg_defined.type
    arg_const = arg_defined.access == OpenQASM3.AccessControl.readonly
    arg_value = ctx(arg_passed)
    fn_ctx.definitions[id(arg_defined)] = ClassicalDef(arg_value, arg_type, ClassicalVar)
    return
end

_get_alias_value(arg_val::String) = arg_val[1]
_get_alias_value(arg_val::Tuple{String,Vector{Int}}) = (arg_val[1], arg_val[2][1])
function _map_arguments_forward(arg_passed, arg_defined::OpenQASM3.QuantumArgument, qubit_alias::Dict, fn_ctx)
    ctx       = parent(fn_ctx)
    arg_name  = id(arg_defined)
    arg_val   = _lookup_name(arg_passed, ctx)
    qubit_alias[arg_name] = _get_alias_value(arg_val)
    return
end

_to_literal(x::Int)  = OpenQASM3.IntegerLiteral(x)
_to_literal(x::Real) = OpenQASM3.FloatLiteral(Float64(x))
function (ctx::AbstractQASMContext)(node::OpenQASM3.FunctionCall)
    fn_name = id(node)
    if haskey(builtin_functions, fn_name)
        f = builtin_functions[fn_name]
        # wrap in OQ3 type
        args = map(_to_literal ∘ ctx, node.arguments)
        return f(args...)
    end
    fn_def  = lookup_def(SubroutineDef, fn_name, ctx; span=node.span)
    fn_ctx  = fn_def.ctx
    isnothing(fn_def) && error("Subroutine $fn_name not found!")
    qubit_alias = Dict()
    foreach(arg_pair->_map_arguments_forward(arg_pair[1], arg_pair[2], qubit_alias, fn_ctx), zip(node.arguments, fn_def.args))
    old_mapping           = deepcopy(fn_ctx.qubit_mapping)
    new_mapping           = Dict(kq=>ctx.qubit_mapping[qubit_alias[kq]] for (kq, vq) in fn_ctx.qubit_mapping)
    fn_ctx.qubit_mapping  = new_mapping
    rv, out               = fn_def.body_gen()
    fn_ctx.qubit_mapping  = old_mapping
    # map arguments back to outer context
    foreach(arg_pair->_map_arguments_back(arg_pair[1], arg_pair[2], fn_ctx), zip(node.arguments, fn_def.args))
    return rv
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.SubroutineDefinition{S}) where {S}
    _check_annotations(node)
    subroutine_name = id(node)
    subroutine_body = node.body
    subroutine_args = node.arguments
    block_ctx       = _new_subroutine_scope(ctx)
    ix = 0
    for arg in subroutine_args 
        ix = block_ctx(arg, ix)
    end
    function subroutine_body_builder()
        return_value    = nothing
        for statement in subroutine_body
            block_ctx(statement)
            if statement isa ReturnStatement
                return_value = block_ctx(statement.expression)
                break
            end
        end
        return return_value, output(block_ctx)
    end
    ctx.definitions[subroutine_name] = SubroutineDef(node.arguments, subroutine_body_builder, node.return_type, block_ctx)
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.ForInLoop)
    _check_annotations(node)
    loopvar_name  = id(node)
    loop_set      = ctx(node.set_declaration)
    block_ctx     = _new_inner_scope(ctx)
    for i in loop_set
        scalar_matches_type(node.type, i, "Loop variable type error: $i is not a ")
        block_ctx.definitions[loopvar_name] = ClassicalDef(i, node.type, ClassicalVar)
        for subnode in node.block
            maybe_break_or_continue = block_ctx(subnode)
            if maybe_break_or_continue isa OpenQASM3.BreakStatement
                return nothing
            elseif maybe_break_or_continue isa OpenQASM3.ContinueStatement
                break
            end
        end
    end
    # update variables in the parent defs
    for k in intersect(keys(ctx.definitions), keys(block_ctx.definitions))
        ctx.definitions[k] = block_ctx.definitions[k]
    end
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.WhileLoop)
    _check_annotations(node)
    block_ctx = _new_inner_scope(ctx)
    while ctx(node.while_condition)
        for subnode in node.block
            maybe_break_or_continue = block_ctx(subnode)
            if maybe_break_or_continue isa OpenQASM3.BreakStatement
                return nothing
            elseif maybe_break_or_continue isa OpenQASM3.ContinueStatement
                break
            end
        end
    end
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.BranchingStatement)
    _check_annotations(node)
    block_ctx = _new_inner_scope(ctx)
    if ctx(node.condition)
        for subnode in node.if_block
            res = block_ctx(subnode)
            isbreakorcontinue(res) && return res
        end
    elseif !isnothing(node.else_block)
        for subnode in node.else_block
            res = block_ctx(subnode)
            isbreakorcontinue(res) && return res
        end
    end
    return nothing
end

function _check_undefined(node, name, ctx; local_only=true)
    is_defined(name, ctx; local_only) && error("Identifier $name already in use at $(node.span).")
    return nothing
end
_check_undefined(node::ClassicalAssignment, name, ctx; local_only=true) = return
_check_undefined(node::ClassicalDeclaration, name, ctx; local_only=true) = return

isbreakorcontinue(node::OpenQASM3.BreakStatement) = true
isbreakorcontinue(node::OpenQASM3.ContinueStatement) = true
isbreakorcontinue(node) = false

_is_hardware_qubit(qname::AbstractString) = !isnothing(match(r"\$[0-9]+", qname))
_is_hardware_qubit(qname::OpenQASM3.Identifier) = _is_hardware_qubit(id(qname))
_is_hardware_qubit(qname) = false
resolve_qubit(q::Tuple{String, Int}, q_name::String, def::QubitDef, ctx::AbstractQASMContext)   = [q]
resolve_qubit(q::String, q_name::String, def::QubitDef, ctx::AbstractQASMContext)               = length(def) == 1 ? [q] : [(q, ix) for ix in 0:def.size-1]
resolve_qubit(q::OpenQASM3.Identifier, q_name::String, def::QubitDef, ctx::AbstractQASMContext) = resolve_qubit(q_name, q_name, def, ctx) 
resolve_qubit(q::Tuple{String, T}, q_name::String, def::QubitDef, ctx::AbstractQASMContext) where {T} = [(q_name, ix) for ix in q[2]]
function resolve_qubit(node::OpenQASM3.IndexedIdentifier, q_name::String, def::QubitDef, ctx::AbstractQASMContext)
    ix  = map(ctx, node.indices)[1]
    ixs = ix isa Int ? [ix] : ix
    return resolve_qubit((q_name, ixs), q_name, def, ctx) 
end
function resolve_qubit(q, ctx::AbstractQASMContext, span=())
    _is_hardware_qubit(q) && return [id(q)]
    q_name = id(q)
    def = lookup_def(QubitDef, q_name, ctx; span=span)
    isnothing(def) && error("Qubit $q_name not defined at $span.")
    return resolve_qubit(q, q_name, def, ctx) 
end

_get_qubits_from_mapping(q, ctx::AbstractQASMContext) = map(q) do qubit
    _is_hardware_qubit(qubit) ? tryparse(Int, replace(qubit, "\$"=>"")) : ctx.qubit_mapping[qubit]
end

# does nothing for now
function (ctx::AbstractQASMContext)(node::Union{OpenQASM3.QuantumMeasurement, OpenQASM3.QuantumMeasurementStatement})
    _check_annotations(node)
    return nothing
end

function (ctx::QASMSubroutineContext)(node::Union{OpenQASM3.ReturnStatement, OpenQASM3.ExpressionStatement})
    _check_annotations(node)
    return ctx(node.expression)
end

_process_init_expression(::Nothing, type::OpenQASM3.ClassicalType, name::String, ctx::AbstractQASMContext) = missing
function _process_init_expression(expr::OpenQASM3.Expression, type::OpenQASM3.ClassicalType, name::String, ctx::AbstractQASMContext)
    val = ctx(expr)
    scalar_matches_type(type, val, "In expression for `$name`, value `$val` does not match declared type:")
    return val
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.ClassicalDeclaration, name::String, type::OpenQASM3.ClassicalType)
    val  = _process_init_expression(node.init_expression, type, name, ctx)
    ctx.definitions[name] = ClassicalDef(val, type, ClassicalVar)
    return nothing
end

function (ctx::AbstractQASMContext)(node::OpenQASM3.ConstantDeclaration, name::String, type::OpenQASM3.ClassicalType)
    val  = _process_init_expression(node.init_expression, type, name, ctx)
    ctx.definitions[name] = ClassicalDef(val, type, ClassicalConst)
    return nothing
end

_check_lval(lv::OpenQASM3.Identifier)        = return
_check_lval(lv::OpenQASM3.IndexedIdentifier) = return
_check_lval(lv::T) where {T} = error("Assignment not implemented for $T.")
_check_node_op(op::OpenQASM3.AssignmentOperator) = return
_check_node_op(op) = error("Unknown op $op in assigment.")
function _check_node_op_name(op::String)
    op ∉ ["=", "+=", "-=", "*=", "/="] && error("Assigment operation $(node.op.name), not currently supported.")
    return
end

function _assign_lvalue(lvalue::Identifier, r_val::Number, d_value::Number, op::String, ctx::AbstractQASMContext)
    op == "="  && return r_val
    op == "+=" && return d_value + r_val
    op == "-=" && return d_value - r_val
    op == "*=" && return d_value * r_val
    op == "/=" && return d_value / r_val
end
_assign_lvalue(lvalue::Identifier, r_val::Vector, d_value::Number, op::String, ctx::AbstractQASMContext) = _assign_lvalue(lvalue, r_val[1], d_value, op, ctx)
function _assign_lvalue(lvalue::IndexedIdentifier, r_val::Vector, d_value::Vector, op::String, ctx::AbstractQASMContext)
    l_inds = mapreduce(ctx, vcat, lvalue.indices) .+ 1
    for (ii, l_ind) in enumerate(l_inds)
        d_value[l_ind] = _assign_lvalue(lvalue.name, r_val[ii], d_value[l_ind], op, ctx)
    end
    return d_value
end
_assign_lvalue(lvalue::IndexedIdentifier, r_val::Number, d_value::Vector, op::String, ctx::AbstractQASMContext) = _assign_lvalue(lvalue, fill(r_val, length(d_value)), d_value, op, ctx)
_assign_lvalue(lvalue, r_val, d_value::Missing, op::String, ctx::AbstractQASMContext) = r_val

function (ctx::AbstractQASMContext)(node::OpenQASM3.ClassicalAssignment, name::String)
    _check_lval(node.lvalue) 
    _check_node_op(node.op)
    def  = lookup_def(ClassicalDef, name, ctx; span=node.span)
    def.kind == ClassicalVar || error("Variable `$name` cannot be assigned to.")
    rval = ctx(node.rvalue)
    val  = _assign_lvalue(node.lvalue, rval, def.value, node.op.name, ctx)
    ctx.definitions[name] = ClassicalDef(val, def.valtype, def.kind)
    return
end

function (ctx::QASMGlobalContext)(node::OpenQASM3.QubitDeclaration, qname::String)
    num_qubits               = isnothing(node.size) ? 1 : node.size.value
    ctx.definitions[qname]   = QubitDef(num_qubits)
    ctx.qubit_mapping[qname] = num_qubits == 1 ? ctx.n_qubits : collect(ctx.n_qubits:(ctx.n_qubits + num_qubits - 1))
    if num_qubits > 1
        for q_ix in 0:num_qubits - 1
            ctx.qubit_mapping[(qname, q_ix)] = ctx.n_qubits + q_ix
        end
    end
    ctx.n_qubits += num_qubits
    return nothing
end

function (ctx::QASMGlobalContext)(node::OpenQASM3.Program)
    for s in node.statements
        res = ctx(s)
        isbreakorcontinue(res) && ctx(res)
    end
end


function Base.collect(ctx::QASMGlobalContext)
    c = Circuit()
    wo = output(ctx)
    for ix in wo.ixs
        Braket.add_instruction!(c, ix)
    end
    for rt in wo.results
        Braket.add_result_type!(c, rt)
    end
    return c
end
function interpret(program::OpenQASM3.Program; extern_lookup=Dict{String,Float64}())
    global_ctx = QASMGlobalContext{Braket.Operator}(extern_lookup)
    # walk the nodes recursively
    global_ctx(program)
    c = collect(global_ctx)
    return c
end
