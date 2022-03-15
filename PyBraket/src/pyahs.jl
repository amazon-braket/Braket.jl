
function Py(x::Braket.IR.AhsProgram)
    fns = filter(n->!(n==:braketSchemaHeader), fieldnames(IR.AhsProgram))
    args = arg_gen(x, fns)
    return pyahs.Program(; args...)
end

for (IRT, PYT) in (
                   (:(Braket.IR.TimeSeries), :(pyahs.TimeSeries)),
                   (:(Braket.IR.AtomArrangement), :(pyahs.AtomArrangement)),
                   (:(Braket.IR.ShiftingField), :(pyahs.ShiftingField)),
                   (:(Braket.IR.DrivingField), :(pyahs.DrivingField)),
                   (:(Braket.IR.PhysicalField), :(pyahs.PhysicalField)),
                   (:(Braket.IR.Hamiltonian), :(pyahs.Hamiltonian)),
                   (:(Braket.IR.Setup), :(pyahs.Setup))
                  )
    @eval begin
        function Py(x::$IRT)
            fns = fieldnames($IRT)
            args = arg_gen(x, fns)
            return $PYT(; args...)
        end
    end
end
