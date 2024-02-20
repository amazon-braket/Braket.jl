
Base.sizeof(array::OpenQASM3.ArrayLiteral, dim::OpenQASM3.IntegerLiteral = OpenQASM3.IntegerLiteral(0)) = return dim.value == 0 ? OpenQASM3.IntegerLiteral(length(array.values)) : sizeof(array.values[1], OpenQASM3.IntegerLiteral(dim.value - 1))
Base.sizeof(array::OpenQASM3.ArrayLiteral, ::Nothing) = return OpenQASM3.IntegerLiteral(length(array.values))
Base.acos(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(acos(x.value))
Base.asin(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(asin(x.value))
Base.atan(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(atan(x.value))
Base.cos(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(cos(x.value))
Base.sin(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(sin(x.value))
Base.tan(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(tan(x.value))

Base.sqrt(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(sqrt(x.value))
Base.exp(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(exp(x.value))
Base.log(x::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(log(x.value))
Base.ceil(x::OpenQASM3.FloatLiteral) = OpenQASM3.IntegerLiteral(ceil(x.value))
Base.floor(x::OpenQASM3.FloatLiteral) = OpenQASM3.IntegerLiteral(floor(x.value))

Base.mod(x::OpenQASM3.FloatLiteral, y::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(mod(x.value, y.value))
Base.mod(x::OpenQASM3.IntegerLiteral, y::OpenQASM3.IntegerLiteral) = OpenQASM3.IntegerLiteral(mod(x.value, y.value))
Base.mod(x::OpenQASM3.FloatLiteral, y::OpenQASM3.IntegerLiteral) = OpenQASM3.FloatLiteral(mod(x.value, y.value))
Base.mod(x::OpenQASM3.IntegerLiteral, y::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(mod(x.value, y.value))

pow(x::OpenQASM3.FloatLiteral, y::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(x.value ^ y.value)
pow(x::OpenQASM3.IntegerLiteral, y::OpenQASM3.IntegerLiteral) = OpenQASM3.IntegerLiteral(x.value ^ y.value)
pow(x::OpenQASM3.FloatLiteral, y::OpenQASM3.IntegerLiteral) = OpenQASM3.FloatLiteral(x.value ^ y.value)
pow(x::OpenQASM3.IntegerLiteral, y::OpenQASM3.FloatLiteral) = OpenQASM3.FloatLiteral(x.value ^ y.value)
    
# does not support symbols or expressions
popcount(x::OpenQASM3.ArrayLiteral)     = OpenQASM3.IntegerLiteral(count('1', [v.value for v in x.values]))
popcount(x::OpenQASM3.IntegerLiteral)   = OpenQASM3.IntegerLiteral(count('1', bitstring(x.value)))
popcount(x::OpenQASM3.BitstringLiteral) = OpenQASM3.IntegerLiteral(count('1', bitstring(x.value)))
popcount(x::Real) = count('1', bitstring(x))

const builtin_functions = Dict{String, Function}("sizeof"=>sizeof,
                                                 "arccos"=>acos,
                                                 "arcsin"=>asin,
                                                 "arctan"=>atan,
                                                 "exp"=>exp,
                                                 "log"=>log,
                                                 "sqrt"=>sqrt,
                                                 "cos"=>cos,
                                                 "sin"=>sin,
                                                 "tan"=>tan,
                                                 "ceiling"=>ceil,
                                                 "floor"=>floor,
                                                 "mod"=>mod,
                                                 "pow"=>pow,
                                                 "popcount"=>popcount,
                                                )
