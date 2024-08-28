export Gate, AngledGate, H, I, X, Y, Z, S, Si, T, Ti, V, Vi, CNot, Swap, ISwap, CV, CY, CZ, ECR, CCNot, CSwap, Unitary, Rx, Ry, Rz, PhaseShift, PSwap, XY, CPhaseShift, CPhaseShift00, CPhaseShift01, CPhaseShift10, XX, YY, ZZ, GPi, GPi2, MS, PRx, U, GPhase
"""
    Gate <: QuantumOperator

Abstract type representing a quantum gate.
"""
abstract type Gate <: QuantumOperator end
StructTypes.StructType(::Type{Gate}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Gate}) = (angledgate=AngledGate, h=H, i=I, x=X, y=Y, z=Z, s=S, si=Si, t=T, ti=Ti, v=V, vi=Vi, cnot=CNot, swap=Swap, iswap=ISwap, cv=CV, cy=CY, cz=CZ, ecr=ECR, ccnot=CCNot, cswap=CSwap, unitary=Unitary, rx=Rx, ry=Ry, rz=Rz, phaseshift=PhaseShift, pswap=PSwap, xy=XY, cphaseshift=CPhaseShift, cphaseshift00=CPhaseShift00, cphaseshift01=CPhaseShift01, cphaseshift10=CPhaseShift10, xx=XX, yy=YY, zz=ZZ, gpi=GPi, gpi2=GPi2, ms=MS, prx=PRx, u=U, gphase=GPhase)

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
                 (:Rx, :(IR.Rx), :1, :1, ("Rx(ang)",), "rx", :0, :1),
                 (:Ry, :(IR.Ry), :1, :1, ("Ry(ang)",), "ry", :0, :1),
                 (:Rz, :(IR.Rz), :1, :1, ("Rz(ang)",), "rz", :0, :1),
                 (:PSwap, :(IR.PSwap), :1, :2, ("PSWAP(ang)", "PSWAP(ang)"), "pswap", :0, :2),
                 (:PhaseShift, :(IR.PhaseShift), :1, :1, ("PHASE(ang)",), "phaseshift", :0, :1),
                 (:CPhaseShift, :(IR.CPhaseShift), :1, :2, ("C", "PHASE(ang)"), "cphaseshift", :1, :1),
                 (:CPhaseShift00, :(IR.CPhaseShift00), :1, :2, ("C", "PHASE00(ang)"), "cphaseshift00", :1, :1),
                 (:CPhaseShift01, :(IR.CPhaseShift01), :1, :2, ("C", "PHASE01(ang)"), "cphaseshift01", :1, :1),
                 (:CPhaseShift10, :(IR.CPhaseShift10), :1, :2, ("C", "PHASE10(ang)"), "cphaseshift10", :1, :1),
                 (:XX, :(IR.XX), :1, :2, ("XX(ang)", "XX(ang)"), "xx", :0, :2),
                 (:XY, :(IR.XY), :1, :2, ("XY(ang)", "XY(ang)"), "xy", :0, :2),
                 (:YY, :(IR.YY), :1, :2, ("YY(ang)", "YY(ang)"), "yy", :0, :2),
                 (:ZZ, :(IR.ZZ), :1, :2, ("ZZ(ang)", "ZZ(ang)"), "zz", :0, :2),
                 (:GPi, :(IR.GPi), :1, :1, ("GPi(ang)",), "gpi", :0, :1),
                 (:GPi2, :(IR.GPi2), :1, :1, ("GPi2(ang)",), "gpi2", :0, :1),
                 (:MS, :(IR.MS), :3, :2, ("MS(ang)", "MS(ang)"), "ms", :0, :2),
                 (:U, :(IR.UndefinedGate), :3, :1, ("U(ang)",), "U", :0, :1),
                 (:PRx, :(IR.UndefinedGate), :2, :1, ("PRx(ang)", "PRx(ang)"), "prx", :0, :1),
                )
    G, IR_G, n_angle, qc, c, lab_str, n_ctrls, n_targs = gate_def
    @eval begin
        @doc """
            $($G) <: AngledGate{$($n_angle)}
            $($G)(angles) -> $($G)
        
        $($G) gate.
        """
        struct $G <: AngledGate{$n_angle}
            angle::NTuple{$n_angle, Union{Real, FreeParameter, FreeParameterExpression}}
            $G(angle::T) where {T<:NTuple{$n_angle, Union{Real, FreeParameter, FreeParameterExpression}}} = new(angle)
        end
        $G(angles::Vararg{Union{Float64, FreeParameter, FreeParameterExpression}}) = $G(tuple(angles...))
        $G(angles::Vararg{Number}) = $G((Float64(a) for a in angles)...)

        chars(::Type{$G}) = $c
        ir_typ(::Type{$G}) = $IR_G
        qubit_count(::Type{$G}) = $qc
        label(::Type{$G}) = $lab_str
        n_controls(g::$G) = Val($n_ctrls)
        n_targets(g::$G) = Val($n_targs)
        n_controls(::Type{$G}) = Val($n_ctrls)
        n_targets(::Type{$G}) = Val($n_targs)
    end
