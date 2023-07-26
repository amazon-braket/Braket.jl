export Gate,AngledGate,TripleAngledGate,H,I,X,Y,Z,S,Si,T,Ti,V,Vi,CNot,Swap,ISwap,CV,CY,CZ,ECR,CCNot,CSwap,Unitary,Rx,Ry,Rz,PhaseShift,PSwap,XY,CPhaseShift,CPhaseShift00,CPhaseShift01,CPhaseShift10,XX,YY,ZZ,GPi,GPi2,MS
"""
    Gate <: QuantumOperator

Abstract type representing a quantum gate.
"""
abstract type Gate <: QuantumOperator end
StructTypes.StructType(::Type{Gate}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Gate}) = (angledgate=AngledGate, tripleangledgate=TripleAngledGate, h=H, i=I, x=X, y=Y, z=Z, s=S, si=Si, t=T, ti=Ti, v=V, vi=Vi, cnot=CNot, swap=Swap, iswap=ISwap, cv=CV, cy=CY, cz=CZ, ecr=ECR, ccnot=CCNot, cswap=CSwap, unitary=Unitary, rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2, ms=MS)

"""
    AngledGate <: Gate

Abstract type representing a quantum gate with an `angle` parameter.
"""
abstract type AngledGate <: Gate end
StructTypes.StructType(::Type{AngledGate}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{AngledGate}) = (rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2)

"""
    TripleAngledGate <: Gate

Abstract type representing a quantum gate with three `angle` parameters.
"""
abstract type TripleAngledGate <: Gate end
StructTypes.StructType(::Type{TripleAngledGate}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{TripleAngledGate}) = (ms=MS)

for (G, IRG, label, qc, c) in zip((:Rx, :Ry, :Rz, :PhaseShift, :PSwap, :XY, :CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :XX, :YY, :ZZ, :GPi, :GPi2), (:(IR.Rx), :(IR.Ry), :(IR.Rz), :(IR.PhaseShift), :(IR.PSwap), :(IR.XY), :(IR.CPhaseShift), :(IR.CPhaseShift00), :(IR.CPhaseShift01), :(IR.CPhaseShift10), :(IR.XX), :(IR.YY), :(IR.ZZ), :(IR.GPi), :(IR.GPi2)), ("rx", "ry", "rz", "phaseshift", "pswap", "xy", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "xx", "yy", "zz", "gpi", "gpi2"), (:1, :1, :1, :1, :2, :2, :2, :2, :2, :2, :2, :2, :2, :1, :1), (["Rx(ang)"], ["Ry(ang)"], ["Rz(ang)"], ["PHASE(ang)"], ["PSWAP(ang)", "PSWAP(ang)"], ["XY(ang)", "XY(ang)"], ["C", "PHASE(ang)"], ["C", "PHASE00(ang)"], ["C", "PHASE01(ang)"], ["C", "PHASE10(ang)"], ["XX(ang)", "XX(ang)"], ["YY(ang)", "YY(ang)"], ["ZZ(ang)", "ZZ(ang)"], ["GPi(ang)"], ["GPi2(ang)"]))
    @eval begin
        @doc """
            $($G) <: AngledGate
            $($G)(angle::Union{Float64, FreeParameter}) -> $($G)
        
        $($G) gate.
        """
        struct $G <: AngledGate
            angle::Union{Float64, FreeParameter}
        end
        chars(g::$G) = map(char->replace(string(char), "ang"=>string(g.angle)), $c)
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
for (G, IRG, label, qc, c) in zip((:MS,), (:(IR.MS),), ("ms",), (:2,), (["MS(ang1, ang2, ang3)", "MS(ang1, ang2, ang3)"],))
    @eval begin
        @doc """
            $($G) <: TripleAngledGate
            $($G)(angle1::Union{Float64, FreeParameter}, angle2::Union{Float64, FreeParameter}, angle3::Union{Float64, FreeParameter}) -> $($G)
        
        $($G) gate.
        """
        struct $G <: TripleAngledGate
            angle1::Union{Float64, FreeParameter}
            angle2::Union{Float64, FreeParameter}
            angle3::Union{Float64, FreeParameter}
        end
        chars(g::$G) = map(char->replace(string(char), "ang1"=>string(g.angle1), "ang2"=>string(g.angle2), "ang3"=>string(g.angle3)), $c)
        qubit_count(g::$G) = $qc
        qubit_count(::Type{$G}) = $qc
        function ir(g::$G, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            return $IRG(g.angle1, g.angle2, g.angle3, collect(t_c)..., $label)
        end
        function ir(g::$G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRG)..., target)
            t   = format_qubits(t_c, serialization_properties)
            return $label*"($(g.angle1), $(g.angle2), $(g.angle3)) $t;"
        end
    end
end
for (G, IRG, label, qc, c) in zip((:H, :I, :X, :Y, :Z, :S, :Si, :T, :Ti, :V, :Vi, :CNot, :Swap, :ISwap, :CV, :CY, :CZ, :ECR, :CCNot, :CSwap), (:(IR.H), :(IR.I), :(IR.X), :(IR.Y), :(IR.Z), :(IR.S), :(IR.Si), :(IR.T), :(IR.Ti), :(IR.V), :(IR.Vi), :(IR.CNot), :(IR.Swap), :(IR.ISwap), :(IR.CV), :(IR.CY), :(IR.CZ), :(IR.ECR), :(IR.CCNot), :(IR.CSwap)), ("h", "i", "x", "y", "z", "s", "si", "t", "ti", "v", "vi", "cnot", "swap", "iswap", "cv", "cy", "cz", "ecr", "ccnot", "cswap"), (:1, :1, :1, :1, :1, :1, :1, :1, :1, :1, :1, :2, :2, :2, :2, :2, :2, :2, :3, :3), (["H"], ["I"], ["X"], ["Y"], ["Z"], ["S"], ["Si"], ["T"], ["Ti"], ["V"], ["Vi"], ["C", "X"], ["SWAP", "SWAP"], ["ISWAP", "ISWAP"], ["C", "V"], ["C", "Y"], ["C", "Z"], ["ECR", "ECR"], ["C", "C", "X"], ["C", "SWAP", "SWAP"]))
    @eval begin
        @doc """
            $($G) <: Gate
            $($G)() -> $($G)
        
        $($G) gate.
        """
        struct $G <: Gate end
        chars(g::$G) = $c
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
Base.:(==)(u1::Unitary, u2::Unitary) = u1.matrix == u2.matrix
qubit_count(g::Unitary) = convert(Int, log2(size(g.matrix, 1)))
chars(g::Unitary) = ntuple(i->"U", qubit_count(g))
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

Parametrizable(g::TripleAngledGate) = Parametrized()
Parametrizable(g::AngledGate) = Parametrized()
Parametrizable(g::Gate) = NonParametrized()

parameters(g::TripleAngledGate) = filter(a->a isa FreeParameter, [g.angle1, g.angle2, g.angle3])
parameters(g::AngledGate) = g.angle isa FreeParameter ? [g.angle] : FreeParameter[] 
parameters(g::Gate)       = FreeParameter[] 
bind_value!(g::G, params::Dict{Symbol, Number}) where {G<:Gate} = bind_value!(Parametrizable(g), g, params)
bind_value!(::NonParametrized, g::G, params::Dict{Symbol, Number}) where {G<:Gate} = g

function bind_value!(::Parametrized, g::G, params::Dict{Symbol, Number}) where {G<:TripleAngledGate}
    new_angles = map([g.angle1, g.angle2, g.angle3]) do angle
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
