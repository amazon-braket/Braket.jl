@inline function pad_bit(amp_index::Ti, t::Tj)::Ti where {Ti<:Integer,Tj<:Integer}
    left = (amp_index >> t) << t
    right = amp_index - left
    return (left << one(Ti)) ⊻ right
end
function pad_bits(ix::Ti, to_pad)::Ti where {Ti<:Integer}
    padded_ix = ix
    for bit in to_pad
        padded_ix = pad_bit(padded_ix, bit)
    end
    return padded_ix
end

@inline function flip_bit(amp_index::Ti, t::Tj)::Ti where {Ti<:Integer,Tj<:Integer}
    return amp_index ⊻ (one(Ti) << t)
end
function flip_bits(ix::Ti, to_flip)::Ti where {Ti<:Integer}
    flipped_ix = ix
    for f_val in to_flip
        flipped_ix = flip_bit(flipped_ix, f_val)
    end
    return flipped_ix
end
@inline endian_qubits(nq::Int, qubit::Int) = nq - 1 - qubit
@inline endian_qubits(nq::Int, qubits::Int...) = nq .- 1 .- qubits
@inline function get_amps_and_qubits(state_vec::AbstractStateVector, qubits::Int...)
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    return n_amps, endian_qubits(nq, qubits...)
end

matrix_rep(g::H) = SMatrix{2,2}(complex((1 / √2) * [1.0 1.0; 1.0 -1.0]))
matrix_rep(g::X) = SMatrix{2,2}(complex([0.0 1.0; 1.0 0.0]))
matrix_rep(g::Y) = SMatrix{2,2}(complex([0.0 -im; im 0.0]))
matrix_rep(g::Z) = SMatrix{2,2}(complex([1.0 0.0; 0.0 -1.0]))
matrix_rep(g::I) = SMatrix{2,2}(complex([1.0 0.0; 0.0 1.0]))
matrix_rep(g::V) = SMatrix{2,2}(0.5 * [1.0+im 1.0-im; 1.0-im 1.0+im])
matrix_rep(g::Vi) = SMatrix{2,2}(0.5 * [1.0-im 1.0+im; 1.0+im 1.0-im])
matrix_rep(g::S) = SMatrix{2,2}([1.0 0.0; 0.0 im])
matrix_rep(g::Si) = SMatrix{2,2}([1.0 0.0; 0.0 -im])
matrix_rep(g::T) = SMatrix{2,2}([1.0 0.0; 0.0 exp(im * π / 4.0)])
matrix_rep(g::Ti) = SMatrix{2,2}([1.0 0.0; 0.0 exp(-im * π / 4.0)])

matrix_rep(g::Rz) =
    SMatrix{2,2}([exp(-im * g.angle[1] / 2.0) 0.0; 0.0 exp(im * g.angle[1] / 2.0)])
matrix_rep(g::Rx) = SMatrix{2,2}(
    [
        cos(g.angle[1] / 2.0) -im*sin(g.angle[1] / 2.0)
        -im*sin(g.angle[1] / 2.0) cos(g.angle[1] / 2.0)
    ],
)
matrix_rep(g::Ry) = SMatrix{2,2}(
    complex(
        [
            cos(g.angle[1] / 2.0) -sin(g.angle[1] / 2.0)
            sin(g.angle[1] / 2.0) cos(g.angle[1] / 2.0)
        ],
    ),
)

