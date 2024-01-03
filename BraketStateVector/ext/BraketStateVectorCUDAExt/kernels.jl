function marginal_probability_kernel(final_probs::CuDeviceVector{T}, probs::CuDeviceVector{T}, sorted_unused::NTuple{N, Int}, flip_masks::CuDeviceVector{Int}) where {T<:Real, N, }
    ix        = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    padded_ix = pad_bits(ix, sorted_unused)
    sum_val   = 0.0
    @inbounds begin
	for flip_mask in flip_masks
	    sum_val += probs[(flip_mask ⊻ padded_ix) + 1]
	end
        final_probs[ix + 1] = sum_val
    end
    return
end

function apply_observable_kernel!(sv::CuDeviceVector{T}, g_mat::SMatrix{2, 2, T}, endian_target::Int) where {T}
    ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    lower_ix   = pad_bit(ix, endian_target)
    higher_ix  = flip_bit(lower_ix, endian_target) + 1
    lower_ix  += 1
    @inbounds begin
	lower_amp  = sv[lower_ix]
	higher_amp = sv[higher_ix]
	sv[lower_ix]  = lower_amp * g_mat[1, 1] + higher_amp * g_mat[1, 2]
	sv[higher_ix] = lower_amp * g_mat[2, 1] + higher_amp * g_mat[2, 2]
    end
    return
end

function apply_observable_kernel!(sv::CuDeviceVector{T}, g_mat::SMatrix{4, 4, T}, endian_t1::Int, endian_t2::Int, small_t::Int, big_t::Int) where {T}
    ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    ix_00   = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10   = flip_bit(ix_00, endian_t2)
    ix_01   = flip_bit(ix_00, endian_t1)
    ix_11   = flip_bit(ix_10, endian_t1)
    @inbounds begin
	    amp_00 = sv[ix_00 + 1]
	    amp_01 = sv[ix_01 + 1]
	    amp_10 = sv[ix_10 + 1]
	    amp_11 = sv[ix_11 + 1]

	    sv[ix_00 + 1] = g_mat[1, 1] * amp_00 + g_mat[1, 2] * amp_01 + g_mat[1, 3] * amp_10 + g_mat[1, 4] * amp_11
	    sv[ix_01 + 1] = g_mat[2, 1] * amp_00 + g_mat[2, 2] * amp_01 + g_mat[2, 3] * amp_10 + g_mat[2, 4] * amp_11
	    sv[ix_10 + 1] = g_mat[3, 1] * amp_00 + g_mat[3, 2] * amp_01 + g_mat[3, 3] * amp_10 + g_mat[3, 4] * amp_11
	    sv[ix_11 + 1] = g_mat[4, 1] * amp_00 + g_mat[4, 2] * amp_01 + g_mat[4, 3] * amp_10 + g_mat[4, 4] * amp_11
    end
    return
end

function apply_observable_kernel!(sv::CuDeviceVector{T}, g_mat::SMatrix{N, N, T}, flip_mask::CuDeviceVector{Int}, ordered_ts::NTuple{Nq, Int}) where {N, Nq, T}
    ix = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    padded_ix = pad_bits(ix, ordered_ts)
    amps      = MVector{N, T}(undef)
    new_amps  = zeros(MVector{N, T})
    @inbounds begin
	    for jx in 1:n_ixs
	        amps[jx] = sv[(flip_masks[jx] ⊻ padded_ix) + 1] 
	    end
	    for jx in 1:n_ixs, kx in 1:n_ixs
	        new_amps[jx] += g_mat[jx, kx] * amps[kx]
	    end
	    for jx in 1:n_ixs
                sv[(flip_masks[jx] ⊻ padded_ix) + 1] = new_amps[jx]
            end
    end
    return
end
#=
function apply_observable_kernel!(dm::CuDeviceMatrix{T}, g_mat::SMatrix{2, 2, T}, endian_qubit::Int) where {T}

    return
end

function apply_observable_kernel!(dm::CuDeviceMatrix{T}, g_mat::SMatrix{4, 4, T}, endian_t1::Int, endian_t2::Int, small_t::Int, big_t::Int) where {T}

    return
