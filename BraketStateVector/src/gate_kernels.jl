@inline function pad_bit(amp_index::Int64, t::Int64)
    left  = (amp_index >> t) << t
    right = amp_index - left
    return (left << one(Int64)) ⊻ right
end
@inline flip_bit(amp_index::Int, t::Int) = amp_index ⊻ (one(Int64) << t)

matrix_rep(g::H)  = SMatrix{2, 2}(complex((1/√2)*[1. 1.; 1. -1.]))
matrix_rep(g::X)  = SMatrix{2, 2}(complex([0. 1.; 1. 0.]))
matrix_rep(g::Y)  = SMatrix{2, 2}(complex([0. -im; im 0.]))
matrix_rep(g::Z)  = SMatrix{2, 2}(complex([1. 0.; 0. -1.]))
matrix_rep(g::I)  = SMatrix{2, 2}(complex([1. 0.; 0. 1.]))
matrix_rep(g::V)  = SMatrix{2, 2}(0.5*[1.0+im 1.0-im; 1.0-im 1.0+im])
matrix_rep(g::Vi) = SMatrix{2, 2}(0.5*[1.0-im 1.0+im; 1.0+im 1.0-im])
matrix_rep(g::S)  = SMatrix{2, 2}([1. 0.; 0. im])
matrix_rep(g::Si) = SMatrix{2, 2}([1. 0.; 0. -im])
matrix_rep(g::T)  = SMatrix{2, 2}([1. 0.; 0. exp(im*π/4.0)])
matrix_rep(g::Ti) = SMatrix{2, 2}([1. 0.; 0. exp(-im*π/4.0)])

matrix_rep(g::Rz) = SMatrix{2, 2}([exp(-im*g.angle[1]/2.0) 0.; 0. exp(im*g.angle[1]/2.0)])
matrix_rep(g::Rx) = SMatrix{2, 2}([cos(g.angle[1]/2.0) -im*sin(g.angle[1]/2.0); -im*sin(g.angle[1]/2.0) cos(g.angle[1]/2.0)])
matrix_rep(g::Ry) = SMatrix{2, 2}(complex([cos(g.angle[1]/2.0) -sin(g.angle[1]/2.0); sin(g.angle[1]/2.0) cos(g.angle[1]/2.0)]))

matrix_rep(g::PhaseShift) = SMatrix{2, 2}([1. 0.; 0. exp(im*g.angle[1])])
matrix_rep(g::XX) = SMatrix{4, 4}([cos(g.angle[1]/2.0) 0.0 0.0 -im*sin(g.angle[1]/2); 0.0 cos(g.angle[1]/2.0) -im*sin(g.angle[1]/2.0) 0.0; 0.0 -im*sin(g.angle[1]/2.0) cos(g.angle[1]/2.0) 0.0; -im*sin(g.angle[1]/2.0) 0.0 0.0 cos(g.angle[1]/2.0)])
matrix_rep(g::XY) = SMatrix{4, 4}([1.0 0.0 0.0 0.0; 0.0 cos(g.angle[1]/2.0) im*sin(g.angle[1]/2.0) 0.0; 0.0 im*sin(g.angle[1]/2.0) cos(g.angle[1]/2.0) 0.0; 0.0 0.0 0.0 1.0])
matrix_rep(g::YY) = SMatrix{4, 4}([cos(g.angle[1]/2.0) 0.0 0.0 im*sin(g.angle[1]/2); 0.0 cos(g.angle[1]/2.0) -im*sin(g.angle[1]/2.0) 0.0; 0.0 -im*sin(g.angle[1]/2.0) cos(g.angle[1]/2.0) 0.0; im*sin(g.angle[1]/2.0) 0.0 0.0 cos(g.angle[1]/2.0)])
matrix_rep(g::ZZ) = SMatrix{4, 4}(diagm([exp(-im*g.angle[1]/2.0), exp(im*g.angle[1]/2.0), exp(im*g.angle[1]/2.0), exp(-im*g.angle[1]/2.0)]))
matrix_rep(g::ECR) = SMatrix{4, 4}([0.0 0.0 1.0 im; 0.0 0.0 im 1.0; 1.0 -im 0.0 0.0; -im 1.0 0.0 0.0])
matrix_rep(g::Unitary) = g.matrix