matrix_rep(g::PhaseShift) = SMatrix{2,2}([1.0 0.0; 0.0 exp(im * g.angle[1])])
matrix_rep(g::XX) = SMatrix{4,4}(
    [
        cos(g.angle[1] / 2.0) 0.0 0.0 -im*sin(g.angle[1] / 2)
        0.0 cos(g.angle[1] / 2.0) -im*sin(g.angle[1] / 2.0) 0.0
        0.0 -im*sin(g.angle[1] / 2.0) cos(g.angle[1] / 2.0) 0.0
        -im*sin(g.angle[1] / 2.0) 0.0 0.0 cos(g.angle[1] / 2.0)
    ],
)
matrix_rep(g::XY) = SMatrix{4,4}(
    [
        1.0 0.0 0.0 0.0
        0.0 cos(g.angle[1] / 2.0) im*sin(g.angle[1] / 2.0) 0.0
        0.0 im*sin(g.angle[1] / 2.0) cos(g.angle[1] / 2.0) 0.0
        0.0 0.0 0.0 1.0
    ],
)
matrix_rep(g::YY) = SMatrix{4,4}(
    [
        cos(g.angle[1] / 2.0) 0.0 0.0 im*sin(g.angle[1] / 2)
        0.0 cos(g.angle[1] / 2.0) -im*sin(g.angle[1] / 2.0) 0.0
        0.0 -im*sin(g.angle[1] / 2.0) cos(g.angle[1] / 2.0) 0.0
        im*sin(g.angle[1] / 2.0) 0.0 0.0 cos(g.angle[1] / 2.0)
    ],
)
matrix_rep(g::ZZ) = SMatrix{4,4}(
    diagm([
        exp(-im * g.angle[1] / 2.0),
        exp(im * g.angle[1] / 2.0),
        exp(im * g.angle[1] / 2.0),
        exp(-im * g.angle[1] / 2.0),
    ]),
)
matrix_rep(g::ECR) =
    SMatrix{4,4}([0.0 0.0 1.0 im; 0.0 0.0 im 1.0; 1.0 -im 0.0 0.0; -im 1.0 0.0 0.0])
matrix_rep(g::Unitary) = g.matrix

apply_gate!(
    ::Val{V},
    g::I,
    state_vec::AbstractStateVector{T},
    qubit::Int,
) where {V,T<:Complex} = return

apply_gate!(g::Gate, args...) = apply_gate!(Val(false), g, args...)

for (G, g_mat) in (
        (:X, matrix_rep(X())),
        (:Y, matrix_rep(Y())),
        (:Z, matrix_rep(Z())),
        (:H, matrix_rep(H())),
        (:V, matrix_rep(V())),
        (:Vi, matrix_rep(Vi())),
        (:S, matrix_rep(S())),
        (:Si, matrix_rep(Si())),
        (:T, matrix_rep(T())),
        (:Ti, matrix_rep(Ti())),
    ),
    (is_conj, g00, g10, g01, g11) in ((false, g_mat...), (true, conj.(g_mat)...))

    @eval begin
        @inline gate_kernel(
            ::Val{$is_conj},
            ::Val{:lower},
            g::$G,
            lower_amp::Tv,
            higher_amp::Tv,
        ) where {Tv<:Complex} = $g00 * lower_amp + $g01 * higher_amp
        @inline gate_kernel(
            ::Val{$is_conj},
            ::Val{:higher},
            g::$G,
            lower_amp::Tv,
            higher_amp::Tv,
        ) where {Tv<:Complex} = $g10 * lower_amp + $g11 * higher_amp
    end
end
gate_kernel(::Val{V}, g::Unitary, lower_amp::Tv, higher_amp::Tv) where {V,Tv<:Complex} =
    gate_kernel(
        Val(V),
        SMatrix{2,2,ComplexF64}(g.matrix),
        SVector{2,ComplexF64}(lower_amp, higher_amp),
    )

# single target
# use this to avoid hitting generalized Unitary
function apply_gate_single_target!(
    ::Val{V},
    g::G,
    state_vec::AbstractStateVector{T},
    qubit::Int,
) where {V,G<:Gate,T<:Complex}
    n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
    Threads.@threads for ix = 0:div(n_amps, 2)-1
        lower_ix = pad_bit(ix, endian_qubit)
        higher_ix = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix += 1
        @inbounds begin
            lower_amp = state_vec[lower_ix]
            higher_amp = state_vec[higher_ix]
            state_vec[lower_ix] = gate_kernel(Val(V), Val(:lower), g, lower_amp, higher_amp)
            state_vec[higher_ix] =
                gate_kernel(Val(V), Val(:higher), g, lower_amp, higher_amp)
        end
    end
end

# getindex on Tuples is really slow if you do it repeatedly inside a loop!
for G in (:PhaseShift, :Rx, :Ry, :Rz), (is_conj, f) in ((true, :conj), (false, :identity))
    @eval begin
        function apply_gate_single_target!(
            ::Val{$is_conj},
            g::$G,
            state_vec::AbstractStateVector{T},
            qubit::Int,
        ) where {T<:Complex}
            n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
            g_mat = $f(matrix_rep(g))
            g00, g10, g01, g11 = g_mat
            Threads.@threads for ix = 0:div(n_amps, 2)-1
                lower_ix = pad_bit(ix, endian_qubit)
                higher_ix = flip_bit(lower_ix, endian_qubit) + 1
                lower_ix += 1
                @inbounds begin
                    lower_amp = state_vec[lower_ix]
                    higher_amp = state_vec[higher_ix]
                    state_vec[lower_ix] = g00 * lower_amp + g01 * higher_amp
                    state_vec[higher_ix] = g10 * lower_amp + g11 * higher_amp
                end
            end
        end
    end
