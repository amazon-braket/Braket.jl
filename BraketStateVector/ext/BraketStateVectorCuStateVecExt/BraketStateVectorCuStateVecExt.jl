module BraketStateVectorCuVectorExt

using BraketStateVector,
    BraketStateVector.Braket,
    BraketStateVector.StatsBase,
    BraketStateVector.StaticArrays,
    BraketStateVector.Combinatorics,
    cuStateVec,
    cuStateVec.CUDA,
    LinearAlgebra

using cuStateVec: CuVector, applyMatrix!, sample

import BraketStateVector.Braket: Instruction

import BraketStateVector:
    AbstractSimulator,
    classical_shadow,
    AbstractStateVector,
    AbstractDensityMatrix,
    get_amps_and_qubits,
    pad_bits,
    flip_bits,
    flip_bit,
    DoubleExcitation,
    SingleExcitation,
    evolve!,
    apply_gate!,
    apply_noise!,
    pad_bit,
    matrix_rep,
    samples,
    probabilities,
    density_matrix,
    apply_observable!,
    marginal_probability,
    reinit!

const DEFAULT_THREAD_COUNT = 512
const CuVectortorSimulator{T}   = StateVectorSimulator{T,CuVector{T}}
const CuDensityMatrixSimulator{T} = DensityMatrixSimulator{T,CuMatrix{T}}

function get_launch_dims(total_ix::Int)
    if total_ix >= DEFAULT_THREAD_COUNT
        tc = DEFAULT_THREAD_COUNT
        bc = div(total_ix, tc)
    else
        tc = total_ix
        bc = 1
    end
    return tc, bc
end

function CUDA.cu(svs::StateVectorSimulator{T,S}) where {T,S<:AbstractStateVector{T}}
    cu_sv = CuVector{T}(undef, length(svs.state_vector))
    copyto!(cu_sv, svs.state_vector)
    return StateVectorSimulator{T,CuVector{T}}(cu_sv, svs.qubit_count, svs.shots)
end

function CUDA.cu(dms::DensityMatrixSimulator{T,S}) where {T,S<:AbstractDensityMatrix{T}}
    cu_dm = CuMatrix{T}(undef, size(dms.density_matrix)...)
    copyto!(cu_dm, dms.density_matrix)
    return DensityMatrixSimulator{T,CuMatrix{T}}(cu_dm, dms.qubit_count, dms.shots)
end

function __init__()
    BraketStateVector.Braket._simulator_devices[]["braket_sv_custatevec"] =
        StateVectorSimulator{ComplexF64,CuVector{ComplexF64}}
    BraketStateVector.Braket._simulator_devices[]["braket_dm_custatevec"] =
        DensityMatrixSimulator{ComplexF64,CuMatrix{ComplexF64}}
end

function StateVectorSimulator{T,CuVector{T}}(qubit_count::Int, shots::Int) where {T}
    return StateVectorSimulator{T,CuVector{T}}(
        CuVector(T, qubit_count),
        qubit_count,
        shots,
    )
end

function init_zero_state_kernel!(sv::CuDeviceVector{T}) where {T}
    ix = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    sv[ix] = (ix == 1) ? one(T) : zero(T)
    return
end

function reinit!(
    svs::StateVectorSimulator{T,CuVector{T}},
    qubit_count::Int,
    shots::Int,
) where {T}
    if qubit_count != svs.qubit_count
        new_sv = CuVector{T}(undef, 2^qubit_count)
        svs.state_vector = CuVector{T}(new_sv, qubit_count)
    end
    block_size = 512
    tc = 2^qubit_count >= block_size ? block_size : 2^qubit_count
    bc = 2^qubit_count >= block_size ? div(2^qubit_count, block_size) : 1
    @cuda threads = tc blocks = bc init_zero_state_kernel!(svs.state_vector.data)
    svs.qubit_count = qubit_count
    svs.shots = shots
    svs.buffer = CuVector{UInt8}(undef, 0)
    svs._state_vector_after_observables = CuVector{T}(CuVector{T}(undef, 0), 0)
    return
