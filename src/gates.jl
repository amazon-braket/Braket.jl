export Gate, AngledGate, H, I, X, Y, Z, S, Si, T, Ti, V, Vi, CNot, Swap, ISwap, CV, CY, CZ, ECR, CCNot, CSwap, Unitary, Rx, Ry, Rz, PhaseShift, PSwap, XY, CPhaseShift, CPhaseShift00, CPhaseShift01, CPhaseShift10, XX, YY, ZZ, GPi, GPi2, MS, PRx
"""
    Gate <: QuantumOperator

Abstract type representing a quantum gate.
"""
abstract type Gate <: QuantumOperator end
StructTypes.StructType(::Type{Gate}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Gate}) = (angledgate=AngledGate, h=H, i=I, x=X, y=Y, z=Z, s=S, si=Si, t=T, ti=Ti, v=V, vi=Vi, cnot=CNot, swap=Swap, iswap=ISwap, cv=CV, cy=CY, cz=CZ, ecr=ECR, ccnot=CCNot, cswap=CSwap, unitary=Unitary, rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2, ms=MS, prx=PRx)

"""
    AngledGate{NA} <: Gate

Parametric type representing a quantum gate with `NA` `angle` parameters.
"""
abstract type AngledGate{NA} <: Gate end
StructTypes.StructType(::Type{AngledGate}) = StructTypes.AbstractType()
n_angles(::Type{<:Gate}) = 0
n_angles(::Type{<:AngledGate{N}}) where {N} = N
n_angles(g::G) where {G<:Gate} = n_angles(G)

for gate_def in (
                 (:Rx, :(IR.Rx), :1, :1, ("Rx(ang)",), "rx"),
                 (:Ry, :(IR.Ry), :1, :1, ("Ry(ang)",), "ry"),
                 (:Rz, :(IR.Rz), :1, :1, ("Rz(ang)",), "rz"),
                 (:PSwap, :(IR.PSwap), :1, :2, ("PSWAP(ang)", "PSWAP(ang)"), "pswap"),
                 (:PhaseShift, :(IR.PhaseShift), :1, :1, ("PHASE(ang)",), "phaseshift"),
                 (:CPhaseShift, :(IR.CPhaseShift), :1, :2, ("C", "PHASE(ang)"), "cphaseshift"),
                 (:CPhaseShift00, :(IR.CPhaseShift00), :1, :2, ("C", "PHASE00(ang)"), "cphaseshift00"),
                 (:CPhaseShift01, :(IR.CPhaseShift01), :1, :2, ("C", "PHASE01(ang)"), "cphaseshift01"),
                 (:CPhaseShift10, :(IR.CPhaseShift10), :1, :2, ("C", "PHASE10(ang)"), "cphaseshift10"),
                 (:XX, :(IR.XX), :1, :2, ("XX(ang)", "XX(ang)"), "xx"),
                 (:XY, :(IR.XY), :1, :2, ("XY(ang)", "XY(ang)"), "xy"),
                 (:YY, :(IR.YY), :1, :2, ("YY(ang)", "YY(ang)"), "yy"),
                 (:ZZ, :(IR.ZZ), :1, :2, ("ZZ(ang)", "ZZ(ang)"), "zz"),
                 (:GPi, :(IR.GPi), :1, :1, ("GPi(ang)",), "gpi"),
                 (:GPi2, :(IR.GPi2), :1, :1, ("GPi2(ang)",), "gpi2"),
                 (:MS, :(IR.MS), :3, :2, ("MS(ang)", "MS(ang)"), "ms"),
                 (:PRx, :(IR.PRx), :2, :1, ("PRx(ang)", "PRx(ang)"), "prx"),
                )
    G, IR_G, n_angle, qc, c, lab_str = gate_def
    @eval begin
        @doc """
            $($G) <: AngledGate{$($n_angle)}
            $($G)(angles) -> $($G)
        
        $($G) gate.
        """
        struct $G <: AngledGate{$n_angle}
            angle::NTuple{$n_angle, Union{Float64, FreeParameter}}
            $G(angle::T) where {T<:NTuple{$n_angle, Union{Float64, FreeParameter}}} = new(angle)
        end
        $G(angles::Vararg{Union{Float64, FreeParameter}}) = $G(tuple(angles...))
        $G(angles::Vararg{Number}) = $G((Float64(a) for a in angles)...)
        chars(::Type{$G}) = $c
        ir_typ(::Type{$G}) = $IR_G
        qubit_count(::Type{$G}) = $qc
        label(::Type{$G}) = $lab_str
    end
end