end
apply_gate!(
    ::Val{V},
    g::G,
    state_vec::AbstractStateVector{T},
    qubit::Int,
) where {V,G<:Gate,T<:Complex} = apply_gate_single_target!(Val(V), g, state_vec, qubit)
apply_gate!(
    ::Val{V},
    g::Unitary,
    state_vec::AbstractStateVector{T},
    qubit::Int,
) where {V,T<:Complex} = apply_gate_single_target!(Val(V), g, state_vec, qubit)

# generic two-qubit non controlled unitaries
function apply_gate!(
    ::Val{V},
    g::G,
    state_vec::StateVector{T},
    t1::Int,
    t2::Int,
) where {V,G<:Gate,T<:Complex}
    g_mat = matrix_rep(g)
    n_amps, (endian_t1, endian_t2) = get_amps_and_qubits(state_vec, t1, t2)
    small_t, big_t = minmax(endian_t1, endian_t2)
    Threads.@threads for ix = 0:div(n_amps, 4)-1
        # bit shift to get indices
        ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
        ix_10 = flip_bit(ix_00, endian_t2)
        ix_01 = flip_bit(ix_00, endian_t1)
        ix_11 = flip_bit(ix_10, endian_t1)
        ind_vec = SVector(ix_00 + 1, ix_01 + 1, ix_10 + 1, ix_11 + 1)
        @views begin
            @inbounds begin
                amps = SVector{4, T}(state_vec[ind_vec])
                state_vec[ind_vec] = gate_kernel(Val(V), g_mat, amps)
            end
        end
    end
    return
end
# arbitrary vector type to support views
gate_kernel(::Val{true}, g_mat::SMatrix{N,N,T}, s_vec::V) where {N,T,V} =
    conj(g_mat) * s_vec
gate_kernel(::Val{false}, g_mat::SMatrix{N,N,T}, s_vec::V) where {N,T,V} = g_mat * s_vec
gate_kernel(::Val{true}, g_diag::SVector{N,T}, s_vec::V) where {N,T,V} =
    conj(g_diag) .* s_vec
gate_kernel(::Val{false}, g_diag::SVector{N,T}, s_vec::V) where {N,T,V} = g_diag .* s_vec

# controlled unitaries
for (cph, ind) in
    ((:CPhaseShift, 4), (:CPhaseShift00, 1), (:CPhaseShift01, 3), (:CPhaseShift10, 2))
    @eval begin
        matrix_rep(g::$cph) = SVector{4,ComplexF64}(
            setindex!(ones(ComplexF64, 4), exp(im * g.angle[1]), $ind),
        )
    end
end

for (sw, factor) in ((:Swap, 1.0), (:ISwap, im), (:PSwap, :(exp(im * g.angle[1]))))
    @eval begin
        matrix_rep(g::$sw) = SMatrix{4,4,ComplexF64}(
            [1.0 0.0 0.0 0.0 0.0 0.0 $factor 0.0 0.0 $factor 0.0 0.0 0.0 0.0 0.0 1.0],
        )
    end
end

function apply_controlled_gate!(
    ::Val{V},
    ::Val{1},
    g::G,
    tg::TG,
    state_vec::AbstractStateVector{T},
    control::Int,
    target::Int,
) where {V,G<:Gate,TG<:Gate,T<:Complex}
    n_amps, (endian_control, endian_target) =
        get_amps_and_qubits(state_vec, control, target)
    small_t, big_t = minmax(endian_control, endian_target)
    Threads.@threads for ix = 0:div(n_amps, 4)-1
        ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
        ix_10 = flip_bit(ix_00, endian_control)
        ix_01 = flip_bit(ix_00, endian_target)
        ix_11 = flip_bit(ix_01, endian_control)
        lower_ix = ix_10 + 1
        higher_ix = ix_11 + 1
        @inbounds begin
            lower_amp  = state_vec[lower_ix]
            higher_amp = state_vec[higher_ix]
            state_vec[lower_ix] =
                gate_kernel(Val(V), Val(:lower), tg, lower_amp, higher_amp)
            state_vec[higher_ix] =
                gate_kernel(Val(V), Val(:higher), tg, lower_amp, higher_amp)
        end
    end
    return