end
=#
function apply_observable_kernel!(dm::CuDeviceMatrix{T}, g_mat::SMatrix{Ni, Ni, T}, ordered_ts::NTuple{Nq, Int}, flip_masks::CuDeviceVector{Int}) where {T, Ni, Nq}
    ix = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    jx = (threadIdx().y-1) + (blockIdx().y-1) * blockDim().y
    padded_ix = pad_bits(ix, ordered_ts)
    padded_jx = pad_bits(jx, ordered_ts)
    ixs = zeros(MVector{Ni, Int})
    jxs = zeros(MVector{Ni, Int})
    amps = MMatrix{Ni, Ni, T}(undef)
    new_amps = zeros(MMatrix{Ni, Ni, T})
    @inbounds begin
	    for f_ix in 1:Ni
		 ixs[f_ix] = (flip_masks[f_ix] ⊻ padded_ix) + 1
		 jxs[f_ix] = (flip_masks[f_ix] ⊻ padded_jx) + 1
	    end
	    for ii in 1:Ni, jj in 1:Ni
		amps[ii, jj] = dm[ixs[ii], jxs[jj]]
	    end
	    for ii in 1:Ni, jj in 1:Ni, kk in 1:Ni
	        new_amps[ii, jj] += g_mat[ii, kk] * amps[kk, jj]
	    end
	    for ii in 1:Ni, jj in 1:Ni
	        dm[ixs[ii], jxs[jj]] = new_amps[ii, jj]
	    end
    end
    return
end

function apply_noise_kernel_phase_flip!(dm::CuDeviceMatrix{T}, endian_qubit::Int, p::Float64) where {T}
	idx    = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
        n_amps = size(dm, 1)
        ix    = mod(idx, n_amps)
        jx    = div(idx, n_amps)
        i_val = ((1 << endian_qubit) & ix) >> endian_qubit
        j_val = ((1 << endian_qubit) & jx) >> endian_qubit
        fac   = (1.0 - p) + (1.0-2.0*i_val)*(1.0-2.0*j_val)*p
        @inbounds begin
	    dm[ix+1, jx+1] *= fac
        end
	return
end

function apply_noise_kernel!(dm::CuDeviceMatrix{T}, endian_qubit::Int, ns::NTuple{N, SMatrix{2, 2, T}}) where {N, T}
	ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix  += 1
	@inbounds begin
        ρ_00 = dm[lower_ix, lower_ix]
        ρ_01 = dm[lower_ix, higher_ix]
        ρ_10 = dm[higher_ix, lower_ix]
        ρ_11 = dm[higher_ix, higher_ix]
        sm_ρ = SMatrix{2, 2, ComplexF64}(ρ_00, ρ_10, ρ_01, ρ_11)
        term_11 = 0.0
        term_12 = 0.0
        term_21 = 0.0
        term_22 = 0.0
        for k in 1:2, l in 1:2, n in ns
	     term_11 += n[1,k] * sm_ρ[k,l] * conj(n[1, l])
	     term_12 += n[1,k] * sm_ρ[k,l] * conj(n[2, l])
	     term_21 += n[2,k] * sm_ρ[k,l] * conj(n[1, l])
	     term_22 += n[2,k] * sm_ρ[k,l] * conj(n[2, l])
        end
        dm[lower_ix, lower_ix]   = term_11
        dm[lower_ix, higher_ix]  = term_12
        dm[higher_ix, lower_ix]  = term_21
        dm[higher_ix, higher_ix] = term_22
    end
    return
end

