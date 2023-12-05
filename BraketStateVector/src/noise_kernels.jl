function apply_noise!(n::BitFlip, dm::DensityMatrix{T}, qubit::Int) where {T}
    # K₀ = √(1.0 - n.probability) * I
    # K₁ = √(n.probability) * X
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_qubit = nq-qubit-1
    k0_mat = SMatrix{2, 2, ComplexF64}(√(1.0 - n.probability), 0.0, 0.0, √(1.0 - n.probability))
    k1_mat = SMatrix{2, 2, ComplexF64}(0.0, √n.probability, √n.probability, 0.0)
    Threads.@threads :static for ix in 0:div(n_amps, 2)-1
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix  += 1
        ρ_00 = dm[CartesianIndex(lower_ix, lower_ix)]
        ρ_01 = dm[CartesianIndex(lower_ix, higher_ix)]
        ρ_10 = dm[CartesianIndex(higher_ix, lower_ix)]
        ρ_11 = dm[CartesianIndex(higher_ix, higher_ix)]
        sm_ρ = SMatrix{2, 2, ComplexF64}(ρ_00, ρ_10, ρ_01, ρ_11)

        k_ρ  = k0_mat * sm_ρ * k0_mat + k1_mat * sm_ρ * k1_mat
        dm[CartesianIndex(lower_ix, lower_ix)]   = k_ρ[1, 1]
        dm[CartesianIndex(lower_ix, higher_ix)]  = k_ρ[1, 2]
        dm[CartesianIndex(higher_ix, lower_ix)]  = k_ρ[2, 1]
        dm[CartesianIndex(higher_ix, higher_ix)] = k_ρ[2, 2]
    end
end

function apply_noise!(n::PhaseFlip, dm::DensityMatrix{T}, qubit::Int) where {T}
    # K₀ = √(1.0 - n.probability) * I
    # K₁ = √(n.probability) * Z
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_qubit = nq-qubit-1
    Threads.@threads :static for idx in 0:length(dm)-1
        ix    = mod(idx, n_amps)
        jx    = div(idx, n_amps)
        i_val = ((1 << endian_qubit) & ix) >> endian_qubit
        j_val = ((1 << endian_qubit) & jx) >> endian_qubit
        fac   = (1.0 - n.probability) + (1.0-2.0*i_val)*(1.0-2.0*j_val)*n.probability
        dm[CartesianIndex(ix+1, jx+1)] *= fac
    end
end

function apply_noise!(n::Depolarizing, dm::DensityMatrix{T}, qubit::Int) where {T}
    # K₀ = √(1.0 - n.probability) * I
    # K₁ = √(n.probability / 3.0) * X
    # K₂ = √(n.probability / 3.0) * Y
    # K₃ = √(n.probability / 3.0) * Z
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    k = Kraus([√(1.0-n.probability) * matrix_rep(I()), √(n.probability/3.0)*matrix_rep(X()), √(n.probability/3.0)*matrix_rep(Y()), √(n.probability/3.0)*matrix_rep(Z())])
    apply_noise!(k, dm, qubit)
end

function apply_noise!(n::PauliChannel, dm::DensityMatrix{T}, qubit::Int) where {T}
    I = diagm(ones(ComplexF64, 2))
    Z = diagm(ComplexF64[1.0; -1.0])
    X = ComplexF64[0.0 1.0; 1.0 0.0]
    Y = ComplexF64[0.0 -im; im 0.0]
    K0 = √(1 - n.probX - n.probY - n.probZ) * ComplexF64[1.0 0.0; 0.0 1.0]
    K1 = √n.probX * X
    K2 = √n.probY * Y
    K3 = √n.probZ * Z
    apply_noise!(Kraus([K0, K1, K2, K3]), dm, qubit)
end

