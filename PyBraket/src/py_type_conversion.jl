using PythonCall, Braket, Braket.IR
import Braket.IR: IRObservable, AbstractProgramResult, AbstractProgram, AbstractIR
import Braket: ResultTypeValue

function union_convert(::Type{IRObservable}, x)
    PythonCall.pyisinstance(x, PythonCall.pybuiltins.str) && return pyconvert(String, x)
    x_vec = Union{String, Vector{Vector{Vector{Float64}}}}[PythonCall.pyisinstance(x_, PythonCall.pybuiltins.str) ? pyconvert(String, x_) : pyconvert(Vector{Vector{Vector{Float64}}}, x_) for x_ in x] 
    return x_vec
end

function union_convert(union_type, x)
    union_ts = union_type isa Union ? Type[] : [union_type]
    union_t = union_type
    while union_t isa Union
        union_t.a != Nothing && push!(union_ts, union_t.a)
        !(union_t.b isa Union) && push!(union_ts, union_t.b)
        union_t = union_t.b
    end
    arg = nothing
    for t_ in union_ts
        try
            if pyisinstance(x, PythonCall.pybuiltins.list) && t_ <: Vector
                return [union_convert(Union{eltype(t_)}, attr_) for attr_ in x]
            elseif pyisinstance(x, pybuiltins.str) && t_ <: Integer
                return tryparse(t_, pyconvert(String, x))
            elseif t_ == ResultTypeValue
                if pyhasattr(x, "value")
                    typ = jl_convert(AbstractProgramResult, pygetattr(x, "type"))
                    val = union_convert(Union{Dict{String, ComplexF64}, Float64, Vector}, pygetattr(x, "value"))
                    return PythonCall.pyconvert_return(ResultTypeValue(typ, val))
                else
                    rt = jl_convert(AbstractProgramResult, x)
                    return PythonCall.pyconvert_return(ResultTypeValue(rt, 0.0))
                end
            else
                return pyconvert(t_, x)
            end
        catch e
        end
    end
    arg isa Vector{Nothing} && (arg = nothing)
    return arg
end

function jl_convert_attr(n, t, attr)
    if !(t isa Union)
        if pyisinstance(attr, PythonCall.pybuiltins.list)
            if eltype(t) isa Union
                return [union_convert(eltype(t), attr_) for attr_ in attr]
            else
                return [pyconvert(eltype(t), attr_) for attr_ in attr]
            end
        else
            return pyconvert(t, attr)
        end
    else
        PythonCall.pyisnone(attr) && return nothing
        return union_convert(t, attr)
    end
end

function jl_convert(::Type{T}, x::Py) where {T}
    fts = fieldtypes(T)
    fns = fieldnames(T)
    args = Any[]
    for (n, t) in zip(fns, fts)
        attr = pygetattr(x, string(n))
        arg = jl_convert_attr(n, t, attr)
        push!(args, arg)
    end
    PythonCall.pyconvert_return(T(args...))
end

function jl_convert(::Type{T}, x::Py) where {T<:AbstractIR}
    fts = fieldtypes(T)[1:end-1]
    fns = fieldnames(T)[1:end-1]
    args = Any[]
    for (n, t) in zip(fns, fts)
        attr = pygetattr(x, string(n))
        arg = jl_convert_attr(n, t, attr)
        push!(args, arg)
    end
    PythonCall.pyconvert_return(T(args..., pyconvert(String, pygetattr(x, "type"))))
end