function apply_noise_kernel!(dm::CuDeviceMatrix{T}, endian_t1::Int, endian_t2::Int, ns::NTuple{N, SMatrix{4, 4, T}}) where {N, T}
    ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    small_t, big_t = minmax(endian_t1, endian_t2)
    padded_ix  = pad_bit(pad_bit(ix, small_t), big_t)
    ix_00 = padded_ix + 1
    ix_01 = flip_bit(padded_ix, endian_t1) + 1
    ix_10 = flip_bit(padded_ix, endian_t2) + 1
    ix_11 = flip_bit(flip_bit(padded_ix, endian_t2), endian_t1) + 1
    ixs   = SVector{4, Int}(ix_00, ix_01, ix_10, ix_11)
    @inbounds begin
        ρ = MMatrix{4, 4, T}(undef)
	for ix in 1:4, jx in 1:4
	    ρ[ix, jx] = dm[ixs[ix], ixs[jx]]
	end
	k_ρ = zeros(MMatrix{4, 4, T})
	for i in 1:4, j in 1:4, k in 1:4, l in 1:4, n in ns
	    k_ρ[i,j] += n[i,k] * ρ[k,l] * conj(n[j, l])
        end
	for ix in 1:4, jx in 1:4
	    dm[ixs[ix], ixs[jx]] = k_ρ[ix, jx]
	end
    end
    return
end

function apply_noise_kernel!(dm::CuDeviceMatrix{T}, ordered_ts::NTuple{N, Int}, flip_masks::CuDeviceVector{Int}, ns::NTuple{NK, SMatrix{Ni, Ni, T}}) where {N, Ni, NK, T}
    ix        = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    padded_ix = pad_bits(ix, ordered_ts)
    ixs = MVector{Ni, Int}(undef)
    ρ   = MMatrix{Ni, Ni, T}(undef)
    k_ρ = MMatrix{Ni, Ni, T}(undef)
    @inbounds begin
	for ii in 1:2^N
	    ixs[ii] = (flip_masks[ii] ⊻ padded_ix) + 1
	end
	for ii in 1:2^N, jj in 1:2^N
	    ρ[ii, jj]   = dm[ixs[ii], ixs[jj]]
	    k_ρ[ii, jj] = zero(T)
	end
	for i in 1:2^N, j in 1:2^N, k in 1:2^N, l in 1:2^N, n in ns
	    k_ρ[i, j] += n[i,k] * ρ[k,l] * conj(n[j, l])
	end
	for ii in 1:2^N, jj in 1:2^N
	    dm[ixs[ii], ixs[jj]] = k_ρ[ii, jj]
	end
    end
    return
end

function apply_gate_single_ex_kernel!(cosϕ::T, sinϕ::T, state_vec::CuDeviceVector{T}, endian_t1::Int64, endian_t2::Int64) where {T<:Complex}
    ix             = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    small_t, big_t = minmax(endian_t1, endian_t2)
    padded_ix      = pad_bits(ix, (small_t, big_t))
    @inbounds begin
        i01     = flip_bit(padded_ix, endian_t1) + 1
	i10     = flip_bit(padded_ix, endian_t2) + 1
        amp01   = state_vec[i01]
        amp10   = state_vec[i10]
        state_vec[i01] = cosϕ * amp01 - sinϕ * amp10
        state_vec[i10] = sinϕ * amp01 + cosϕ * amp10
    end
    return
end

function apply_gate_double_ex_kernel!(cosϕ::T, sinϕ::T, state_vec::CuDeviceVector{T}, endian_ts::NTuple{4, Int}, ordered_ts::NTuple{4, Int}) where {T<:Complex}
    ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    t1, t2, t3, t4 = endian_ts
    @inbounds begin
        padded_ix = pad_bits(ix, ordered_ts)
        i0011     = flip_bits(padded_ix, (t3, t4)) + 1
        i1100     = flip_bits(padded_ix, (t1, t2)) + 1
        amp0011   = state_vec[i0011]
        amp1100   = state_vec[i1100]
        state_vec[i0011] = cosϕ * amp0011 - sinϕ * amp1100
        state_vec[i1100] = sinϕ * amp0011 + cosϕ * amp1100
    end
    return
end

function apply_gate_single_target_kernel!(g_00::T, g_01::T, g_10::T, g_11::T, state_vec::CuDeviceVector{T}, endian_qubit::Int64) where {T<:Complex}
    ix         = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    lower_ix   = pad_bit(ix, endian_qubit)
    higher_ix  = flip_bit(lower_ix, endian_qubit)
    higher_ix += 1
    lower_ix  += 1
    @inbounds begin
	    lower_amp  = state_vec[lower_ix]
	    higher_amp = state_vec[higher_ix]
	    state_vec[lower_ix]  = g_00 * lower_amp + g_01 * higher_amp
	    state_vec[higher_ix] = g_10 * lower_amp + g_11 * higher_amp
    end
    return