end

for gate_def in (
                 (:H, :(IR.H), :1, ("H",), "h", :0, :1),
                 (:I, :(IR.I), :1, ("I",), "i", :0, :1),
                 (:X, :(IR.X), :1, ("X",), "x", :0, :1),
                 (:Y, :(IR.Y), :1, ("Y",), "y", :0, :1),
                 (:Z, :(IR.Z), :1, ("Z",), "z", :0, :1),
                 (:S, :(IR.S), :1, ("S",), "s", :0, :1),
                 (:Si, :(IR.Si), :1, ("Si",), "si", :0, :1),
                 (:T, :(IR.T), :1, ("T",), "t", :0, :1),
                 (:Ti, :(IR.Ti), :1, ("Ti",), "ti", :0, :1),
                 (:V, :(IR.V), :1, ("V",), "v", :0, :1),
                 (:Vi, :(IR.Vi), :1, ("Vi",), "vi", :0, :1),
                 (:CNot, :(IR.CNot), :2, ("C", "X"), "cnot", :1, :1),
                 (:Swap, :(IR.Swap), :2, ("SWAP", "SWAP"), "swap", :0, :2),
                 (:ISwap, :(IR.ISwap), :2, ("ISWAP", "ISWAP"), "iswap", :0, :2),
                 (:CV, :(IR.CV), :2, ("C", "V"), "cv", :1, :1),
                 (:CY, :(IR.CY), :2, ("C", "Y"), "cy", :1, :1),
                 (:CZ, :(IR.CZ), :2, ("C", "Z"), "cz", :1, :1),
                 (:ECR, :(IR.ECR), :2, ("ECR", "ECR"), "ecr", :0, :2),
                 (:CCNot, :(IR.CCNot), :3, ("C", "C", "X"), "ccnot", :2, :1),
                 (:CSwap, :(IR.CSwap), :3, ("C", "SWAP", "SWAP"), "cswap", :1, :2),
                )
    G, IR_G, qc, c, lab_str, n_ctrls, n_targs = gate_def
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
        n_controls(g::$G) = Val($n_ctrls)
        n_targets(g::$G) = Val($n_targs)
        n_controls(::Type{$G}) = Val($n_ctrls)
        n_targets(::Type{$G}) = Val($n_targs)
    end