apply_gate!(g::I, state_vec::AbstractStateVector{T}, qubit::Int) where {T} = return
apply_gate_conj!(g::I, state_vec::AbstractStateVector{T}, qubit::Int) where {T} = return

for (G, g00, g10, g01, g11) in ((:X, matrix_rep(X())...),
                                (:Y, matrix_rep(Y())...),
                                (:Z, matrix_rep(Z())...),
                                (:H, matrix_rep(H())...),
                                (:V, matrix_rep(V())...),
                                (:Vi, matrix_rep(Vi())...),
                                (:S, matrix_rep(S())...),
                                (:Si, matrix_rep(Si())...),
                                (:T, matrix_rep(T())...),
                                (:Ti, matrix_rep(Ti())...))
    @eval begin
        function apply_gate!(g::$G, state_vec::AbstractStateVector{Ty}, qubit::Int) where {Ty}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_qubit = nq-qubit-1
            Threads.@threads :static for ix in 0:div(n_amps, 2)-1
                lower_ix   = pad_bit(ix, endian_qubit)
                higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
                lower_ix  += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = $g00 * lower_amp + $g01 * higher_amp
                state_vec[higher_ix] = $g10 * lower_amp + $g11 * higher_amp
            end
            return
        end
        function apply_gate_conj!(g::$G, state_vec::AbstractStateVector{Ty}, qubit::Int) where {Ty}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_qubit = nq-qubit-1
            Threads.@threads :static for ix in 0:div(n_amps, 2)-1
                lower_ix   = pad_bit(ix, endian_qubit)
                higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
                lower_ix  += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = $(conj(g00)) * lower_amp + $(conj(g01)) * higher_amp
                state_vec[higher_ix] = $(conj(g10)) * lower_amp + $(conj(g11)) * higher_amp
            end
            return
        end
    end
end

for (G, cos_g, sin_g, g00, g10, g01, g11) in ((:PhaseShift, :(cos(g.angle[1])), :(sin(g.angle[1])), 1.0, 0.0, 0.0, :(cos_g + im*sin_g)),
                                              (:Rx, :(cos(g.angle[1]/2.0)), :(sin(g.angle[1]/2.0)), :cos_g, :(-im*sin_g), :(-im*sin_g), :cos_g),
                                              (:Ry, :(cos(g.angle[1]/2.0)), :(sin(g.angle[1]/2.0)), :cos_g, :sin_g, :(-sin_g), :cos_g),
                                              (:Rz, :(cos(g.angle[1]/2.0)), :(sin(g.angle[1]/2.0)), :(cos_g-im*sin_g), 0.0, 0.0, :(cos_g+im*sin_g)))
    @eval begin
        function apply_gate!(g::$G, state_vec::AbstractStateVector{T}, qubit::Int) where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_qubit = nq-qubit-1
            cos_g = $cos_g
            sin_g = $sin_g
            Threads.@threads :static for ix in 0:div(n_amps, 2)-1
                lower_ix   = pad_bit(ix, endian_qubit)
                higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
                lower_ix  += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = $g00 * lower_amp + $g01 * higher_amp
                state_vec[higher_ix] = $g10 * lower_amp + $g11 * higher_amp
            end
            return
        end
        function apply_gate_conj!(g::$G, state_vec::AbstractStateVector{Ty}, qubit::Int) where {Ty}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_qubit = nq-qubit-1
            cos_g = $cos_g
            sin_g = $sin_g
            Threads.@threads :static for ix in 0:div(n_amps, 2)-1
                lower_ix   = pad_bit(ix, endian_qubit)
                higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
                lower_ix  += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = conj($g00) * lower_amp + conj($g01) * higher_amp
                state_vec[higher_ix] = conj($g10) * lower_amp + conj($g11) * higher_amp
            end
            return
        end
    end
end
function apply_gate!(g::Unitary, state_vec::AbstractStateVector{T}, qubit::Int) where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_qubit = nq-qubit-1
    g_mat = g.matrix
    Threads.@threads :static for ix in 0:div(n_amps, 2)-1
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix  += 1
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[[lower_ix, higher_ix]] = g_mat * [lower_amp; higher_amp] 
    end
    return
