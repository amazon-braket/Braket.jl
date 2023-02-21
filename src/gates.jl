export Gate,AngledGate,DoubleAngledGate,H,I,X,Y,Z,S,Si,T,Ti,V,Vi,CNot,Swap,ISwap,CV,CY,CZ,ECR,CCNot,CSwap,Unitary,Rx,Ry,Rz,PhaseShift,PSwap,XY,CPhaseShift,CPhaseShift00,CPhaseShift01,CPhaseShift10,XX,YY,ZZ,GPi,GPi2,MS
"""
    Gate <: QuantumOperator

Abstract type representing a quantum gate.
"""
abstract type Gate <: QuantumOperator end

StructTypes.StructType(::Type{Gate}) = StructTypes.AbstractType()
 
StructTypes.subtypes(::Type{Gate}) = (angledgate=AngledGate, doubleangledgate=DoubleAngledGate, h=H, i=I, x=X, y=Y, z=Z, s=S, si=Si, t=T, ti=Ti, v=V, vi=Vi, cnot=CNot, swap=Swap, iswap=ISwap, cv=CV, cy=CY, cz=CZ, ecr=ECR, ccnot=CCNot, cswap=CSwap, unitary=Unitary, rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2, ms=MS)
"""
    AngledGate <: Gate

Abstract type representing a quantum gate with an `angle` parameter.
"""
abstract type AngledGate <: Gate end

StructTypes.StructType(::Type{AngledGate}) = StructTypes.AbstractType()
 
StructTypes.subtypes(::Type{AngledGate}) = (rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2)
"""
    DoubleAngledGate <: Gate

Abstract type representing a quantum gate with two `angle` parameters.
"""
abstract type DoubleAngledGate <: Gate end

StructTypes.StructType(::Type{DoubleAngledGate}) = StructTypes.AbstractType()
 
