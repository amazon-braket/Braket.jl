function Py(x::IR.BitFlip)
    fns = fieldnames(IR.BitFlip)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.BitFlip(; args...)
end
function Py(x::BitFlip)
    fns = fieldnames(BitFlip)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.BitFlip(; args...)
end
function Py(x::IR.PhaseDamping)
    fns = fieldnames(IR.PhaseDamping)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.PhaseDamping(; args...)
end
function Py(x::PhaseDamping)
    fns = fieldnames(PhaseDamping)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.PhaseDamping(; args...)
end
function Py(x::IR.TwoQubitDepolarizing)
    fns = fieldnames(IR.TwoQubitDepolarizing)
    args = arg_gen(x, fns)
    return pyjaqcd.TwoQubitDepolarizing(; args...)
end
function Py(x::TwoQubitDepolarizing)
    fns = fieldnames(TwoQubitDepolarizing)
    args = (fn=>Py(getproperty(x, fn)) for fn in fns)
    return pynoises.TwoQubitDepolarizing(; args...)
end
function Py(x::IR.PauliChannel)
    fns = fieldnames(IR.PauliChannel)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.PauliChannel(; args...)
end
function Py(x::PauliChannel)
    fns = fieldnames(PauliChannel)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.PauliChannel(; args...)
end
function Py(x::IR.Kraus)
    fns = fieldnames(IR.Kraus)
    args = arg_gen(x, fns)
    return pyjaqcd.Kraus(; args...)
end
function Py(x::Kraus)
    fns = fieldnames(Kraus)
    args = (fn=>Py(getproperty(x, fn)) for fn in fns)
    return pynoises.Kraus(; args...)
end
function Py(x::IR.MultiQubitPauliChannel)
    fns = fieldnames(IR.MultiQubitPauliChannel)
    args = arg_gen(x, fns)
    return pyjaqcd.MultiQubitPauliChannel(; args...)
end
function Py(x::TwoQubitPauliChannel)
    fns = fieldnames(TwoQubitPauliChannel)
    args = arg_gen(x, fns)
    return pynoises.TwoQubitPauliChannel(; args...)
end
function Py(x::IR.Depolarizing)
    fns = fieldnames(IR.Depolarizing)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.Depolarizing(; args...)
end
function Py(x::Depolarizing)
    fns = fieldnames(Depolarizing)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.Depolarizing(; args...)
end
function Py(x::IR.AmplitudeDamping)
    fns = fieldnames(IR.AmplitudeDamping)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.AmplitudeDamping(; args...)
end
function Py(x::AmplitudeDamping)
    fns = fieldnames(AmplitudeDamping)
    args = (fn=>Py(getproperty(x, fn)) for fn in fns)
    return pynoises.AmplitudeDamping(; args...)
end
function Py(x::IR.TwoQubitDephasing)
    fns = fieldnames(IR.TwoQubitDephasing)
    args = arg_gen(x, fns)
    return pyjaqcd.TwoQubitDephasing(; args...)
end
function Py(x::TwoQubitDephasing)
    fns = fieldnames(TwoQubitDephasing)
    args = (fn=>Py(getproperty(x, fn)) for fn in fns)
    return pynoises.TwoQubitDephasing(; args...)
end
function Py(x::IR.GeneralizedAmplitudeDamping)
    fns = fieldnames(IR.GeneralizedAmplitudeDamping)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.GeneralizedAmplitudeDamping(; args...)
end
function Py(x::GeneralizedAmplitudeDamping)
    fns = fieldnames(GeneralizedAmplitudeDamping)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.GeneralizedAmplitudeDamping(; args...)
end
function Py(x::IR.PhaseFlip)
    fns = fieldnames(IR.PhaseFlip)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pyjaqcd.PhaseFlip(; args...)
end
function Py(x::PhaseFlip)
    fns = fieldnames(PhaseFlip)
    args = (fn=>getproperty(x, fn) for fn in fns)
    return pynoises.PhaseFlip(; args...)
end