end
function apply_gate_conj!(g::Unitary, state_vec::AbstractStateVector{T}, qubit::Int) where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_qubit = nq-qubit-1
    g_mat = conj(g.matrix)
    Threads.@threads :static for ix in 0:div(n_amps, 2)-1
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix  += 1
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[[lower_ix, higher_ix]] = g_mat * [lower_amp; higher_amp] 
    end
    return
end

# two-qubit non controlled unitaries
for G in (:XX, :YY, :XY, :ZZ, :ECR)
    @eval begin
        function apply_gate!(g::$G, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_t1 = nq-t1-1
            endian_t2 = nq-t2-1
            small_t, big_t = minmax(endian_t1, endian_t2)
            g_mat = matrix_rep(g)
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                # bit shift to get indices
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_t2)
                ix_01 = flip_bit(ix_00, endian_t1)
                ix_11 = flip_bit(ix_10, endian_t1)
                ind_vec = [ix_00+1, ix_01+1, ix_10+1, ix_11+1]
                state_vec[ind_vec] = g_mat * state_vec[ind_vec]
            end
            return state_vec
        end
        function apply_gate_conj!(g::$G, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_t1 = nq-t1-1
            endian_t2 = nq-t2-1
            small_t, big_t = minmax(endian_t1, endian_t2)
            g_mat = conj(matrix_rep(g))
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                # bit shift to get indices
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_t2)
                ix_01 = flip_bit(ix_00, endian_t1)
                ix_11 = flip_bit(ix_10, endian_t1)
                ind_vec = [ix_00+1, ix_01+1, ix_10+1, ix_11+1]
                state_vec[ind_vec] = g_mat * state_vec[ind_vec]
            end
            return state_vec
        end
    end
end

# controlled unitaries
for (cph, ind) in ((:CPhaseShift, :ix_11), (:CPhaseShift00, :ix_00), (:CPhaseShift01, :ix_01), (:CPhaseShift10, :ix_10))
    @eval begin
        function apply_gate!(g::$cph, state_vec::AbstractStateVector{T}, control::Int, target::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq     = Int(log2(n_amps))
            endian_control = nq-control-1
            endian_target = nq-target-1
            small_t, big_t = minmax(endian_control, endian_target)
            factor = exp(im*g.angle[1])
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_control)
                ix_01 = flip_bit(ix_00, endian_target)
                ix_11 = flip_bit(ix_10, endian_target)
                state_vec[$ind + 1] *= factor
            end
            return state_vec
        end
        function apply_gate_conj!(g::$cph, state_vec::AbstractStateVector{T}, control::Int, target::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq     = Int(log2(n_amps))
            endian_control = nq-control-1
            endian_target = nq-target-1
            small_t, big_t = minmax(endian_control, endian_target)
            factor = exp(-im*g.angle[1])
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_control)
                ix_01 = flip_bit(ix_00, endian_target)
                ix_11 = flip_bit(ix_10, endian_target)
                state_vec[$ind + 1] *= factor
            end
            return state_vec
        end
    end
end

for (cp, mat, g00, g10, g01, g11) in ((:CNot, :X, matrix_rep(X())...), (:CY, :Y, matrix_rep(Y())...), (:CZ, :Z, matrix_rep(Z())...), (:CV, :V, matrix_rep(V())...))
    @eval begin
        function apply_gate!(g::$cp, state_vec::AbstractStateVector{T}, control::Int, target::Int) where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_control = nq-control-1
            endian_target  = nq-target-1
            small_t, big_t = minmax(endian_control, endian_target)
            Threads.@threads :static for ix in 0:div(n_amps, 4)-1
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_control)
                ix_01 = flip_bit(ix_00, endian_target)
                ix_11 = flip_bit(ix_01, endian_control)
                lower_ix   = ix_10+1
                higher_ix  = ix_11+1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = $g00 * lower_amp + $g01 * higher_amp 
                state_vec[higher_ix] = $g10 * lower_amp + $g11 * higher_amp 
            end
            return
        end
        function apply_gate_conj!(g::$cp, state_vec::AbstractStateVector{T}, control::Int, target::Int) where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_control = nq-control-1
            endian_target  = nq-target-1
            small_t, big_t = minmax(endian_control, endian_target)
            Threads.@threads :static for ix in 0:div(n_amps, 4)-1
                ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
                ix_10 = flip_bit(ix_00, endian_control)
                ix_01 = flip_bit(ix_00, endian_target)
                ix_11 = flip_bit(ix_01, endian_control)
                lower_ix   = ix_10+1
                higher_ix  = ix_11+1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = conj($g00) * lower_amp + conj($g01) * higher_amp 
                state_vec[higher_ix] = conj($g10) * lower_amp + conj($g11) * higher_amp 
            end
            return
        end
    end