function apply_noise!(n::AmplitudeDamping, dm::DensityMatrix{T}, qubit::Int) where {T}
    K_0 = complex([1.0 0.0; 0.0 √(1.0-n.gamma)])
    K_1 = complex([0.0 √n.gamma; 0.0 0.0])
    k   = Kraus([K_0, K_1])
    apply_noise!(k, dm, qubit)
end

function apply_noise!(n::GeneralizedAmplitudeDamping, dm::DensityMatrix{T}, qubit::Int) where {T}
    K0 = √n.probability * [1.0 0.0; 0.0 √(1.0 - n.gamma)]
    K1 = √n.probability * [0.0 √n.gamma; 0.0 0.0]
    K2 = √(1.0 - n.probability) * [√(1.0 - n.gamma) 0.0; 0.0 1.0]
    K3 = √(1.0 - n.probability) * [0.0 0.0; √n.gamma 0.0]
    apply_noise!(Kraus([K0, K1, K2, K3]), dm, qubit)
end

function apply_noise!(n::PhaseDamping, dm::DensityMatrix{T}, qubit::Int) where {T}
    K_0 = complex([1.0 0.0; 0.0 √(1.0-n.gamma)])
    K_1 = complex([0.0 0.0; 0.0 √n.gamma])
    k   = Kraus([K_0, K_1])
    apply_noise!(k, dm, qubit)
end

function apply_noise!(n::TwoQubitDepolarizing, dm::DensityMatrix{T}, t1::Int, t2::Int) where {T}
    I = diagm(ones(ComplexF64, 2))
    Z = diagm(ComplexF64[1.0; -1.0])
    X = ComplexF64[0.0 1.0; 1.0 0.0]
    Y = ComplexF64[0.0 -im; im 0.0]
    ks = (I, X, Y, Z)
    fac = √(n.probability / 15.0)
    Ks = [kron(ki, kj) for ki in ks, kj in ks]
    Ks[1] .*= √(1.0 - n.probability)
    Ks[2:end] .*= fac
    apply_noise!(Kraus(vec(Ks)), dm, t1, t2)
end

function apply_noise!(n::TwoQubitPauliChannel, dm::DensityMatrix{T}, t1::Int, t2::Int) where {T}
    I = diagm(ones(ComplexF64, 2))
    Z = diagm(ComplexF64[1.0; -1.0])
    X = ComplexF64[0.0 1.0; 1.0 0.0]
    Y = ComplexF64[0.0 -im; im 0.0]
    k_dict = Dict('I'=>I, 'X'=>X, 'Y'=>Y, 'Z'=>Z)
    total_p = sum(values(n.probabilities))
    Ks = [diagm(√(1.0 - total_p) * ones(ComplexF64, 4))]
    for (k, v) in n.probabilities
        k != "II" && push!(Ks, √v * kron(k_dict[k[1]], k_dict[k[2]]))
    end
    apply_noise!(Kraus(Ks), dm, t1, t2)
end

function apply_noise!(n::TwoQubitDephasing, dm::DensityMatrix{T}, t1::Int, t2::Int) where {T}
    # K₀ = √(1.0 - n.probability) * II 
    # K₁ = √(n.probability / 3.0) * IZ
    # K₂ = √(n.probability / 3.0) * ZI
    # K₃ = √(n.probability / 3.0) * ZZ
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    I = diagm(ones(ComplexF64, 2))
    Z = diagm(ComplexF64[1.0; -1.0])
    II = kron(I, I)
    IZ = kron(I, Z)
    ZI = kron(Z, I)
    ZZ = kron(Z, Z)
    Ks = [√(1.0 - n.probability) * II, √(n.probability/3.0) * IZ, √(n.probability/3.0) * ZI, √(n.probability/3.0) * ZZ]
    apply_noise!(Kraus(Ks), dm, t1, t2)
end

