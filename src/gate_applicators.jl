(::Type{G})(c::Circuit) where {G<:Gate} = throw(ArgumentError("gate applied to a circuit must have targets.")) 
(::Type{G})(c::Circuit, args...) where {G<:Gate} = apply_gate!(Val(n_angles(G)), n_controls(G), n_targets(G), G, c, args...)
(::Type{Unitary})(c::Circuit, args...) = apply_gate!(Unitary, c, args...)
apply_gate!(::Type{G}, c::Circuit, args...) where {G<:Gate} = apply_gate!(Val(n_angles(G)), n_controls(G), n_targets(G), G, c, args...)

apply_gate!(::Val{N}, ::Val{0}, ::Val{1}, ::Type{G}, c::Circuit, args...) where {G<:Gate, N} = (foreach(i->add_instruction!(c, Instruction{G}(G(args[end-(N-1):end]), i)), args[1:end-N]); return c)
apply_gate!(::Val{0}, ::Val{0}, ::Val{1}, ::Type{G}, c::Circuit, args::IntOrQubit...) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction{G}(G(), i)), args); return c)
apply_gate!(::Val{0}, ::Val{0}, ::Val{1}, ::Type{G}, c::Circuit, args::VecOrQubitSet) where {G<:Gate} = (foreach(i->add_instruction!(c, Instruction{G}(G(), i)), args); return c)
apply_gate!(::Val{N}, ::Val{0}, ::Val{1}, ::Type{G}, c::Circuit, args::VecOrQubitSet, angles::Union{Real, FreeParameter}...) where {N, G<:Gate} = (foreach(i->add_instruction!(c, Instruction{G}(G(tuple(angles[1:N]...)), i)), args); return c)

apply_gate!(::Val{N}, ::Val{0}, ::Val{2}, ::Type{G}, c::Circuit, t1::IntOrQubit, t2::IntOrQubit, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), [t1, t2]))
apply_gate!(::Val{N}, ::Val{0}, ::Val{2}, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), args[1:2]))
apply_gate!(::Val{N}, ::Val{0}, ::Val{2}, ::Type{G}, c::Circuit, args::NTuple{2, Ti}, angle::Union{Real, FreeParameter}...) where {G<:Gate, N, Ti} = add_instruction!(c, Instruction{G}(G(angle), args[1:2]))

apply_gate!(::Val{N}, ::Val{1}, ::Val{1}, ::Type{G}, c::Circuit, ci::IntOrQubit, ti::IntOrQubit, angles::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angles), [ci, ti]))
apply_gate!(::Val{N}, ::Val{1}, ::Val{1}, ::Type{G}, c::Circuit, args::VecOrQubitSet, angles::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angles), args[1:2]))
apply_gate!(::Val{N}, ::Val{1}, ::Val{1}, ::Type{G}, c::Circuit, args::NTuple{2, Ti}, angles::Union{Real, FreeParameter}...) where {G<:Gate, N, Ti} = add_instruction!(c, Instruction{G}(G(angles), [args...]))

apply_gate!(::Val{N}, ::Val{1}, ::Val{2}, ::Type{G}, c::Circuit, ci::IntOrQubit, t1::IntOrQubit, t2::IntOrQubit, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), [ci, t1, t2]))
apply_gate!(::Val{N}, ::Val{1}, ::Val{2}, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), args[1:3]))
apply_gate!(::Val{N}, ::Val{1}, ::Val{2}, ::Type{G}, c::Circuit, args::NTuple{3, Ti}, angle::Union{Real, FreeParameter}...) where {G<:Gate, N, Ti} = add_instruction!(c, Instruction{G}(G(angle), [args...]))

apply_gate!(::Val{N}, ::Val{2}, ::Val{1}, ::Type{G}, c::Circuit, c1::IntOrQubit, c2::IntOrQubit, ti::IntOrQubit, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), [c1, c2, ti]))
apply_gate!(::Val{N}, ::Val{2}, ::Val{1}, ::Type{G}, c::Circuit, args::VecOrQubitSet, angle::Union{Real, FreeParameter}...) where {G<:Gate, N} = add_instruction!(c, Instruction{G}(G(angle), args[1:3]))
apply_gate!(::Val{N}, ::Val{2}, ::Val{1}, ::Type{G}, c::Circuit, args::NTuple{3, Ti}, angle::Union{Real, FreeParameter}...) where {G<:Gate, N, Ti} = add_instruction!(c, Instruction{G}(G(angle), [args...]))

apply_gate!(::Type{Unitary}, c::Circuit, v::VecOrQubitSet, m::Matrix{ComplexF64}) = add_instruction!(c, Instruction{Unitary}(Unitary(m), v))
apply_gate!(::Type{Unitary}, c::Circuit, args...) = add_instruction!(c, Instruction{Unitary}(Unitary(args[end]), [args[1:end-1]...]))