end

for (sw, factor) in ((:Swap, 1.0), (:ISwap, im)) 
    @eval begin
        function apply_gate!(g::$sw, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_t1 = nq-t1-1
            endian_t2 = nq-t2-1
            # we only swap 01 and 10
            small_t, big_t = minmax(t1, t2)
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                # insert 0 at t1, 0 at t2
                padded_ix = pad_bit(pad_bit(ix, small_t), big_t)
                lower_ix  = flip_bit(padded_ix, endian_t1) 
                higher_ix = flip_bit(padded_ix, endian_t2) + 1
                lower_ix += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = $factor * higher_amp
                state_vec[higher_ix] = $factor * lower_amp 
            end
            return state_vec
        end
        function apply_gate_conj!(g::$sw, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
            n_amps = length(state_vec)
            nq = Int(log2(n_amps))
            endian_t1 = nq-t1-1
            endian_t2 = nq-t2-1
            # we only swap 01 and 10
            small_t, big_t = minmax(t1, t2)
            Threads.@threads for ix in 0:div(n_amps, 4)-1
                # insert 0 at t1, 0 at t2
                padded_ix = pad_bit(pad_bit(ix, small_t), big_t)
                lower_ix  = flip_bit(padded_ix, endian_t1) 
                higher_ix = flip_bit(padded_ix, endian_t2) + 1
                lower_ix += 1
                lower_amp  = state_vec[lower_ix]
                higher_amp = state_vec[higher_ix]
                state_vec[lower_ix]  = conj($factor) * higher_amp
                state_vec[higher_ix] = conj($factor) * lower_amp 
            end
            return state_vec
        end
    end
end

function apply_gate!(g::PSwap, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_t1 = nq-t1-1
    endian_t2 = nq-t2-1
    # we only swap 01 and 10
    small_t, big_t = minmax(t1, t2)
    factor = exp(im*g.angle[1])
    Threads.@threads for ix in 0:div(n_amps, 4)-1
        # insert 0 at t1, 0 at t2
        padded_ix  = pad_bit(pad_bit(ix, small_t), big_t)
        lower_ix   = flip_bit(padded_ix, endian_t1) 
        higher_ix  = flip_bit(padded_ix, endian_t2) + 1
        lower_ix  += 1
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[lower_ix]  = factor * higher_amp
        state_vec[higher_ix] = factor * lower_amp 
    end
    return state_vec
end
function apply_gate_conj!(g::PSwap, state_vec::AbstractStateVector{T}, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_t1 = nq-t1-1
    endian_t2 = nq-t2-1
    # we only swap 01 and 10
    small_t, big_t = minmax(t1, t2)
    factor = exp(-im*g.angle[1])
    Threads.@threads for ix in 0:div(n_amps, 4)-1
        # insert 0 at t1, 0 at t2
        padded_ix  = pad_bit(pad_bit(ix, small_t), big_t)
        lower_ix   = flip_bit(padded_ix, endian_t1) 
        higher_ix  = flip_bit(padded_ix, endian_t2) + 1
        lower_ix  += 1
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[lower_ix]  = factor * higher_amp
        state_vec[higher_ix] = factor * lower_amp 
    end
    return state_vec
end

function apply_gate!(g::CSwap, state_vec::AbstractStateVector{T}, control::Int, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_control = nq-control-1
    endian_t1 = nq-t1-1
    endian_t2 = nq-t2-1
    # we only swap 01 and 10
    small_t, mid_t, big_t = sort([endian_control, endian_t1, endian_t2])
    Threads.@threads for ix in 0:div(n_amps, 8)-1
        # insert 0 at t1, 0 at t2
        padded_ix = pad_bit(pad_bit(pad_bit(ix, small_t), mid_t), big_t)
        # flip control bit
        padded_ix = flip_bit(padded_ix, endian_control)
        lower_ix  = flip_bit(padded_ix, endian_t1)
        higher_ix = flip_bit(padded_ix, endian_t2) + 1
        lower_ix += 1 
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[lower_ix]  = higher_amp
        state_vec[higher_ix] = lower_amp 
    end
    return state_vec
end
apply_gate_conj!(g::CSwap, state_vec::AbstractStateVector{T}, control::Int, t1::Int, t2::Int)::AbstractStateVector{T} where {T<:Complex} = apply_gate!(g, state_vec, control, t1, t2)

# doubly controlled unitaries
function apply_gate!(g::CCNot, state_vec::AbstractStateVector{T}, c1::Int, c2::Int, target::Int)::AbstractStateVector{T} where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_c1 = nq-c1-1
    endian_c2 = nq-c2-1
    endian_target = nq-target-1
    small_t, mid_t, big_t = sort([endian_c1, endian_c2, endian_target])
    Threads.@threads for ix in 0:div(n_amps, 8)-1
        # insert 0 at c1, 0 at c2, 0 at target
        padded_ix = pad_bit(pad_bit(pad_bit(ix, small_t), mid_t), big_t)
        # flip c1 and c2
        lower_ix  = flip_bit(flip_bit(padded_ix, endian_c1), endian_c2)
        # flip target
        higher_ix = flip_bit(lower_ix, endian_target) + 1
        lower_ix += 1
        lower_amp  = state_vec[lower_ix]
        higher_amp = state_vec[higher_ix]
        state_vec[lower_ix]  = higher_amp
        state_vec[higher_ix] = lower_amp 
    end
    return state_vec
end
apply_gate_conj!(g::CCNot, state_vec::AbstractStateVector{T}, c1::Int, c2::Int, target::Int)::AbstractStateVector{T} where {T<:Complex} = apply_gate!(g, state_vec, c1, c2, target)

# arbitrary number of targets
function apply_gate!(g::Unitary, state_vec::AbstractStateVector{T}, ts::Int...) where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_ts  = nq - 1 .- ts
    g_mat = g.matrix
    ordered_ts = sort(collect(endian_ts))
    flip_list  = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix in 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    Threads.@threads :static for ix in 0:div(n_amps, 2^length(ts))-1
        padded_ix = ix
        for t in ordered_ts
            padded_ix = pad_bit(padded_ix, t)
        end
        ixs = map(flip_list) do f
            flipped_ix = padded_ix
            for f_val in f
                flipped_ix = flip_bit(flipped_ix, f_val)
            end
            return flipped_ix + 1
        end
        @views begin
            amps = state_vec[ixs[:]]
            state_vec[ixs[:]] = g_mat * amps
        end
    end
    return
end
function apply_gate_conj!(g::Unitary, state_vec::AbstractStateVector{T}, ts::Int...) where {T<:Complex}
    n_amps = length(state_vec)
    nq = Int(log2(n_amps))
    endian_ts  = nq - 1 .- ts
    g_mat = conj(g.matrix)
    ordered_ts = sort(collect(endian_ts))
    flip_list  = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix in 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    Threads.@threads :static for ix in 0:div(n_amps, 2^length(ts))-1
        padded_ix = ix
        for t in ordered_ts
            padded_ix = pad_bit(padded_ix, t)
        end
        ixs = map(flip_list) do f
            flipped_ix = padded_ix
            for flip_q in f
                flipped_ix = flip_bit(flipped_ix, flip_q)
            end
            return flipped_ix + 1
        end
        @views begin
            amps = state_vec[ixs[:]]
            state_vec[ixs[:]] = g_mat * amps
        end
    end
    return
end