end

# generic two-qubit non controlled unitaries
function apply_gate_kernel!(g_mat::CuDeviceVector{T}, state_vec::CuDeviceVector{T}, endian_t1::Int, endian_t2::Int) where {T<:Complex}
    small_t, big_t = minmax(endian_t1, endian_t2)
    ix      = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    # bit shift to get indices
    ix_00   = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10   = flip_bit(ix_00, endian_t2)
    ix_01   = flip_bit(ix_00, endian_t1)
    ix_11   = flip_bit(ix_10, endian_t1)
    ix_00  += 1
    ix_01  += 1
    ix_10  += 1
    ix_11  += 1
    @inbounds begin
	    amp_00 = state_vec[ix_00]
	    amp_01 = state_vec[ix_01]
	    amp_10 = state_vec[ix_10]
	    amp_11 = state_vec[ix_11]

	    state_vec[ix_00] = g_mat[1] * amp_00
	    state_vec[ix_01] = g_mat[2] * amp_01
	    state_vec[ix_10] = g_mat[3] * amp_10
	    state_vec[ix_11] = g_mat[4] * amp_11
    end
    return
end

function apply_gate_kernel!(g_mat::CuDeviceMatrix{T}, state_vec::CuDeviceVector{T}, endian_t1::Int, endian_t2::Int) where {T<:Complex}
    small_t, big_t = minmax(endian_t1, endian_t2)
    ix      = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    # bit shift to get indices
    ix_00   = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10   = flip_bit(ix_00, endian_t2)
    ix_01   = flip_bit(ix_00, endian_t1)
    ix_11   = flip_bit(ix_10, endian_t1)
    ix_00  += 1
    ix_01  += 1
    ix_10  += 1
    ix_11  += 1
    @inbounds begin
	    amp_00 = state_vec[ix_00]
	    amp_01 = state_vec[ix_01]
	    amp_10 = state_vec[ix_10]
	    amp_11 = state_vec[ix_11]

	    state_vec[ix_00] = g_mat[1, 1] * amp_00 + g_mat[1, 2] * amp_01 + g_mat[1, 3] * amp_10 + g_mat[1, 4] * amp_11
	    state_vec[ix_01] = g_mat[2, 1] * amp_00 + g_mat[2, 2] * amp_01 + g_mat[2, 3] * amp_10 + g_mat[2, 4] * amp_11
	    state_vec[ix_10] = g_mat[3, 1] * amp_00 + g_mat[3, 2] * amp_01 + g_mat[3, 3] * amp_10 + g_mat[3, 4] * amp_11
	    state_vec[ix_11] = g_mat[4, 1] * amp_00 + g_mat[4, 2] * amp_01 + g_mat[4, 3] * amp_10 + g_mat[4, 4] * amp_11
    end
    return
end

function apply_controlled_gate_kernel!(::Val{1}, g_00::T, g_01::T, g_10::T, g_11::T, state_vec::CuDeviceVector{T}, endian_control::Int, endian_target::Int) where {T<:Complex}
    small_t, big_t = minmax(endian_control, endian_target)
    ix    = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10 = flip_bit(ix_00, endian_control)
    ix_01 = flip_bit(ix_00, endian_target)
    ix_11 = flip_bit(ix_01, endian_control)
    lower_ix   = ix_10+1
    higher_ix  = ix_11+1
    @inbounds begin
	    lower_amp  = state_vec[lower_ix]
	    higher_amp = state_vec[higher_ix]
	    state_vec[lower_ix]  = g_00 * lower_amp + g_01 * higher_amp
	    state_vec[higher_ix] = g_10 * lower_amp + g_11 * higher_amp
    end
    return
end