end
function apply_controlled_gate!(
    ::Val{V},
    ::Val{1},
    g::G,
    tg::TG,
    state_vec::AbstractStateVector{T},
    control::Int,
    t1::Int,
    t2::Int,
) where {V,G<:Gate,TG<:Gate,T<:Complex}
    tg_mat = matrix_rep(tg)
    n_amps, (endian_control, endian_t1, endian_t2) =
        get_amps_and_qubits(state_vec, control, t1, t2)
    small_t, mid_t, big_t = sort([endian_control, endian_t1, endian_t2])
    Threads.@threads for ix = 0:div(n_amps, 8)-1
        ix_00 = flip_bit(pad_bits(ix, [small_t, mid_t, big_t]), endian_control)
        ix_10 = flip_bit(ix_00, endian_t2)
        ix_01 = flip_bit(ix_00, endian_t1)
        ix_11 = flip_bit(ix_01, endian_t2)
        ix_vec = SVector{4,Int}(ix_00 + 1, ix_01 + 1, ix_10 + 1, ix_11 + 1)
        @views begin
            @inbounds begin
                amps = SVector{4, T}(state_vec[ix_vec])
                state_vec[ix_vec] = gate_kernel(Val(V), tg_mat, amps)
            end
        end
    end
    return
end

# doubly controlled unitaries
function apply_controlled_gate!(
    ::Val{V},
    ::Val{2},
    g::G,
    tg::TG,
    state_vec::AbstractStateVector{T},
    c1::Int,
    c2::Int,
    t::Int,
) where {V,G<:Gate,TG<:Gate,T<:Complex}
    n_amps, (endian_c1, endian_c2, endian_target) =
        get_amps_and_qubits(state_vec, c1, c2, t)
    small_t, mid_t, big_t = sort([endian_c1, endian_c2, endian_target])
    Threads.@threads for ix = 0:div(n_amps, 8)-1
        # insert 0 at c1, 0 at c2, 0 at target
        padded_ix = pad_bits(ix, [small_t, mid_t, big_t])
        # flip c1 and c2
        lower_ix = flip_bit(flip_bit(padded_ix, endian_c1), endian_c2)
        # flip target
        higher_ix = flip_bit(lower_ix, endian_target) + 1
        lower_ix += 1
        @inbounds begin
            lower_amp = state_vec[lower_ix]
            higher_amp = state_vec[higher_ix]
            state_vec[lower_ix] =
                gate_kernel(Val(V), Val(:lower), tg, lower_amp, higher_amp)
            state_vec[higher_ix] =
                gate_kernel(Val(V), Val(:higher), tg, lower_amp, higher_amp)
        end
    end
    return
end

for (cg, tg, nc) in (
    (:CNot, :X, 1),
    (:CY, :Y, 1),
    (:CZ, :Z, 1),
    (:CV, :V, 1),
    (:CSwap, :Swap, 1),
    (:CCNot, :X, 2),
)
    @eval begin
        apply_gate!(
            ::Val{Vc},
            g::$cg,
            state_vec::StateVector{T},
            qubits::Int...,
        ) where {Vc,T<:Complex} =
            apply_controlled_gate!(Val(Vc), Val($nc), g, $tg(), state_vec, qubits...)
    end
end

# arbitrary number of targets
function apply_gate!(
    ::Val{V},
    g::Unitary,
    state_vec::StateVector{T},
    ts::Vararg{Int,NQ},
) where {V,T<:Complex,NQ}
    n_amps, endian_ts = get_amps_and_qubits(state_vec, ts...)
    endian_ts isa Int && (endian_ts = (endian_ts,))
    ordered_ts = sort(collect(endian_ts))
    nq = NQ
    g_mat = SMatrix{2^nq,2^nq,ComplexF64}(matrix_rep(g))
    flip_list = map(0:2^nq-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:nq-1]
        return ordered_ts[f_vals]
    end
    Threads.@threads for ix = 0:div(n_amps, 2^nq)-1
        padded_ix = pad_bits(ix, ordered_ts)
        ixs = SVector{2^nq,Int}(flip_bits(padded_ix, f) + 1 for f in flip_list)
        @views begin
            @inbounds begin
                amps = SVector{2^NQ, T}(state_vec[ixs])
                new_amps = gate_kernel(Val(V), g_mat, amps)
                state_vec[ixs] = new_amps
            end
        end
    end
    return
end
