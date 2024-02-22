function _check_annotations(node)
    if length(node.annotations) > 0
        @warn "Unsupported annotations $(node.annotations) at $(node.span)."
    end
    return nothing
end

abstract type AbstractExtLookup end
struct LookupScalar <: AbstractExtLookup end

struct WalkerOutput
    ixs::Vector{Instruction}
    results::Vector{Braket.Result}
    WalkerOutput() = new(Instruction[], Braket.AbstractProgramResult[])
end

abstract type AbstractQASMContext end

# We use `ConstOnlyVis` to prevent subroutines and defcals seeing non-const global QASM variables
@enum OpenQASMGlobalVisibility DefaultVis ConstOnlyVis

const ExternDef = OpenQASM3.ExternDeclaration

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
end

function QASMGlobalContext{W}(ext_lookup::F=nothing) where {W, F}
    ctx = QASMGlobalContext{W, F}(
        Dict{String, QASMDefinition}(),
        Dict{Union{String, Tuple{String, Int}}, Union{Int, Vector{Int}}}(),
        0,
        ext_lookup,
        DefaultVis,
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

Base.parent(ctx::AbstractQASMContext) = ctx.parent
Base.parent(::QASMGlobalContext)      = nothing

function is_defined(name::String, ctx::AbstractQASMContext; local_only=false)
    return haskey(ctx.definitions, name) || (!local_only && is_defined(name, parent(ctx)))
end
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

const NumberLiteral = Union{OpenQASM3.IntegerLiteral, OpenQASM3.FloatLiteral, OpenQASM3.BooleanLiteral, OpenQASM3.BitstringLiteral}
evaluate_classical_expression(node::T, _) where {T<:NumberLiteral} = node.value
evaluate_classical_expression(node::T, _) where {T<:Number} = node
_check_def_value(def::Nothing, name::String, span) = error("'$name' referenced in $span, but not defined.")
_check_def_value(def, name::String, span) = ismissing(def.value) ? error("Uninitialized variable `$name` used in $span.") : nothing

evaluate_classical_expression(::Nothing, ctx::AbstractQASMContext) = nothing
function evaluate_classical_expression(node::OpenQASM3.SizeOf, ctx::AbstractQASMContext)
    target = evaluate_classical_expression(node.target, ctx)
    dim    = evaluate_classical_expression(node.index, ctx)
    d      = isnothing(dim) ? 1 : dim
    return size(target, d) 
end

evaluate_classical_expression(node::OpenQASM3.ArrayLiteral, ctx::AbstractQASMContext) = [evaluate_classical_expression(exp, ctx) for exp in node.values]
function evaluate_classical_expression(node::OpenQASM3.Identifier, ctx::AbstractQASMContext)
    name = node.name
    name == "pi"    || name == "π" && return π
    name == "euler" || name == "ℇ" && return ℯ 
    def  = lookup_def(ClassicalDef, name, ctx; span=node.span)
    _check_def_value(def, name, node.span)
    # TODO: Maybe return a wrapper to track OpenQASM types, const status, etc.
    return evaluate_classical_expression(def.value, ctx)
end
evaluate_classical_expression(node::OpenQASM3.DiscreteSet, ctx::AbstractQASMContext) = [evaluate_classical_expression(n, ctx) for n in node.values]

function evaluate_classical_expression(
    node::OpenQASM3.RangeDefinition,
    ctx::AbstractQASMContext,
)
    start = evaluate_classical_expression(node.start, ctx)
    stop  = evaluate_classical_expression(node.stop, ctx)
    stop < 0 && error("Range end $stop cannot be less than 0.") 
    step  = isnothing(node.step) ? 1 : evaluate_classical_expression(node.step, ctx)
    return range(start, step=step, stop=stop)
end

function evaluate_classical_expression(
    node::OpenQASM3.RangeDefinition,
    len::Int,
    ctx::AbstractQASMContext,
)
    start = evaluate_classical_expression(node.start, ctx)
    stop  = evaluate_classical_expression(node.stop, ctx)
    stop < 0 && (stop = len + stop)
    step  = isnothing(node.step) ? 1 : evaluate_classical_expression(node.step, ctx)
    return range(start, step=step, stop=stop)
end

function _lookup_name(node::OpenQASM3.IndexExpression, ctx::AbstractQASMContext)
    if node.index isa RangeDefinition
        def = lookup_def(QASMDefinition, node.collection.name, ctx)
        len = def isa QubitDef ? def.size : length(def.value)
        indices = evaluate_classical_expression(node.index, len, ctx)
    elseif node.index isa Vector{RangeDefinition}
        def = lookup_def(QASMDefinition, node.collection.name, ctx)
        len = def isa QubitDef ? def.size : length(def.value)
        indices = evaluate_classical_expression(node.index[1], len, ctx)
    else
        indices = evaluate_classical_expression(node.index, ctx)
    end
    return [(node.collection.name, index) for index in indices]
end

_lookup_name(node, ctx) = node.name
function evaluate_classical_expression(node::OpenQASM3.IndexExpression, ctx::AbstractQASMContext)
    names = _lookup_name(node, ctx)
    return map(names) do name
        obj_name, obj_inds = name
        obj = lookup_def(QASMDefinition, obj_name, ctx; span=node.span)
        return obj.value[obj_inds .+ 1]
    end
end

function evaluate_classical_expression(node::OpenQASM3.BinaryExpression, ctx::AbstractQASMContext)
    left   = evaluate_classical_expression(node.lhs, ctx)
    right  = evaluate_classical_expression(node.rhs, ctx)
    opname = node.op.name
    return eval(Expr(:call, Symbol(opname), left, right))
end

function evaluate_classical_expression(
    node::OpenQASM3.UnaryExpression,
    ctx::AbstractQASMContext,
)
    operand = evaluate_classical_expression(node.expression, ctx)
    opname = node.op.name
    opname != "-" && error("Unary op $(node.op) not yet implemented.")
    return -operand
end

evaluate_classical_expression(nodes::Vector{T}, ctx::AbstractQASMContext) where {T} = [evaluate_classical_expression(node, ctx) for node in nodes]

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
function parse_result_pragma(::Val{:adjoint_gradient}, output::WalkerOutput, body, ctx::AbstractQASMContext)

end

function parse_result_pragma(::Val{:amplitude}, output::WalkerOutput, body, ctx::AbstractQASMContext)
    chopped_body = replace(chopprefix(body, "amplitude "), "\""=>"")
    states       = split(chopped_body, " ")
    push!(output.results, Braket.Amplitude([String(replace(s, ","=>"")) for s in states]))
    return
end

function parse_result_pragma(::Val{:state_vector}, output::WalkerOutput, body, ctx::AbstractQASMContext)
    push!(output.results, Braket.StateVector())
    return
end

function parse_result_pragma(::Val{:density_matrix}, output::WalkerOutput, body, ctx::AbstractQASMContext)
    chopped_body = chopprefix(body, "density_matrix")
    if chopped_body == "all" || isempty(chopped_body)
        push!(output.results, Braket.DensityMatrix())
    else
        targets = parse_pragma_qubits(output, chopped_body, ctx)
        push!(output.results, Braket.DensityMatrix(targets))
    end
    return
end

function parse_result_pragma(::Val{:probability}, output::WalkerOutput, body, ctx::AbstractQASMContext)
    chopped_body = chopprefix(body, "probability ")
    if chopped_body == "all" || isempty(chopped_body)
        push!(output.results, Braket.Probability())
    else
        targets = parse_pragma_qubits(output, String(chopped_body), ctx)
        push!(output.results, Braket.Probability(targets))
    end
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

function parse_hermitian_qubits(op_str::String, ctx::AbstractQASMContext)
    clean_op_str = replace(op_str, "hermitian "=>"")
    clean_op_str == "all" && return nothing
    return parse_pragma_qubits(WalkerOutput(), clean_op_str, ctx)
end

function parse_non_hermitian_qubits(qubit_str::String, ctx::AbstractQASMContext)
    isempty(qubit_str) && return nothing
    return parse_pragma_qubits(WalkerOutput(), qubit_str, ctx)
end

function parse_individual_op(op_str::AbstractString, ctx::AbstractQASMContext)
    head_chop = startswith(op_str, ' ') ? 1 : 0
    tail_chop = endswith(op_str, ' ') ? 1 : 0
    clean_op  = chop(op_str, head=head_chop, tail=tail_chop)
    stripped_op, arg = get_pragma_arg(clean_op)
    clean_arg        = isnothing(arg) ? nothing : replace(arg, "("=>"", ")"=>"")
    is_hermitian     = startswith(stripped_op, "hermitian")
    if !is_hermitian && isnothing(arg)
        op     = Braket.StructTypes.constructfrom(Braket.Observables.Observable, string(stripped_op[1]))
        qubits = nothing
        return op, qubits
    else
        op     = is_hermitian ? parse_hermitian(clean_arg) : Braket.StructTypes.constructfrom(Braket.Observables.Observable, string(stripped_op[1]))
        qubits = is_hermitian ? parse_hermitian_qubits(String(stripped_op), ctx) : parse_non_hermitian_qubits(clean_arg, ctx)
        return op, qubits
    end
end

function parse_op(op_str::String, ctx::AbstractQASMContext)
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

function parse_pragma_qubits(output::WalkerOutput, body::String, ctx::AbstractQASMContext)
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
                exp = node.expression
                if exp isa OpenQASM3.IndexExpression
                    r_qubits = [resolve_qubit(name, ctx) for name in _lookup_name(exp, ctx)]
                else
                    r_qubits = interpret!(output, exp, ctx)
                end
                append!(qubits, [ctx.qubit_mapping[q] for q in Iterators.flatten(r_qubits)])
            end
            segment_start = segment_end + 1
            !isnothing(segment_start) && (segment_start += 1)
            segment_end = !isnothing(segment_start) && segment_start <= length(body) ? findnext(']', body, segment_start) : nothing
        end
    else
        qubits = map(split(body, ",")) do q_name
            clean_name = String(replace(q_name, " "=>""))
            r_qubits   = resolve_qubit(clean_name, ctx)
            return [ctx.qubit_mapping[q] for q in r_qubits]
        end
    end
    targets    = collect(Iterators.flatten(qubits))
    return targets
end

for (tag, type, type_str) in ((Val{:expectation}, :(Braket.Expectation), "expectation"), (Val{:variance}, :(Braket.Variance), "variance"), (Val{:sample}, :(Braket.Sample), "sample"))
    @eval begin
        function parse_result_pragma(::$tag, output::WalkerOutput, body, ctx::AbstractQASMContext)
            chopped_body = String(chopprefix(body, $type_str * " "))
            op_str       = chopped_body
            op, targets  = parse_op(op_str, ctx)
            rt           = $type(op, targets)
            push!(output.results, rt)
            return
        end
    end
end

function parse_pragma(::Val{:result}, output::WalkerOutput, body::String, ctx::AbstractQASMContext)
    chopped_body = chopprefix(body, "result ")
    result_type  = Val(Symbol(split(chopped_body, " ")[1]))
    parse_result_pragma(result_type, output, chopped_body, ctx)
    return
end

function parse_pragma(::Val{:noise}, output::WalkerOutput, body::String, ctx::AbstractQASMContext)
    stripped_body, arg = get_pragma_arg(String(chopprefix(body, "noise ")))
    split_body         = filter(!isempty, split(stripped_body, " "))
    raw_op             = split_body[1]
    rebuilt_qubits     = join(split_body[2:end], " ")
    targets            = parse_pragma_qubits(output, rebuilt_qubits, ctx)  
    noise_id           = Symbol(raw_op)
    noise_type         = Braket.StructTypes.subtypes(Noise)[noise_id]
    if raw_op == "kraus"
        stripped_arg = replace(arg, ")"=>"]", "("=>"[")
        raw_arg      = eval(Meta.parse(stripped_arg))
        noise_arg = map(raw_arg) do a
            return reduce(hcat, a)
        end
        op        = Kraus(noise_arg)
        push!(output.ixs, Instruction(op, targets))
    else
        args = map(split(arg, ",")) do arg_str
            pretty_arg_str = replace(arg_str, " "=>"", ")"=>"", "("=>"")
            return tryparse(Float64, pretty_arg_str)
        end
        op = noise_type(args...)
        push!(output.ixs, Instruction(op, targets))
    end
    return
end

function parse_pragma(::Val{:unitary}, output::WalkerOutput, body::String, ctx::AbstractQASMContext)
    stripped_body, arg = get_pragma_arg(String(chopprefix(body, "unitary ")))
    split_body         = filter(!isempty, split(stripped_body, " "))
    rebuilt_qubits     = join(split_body[2:end], " ")
    targets            = parse_pragma_qubits(output, rebuilt_qubits, ctx)  
    cleaned_arg        = replace(arg, "("=>"", ")"=>"")
    raw_arg            = eval(Meta.parse(cleaned_arg))
    gate_arg           = reduce(hcat, raw_arg)
    op                 = Unitary(gate_arg)
    push!(output.ixs, Instruction(op, targets))
    return
end

function parse_pragma(output::WalkerOutput, cmd::String, ctx::AbstractQASMContext)
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
    parse_pragma(op_type, output, pragma_body, ctx)
    return
end

function interpret!(output::WalkerOutput, node::OpenQASM3.Box, ctx::AbstractQASMContext)
    for s in node.body
        interpret!(output, s, ctx)
    end
    return nothing
end

function interpret!(output::WalkerOutput, node::OpenQASM3.Pragma, ctx::AbstractQASMContext)
    parse_pragma(output, node.command, ctx)
    return nothing
end

# NOTE: `node.type` cannot be inferred. Could avoid runtime dispatch here
#       by branching on allowed types (i.e. manual dispatch).
interpret!(output::WalkerOutput, node::OpenQASM3.ClassicalDeclaration, ctx::AbstractQASMContext) = interpret!(output, node, node.type, ctx)
interpret!(output::WalkerOutput, node::OpenQASM3.ConstantDeclaration, ctx::AbstractQASMContext) = interpret!(output, node, node.type, ctx)

function _lookup_ext_scalar(name, ctx::QASMGlobalContext)
    val = ctx.ext_lookup[name]
    isnothing(val) || val isa Number || error("QASM program expects '$name' to be a scalar. Got '$val'.")
    return val
end
_lookup_ext_scalar(name, ctx::AbstractQASMContext) = _lookup_ext_scalar(name, parent(ctx))

function interpret!(output::WalkerOutput, node::OpenQASM3.IODeclaration, ctx::AbstractQASMContext)
    _check_annotations(node)
    if node.io_identifier == OpenQASM3.IOKeyword.input
        name = node.identifier.name
        _check_undefined(node, name, ctx)
        if node.type isa OpenQASM3.ClassicalType
            val = _lookup_ext_scalar(name, ctx)
            isnothing(val) && error("Input variable $name was not supplied at $(node.span).")
            scalar_matches_type(node.type, val, "Input variable $name at $(node.span): type does not match ")
            _check_undefined(node, name, ctx)
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

function interpret!(output::WalkerOutput, node::OpenQASM3.ExternDeclaration, ctx::AbstractQASMContext)
    _check_annotations(node)
    name = node.name.name
    _check_undefined(node, name, ctx)
    ctx.definitions[name] = node
    return nothing
end

function interpret!(output::WalkerOutput, node::OpenQASM3.ExpressionStatement, ctx::AbstractQASMContext)
    _check_annotations(node)
    return interpret!(output, node.expression, ctx)
end

function interpret!(output::WalkerOutput, node::OpenQASM3.QuantumPhase, ctx::AbstractQASMContext)
    _check_annotations(node)
    resolved_qubits = [resolve_qubit(q, ctx) for q in node.qubits]
    gate_qubits     = _get_qubits_from_mapping(collect(Iterators.flatten(resolved_qubits)), ctx)
    gate_mods       = node.modifiers
    gate_arg = if node.argument isa OpenQASM3.FunctionCall
            interpret!(output, node.argument, ctx)
        else
            evaluate_classical_expression(node.argument, ctx)
    end
    braket_gate_type = MultiQubitPhaseShift{length(gate_qubits)}
    braket_gate      = braket_gate_type(gate_arg...)
    push!(output.ixs, Instruction(braket_gate, gate_qubits))
    return
end

function interpret!(output::WalkerOutput, node::OpenQASM3.QuantumGate, ctx::AbstractQASMContext)
    _check_annotations(node)
    gate_name        = node.name.name
    resolved_qubits  = [resolve_qubit(q, ctx) for q in node.qubits]
    gate_mods        = node.modifiers
    gate_args        = map(node.arguments) do a
        if a isa OpenQASM3.FunctionCall
            return interpret!(output, a, ctx)
        else
            return evaluate_classical_expression(a, ctx)
        end
    end
    braket_gate_type = Braket.StructTypes.subtypes(Braket.Gate)[Symbol(gate_name)]
    braket_gate      = braket_gate_type(gate_args...)
    if qubit_count(braket_gate) == 1
        gate_qubits = _get_qubits_from_mapping(Iterators.flatten(resolved_qubits), ctx)
        for q in gate_qubits
            push!(output.ixs, Instruction(braket_gate, q))
        end
    else
        length(resolved_qubits) == qubit_count(braket_gate) || error("Gate of type $braket_gate_type has qubit count $(qubit_count(braket_gate)) but $gate_qubits were provided. Node qubits: $(node.qubits), resolved_qubits: $resolved_qubits, context keys: $(collect(keys(ctx.definitions)))")
        if !all(length(qubits) == length(resolved_qubits[1]) for qubits in resolved_qubits)
            for r_ix in 1:length(resolved_qubits)
                if length(resolved_qubits[r_ix]) == 1
                    resolved_qubits[r_ix] = [resolved_qubits[r_ix][1] for _ in 1:maximum(length, resolved_qubits)]
                end
            end
        end
        for gate_qubits in zip(resolved_qubits...)
            qubits = _get_qubits_from_mapping(gate_qubits, ctx)
            push!(output.ixs, Instruction(braket_gate, qubits))
        end
    end
    return
end

function interpret!(node::QuantumArgument, ix::Int, ctx::QASMSubroutineContext)
    name = node.name.name
    _check_undefined(node, name, ctx)
    n_qubits = isnothing(node.size) ? 1 : evaluate_classical_expression(node.size, ctx)
    ctx.definitions[name]   = QubitDef(n_qubits)
    ctx.qubit_mapping[name] = n_qubits == 1 ? ix : collect(ix:ix+n_qubits-1)
    ix += n_qubits
    return ix
end

function interpret!(node::ClassicalArgument, ix::Int, ctx::QASMSubroutineContext)
    name = node.name.name
    _check_undefined(node, name, ctx)
    ctx.definitions[name] = ClassicalDef(undef, node.type, ClassicalVar) 
    return ix
end

function interpret!(output::WalkerOutput, node::OpenQASM3.FunctionCall, ctx::AbstractQASMContext)
    fn_name = node.name.name
    if haskey(builtin_functions, fn_name)
        f = builtin_functions[fn_name]
        args = [evaluate_classical_expression(arg, ctx) for arg in node.arguments]
        return f(args...)
    end
    fn_def  = lookup_def(SubroutineDef, fn_name, ctx; span=node.span)
    fn_ctx  = fn_def.ctx
    isnothing(fn_def) && error("Subroutine $fn_name not found!")
    qubit_alias = Dict()
    for (arg_passed, arg_defined) in zip(node.arguments, fn_def.args)
        if arg_defined isa OpenQASM3.ClassicalArgument
            arg_name  = arg_defined.name.name
            arg_type  = arg_defined.type
            arg_const = arg_defined.access == OpenQASM3.AccessControl.readonly 
            arg_value = evaluate_classical_expression(arg_passed, ctx)
            fn_ctx.definitions[arg_name] = ClassicalDef(arg_value, arg_type, ClassicalVar)
        else  # QuantumArgument
            qubit_name = arg_defined.name.name
            arg_val    = _lookup_name(arg_passed, ctx)
            qubit_alias[qubit_name] = arg_val[1]
        end
    end
    old_mapping = deepcopy(fn_ctx.qubit_mapping)
    new_mapping = Dict{String, Int}(kq=>ctx.qubit_mapping[qubit_alias[kq]] for (kq, vq) in fn_ctx.qubit_mapping)
    fn_ctx.qubit_mapping  = new_mapping
    rv, subroutine_walker = fn_def.body_gen()
    subroutine_ixs        = subroutine_walker.ixs
    subroutine_rts        = subroutine_walker.results
    fn_ctx.qubit_mapping  = old_mapping
    append!(output.ixs, subroutine_ixs)
    append!(output.results, subroutine_rts)
    for (arg_passed, arg_defined) in zip(node.arguments, fn_def.args)
        if arg_defined isa OpenQASM3.ClassicalArgument && !(arg_defined.access == OpenQASM3.AccessControl.readonly)
            if arg_passed isa IndexExpression
                names = _lookup_name(arg_passed, ctx)
                aix   = 1
                for (n, ix) in names
                    for ind in ix
                        ctx.definitions[n].value[ind+1] = fn_ctx.definitions[arg_defined.name.name].value[aix]
                        aix += 1
                    end
                end
            elseif arg_passed isa Identifier
                passed_arg_name  = arg_passed.name
                defined_arg_name = arg_defined.name.name
                new_def = fn_ctx.definitions[defined_arg_name]
                ctx.definitions[passed_arg_name] = new_def
            end
        end
    end
    return rv
end

function interpret!(output::WalkerOutput, node::OpenQASM3.SubroutineDefinition{S}, ctx::T) where {T<:AbstractQASMContext, S}
    _check_annotations(node)
    subroutine_name = node.name.name
    subroutine_body = node.body
    subroutine_args = node.arguments
    block_ctx       = _new_subroutine_scope(ctx)
    ix = 0
    for arg in subroutine_args 
        ix = interpret!(arg, ix, block_ctx)
    end
    function subroutine_body_builder()
        block_output    = WalkerOutput()
        return_value    = nothing
        for statement in subroutine_body
            interpret!(block_output, statement, block_ctx)
            if statement isa ReturnStatement
                return_value = evaluate_classical_expression(statement.expression, block_ctx)
                break
            end
        end
        return return_value, block_output
    end
    ctx.definitions[subroutine_name] = SubroutineDef(node.arguments, subroutine_body_builder, node.return_type, block_ctx)
    return nothing
end

function interpret!(output::WalkerOutput, node::OpenQASM3.ForInLoop, ctx::T) where {T<:AbstractQASMContext}
    _check_annotations(node)
    loop_set      = evaluate_classical_expression(node.set_declaration, ctx)
    loopvar_name  = node.identifier.name
    block_ctx     = _new_inner_scope(ctx)
    for i in loop_set
        scalar_matches_type(node.type, i, "Loop variable type error: $i is not a ")
        block_ctx.definitions[loopvar_name] = ClassicalDef(i, node.type, ClassicalVar)
        for subnode in node.block
            maybe_break_or_continue = interpret!(output, subnode, block_ctx)
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

function interpret!(output::WalkerOutput, node::OpenQASM3.WhileLoop, ctx::AbstractQASMContext)
    _check_annotations(node)
    block_ctx = _new_inner_scope(ctx)
    while evaluate_classical_expression(node.while_condition, ctx)
        for subnode in node.block
            maybe_break_or_continue = interpret!(output, subnode, block_ctx)
            if maybe_break_or_continue isa OpenQASM3.BreakStatement
                return nothing
            elseif maybe_break_or_continue isa OpenQASM3.ContinueStatement
                break
            end
        end
    end
    return nothing
end

function interpret!(output::WalkerOutput, node::OpenQASM3.BranchingStatement, ctx::AbstractQASMContext)
    _check_annotations(node)
    cond = evaluate_classical_expression(node.condition, ctx)
    block_ctx = _new_inner_scope(ctx)
    if cond
        for subnode in node.if_block
            res = interpret!(output, subnode, block_ctx)
            isbreakorcontinue(res) && return res
        end
    elseif !isnothing(node.else_block)
        for subnode in node.else_block
            res = interpret!(output, subnode, block_ctx)
            isbreakorcontinue(res) && return res
        end
    end
    return nothing
end

function _check_undefined(node, name, ctx; local_only=true)
    is_defined(name, ctx; local_only) && error("Identifier $name already in use at $(node.span).")
    return nothing
end

isbreakorcontinue(node::OpenQASM3.BreakStatement) = true
isbreakorcontinue(node::OpenQASM3.ContinueStatement) = true
isbreakorcontinue(node) = false

_is_hardware_qubit(qname::AbstractString) = !isnothing(match(r"\$[0-9]+", qname))
_is_hardware_qubit(qname) = false
function resolve_qubit(node::OpenQASM3.IndexedIdentifier, ctx::AbstractQASMContext)
    q_name  = node.name.name
    _is_hardware_qubit(q_name) && return [q_name]
    raw_ix = [evaluate_classical_expression(nix, ctx) for nix in node.indices]
    ix = if length(raw_ix) == 1 && length(raw_ix[1]) == 1
        raw_ix[1][1]
    elseif length(raw_ix) == 1 && length(raw_ix[1]) != 1
        raw_ix[1]
    else 
        raw_ix
    end
    def = lookup_def(QubitDef, q_name, ctx; span=node.span)
    isnothing(def) && error("Qubit $q not defined at $(node.span).")
    ixs = ix isa Int ? [ix] : ix
    return [(q_name, q_ix) for q_ix in ixs]
end
function resolve_qubit(q::String, ctx::AbstractQASMContext, span=())
    _is_hardware_qubit(q) && return [q]
    def = lookup_def(QubitDef, q, ctx; span=span)
    isnothing(def) && error("Qubit $q not defined.")
    return def.size == 1 ? [q] : [(q, ix) for ix in 0:def.size-1]
end
function resolve_qubit(q::Tuple{String, Int}, ctx::AbstractQASMContext, span=())
    def = lookup_def(QubitDef, q[1], ctx; span=span)
    isnothing(def) && error("Qubit $(q[1]) not defined.")
    return [q]
end
function resolve_qubit(q::Tuple{String, T}, ctx::AbstractQASMContext, span=()) where {T}
    def = lookup_def(QubitDef, q[1], ctx; span=span)
    isnothing(def) && error("Qubit $(q[1]) not defined.")
    return [(q[1], ix) for ix in q[2]]
end
resolve_qubit(node::OpenQASM3.Identifier, ctx::AbstractQASMContext) = resolve_qubit(node.name, ctx, node.span)

function _get_qubits_from_mapping(q, ctx::AbstractQASMContext)
    return map(q) do qubit
        if _is_hardware_qubit(qubit)
            return tryparse(Int, replace(qubit, "\$"=>""))
        else
            return ctx.qubit_mapping[qubit]
        end
    end
end

# does nothing for now
function interpret!(output::WalkerOutput, node::OpenQASM3.QuantumMeasurementStatement, ctx::AbstractQASMContext)
    _check_annotations(node)
    return nothing
end

function interpret!(output::WalkerOutput, node::OpenQASM3.ReturnStatement, ctx::QASMSubroutineContext)
    _check_annotations(node)
    node.expression isa OpenQASM3.QuantumMeasurement && return nothing
    return evaluate_classical_expression(node.expression, ctx)
end

function interpret!(wo::WalkerOutput, node::OpenQASM3.ClassicalDeclaration, type::OpenQASM3.ClassicalType, ctx::AbstractQASMContext)
    _check_annotations(node)
    name = node.identifier.name
    if isnothing(node.init_expression)
        val = missing
    else
        if node.init_expression isa OpenQASM3.FunctionCall
            val = interpret!(wo, node.init_expression, ctx)
        else
            val = evaluate_classical_expression(node.init_expression, ctx)
            scalar_matches_type(type, val, "In expression for `$name`, value `$val` does not match declared type:")
        end
    end
    ctx.definitions[name] = ClassicalDef(val, type, ClassicalVar)
    return nothing
end

function interpret!(wo::WalkerOutput, node::OpenQASM3.ConstantDeclaration, type::OpenQASM3.ClassicalType, ctx::AbstractQASMContext)
    _check_annotations(node)
    name = node.identifier.name
    _check_undefined(node, name, ctx)
    if isnothing(node.init_expression)
        val = missing
    else
        if node.init_expression isa OpenQASM3.FunctionCall
            val = interpret!(wo, node.init_expression, ctx)
        else
            val = evaluate_classical_expression(node.init_expression, ctx)
            scalar_matches_type(type, val, "In expression for `$name`, value `$val` does not match declared type:")
        end
    end
    ctx.definitions[name] = ClassicalDef(val, type, ClassicalConst)
    return nothing
end

_check_lval(lv::OpenQASM3.Identifier) = return
_check_lval(lv::OpenQASM3.IndexedIdentifier) = return
_check_lval(lv::T) where {T} = error("Assignment not implemented for $T.")
function interpret!(wo::WalkerOutput, node::OpenQASM3.ClassicalAssignment, ctx::AbstractQASMContext)
    _check_annotations(node)
    _check_lval(node.lvalue) 
    name = node.lvalue isa OpenQASM3.Identifier ? node.lvalue.name : node.lvalue.name.name
    def  = lookup_def(ClassicalDef, name, ctx; span=node.span)
    isnothing(def) && error("Variable `$name` not defined at $(node.span).")
    def.kind == ClassicalVar || error("Variable `$name` cannot be assigned to.")
    node.op isa OpenQASM3.AssignmentOperator || error("Unknown op in assigment.")
    if node.rvalue isa OpenQASM3.FunctionCall
        val = interpret!(wo, node.rvalue, ctx)
        ctx.definitions[name] = ClassicalDef(val, def.valtype, def.kind)
    elseif node.lvalue isa Identifier
        d_val = def.value
        rval  = evaluate_classical_expression(node.rvalue, ctx)
        if def.value isa Number && rval isa Vector
            rval = rval[1]
        end
        if node.op.name == "="
            val = rval
        elseif node.op.name == "+="
            val = def.value + rval
        elseif node.op.name == "-="
            val = def.value - rval
        elseif node.op.name == "*="
            val = def.value * rval
        elseif node.op.name == "/="
            val = def.value / rval
        else
            error("Assigment operation $(node.op.name), not currently supported.")
        end
        ctx.definitions[name] = ClassicalDef(val, def.valtype, def.kind)
    elseif node.lvalue isa IndexedIdentifier
        d_val = def.value
        l_ind = reduce(vcat, evaluate_classical_expression(ix, ctx) for ix in node.lvalue.indices) .+ 1
        rval  = evaluate_classical_expression(node.rvalue, ctx)
        if node.op.name == "="
            d_val[l_ind] .= rval
        elseif node.op.name == "+="
            d_val[l_ind] .+= rval
        elseif node.op.name == "-="
            d_val[l_ind] .-= rval
        elseif node.op.name == "*="
            d_val[l_ind] .*= rval
        elseif node.op.name == "/="
            d_val[l_ind] ./= rval
        else
            error("Assigment operation $(node.op.name), not currently supported.")
        end
        ctx.definitions[name] = ClassicalDef(d_val, def.valtype, def.kind)
    end
    return nothing
end

function interpret!(wo::WalkerOutput, node::OpenQASM3.QubitDeclaration, ctx::QASMGlobalContext)
    _check_annotations(node)
    num_qubits = isnothing(node.size) ? 1 : node.size.value
    qname      = node.qubit.name
    _check_undefined(node, qname, ctx)
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

function interpret!(wo::WalkerOutput, node::OpenQASM3.Program, ctx::QASMGlobalContext)
    for s in node.statements
        res = interpret!(wo, s, ctx)
        isbreakorcontinue(res) && interpret!(wo, res, ctx)
    end
    return nothing
end

function interpret(program::OpenQASM3.Program; extern_lookup=Dict{String,Float64}())
    global_ctx = QASMGlobalContext{Braket.Operator}(extern_lookup)
    # walk the nodes recursively
    wo = WalkerOutput()
    interpret!(wo, program, global_ctx)
    c = Circuit()
    for ix in wo.ixs
        Braket.add_instruction!(c, ix)
    end
    for rt in wo.results
        Braket.add_result_type!(c, rt)
    end
    return c
end
