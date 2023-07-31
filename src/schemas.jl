using InteractiveUtils

"""
    Instruction
    Instruction(o::Operator, target)

Represents a single operation applied to a [`Circuit`](@ref).
Contains an `operator`, which may be any subtype of [`Operator`](@ref),
and a `target` set of qubits to which the `operator` is applied.

# Examples
```jldoctest
julia> Instruction(H(), 1)
Braket.Instruction(H(), QubitSet(1))

julia> Instruction(CNot(), [1, Qubit(4)])
Braket.Instruction(CNot(), QubitSet(1, Qubit(4)))

julia> Instruction(StartVerbatimBox(), QubitSet())
Braket.Instruction(StartVerbatimBox(), QubitSet())
```
"""
struct Instruction
    operator::Operator
    target::QubitSet
    Instruction(o::Operator, target) = new(o, QubitSet(target))
end
Instruction(cd::CompilerDirective) = Instruction(cd, Int[])
operator(ix::Instruction) = ix.operator
StructTypes.StructType(::Type{Instruction}) = StructTypes.CustomStruct()
StructTypes.lower(x::Instruction) = isempty(x.target) ? ir(x.operator, Val(:JAQCD)) : ir(x.operator, x.target, Val(:JAQCD))
ir(x::Instruction, ::Val{:OpenQASM}; kwargs...) = isempty(x.target) ? ir(x.operator, Val(:OpenQASM); kwargs...) : ir(x.operator, x.target, Val(:OpenQASM); kwargs...)

conc_types = filter(Base.isconcretetype, vcat(subtypes(AbstractIR), subtypes(CompilerDirective)))
nt_dict = merge([Dict(zip(fieldnames(t), (Union{Nothing, x} for x in fieldtypes(t)))) for t in conc_types]...)
ks = tuple(:angles, keys(nt_dict)...)
vs = Tuple{Union{Nothing, Vector{Float64}}, values(nt_dict)...}
inst_typ = NamedTuple{ks, vs}
StructTypes.lowertype(::Type{Instruction}) = inst_typ
function Instruction(x)
    sts    = merge(StructTypes.subtypes(Gate), StructTypes.subtypes(Noise), StructTypes.subtypes(CompilerDirective))
    o_type = sts[Symbol(x[:type])]
    (o_type <: CompilerDirective) && return Instruction(o_type(), Int[])
    if o_type <: AngledGate{1}
        o_fns  = (:angles, :angle) 
        args   = (x[:angle],)
        op     = o_type(args)
    elseif o_type <: AngledGate{3}
        o_fns  = (:angles, :angle1, :angle2, :angle3) 
        args   = tuple([x[fn] for fn in [Symbol("angle$i") for i in 1:n_angles(o_type)]]...)
        op     = o_type(args)
    else
        o_fns  = fieldnames(o_type)
        args   = [x[fn] for fn in o_fns]
        op     = o_type(args...)
    end
    raw_target  = Int[]
    target_keys = collect(setdiff(keys(x), vcat(o_fns..., :type)))
    for k in sort(target_keys, by=(x->occursin("target", string(x))))
        v = get(x, k, nothing)
        !isnothing(v) && append!(raw_target, v)
    end
    target = reduce(vcat, raw_target)
    return Instruction(op, target)
end
StructTypes.constructfrom(::Type{Instruction}, x::Union{Dict{Symbol, Any}, NamedTuple}) = Instruction(x)
Base.:(==)(ix1::Instruction, ix2::Instruction) = (ix1.operator == ix2.operator && ix1.target == ix2.target)

bind_value!(ix::Instruction, param_values::Dict{Symbol, Number}) = Instruction(bind_value!(ix.operator, param_values), ix.target)

remap(ix::Instruction, mapping::Dict{<:Integer, <:Integer}) = Instruction(copy(ix.operator), [mapping[q] for q in ix.target])
remap(ix::Instruction, target::VecOrQubitSet) = Instruction(copy(ix.operator), target[1:length(ix.target)])
remap(ix::Instruction, target::IntOrQubit)    = Instruction(copy(ix.operator), target)

function StructTypes.constructfrom(::Type{Program}, obj)
    new_obj = copy(obj)
    for (i, k) in enumerate(fieldnames(Program))
        if !haskey(new_obj, k) || (haskey(StructTypes.defaults(Program), k) && isnothing(new_obj[k]))
            new_obj[k] = StructTypes.defaults(Program)[k]
        end
    end
    new_obj[:instructions] = StructTypes.constructfrom(Vector{Instruction}, new_obj[:instructions])
    return StructTypes.constructfrom(StructTypes.StructType(Program), Program, new_obj)
end