function apply_noise!(n::Kraus, dm::DensityMatrix{T}, qubit::Int) where {T}
    k_mats      = ntuple(ix->SMatrix{2, 2, ComplexF64}(n.matrices[ix]), length(n.matrices))
    k_mats_conj = ntuple(ix->SMatrix{2, 2, ComplexF64}(adjoint(n.matrices[ix])), length(n.matrices))
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_qubit = nq-qubit-1
    Threads.@threads :static for ix in 0:div(n_amps, 2)-1
        # maybe not diagonal
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
        lower_ix  += 1

        ρ_00 = dm[CartesianIndex(lower_ix, lower_ix)]
        ρ_01 = dm[CartesianIndex(lower_ix, higher_ix)]
        ρ_10 = dm[CartesianIndex(higher_ix, lower_ix)]
        ρ_11 = dm[CartesianIndex(higher_ix, higher_ix)]
        sm_ρ = SMatrix{2, 2, ComplexF64}(ρ_00, ρ_10, ρ_01, ρ_11)

        k_ρ  = k_mats[1] * sm_ρ * k_mats_conj[1]
        for mat_ix in 2:length(k_mats)
            k_ρ += k_mats[mat_ix] * sm_ρ * k_mats_conj[mat_ix]
        end
        dm[CartesianIndex(lower_ix, lower_ix)]   = k_ρ[1, 1]
        dm[CartesianIndex(lower_ix, higher_ix)]  = k_ρ[1, 2]
        dm[CartesianIndex(higher_ix, lower_ix)]  = k_ρ[2, 1]
        dm[CartesianIndex(higher_ix, higher_ix)] = k_ρ[2, 2]
    end
end

function apply_noise!(n::Kraus, dm::DensityMatrix{T}, t1::Int, t2::Int) where {T}
    k_mats      = ntuple(ix->SMatrix{4, 4, ComplexF64}(n.matrices[ix]), length(n.matrices))
    k_mats_conj = ntuple(ix->SMatrix{4, 4, ComplexF64}(adjoint(n.matrices[ix])), length(n.matrices))
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_t1 = nq-t1-1
    endian_t2 = nq-t2-1
    small_t, big_t = minmax(endian_t1, endian_t2)
    Threads.@threads :static for ix in 0:div(n_amps, 4)-1
        # maybe not diagonal
        padded_ix  = pad_bit(pad_bit(ix, small_t), big_t)
        ix_00 = padded_ix + 1
        ix_01 = flip_bit(padded_ix, endian_t1) + 1
        ix_10 = flip_bit(padded_ix, endian_t2) + 1
        ix_11 = flip_bit(flip_bit(padded_ix, endian_t2), endian_t1) + 1
        @inbounds begin
            ixs = CartesianIndex.(collect(Iterators.product((ix_00, ix_10, ix_01, ix_11), (ix_00, ix_10, ix_01, ix_11))))
            dm_vec = view(dm, ixs)
            ρ = SMatrix{4, 4, ComplexF64}(dm_vec)
            k_ρ  = k_mats[1] * ρ * k_mats_conj[1]
            for mat_ix in 2:length(k_mats)
                k_ρ += k_mats[mat_ix] * ρ * k_mats_conj[mat_ix]
            end
            dm_vec[:] = k_ρ[:]
        end
    end
end

function apply_noise!(n::Kraus, dm::DensityMatrix{T}, ts::Int...) where {T}
    k_mats      = n.matrices 
    k_mats_conj = ntuple(ix->adjoint(n.matrices[ix]), length(n.matrices))
    # ρ = ∑ᵢ Kᵢ ρ Kᵢ\^†
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_ts  = nq - 1 .- ts
    ordered_ts = sort(endian_ts)
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
        ix_pairs = CartesianIndex.(collect(Iterators.product(ixs, ixs)))
        @views begin
            ρ = dm[ix_pairs]
            k_ρ  = k_mats[1] * ρ * k_mats_conj[1]
            for mat_ix in 2:length(k_mats)
                k_ρ += k_mats[mat_ix] * ρ * k_mats_conj[mat_ix]
            end
            dm[ix_pairs] = k_ρ[:,:]
        end
    end
end
