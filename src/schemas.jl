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
struct Instruction{O<:Operator}
    operator::O
    target::QubitSet
end
Instruction(o::O, target...) where {O<:Operator} = Instruction{O}(o, QubitSet(target...))
Instruction(o::O, target) where {O<:Operator} = Instruction{O}(o, QubitSet(target...))
Instruction{CD}(cd::CD) where {CD<:CompilerDirective} = Instruction{CD}(cd, QubitSet(Int[]))
Instruction(cd::CD) where {CD<:CompilerDirective} = Instruction{CD}(cd, Int[])
operator(ix::Instruction{O}) where {O<:Operator} = ix.operator
StructTypes.StructType(::Type{Instruction{O}}) where {O} = StructTypes.CustomStruct()
StructTypes.StructType(::Type{Instruction}) = StructTypes.CustomStruct()
StructTypes.lower(x::Instruction{O}) where {O<:Operator} = isempty(x.target) ? ir(x.operator, Val(:JAQCD)) : ir(x.operator, x.target, Val(:JAQCD))
ir(x::Instruction{O}, ::Val{:OpenQASM}; kwargs...) where {O<:Operator} = isempty(x.target) ? ir(x.operator, Val(:OpenQASM); kwargs...) : ir(x.operator, x.target, Val(:OpenQASM); kwargs...)

conc_types = filter(Base.isconcretetype, vcat(subtypes(AbstractIR), subtypes(CompilerDirective)))
nt_dict = merge([Dict(zip(fieldnames(t), (Union{Nothing, x} for x in fieldtypes(t)))) for t in conc_types]...)
ks = tuple(:angles, keys(nt_dict)...)
vs = Tuple{Union{Nothing, Vector{Float64}}, values(nt_dict)...}
inst_typ = NamedTuple{ks, vs}
StructTypes.lowertype(::Type{Instruction{O}}) where {O} = inst_typ
StructTypes.lowertype(::Type{Instruction}) = inst_typ
Instruction(x::Instruction{O}) where {O<:Braket.Operator} = x
function Instruction(x)
    sts    = merge(StructTypes.subtypes(Gate), StructTypes.subtypes(Noise), StructTypes.subtypes(CompilerDirective))
    o_type = sts[Symbol(x[:type])]
    (o_type <: CompilerDirective) && return Instruction(o_type(), Int[])
    if o_type <: AngledGate{1}
        o_fns  = (:angles, :angle)
        args   = (Float64(x[:angle]),)
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
Instruction(x::Dict{String, <:Any}) = Instruction(Dict(Symbol(k)=>v for (k,v) in x))
StructTypes.constructfrom(::Type{Instruction}, x::Union{Dict{Symbol, Any}, NamedTuple}) = Instruction(x)
Base.:(==)(ix1::Instruction{O}, ix2::Instruction{O}) where {O<:Operator} = (ix1.operator == ix2.operator && ix1.target == ix2.target)
qubits(ix::Instruction{O}) where {O<:Operator} = ix.target
qubit_count(ix::Instruction{O}) where {O<:Operator} = length(ix.target)
qubits(ixs::Vector{Instruction{O}}) where {O<:Operator}  = mapreduce(ix->ix.target, union!, ixs, init=Set{Int}())
qubits(ixs::Vector{Instruction}) = mapreduce(ix->ix.target, union!, ixs, init=Set{Int}())
qubit_count(ixs::Vector{Instruction{O}}) where {O<:Operator} = length(qubits(ixs)) 
qubit_count(ixs::Vector{Instruction}) = length(qubits(ixs)) 

bind_value!(ix::Instruction{O}, param_values::Dict{Symbol, Number}) where {O<:Operator} = Instruction{O}(bind_value!(ix.operator, param_values), ix.target)

remap(ix::Instruction{O}, mapping::Dict{<:Integer, <:Integer}) where {O<:Operator} = Instruction{O}(copy(ix.operator), [mapping[q] for q in ix.target])
remap(ix::Instruction{O}, target::VecOrQubitSet) where {O<:Operator} = Instruction{O}(copy(ix.operator), target[1:length(ix.target)])
remap(ix::Instruction{O}, target::IntOrQubit) where {O<:Operator}    = Instruction{O}(copy(ix.operator), target)

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