end
(::Type{G})(x::Tuple{}) where {G<:Gate} = G()
(::Type{G})(x::Tuple{}) where {G<:AngledGate} = throw(ArgumentError("angled gate must be constructed with at least one angle."))
(::Type{G})(x::AbstractVector) where {G<:AngledGate} = G(x...)
(::Type{G})(angle::T) where {G<:AngledGate{1}, T<:Union{Real, FreeParameter, FreeParameterExpression}} = G((angle,))
(::Type{G})(angle1::T1, angle2::T2) where {T1<:Union{Real, FreeParameter, FreeParameterExpression}, T2<:Union{Real, FreeParameter, FreeParameterExpression}, G<:AngledGate{2}} = G((angle1, angle2,))
(::Type{G})(angle1::T1, angle2::T2, angle3::T3) where {T1<:Union{Real, FreeParameter, FreeParameterExpression}, T2<:Union{Real, FreeParameter, FreeParameterExpression}, T3<:Union{Real, FreeParameter, FreeParameterExpression}, G<:AngledGate{3}} = G((angle1, angle2, angle3,))
qubit_count(g::G) where {G<:Gate}  = qubit_count(G)
angles(g::G) where {G<:Gate}       = ()
angles(g::AngledGate{N}) where {N} = g.angle
chars(g::G) where {G<:Gate}        = map(char->replace(string(char), "ang"=>join(string.(angles(g)), ", ")), chars(G))
ir_typ(g::G) where {G<:Gate}       = ir_typ(G)
label(g::G)  where {G<:Gate}       = label(G)
ir_str(g::G) where {G<:AngledGate} = label(g) * "(" * join(string.(angles(g)), ", ") * ")"
ir_str(g::G) where {G<:Gate}       = label(g)
targets_and_controls(g::G, target::QubitSet) where {G<:Gate} = targets_and_controls(n_controls(g), n_targets(g), target)
targets_and_controls(::Val{0}, ::Val{1}, target::QubitSet)           = ((), target[1])
targets_and_controls(::Val{0}, ::Val{N}, target::QubitSet) where {N} = ((), collect(target))
targets_and_controls(::Val{1}, ::Val{1}, target::QubitSet)           = (target[1], target[2])
targets_and_controls(::Val{1}, ::Val{N}, target::QubitSet) where {N} = (target[1], target[2:end])
targets_and_controls(::Val{NC}, ::Val{1}, target::QubitSet) where {NC} = (target[1:NC], target[NC+1])
targets_and_controls(::Val{NC}, ::Val{NT}, target::QubitSet) where {NC, NT} = (target[1:NC], target[NC+1:NC+NT])
function ir(g::G, target::QubitSet, ::Val{:JAQCD}; kwargs...) where {G<:Gate}
    t_c = targets_and_controls(g, target)
    if isempty(t_c[1])
        return ir_typ(g)(angles(g)..., t_c[2], label(g))
    else
        return ir_typ(g)(angles(g)..., t_c[1], t_c[2], label(g))
    end
end
function ir(g::G, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties()) where {G<:Gate}
    t = format_qubits(target, serialization_properties)
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
n_targets(g::Unitary)   = qubit_count(g)
n_controls(g::Unitary)  = 0

ir_str(g::Unitary) = "#pragma braket unitary(" * format_matrix(g.matrix) * ")"
function ir(g::Unitary, target::QubitSet, ::Val{:JAQCD}; kwargs...)
    mat = complex_matrix_to_ir(g.matrix) 
    return IR.Unitary(collect(target), mat, "unitary")
end

"""
    GPhase <: Gate
    GPhase(ϕ::Union{Real, FreeParameter}) -> GPhase

Global phase gate.
"""
struct GPhase <: Gate
    angle::NTuple{1, Union{Real, FreeParameter}}
    GPhase(angle::T) where {T<:NTuple{1, Union{Real, FreeParameter}}} = new(angle)
end
Base.:(==)(g1::GPhase, g2::GPhase) = g1.angle == g2.angle
qubit_count(g::GPhase) = 0
chars(g::GPhase)       = ("gphase(ang)",)
ir_typ(::Type{GPhase}) = IR.UndefinedGate
label(::Type{GPhase})  = "gphase"
n_targets(g::GPhase)   = 0 
n_controls(g::GPhase)  = 0
ir(g::GPhase, target::QubitSet, ::Val{:JAQCD}; kwargs...) = throw(MethodError(ir, (g, target, Val(:JAQCD))))
targets_and_controls(g::GPhase, target::QubitSet) = ((), tuple(target...)) 
StructTypes.StructType(::Type{<:Gate}) = StructTypes.Struct()

Parametrizable(g::AngledGate) = Parametrized()
Parametrizable(g::Gate)       = NonParametrized()
parameters(g::AngledGate)     = collect(filter(a->a isa FreeParameter, angles(g)))
parameters(g::Gate)           = FreeParameter[] 
bind_value!(g::G, params::Dict{Symbol, <:Number}) where {G<:Gate} = bind_value!(Parametrizable(g), g, params)
bind_value!(::NonParametrized, g::G, params::Dict{Symbol, <:Number}) where {G<:Gate} = g
function bind_value!(::Parametrized, g::G, params::Dict{Symbol, <:Number}) where {G<:AngledGate}
    new_angles = map(angles(g)) do angle
        angle isa FreeParameter || return angle
        return get(params, angle.name, angle)
    end
    return G(new_angles...)
end
ir(g::Gate, target::Int, args...) = ir(g, QubitSet(target), args...)
Base.copy(g::G) where {G<:Gate} = G((copy(getproperty(g, fn)) for fn in fieldnames(G))...)
Base.copy(g::G) where {G<:AngledGate} = G(angles(g))