end

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    sv::CuVector{T},
    targets::Vararg{Int,N},
) where {T<:Complex,N}
    applyMatrix!(sv, observable.matrix, false, collect(targets), Int[], Int[])
    return sv
end

function evolve!(
    svs::StateVectorSimulator{T,CuVector{T}},
    operations::Vector{Instruction},
) where {T<:Complex}
    for (oix, op) in enumerate(operations)
        apply_gate!(op.operator, svs.state_vector, op.target...)
    end
    return svs
end

function customApplyMatrix!(
    state_vec::CuVector{T},
    mat::Matrix{T},
    targets::Vector{Int},
    controls::Vector{Int},
) where {T}
    n_bits = Int(log2(length(state_vec)))
    function bufferSize()
        out = Ref{Csize_t}()
        cuStateVec.custatevecApplyMatrixGetWorkspaceSize(
            cuStateVec.handle(),
            T,
            n_bits,
            mat,
            T,
            cuStateVec.CUSTATEVEC_MATRIX_LAYOUT_COL,
            Int32(false),
            length(targets),
            length(controls),
            cuStateVec.compute_type(T, T),
            out,
        )
        out[]
    end
    buf_size = bufferSize()
    if buf_size > 0
        buffer = CuVector{UInt8}(undef, buffer_size)
    else
        buffer = CuVector{UInt8}(undef, 0)
    end
    cuStateVec.custatevecApplyMatrix(
        cuStateVec.handle(),
        state_vec,
        T,
        n_bits,
        mat,
        T,
        cuStateVec.CUSTATEVEC_MATRIX_LAYOUT_COL,
        Int32(false),
        convert(Vector{Int32}, targets),
        length(targets),
        convert(Vector{Int32}, controls),
        ones(Int32, length(controls)),
        length(controls),
        cuStateVec.compute_type(T, T),
        buffer,
        length(buffer),
    )
    return
end

for (V, f) in ((true, :conj), (false, :identity))
    @eval begin
        function apply_gate!(
            ::Val{$V},
            g::G,
            state_vec::CuVector{T},
            t::Vararg{Int,N},
        ) where {G<:Gate,T<:Complex,N}
            g_mat = $f(Matrix(matrix_rep(g)))
            return customApplyMatrix!(state_vec, g_mat, collect(t), Int[])
        end
    end
    for G in (:CPhaseShift, :CPhaseShift00, :CPhaseShift10, :CPhaseShift01)
        @eval begin
            function apply_gate!(
                ::Val{$V},
                g::$G,
                state_vec::CuVector{T},
                c::Int,
                t::Int,
            ) where {T<:Complex}
                g_mat = $f(diagm(matrix_rep(g)))
                return customApplyMatrix!(state_vec, g_mat, [t], [c])
            end
        end
    end
    for (cg, tg) in ((:CNot, :X), (:CY, :Y), (:CZ, :Z), (:CV, :V), (:CSwap, :Swap))
        @eval begin
            function apply_gate!(
                ::Val{$V},
                g::$cg,
                state_vec::CuVector{T},
                c::Int,
                ts::Int...,
            ) where {T<:Complex}
                g_mat = $f(matrix_rep(g))
                return customApplyMatrix!(state_vec, g_mat, collect(ts), [c])
            end
        end
    end
    for g in (:CCNot,)
        @eval begin
            function apply_gate!(
                ::Val{$V},
                g::$g,
                state_vec::CuVector{T},
                c1::Int,
                c2::Int,
                ts::Int...,
            ) where {T<:Complex}
                g_mat = $f(matrix_rep(g))
                return customApplyMatrix!(state_vec, g_mat, collect(ts), [c1, c2])
            end
        end
    end
end

