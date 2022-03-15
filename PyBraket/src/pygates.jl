function Py(x::IR.Rx)
    fns = fieldnames(IR.Rx)
    args = arg_gen(x, fns)
    return pyjaqcd.Rx(; args...)
end
function Py(x::Rx)
    fns = fieldnames(Rx)
    args = arg_gen(x, fns)
    return pygates.Rx(; args...)
end
function Py(x::IR.Ry)
    fns = fieldnames(IR.Ry)
    args = arg_gen(x, fns)
    return pyjaqcd.Ry(; args...)
end
function Py(x::Ry)
    fns = fieldnames(Ry)
    args = arg_gen(x, fns)
    return pygates.Ry(; args...)
end
function Py(x::IR.Rz)
    fns = fieldnames(IR.Rz)
    args = arg_gen(x, fns)
    return pyjaqcd.Rz(; args...)
end
function Py(x::Rz)
    fns = fieldnames(Rz)
    args = arg_gen(x, fns)
    return pygates.Rz(; args...)
end
function Py(x::IR.PhaseShift)
    fns = fieldnames(IR.PhaseShift)
    args = arg_gen(x, fns)
    return pyjaqcd.PhaseShift(; args...)
end
function Py(x::PhaseShift)
    fns = fieldnames(PhaseShift)
    args = arg_gen(x, fns)
    return pygates.PhaseShift(; args...)
end
function Py(x::IR.PSwap)
    fns = fieldnames(IR.PSwap)
    args = arg_gen(x, fns)
    return pyjaqcd.PSwap(; args...)
end
function Py(x::PSwap)
    fns = fieldnames(PSwap)
    args = arg_gen(x, fns)
    return pygates.PSwap(; args...)
end
function Py(x::IR.XY)
    fns = fieldnames(IR.XY)
    args = arg_gen(x, fns)
    return pyjaqcd.XY(; args...)
end
function Py(x::XY)
    fns = fieldnames(XY)
    args = arg_gen(x, fns)
    return pygates.XY(; args...)
end
function Py(x::IR.CPhaseShift)
    fns = fieldnames(IR.CPhaseShift)
    args = arg_gen(x, fns)
    return pyjaqcd.CPhaseShift(; args...)
end
function Py(x::CPhaseShift)
    fns = fieldnames(CPhaseShift)
    args = arg_gen(x, fns)
    return pygates.CPhaseShift(; args...)
end
function Py(x::IR.CPhaseShift00)
    fns = fieldnames(IR.CPhaseShift00)
    args = arg_gen(x, fns)
    return pyjaqcd.CPhaseShift00(; args...)
end
function Py(x::CPhaseShift00)
    fns = fieldnames(CPhaseShift00)
    args = arg_gen(x, fns)
    return pygates.CPhaseShift00(; args...)
end
function Py(x::IR.CPhaseShift01)
    fns = fieldnames(IR.CPhaseShift01)
    args = arg_gen(x, fns)
    return pyjaqcd.CPhaseShift01(; args...)
end
function Py(x::CPhaseShift01)
    fns = fieldnames(CPhaseShift01)
    args = arg_gen(x, fns)
    return pygates.CPhaseShift01(; args...)
end
function Py(x::IR.CPhaseShift10)
    fns = fieldnames(IR.CPhaseShift10)
    args = arg_gen(x, fns)
    return pyjaqcd.CPhaseShift10(; args...)
end
function Py(x::CPhaseShift10)
    fns = fieldnames(CPhaseShift10)
    args = arg_gen(x, fns)
    return pygates.CPhaseShift10(; args...)
end
function Py(x::IR.XX)
    fns = fieldnames(IR.XX)
    args = arg_gen(x, fns)
    return pyjaqcd.XX(; args...)
end
function Py(x::XX)
    fns = fieldnames(XX)
    args = arg_gen(x, fns)
    return pygates.XX(; args...)
end
function Py(x::IR.YY)
    fns = fieldnames(IR.YY)
    args = arg_gen(x, fns)
    return pyjaqcd.YY(; args...)
end
function Py(x::YY)
    fns = fieldnames(YY)
    args = arg_gen(x, fns)
    return pygates.YY(; args...)
end
function Py(x::IR.ZZ)
    fns = fieldnames(IR.ZZ)
    args = arg_gen(x, fns)
    return pyjaqcd.ZZ(; args...)
end
function Py(x::ZZ)
    fns = fieldnames(ZZ)
    args = arg_gen(x, fns)
    return pygates.ZZ(; args...)
end
function Py(x::IR.H)
    fns = fieldnames(IR.H)
    args = arg_gen(x, fns)
    return pyjaqcd.H(; args...)
end
function Py(x::H)
    fns = fieldnames(H)
    args = arg_gen(x, fns)
    return pygates.H(; args...)
end
function Py(x::IR.I)
    fns = fieldnames(IR.I)
    args = arg_gen(x, fns)
    return pyjaqcd.I(; args...)
end
function Py(x::I)
    fns = fieldnames(I)
    args = arg_gen(x, fns)
    return pygates.I(; args...)
end
function Py(x::IR.X)
    fns = fieldnames(IR.X)
    args = arg_gen(x, fns)
    return pyjaqcd.X(; args...)
end
function Py(x::X)
    fns = fieldnames(X)
    args = arg_gen(x, fns)
    return pygates.X(; args...)
end
function Py(x::IR.Y)
    fns = fieldnames(IR.Y)
    args = arg_gen(x, fns)
    return pyjaqcd.Y(; args...)