for gate_def in (
                 (:H, :(IR.H), :1, ("H",), "h"),
                 (:I, :(IR.I), :1, ("I",), "i"),
                 (:X, :(IR.X), :1, ("X",), "x"),
                 (:Y, :(IR.Y), :1, ("Y",), "y"),
                 (:Z, :(IR.Z), :1, ("Z",), "z"),
                 (:S, :(IR.S), :1, ("S",), "s"),
                 (:Si, :(IR.Si), :1, ("Si",), "si"),
                 (:T, :(IR.T), :1, ("T",), "t"),
                 (:Ti, :(IR.Ti), :1, ("Ti",), "ti"),
                 (:V, :(IR.V), :1, ("V",), "v"),
                 (:Vi, :(IR.Vi), :1, ("Vi",), "vi"),
                 (:CNot, :(IR.CNot), :2, ("C", "X"), "cnot"),
                 (:Swap, :(IR.Swap), :2, ("SWAP", "SWAP"), "swap"),
                 (:ISwap, :(IR.ISwap), :2, ("ISWAP", "ISWAP"), "iswap"),
                 (:CV, :(IR.CV), :2, ("C", "V"), "cv"),
                 (:CY, :(IR.CY), :2, ("C", "Y"), "cy"),
                 (:CZ, :(IR.CZ), :2, ("C", "Z"), "cz"),
                 (:ECR, :(IR.ECR), :2, ("ECR", "ECR"), "ecr"),
                 (:CCNot, :(IR.CCNot), :3, ("C", "C", "X"), "ccnot"),
                 (:CSwap, :(IR.CSwap), :3, ("C", "SWAP", "SWAP"), "cswap"),
                )
    G, IR_G, qc, c, lab_str = gate_def
    @eval begin
        @doc """
            $($G) <: Gate
            $($G)() -> $($G)
        
        $($G) gate.
        """
        struct $G <: Gate end
        chars(::Type{$G}) = $c
        ir_typ(::Type{$G}) = $IR_G
        qubit_count(::Type{$G}) = $qc
        label(::Type{$G}) = $lab_str
    end
end
(::Type{G})(x::Tuple{}) where {G<:Gate} = G()
(::Type{G})(x::Tuple{}) where {G<:AngledGate} = throw(ArgumentError("angled gate must be constructed with at least one angle."))
(::Type{G})(x::AbstractVector) where {G<:AngledGate} = G(x...)
(::Type{G})(x::T) where {G<:AngledGate{1}, T<:Union{Float64, FreeParameter}} = G((x,))
qubit_count(g::G) where {G<:Gate}  = qubit_count(G)
angles(g::G) where {G<:Gate}       = ()
angles(g::AngledGate{N}) where {N} = g.angle
chars(g::G) where {G<:Gate}        = map(char->replace(string(char), "ang"=>join(string.(angles(g)), ", ")), chars(G))
ir_typ(g::G) where {G<:Gate}       = ir_typ(G)
label(g::G) where {G<:Gate}        = label(G)
ir_str(g::G) where {G<:AngledGate} = label(g) * "(" * join(string.(angles(g)), ", ") * ")"
ir_str(g::G) where {G<:Gate}       = label(g)
targets_and_controls(g::G, target::QubitSet) where {G<:Gate} = IR._generate_control_and_target(IR.ControlAndTarget(ir_typ(g))..., target)
function ir(g::G, target::QubitSet, ::Val{:JAQCD}; kwargs...) where {G<:Gate}
    t_c = targets_and_controls(g, target)
    return ir_typ(g)(angles(g)..., t_c..., label(g))
end
function ir(g::G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties()) where {G<:Gate}
    t = format_qubits(targets_and_controls(g, target), serialization_properties)
    ir_string = ir_str(g) * " " * t
    if occursin("#pragma", ir_string)
        return ir_string
    else
        return ir_string * ";"
    end
end
"""
    Unitary <: Gate
    Unitary(matrix::Matrix{ComplexF64}) -> Unitary

Arbitrary unitary gate.
"""
struct Unitary <: Gate
    matrix::Matrix{ComplexF64}
    Unitary(matrix::Matrix{<:Number}) = new(ComplexF64.(matrix))
end
Unitary(mat::Vector{Vector{Vector{T}}}) where {T} = Unitary(complex_matrix_from_ir(mat))
Base.:(==)(u1::Unitary, u2::Unitary) = u1.matrix == u2.matrix
qubit_count(g::Unitary) = convert(Int, log2(size(g.matrix, 1)))
chars(g::Unitary)       = ntuple(i->"U", qubit_count(g))
ir_typ(::Type{Unitary}) = IR.Unitary
label(::Type{Unitary})  = "unitary"

targets_and_controls(g::Unitary, target::QubitSet) = target[1:convert(Int, log2(size(g.matrix, 1)))]
ir_str(g::Unitary) = "#pragma braket unitary(" * format_matrix(g.matrix) * ")"
function ir(g::Unitary, target::QubitSet, ::Val{:JAQCD}; kwargs...)
    t_c = targets_and_controls(g, target)
    mat = complex_matrix_to_ir(g.matrix) 
    return IR.Unitary(t_c, mat, "unitary")
end
StructTypes.StructType(::Type{<:Gate}) = StructTypes.Struct()

Parametrizable(g::AngledGate) = Parametrized()
Parametrizable(g::Gate)       = NonParametrized()
parameters(g::AngledGate)     = collect(filter(a->a isa FreeParameter, angles(g)))
parameters(g::Gate)           = FreeParameter[] 
bind_value!(g::G, params::Dict{Symbol, Number}) where {G<:Gate} = bind_value!(Parametrizable(g), g, params)
bind_value!(::NonParametrized, g::G, params::Dict{Symbol, Number}) where {G<:Gate} = g
function bind_value!(::Parametrized, g::G, params::Dict{Symbol, Number}) where {G<:AngledGate}
    new_angles = map(angles(g)) do angle
        angle isa FreeParameter || return angle
        return get(params, angle.name, angle)
    end
    return G(new_angles...)
end
ir(g::Gate, target::Int, args...) = ir(g, QubitSet(target), args...)
Base.copy(g::G) where {G<:Gate} = G((copy(getproperty(g, fn)) for fn in fieldnames(G))...)
Base.copy(g::G) where {G<:AngledGate} = G(angles(g))