function apply_noise!(k::Kraus, dm::CuMatrix{T}, qubit::Int) where {T}
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_qubit = nq - qubit - 1
    total_ix = div(n_amps, 2)
    tc, bc = get_launch_dims(total_ix)
    n_mats = ntuple(ix -> SMatrix{2,2,T}(k.matrices[ix]), length(k.matrices))
    @cuda threads = tc blocks = bc apply_noise_kernel!(dm, endian_qubit, n_mats)
    return
end

function apply_noise!(k::Kraus, dm::CuMatrix{T}, t1::Int, t2::Int) where {T}
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_t1 = nq - t1 - 1
    endian_t2 = nq - t2 - 1
    small_t, big_t = minmax(endian_t1, endian_t2)
    total_ix = div(n_amps, 4)
    tc, bc = get_launch_dims(total_ix)
    n_mats = ntuple(ix -> SMatrix{4,4,T}(k.matrices[ix]), length(k.matrices))
    @cuda threads = tc blocks = bc apply_noise_kernel!(dm, endian_t1, endian_t2, n_mats)
    return
end

function apply_noise!(k::Kraus, dm::CuMatrix{T}, ts::Vararg{Int,N}) where {T,N}
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_ts = nq - 1 .- ts
    ordered_ts = sort(collect(endian_ts))
    flip_list = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    flip_masks = map(flip_list) do fl
        return flip_bits(0, fl)
    end
    total_ix = div(n_amps, 2^length(ts))
    tc, bc = get_launch_dims(total_ix)
    n_mats = ntuple(ix -> SMatrix{2^N,2^N,T}(k.matrices[ix]), length(k.matrices))
    @cuda threads = tc blocks = bc apply_noise_kernel!(
        dm,
        tuple(ordered_ts...),
        CuVector{Int}(flip_masks),
        n_mats,
    )
    return
end

function apply_noise!(ph::PhaseFlip, dm::CuMatrix{T}, qubit::Int) where {T}
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_qubit = nq - qubit - 1
    total_ix = length(dm)
    tc, bc = get_launch_dims(total_ix)
    @cuda threads = tc blocks = bc apply_noise_kernel_phase_flip!(
        dm,
        endian_qubit,
        ph.probability,
    )
    return
end

include("kernels.jl")

function density_matrix(svs::StateVectorSimulator{T,CuVector{T}}) where {T}
    sv_mat = CuMatrix{T}(undef, length(svs.state_vector), 1)
    sv_mat .= svs.state_vector
    adj_sv_mat = CuMatrix{T}(undef, 1, length(svs.state_vector))
    adj_sv_mat .= adjoint(svs.state_vector)
    dm = CUDA.zeros(T, length(svs.state_vector), length(svs.state_vector))
    CUDA.@allowscalar begin
        kron!(dm, sv_mat, adj_sv_mat)
    end
    CUDA.unsafe_free!(sv_mat)
    CUDA.unsafe_free!(adj_sv_mat)
    return dm
end

function marginal_probability(probs::CuVector{T}, qubit_count::Int, targets) where {T<:Real}
    unused_qubits = setdiff(collect(0:qubit_count-1), targets)
    endian_unused = [qubit_count - uq - 1 for uq in unused_qubits]
    sorted_unused = tuple(sort(endian_unused)...)
    final_probs = CUDA.zeros(Float64, 2^length(targets))
    q_combos = vcat([Int[]], collect(combinations(endian_unused)))
    flip_masks = map(q_combos) do fl
        return flip_bits(0, fl)
    end
    total_ix = 2^length(targets)
    tc, bc = get_launch_dims(total_ix)
    @cuda threads = tc blocks = bc marginal_probability_kernel(
        final_probs,
        probs,
        sorted_unused,
        CuVector{Int}(flip_masks),
    )
    return final_probs
end

function samples(svs::StateVectorSimulator{T,CuVector{T}}) where {T}
    return sample(CuStateVec{T}(svs.state_vector, svs.qubit_count), collect(0:svs.qubit_count-1), svs.shots)
end

end # module
