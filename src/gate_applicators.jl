for (G, IRG) in zip((:H,:I,:X,:Y,:Z,:S,:Si,:T,:Ti,:V,:Vi,:CNot,:Swap,:ISwap,:CV,:CY,:CZ,:ECR,:CCNot,:CSwap,:Unitary,:Rx,:Ry,:Rz,:PhaseShift,:PSwap,:XY,:CPhaseShift,:CPhaseShift00,:CPhaseShift01,:CPhaseShift10,:XX,:YY,:ZZ,:GPi,:GPi2,:MS), (:(IR.H), :(IR.I), :(IR.X), :(IR.Y), :(IR.Z), :(IR.S), :(IR.Si), :(IR.T), :(IR.Ti), :(IR.V), :(IR.Vi), :(IR.CNot), :(IR.Swap), :(IR.ISwap), :(IR.CV), :(IR.CY), :(IR.CZ), :(IR.ECR), :(IR.CCNot), :(IR.CSwap), :(IR.Unitary), :(IR.Rx), :(IR.Ry), :(IR.Rz), :(IR.PhaseShift), :(IR.PSwap), :(IR.XY), :(IR.CPhaseShift), :(IR.CPhaseShift00), :(IR.CPhaseShift01), :(IR.CPhaseShift10), :(IR.XX), :(IR.YY), :(IR.ZZ), :(IR.GPi), :(IR.GPi2), :(IR.MS)))
    @eval begin
        $G(c::Circuit, args...) = apply_gate!(IR.Angle($IRG), IR.Control($IRG), IR.Target($IRG), $G, c, args...)
        apply_gate!(::Type{$G}, c::Circuit, args...) = apply_gate!(IR.Angle($IRG), IR.Control($IRG), IR.Target($IRG), $G, c, args...)
    end
end
apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, arg::IntOrQubit)   where {G<:Gate} = add_instruction!(c, Instruction(G(), arg))
apply_gate!(::IR.Angled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, arg::IntOrQubit, angle)   where {G<:Gate} = add_instruction!(c, Instruction(G(angle), arg))
apply_gate!(::IR.DoubleAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, arg::IntOrQubit, angle1, angle2)   where {G<:Gate} = add_instruction!(c, Instruction(G(angle1, angle2), arg))
apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, arg::VecOrQubitSet) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(), i)), arg); return c)
apply_gate!(::IR.Angled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, v::VecOrQubitSet, angle) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(angle), i)), v); return c)
apply_gate!(::IR.DoubleAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, v::VecOrQubitSet, angle1, angle2) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(angle1, angle2), i)), v); return c)

apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(), i)), args); return c)
apply_gate!(::IR.Angled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(args[end]), i)), args[1:end-1]); return c)
apply_gate!(::IR.DoubleAngled, ::IR.NoControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction(G(args[end-1], args[end]), i)), args[1:end-2]); return c)

apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet) where {G<:Gate} = add_instruction!(c, Instruction(G(), args[1:2]))
apply_gate!(::IR.Angled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle) where {G<:Gate} = add_instruction!(c, Instruction(G(angle), args[1:2]))
apply_gate!(::IR.DoubleAngled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle1, angle2) where {G<:Gate} = add_instruction!(c, Instruction(G(angle1, angle2), args[1:2]))

apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(), [args[1:2]...]))
apply_gate!(::IR.Angled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end]), [args[1:2]...]))
apply_gate!(::IR.DoubleAngled, ::IR.NoControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end-1], args[end]), [args[1:2]...]))

apply_gate!(::IR.NonAngled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet) where {G<:Gate} = add_instruction!(c, Instruction(G(), args[1:2]))
apply_gate!(::IR.Angled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle) where {G<:Gate} = add_instruction!(c, Instruction(G(angle), args[1:2]))
apply_gate!(::IR.DoubleAngled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle1, angle2) where {G<:Gate} = add_instruction!(c, Instruction(G(angle1, angle2), args[1:2]))

apply_gate!(::IR.NonAngled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(), [args[1:2]...]))
apply_gate!(::IR.Angled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end]), [args[1:2]...]))
apply_gate!(::IR.DoubleAngled, ::IR.SingleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end-1], args[end]), [args[1:2]...]))

apply_gate!(::IR.NonAngled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet) where {G<:Gate} = add_instruction!(c, Instruction(G(), args[1:3]))
apply_gate!(::IR.Angled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle) where {G<:Gate} = add_instruction!(c, Instruction(G(angle), args[1:3]))
apply_gate!(::IR.DoubleAngled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle1, angle2) where {G<:Gate} = add_instruction!(c, Instruction(G(angle1, angle2), args[1:3]))

apply_gate!(::IR.NonAngled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(), [args[1:3]...]))
apply_gate!(::IR.Angled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end]), [args[1:3]...]))
apply_gate!(::IR.DoubleAngled, ::IR.SingleControl, ::IR.DoubleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end-1], args[end]), [args[1:3]...]))

apply_gate!(::IR.NonAngled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet) where {G<:Gate} = add_instruction!(c, Instruction(G(), args[1:3]))
apply_gate!(::IR.Angled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle) where {G<:Gate} = add_instruction!(c, Instruction(G(angle), args[1:3]))
apply_gate!(::IR.DoubleAngled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle1, angle2) where {G<:Gate} = add_instruction!(c, Instruction(G(angle1, angle2), args[1:3]))

apply_gate!(::IR.NonAngled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(), [args[1:3]...]))
apply_gate!(::IR.Angled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end]), [args[1:3]...]))
apply_gate!(::IR.DoubleAngled, ::IR.DoubleControl, ::IR.SingleTarget, ::Type{G}, c::Circuit, args...) where {G<:Gate} = add_instruction!(c, Instruction(G(args[end-1], args[end]), [args[1:3]...]))

apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.MultiTarget, ::Type{Unitary}, c::Circuit, v::VecOrQubitSet, m::Matrix{ComplexF64}) = add_instruction!(c, Instruction(Unitary(m), v))
apply_gate!(::IR.NonAngled, ::IR.NoControl, ::IR.MultiTarget, ::Type{Unitary}, c::Circuit, args...) = add_instruction!(c, Instruction(Unitary(args[end]), [args[1:end-1]...]))