end
function Py(x::Y)
    fns = fieldnames(Y)
    args = arg_gen(x, fns)
    return pygates.Y(; args...)
end
function Py(x::IR.Z)
    fns = fieldnames(IR.Z)
    args = arg_gen(x, fns)
    return pyjaqcd.Z(; args...)
end
function Py(x::Z)
    fns = fieldnames(Z)
    args = arg_gen(x, fns)
    return pygates.Z(; args...)
end
function Py(x::IR.S)
    fns = fieldnames(IR.S)
    args = arg_gen(x, fns)
    return pyjaqcd.S(; args...)
end
function Py(x::S)
    fns = fieldnames(S)
    args = arg_gen(x, fns)
    return pygates.S(; args...)
end
function Py(x::IR.Si)
    fns = fieldnames(IR.Si)
    args = arg_gen(x, fns)
    return pyjaqcd.Si(; args...)
end
function Py(x::Si)
    fns = fieldnames(Si)
    args = arg_gen(x, fns)
    return pygates.Si(; args...)
end
function Py(x::IR.T)
    fns = fieldnames(IR.T)
    args = arg_gen(x, fns)
    return pyjaqcd.T(; args...)
end
function Py(x::T)
    fns = fieldnames(T)
    args = arg_gen(x, fns)
    return pygates.T(; args...)
end
function Py(x::IR.Ti)
    fns = fieldnames(IR.Ti)
    args = arg_gen(x, fns)
    return pyjaqcd.Ti(; args...)
end
function Py(x::Ti)
    fns = fieldnames(Ti)
    args = arg_gen(x, fns)
    return pygates.Ti(; args...)
end
function Py(x::IR.V)
    fns = fieldnames(IR.V)
    args = arg_gen(x, fns)
    return pyjaqcd.V(; args...)
end
function Py(x::V)
    fns = fieldnames(V)
    args = arg_gen(x, fns)
    return pygates.V(; args...)
end
function Py(x::IR.Vi)
    fns = fieldnames(IR.Vi)
    args = arg_gen(x, fns)
    return pyjaqcd.Vi(; args...)
end
function Py(x::Vi)
    fns = fieldnames(Vi)
    args = arg_gen(x, fns)
    return pygates.Vi(; args...)
end
function Py(x::IR.CNot)
    fns = fieldnames(IR.CNot)
    args = arg_gen(x, fns)
    return pyjaqcd.CNot(; args...)
end
function Py(x::CNot)
    fns = fieldnames(CNot)
    args = arg_gen(x, fns)
    return pygates.CNot(; args...)
end
function Py(x::IR.Swap)
    fns = fieldnames(IR.Swap)
    args = arg_gen(x, fns)
    return pyjaqcd.Swap(; args...)
end
function Py(x::Swap)
    fns = fieldnames(Swap)
    args = arg_gen(x, fns)
    return pygates.Swap(; args...)
end
function Py(x::IR.ISwap)
    fns = fieldnames(IR.ISwap)
    args = arg_gen(x, fns)
    return pyjaqcd.ISwap(; args...)
end
function Py(x::ISwap)
    fns = fieldnames(ISwap)
    args = arg_gen(x, fns)
    return pygates.ISwap(; args...)
end
function Py(x::IR.CV)
    fns = fieldnames(IR.CV)
    args = arg_gen(x, fns)
    return pyjaqcd.CV(; args...)
end
function Py(x::CV)
    fns = fieldnames(CV)
    args = arg_gen(x, fns)
    return pygates.CV(; args...)
end
function Py(x::IR.CY)
    fns = fieldnames(IR.CY)
    args = arg_gen(x, fns)
    return pyjaqcd.CY(; args...)
end
function Py(x::CY)
    fns = fieldnames(CY)
    args = arg_gen(x, fns)
    return pygates.CY(; args...)
end
function Py(x::IR.CZ)
    fns = fieldnames(IR.CZ)
    args = arg_gen(x, fns)
    return pyjaqcd.CZ(; args...)
end
function Py(x::CZ)
    fns = fieldnames(CZ)
    args = arg_gen(x, fns)
    return pygates.CZ(; args...)
end
function Py(x::IR.ECR)
    fns = fieldnames(IR.ECR)
    args = arg_gen(x, fns)
    return pyjaqcd.ECR(; args...)
end
function Py(x::ECR)
    fns = fieldnames(ECR)
    args = arg_gen(x, fns)
    return pygates.ECR(; args...)
end
function Py(x::IR.CCNot)
    fns = fieldnames(IR.CCNot)
    args = arg_gen(x, fns)
    return pyjaqcd.CCNot(; args...)
end
function Py(x::CCNot)
    fns = fieldnames(CCNot)
    args = arg_gen(x, fns)
    return pygates.CCNot(; args...)
end
function Py(x::IR.CSwap)
    fns = fieldnames(IR.CSwap)
    args = arg_gen(x, fns)
    return pyjaqcd.CSwap(; args...)
end
function Py(x::CSwap)
    fns = fieldnames(CSwap)
    args = arg_gen(x, fns)
    return pygates.CSwap(; args...)
end
function Py(x::IR.Unitary)
    fns = fieldnames(IR.Unitary)
    args = arg_gen(x, fns)
    return pyjaqcd.Unitary(; args...)
end
function Py(x::Unitary)
    fns = fieldnames(Unitary)
    args = arg_gen(x, fns)
    return pygates.Unitary(; args...)
end