function apply_controlled_gate_kernel!(::Val{1}, g_mat::CuDeviceMatrix{T}, state_vec::CuDeviceVector{T}, endian_control::Int, endian_t1::Int, endian_t2::Int, small_t::Int, mid_t::Int, big_t::Int) where {T<:Complex}
    ix    = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    raw_ix = ix
    raw_ix = pad_bit(raw_ix, small_t)
    raw_ix = pad_bit(raw_ix, mid_t)
    raw_ix = pad_bit(raw_ix, big_t)
    ix_00 = flip_bit(raw_ix, endian_control)
    ix_10 = flip_bit(ix_00, endian_t2)
    ix_01 = flip_bit(ix_00, endian_t1)
    ix_11 = flip_bit(ix_01, endian_t2)
    ix_00  += 1
    ix_01  += 1
    ix_10  += 1
    ix_11  += 1
    @inbounds begin
	    amp_00 = state_vec[ix_00]
	    amp_01 = state_vec[ix_01]
	    amp_10 = state_vec[ix_10]
	    amp_11 = state_vec[ix_11]

	    state_vec[ix_00] = g_mat[1, 1] * amp_00 + g_mat[1, 2] * amp_01 + g_mat[1, 3] * amp_10 + g_mat[1, 4] * amp_11
	    state_vec[ix_01] = g_mat[2, 1] * amp_00 + g_mat[2, 2] * amp_01 + g_mat[2, 3] * amp_10 + g_mat[2, 4] * amp_11
	    state_vec[ix_10] = g_mat[3, 1] * amp_00 + g_mat[3, 2] * amp_01 + g_mat[3, 3] * amp_10 + g_mat[3, 4] * amp_11
	    state_vec[ix_11] = g_mat[4, 1] * amp_00 + g_mat[4, 2] * amp_01 + g_mat[4, 3] * amp_10 + g_mat[4, 4] * amp_11
    end
    return
end

function apply_controlled_gate_kernel!(::Val{2}, g_00::T, g_01::T, g_10::T, g_11::T, state_vec::CuDeviceVector{T}, endian_c1::Int, endian_c2::Int, endian_t::Int, small_t::Int, mid_t::Int, big_t::Int) where {T<:Complex}
    ix    = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    # insert 0 at c1, 0 at c2, 0 at target
    padded_ix  = ix
    padded_ix  = pad_bit(padded_ix, small_t)
    padded_ix  = pad_bit(padded_ix, mid_t)
    padded_ix  = pad_bit(padded_ix, big_t)
    # flip c1 and c2
    lower_ix   = flip_bit(flip_bit(padded_ix, endian_c1), endian_c2)
    # flip target
    higher_ix  = flip_bit(lower_ix, endian_t) + 1
    lower_ix  += 1
    @inbounds begin
	    lower_amp  = state_vec[lower_ix]
	    higher_amp = state_vec[higher_ix]
	    state_vec[lower_ix]  = g_00 * lower_amp + g_01 * higher_amp
	    state_vec[higher_ix] = g_10 * lower_amp + g_11 * higher_amp
    end
    return
end

function apply_gate_kernel!(g_mat::CuDeviceMatrix{T}, flip_masks::CuDeviceVector{Int}, state_vec::CuDeviceVector{T}, ordered_ts::NTuple{N, Int}, ::Val{n_ixs}) where {n_ixs, N, T<:Complex}
    ix        = (threadIdx().x-1) + (blockIdx().x-1) * blockDim().x
    padded_ix = pad_bits(ix, ordered_ts)
    amps      = MVector{n_ixs, T}(undef)
    new_amps  = zeros(MVector{n_ixs, T})
    @inbounds begin
	    for jx in 1:n_ixs
	        amps[jx] = state_vec[(flip_masks[jx] ⊻ padded_ix) + 1] 
	    end
	    for jx in 1:n_ixs, kx in 1:n_ixs
	        new_amps[jx] += g_mat[jx, kx] * amps[kx]
	    end
	    for jx in 1:n_ixs
                state_vec[(flip_masks[jx] ⊻ padded_ix) + 1] = new_amps[jx]
            end
    end
    return
end