StructTypes.subtypes(::Type{DoubleAngledGate}) = (ms=MS)
for (G, IRG, label, qc) in zip((:Rx, :Ry, :Rz, :PhaseShift, :PSwap, :XY, :CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :XX, :YY, :ZZ, :GPi, :GPi2), (:(IR.Rx), :(IR.Ry), :(IR.Rz), :(IR.PhaseShift), :(IR.PSwap), :(IR.XY), :(IR.CPhaseShift), :(IR.CPhaseShift00), :(IR.CPhaseShift01), :(IR.CPhaseShift10), :(IR.XX), :(IR.YY), :(IR.ZZ), :(IR.GPi), :(IR.GPi2)), ("rx", "ry", "rz", "phaseshift", "pswap", "xy", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "xx", "yy", "zz", "gpi", "gpi2"), (:1, :1, :1, :1, :2, :2, :2, :2, :2, :2, :2, :2, :2, :1, :1))
    @eval begin
        @doc """
            $($G) <: AngledGate
            $($G)(angle::Union{Float64, FreeParameter}) -> $($G)
        
        $($G) gate.
        """
        struct $G <: AngledGate
            angle::Union{Float64, FreeParameter}
        end
        qubit_count(g::$G) = $qc
        qubit_count(::Type{$G}) = $qc
        function ir(g::$G, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            return $IRG(g.angle, t_c..., $label)
        end
        function ir(g::$G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            t   = format_qubits(t_c, serialization_properties)
            return $label*"($(g.angle)) $t;"
        end
    end
end
for (G, IRG, label, qc) in zip((:MS,), (:(IR.MS),), ("ms",), (:2,))
    @eval begin
        @doc """
            $($G) <: DoubleAngledGate
            $($G)(angle1::Union{Float64, FreeParameter}, angle2::Union{Float64, FreeParameter}) -> $($G)
        
        $($G) gate.
        """
        struct $G <: DoubleAngledGate
            angle1::Union{Float64, FreeParameter}
            angle2::Union{Float64, FreeParameter}
        end
        qubit_count(g::$G) = $qc
        qubit_count(::Type{$G}) = $qc
        function ir(g::$G, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            return $IRG(g.angle1, g.angle2, collect(t_c)..., $label)
        end
        function ir(g::$G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            t   = format_qubits(t_c, serialization_properties)
            return $label*"($(g.angle1), $(g.angle2)) $t;"
        end
    end
end
for (G, IRG, label, qc) in zip((:H, :I, :X, :Y, :Z, :S, :Si, :T, :Ti, :V, :Vi, :CNot, :Swap, :ISwap, :CV, :CY, :CZ, :ECR, :CCNot, :CSwap), (:(IR.H), :(IR.I), :(IR.X), :(IR.Y), :(IR.Z), :(IR.S), :(IR.Si), :(IR.T), :(IR.Ti), :(IR.V), :(IR.Vi), :(IR.CNot), :(IR.Swap), :(IR.ISwap), :(IR.CV), :(IR.CY), :(IR.CZ), :(IR.ECR), :(IR.CCNot), :(IR.CSwap)), ("h", "i", "x", "y", "z", "s", "si", "t", "ti", "v", "vi", "cnot", "swap", "iswap", "cv", "cy", "cz", "ecr", "ccnot", "cswap"), (:1, :1, :1, :1, :1, :1, :1, :1, :1, :1, :1, :2, :2, :2, :2, :2, :2, :2, :3, :3))
    @eval begin
        @doc """
            $($G) <: Gate
            $($G)() -> $($G)
        
        $($G) gate.
        """
        struct $G <: Gate end
        qubit_count(g::$G) = $qc
        qubit_count(::Type{$G}) = $qc
        function ir(g::$G, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            return $IRG(t_c..., $label)
        end
        function ir(g::$G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            t   = format_qubits(t_c, serialization_properties)
            return $label*" $t;"
        end
    end
end
"""
    Unitary <: Gate
    Unitary(matrix::Matrix{ComplexF64}) -> Unitary

Arbitrary unitary gate.
"""
struct Unitary <: Gate
    matrix::Matrix{ComplexF64}
end
Unitary(mat::Vector{Vector{Vector{Float64}}}) = Unitary(complex_matrix_from_ir(mat))
Base.:(==)(u1::Unitary, u2::Unitary) = u1.matrix ≈ u2.matrix
qubit_count(g::Unitary) = convert(Int, log2(size(g.matrix, 1)))

function ir(g::Unitary, target::QubitSet, ::Val{:JAQCD}; kwargs...)
    mat = complex_matrix_to_ir(g.matrix) 
    t_c = target[1:convert(Int, log2(size(g.matrix, 1)))]
    return IR.Unitary(t_c, mat, "unitary")
end
function ir(g::Unitary, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
    t_c = target[1:convert(Int, log2(size(g.matrix, 1)))]
    m   = format_matrix(g.matrix)
    t   = format_qubits(t_c, serialization_properties)
    return "#pragma braket unitary($m) $t"
end
StructTypes.StructType(::Type{<:Gate}) = StructTypes.Struct()
abstract type Parametrizable end
struct Parametrized end 
struct NonParametrized end 

Parametrizable(g::DoubleAngledGate) = Parametrized()
Parametrizable(g::AngledGate) = Parametrized()
Parametrizable(g::Gate) = NonParametrized()

parameters(g::DoubleAngledGate) = filter(a->a isa FreeParameter, [g.angle1, g.angle2])
parameters(g::AngledGate) = g.angle isa FreeParameter ? [g.angle] : FreeParameter[] 
parameters(g::Gate)       = FreeParameter[] 
bind_value!(g::G, params::Dict{Symbol, Number}) where {G<:Gate} = bind_value!(Parametrizable(g), g, params)
bind_value!(::NonParametrized, g::G, params::Dict{Symbol, Number}) where {G<:Gate} = g

function bind_value!(::Parametrized, g::G, params::Dict{Symbol, Number}) where {G<:DoubleAngledGate}
    new_angles = map([g.angle2, g.angle2]) do angle
        angle isa FreeParameter || return angle
        return get(params, angle.name, angle)
    end
    return G(new_angles...)
end

function bind_value!(::Parametrized, g::G, params::Dict{Symbol, Number}) where {G<:AngledGate}
    g.angle isa FreeParameter || return G(g.angle)
    new_angle = get(params, g.angle.name, g.angle)
    return G(new_angle)
end
ir(g::Gate, target::Int, args...) = ir(g, QubitSet(target), args...)
Base.copy(g::G) where {G<:Gate} = G((copy(getproperty(g, fn)) for fn in fieldnames(G))...)

for (G, c) in zip((:H, :I, :X, :Y, :Z, :S, :Si, :T, :Ti, :V, :Vi), ("H", "I", "X", "Y", "Z", "S", "Si", "T", "Ti", "V", "Vi"))
    @eval begin
        chars(g::$G) = ($c,)
    end
end

for (G, c) in zip((:PhaseShift, :Rx, :Ry, :Rz), ("Phase", "Rx", "Ry", "Rz"))
    @eval begin
        chars(g::$G) = ($c * "(" * string(g.angle) * ")",)
    end
end

for (G, cs) in zip((:CNot, :Swap, :ECR, :ISwap, :CV, :CY, :CZ), (("C", "X"), ("SWAP", "SWAP"), ("ECR", "ECR"), ("iSWAP", "iSWAP"), ("C", "V"), ("C", "Y"), ("C", "Z")))
    @eval begin
        chars(g::$G) = $cs
    end
end

for (G, cs) in zip((:CCNot, :CSwap), (("C", "C", "X"), ("C", "SWAP", "SWAP")))
    @eval begin
        chars(g::$G) = $cs
    end
end

for (G, c) in zip((:CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10), ("Phase", "Phase00", "Phase01", "Phase10"))
    @eval begin
        chars(g::$G) = ("C", $c * "(" * string(g.angle) * ")",)
    end
end

for (G, c) in zip((:XX, :YY, :ZZ, :PSwap), ("X", "Y", "Z", "PSwap"))
    @eval begin
        chars(g::$G) = ($c * "(" * string(g.angle) * ")",$c * "(" * string(g.angle) * ")")
    end
end
