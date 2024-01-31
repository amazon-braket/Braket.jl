function marginal_probability_kernel(
    final_probs::CuDeviceVector{T},
    probs::CuDeviceVector{T},
    sorted_unused::NTuple{N,Int},
    flip_masks::CuDeviceVector{Int},
) where {T<:Real,N}
    ix = (threadIdx().x - 1) + (blockIdx().x - 1) * blockDim().x
    padded_ix = pad_bits(ix, sorted_unused)
    sum_val = 0.0
    @inbounds begin
        for flip_mask in flip_masks
            sum_val += probs[(flip_mask⊻padded_ix)+1]
        end
        final_probs[ix+1] = sum_val
    end
    return
end

function init_zero_state_kernel!(sv::CuDeviceVector{T}) where {T}
    ix = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    sv[ix] = (ix == 1) ? one(T) : zero(T)
    return
end

function init_zero_state_kernel!(dm::CuDeviceMatrix{T}) where {T}
    ix = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    dm[ix, ix] = (ix == 1) ? one(T) : zero(T)
    return
end

function apply_noise_kernel_phase_flip!(
    dm::CuDeviceMatrix{T},
    endian_qubit::Int,
    p::Float64,
) where {T}
    idx = (threadIdx().x - 1) + (blockIdx().x - 1) * blockDim().x
    n_amps = size(dm, 1)
    ix = mod(idx, n_amps)
    jx = div(idx, n_amps)
    i_val = ((1 << endian_qubit) & ix) >> endian_qubit
    j_val = ((1 << endian_qubit) & jx) >> endian_qubit
    fac = (1.0 - p) + (1.0 - 2.0 * i_val) * (1.0 - 2.0 * j_val) * p
    @inbounds begin
        dm[ix+1, jx+1] *= fac
    end
    return
end

function apply_noise_kernel!(
    dm::CuDeviceMatrix{T},
    endian_qubit::Int,
    ns::NTuple{N,SMatrix{2,2,T}},
) where {N,T}
    ix = (threadIdx().x - 1) + (blockIdx().x - 1) * blockDim().x
    lower_ix = pad_bit(ix, endian_qubit)
    higher_ix = flip_bit(lower_ix, endian_qubit) + 1
    lower_ix += 1
    @inbounds begin
        ρ_00 = dm[lower_ix, lower_ix]
        ρ_01 = dm[lower_ix, higher_ix]
        ρ_10 = dm[higher_ix, lower_ix]
        ρ_11 = dm[higher_ix, higher_ix]
        sm_ρ = SMatrix{2,2,ComplexF64}(ρ_00, ρ_10, ρ_01, ρ_11)
        term_11 = 0.0
        term_12 = 0.0
        term_21 = 0.0
        term_22 = 0.0
        for k = 1:2, l = 1:2, n in ns
            term_11 += n[1, k] * sm_ρ[k, l] * conj(n[1, l])
            term_12 += n[1, k] * sm_ρ[k, l] * conj(n[2, l])
            term_21 += n[2, k] * sm_ρ[k, l] * conj(n[1, l])
            term_22 += n[2, k] * sm_ρ[k, l] * conj(n[2, l])
        end
        dm[lower_ix, lower_ix] = term_11
        dm[lower_ix, higher_ix] = term_12
        dm[higher_ix, lower_ix] = term_21
        dm[higher_ix, higher_ix] = term_22
    end
    return
end

function apply_noise_kernel!(
    dm::CuDeviceMatrix{T},
    endian_t1::Int,
    endian_t2::Int,
    ns::NTuple{N,SMatrix{4,4,T}},
) where {N,T}
    ix = (threadIdx().x - 1) + (blockIdx().x - 1) * blockDim().x
    small_t, big_t = minmax(endian_t1, endian_t2)
    padded_ix = pad_bit(pad_bit(ix, small_t), big_t)
    ix_00 = padded_ix + 1
    ix_01 = flip_bit(padded_ix, endian_t1) + 1
    ix_10 = flip_bit(padded_ix, endian_t2) + 1
    ix_11 = flip_bit(flip_bit(padded_ix, endian_t2), endian_t1) + 1
    ixs = SVector{4,Int}(ix_00, ix_01, ix_10, ix_11)
    @inbounds begin
        ρ = MMatrix{4,4,T}(undef)
        for ix = 1:4, jx = 1:4
            ρ[ix, jx] = dm[ixs[ix], ixs[jx]]
        end
        k_ρ = zeros(MMatrix{4,4,T})
        for i = 1:4, j = 1:4, k = 1:4, l = 1:4, n in ns
            k_ρ[i, j] += n[i, k] * ρ[k, l] * conj(n[j, l])
        end
        for ix = 1:4, jx = 1:4
            dm[ixs[ix], ixs[jx]] = k_ρ[ix, jx]
        end
    end
    return
end

function apply_noise_kernel!(
    dm::CuDeviceMatrix{T},
    ordered_ts::NTuple{N,Int},
    flip_masks::CuDeviceVector{Int},
    ns::NTuple{NK,SMatrix{Ni,Ni,T}},
) where {N,Ni,NK,T}
    ix = (threadIdx().x - 1) + (blockIdx().x - 1) * blockDim().x
    padded_ix = pad_bits(ix, ordered_ts)
    ixs = MVector{Ni,Int}(undef)
    ρ = MMatrix{Ni,Ni,T}(undef)
    k_ρ = MMatrix{Ni,Ni,T}(undef)
    @inbounds begin
        for ii = 1:2^N
            ixs[ii] = (flip_masks[ii] ⊻ padded_ix) + 1
        end
        for ii = 1:2^N, jj = 1:2^N
            ρ[ii, jj] = dm[ixs[ii], ixs[jj]]
            k_ρ[ii, jj] = zero(T)
        end
        for i = 1:2^N, j = 1:2^N, k = 1:2^N, l = 1:2^N, n in ns
            k_ρ[i, j] += n[i, k] * ρ[k, l] * conj(n[j, l])
        end
        for ii = 1:2^N, jj = 1:2^N
            dm[ixs[ii], ixs[jj]] = k_ρ[ii, jj]
        end
    end
    return
end
