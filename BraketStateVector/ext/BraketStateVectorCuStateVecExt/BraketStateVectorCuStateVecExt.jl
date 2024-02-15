module BraketStateVectorCuStateVecExt

using BraketStateVector,
    BraketStateVector.Braket,
    BraketStateVector.StatsBase,
    BraketStateVector.StaticArrays,
    BraketStateVector.Combinatorics,
    cuStateVec,
    cuStateVec.CUDA,
    LinearAlgebra

using cuStateVec: CuStateVec, applyMatrix!, sample
import cuStateVec.CUDA: cu

import BraketStateVector.Braket: I, Instruction

import BraketStateVector:
    AbstractSimulator,
    classical_shadow,
    AbstractStateVector,
    AbstractDensityMatrix,
    StateVectorSimulator,
    DensityMatrixSimulator,
    pad_bits,
    flip_bits,
    flip_bit,
    DoubleExcitation,
    SingleExcitation,
    apply_gate!,
    apply_noise!,
    pad_bit,
    matrix_rep,
    samples,
    calculate,
    probabilities,
    expectation,
    density_matrix,
    apply_observable!,
    marginal_probability,
    reinit!

const DEFAULT_THREAD_COUNT = 512
const CuStateVectorSimulator{T} = StateVectorSimulator{T,CuVector{T}}
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

function cu(svs::StateVectorSimulator{T,S}) where {T,S<:AbstractVector{T}}
    cu_sv = CuVector{T}(undef, length(svs.state_vector))
    copyto!(cu_sv, svs.state_vector)
    return StateVectorSimulator{T,CuVector{T}}(cu_sv, svs.qubit_count, svs.shots)
end

function cu(dms::DensityMatrixSimulator{T,S}) where {T,S<:AbstractMatrix{T}}
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
    sv_size = iszero(qubit_count) ? 0 : 2^qubit_count
    sv = CuVector{T}(undef, sv_size)
    if sv_size > 0
        tc, bc = get_launch_dims(sv_size)
        @cuda threads = tc blocks = bc init_zero_state_kernel!(sv)
    end
    return StateVectorSimulator{T,CuVector{T}}(sv, qubit_count, shots)
end
function DensityMatrixSimulator{T,CuMatrix{T}}(qubit_count::Int, shots::Int) where {T}
    dm_size = iszero(qubit_count) ? 0 : 2^qubit_count
    dm = CuMatrix{T}(undef, dm_size, dm_size)
    if dm_size > 0
        tc, bc = get_launch_dims(dm_size)
        @cuda threads = tc blocks = bc init_zero_state_kernel!(dm)
    end
    return DensityMatrixSimulator{T,CuMatrix{T}}(dm, qubit_count, shots)
end

function reinit!(
    svs::StateVectorSimulator{T,CuVector{T}},
    qubit_count::Int,
    shots::Int,
) where {T}
    sv_size = iszero(qubit_count) ? 0 : 2^qubit_count
    if qubit_count != svs.qubit_count
        svs.state_vector = CuVector{T}(undef, sv_size)
    end
    if qubit_count > 0
        tc, bc = get_launch_dims(sv_size)
        @cuda threads = tc blocks = bc init_zero_state_kernel!(svs.state_vector)
    end
    svs.qubit_count = qubit_count
    svs.shots = shots
    svs.buffer = CuVector{UInt8}(undef, 0)
    svs._state_vector_after_observables = CuVector{T}(undef, 0)
    return
end
function reinit!(
    dms::DensityMatrixSimulator{T,CuMatrix{T}},
    qubit_count::Int,
    shots::Int,
) where {T}
    dm_size = iszero(qubit_count) ? 0 : 2^qubit_count
    if qubit_count != dms.qubit_count
        dms.density_matrix = CuMatrix{T}(undef, dm_size, dm_size)
    end
    if qubit_count > 0
        tc, bc = get_launch_dims(dm_size)
        @cuda threads = (tc, tc) blocks = (bc, bc) init_zero_state_kernel!(
            dms.density_matrix,
        )
    end
    dms.qubit_count = qubit_count
    dms.shots = shots
    dms.buffer = CuVector{UInt8}(undef, 0)
    dms._density_matrix_after_observables = CuMatrix{T}(undef, 0, 0)
    return
end

function customApplyMatrix!(
    state::CuVecOrMat{T},
    mat::Matrix{T},
    targets::Vector{Int},
    controls::Vector{Int},
    adjoint::Bool = false,
) where {T}
    n_bits = Int(log2(length(state)))
    function bufferSize()
        out = Ref{Csize_t}()
        cuStateVec.custatevecApplyMatrixGetWorkspaceSize(
            cuStateVec.handle(),
            T,
            n_bits,
            mat,
            T,
            cuStateVec.CUSTATEVEC_MATRIX_LAYOUT_COL,
            Int32(adjoint),
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
    endian_targets  = [n_bits - 1 - t for t in targets]
    endian_controls = [n_bits - 1 - c for c in controls]
    cuStateVec.custatevecApplyMatrix(
        cuStateVec.handle(),
        state,
        T,
        n_bits,
        mat,
        T,
        cuStateVec.CUSTATEVEC_MATRIX_LAYOUT_COL,
        Int32(adjoint),
        convert(Vector{Int32}, endian_targets),
        length(targets),
        convert(Vector{Int32}, endian_controls),
        ones(Int32, length(controls)),
        length(controls),
        cuStateVec.compute_type(T, T),
        buffer,
        length(buffer),
    )
    return
end
customApplyMatrix!(
    state::CuVecOrMat{T},
    mat::AbstractMatrix{T},
    targets::Vector{Int},
    controls::Vector{Int},
    adjoint::Bool = false,
) where {T} = customApplyMatrix!(state, Matrix{T}(mat), targets, controls, adjoint)

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    state::CuVecOrMat{T},
    targets::Vararg{Int,N},
) where {T<:Complex,N}
    customApplyMatrix!(state, observable.matrix, collect(targets), Int[])
    return state
end

apply_gate!(::Val{false}, g::I, state_vec::CuVector{T}, t::Int) where {T<:Complex} = return
apply_gate!(::Val{true}, g::I, state_vec::CuVector{T}, t::Int) where {T<:Complex} = return
function apply_gate!(
    ::Val{false},
    g::Unitary,
    state_vec::CuVector{T},
    t::Int,
) where {T<:Complex}
    g_mat = Matrix(matrix_rep(g))
    return customApplyMatrix!(state_vec, g_mat, [t], Int[])
end
function apply_gate!(
    ::Val{true},
    g::Unitary,
    state_vec::CuVector{T},
    t::Int,
) where {T<:Complex}
    g_mat = conj(Matrix(matrix_rep(g)))
    return customApplyMatrix!(state_vec, g_mat, [t], Int[])
end
function apply_gate!(
    ::Val{false},
    g::Unitary,
    state_vec::CuVector{T},
    t::Vararg{Int,N},
) where {T<:Complex,N}
    g_mat = Matrix(matrix_rep(g))
    return customApplyMatrix!(state_vec, g_mat, reverse(collect(t)), Int[])
end
function apply_gate!(
    ::Val{true},
    g::Unitary,
    state_vec::CuVector{T},
    t::Vararg{Int,N},
) where {T<:Complex,N}
    g_mat = conj(Matrix(matrix_rep(g)))
    return customApplyMatrix!(state_vec, g_mat, reverse(collect(t)), Int[])
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
                return customApplyMatrix!(state_vec, g_mat, [c, t], Int[])
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
                g_mat = $f(matrix_rep($tg()))
                return customApplyMatrix!(state_vec, g_mat, collect(ts), [c])
            end
        end
    end
    for (cg, tg) in ((:CCNot, :X),)
        @eval begin
            function apply_gate!(
                ::Val{$V},
                g::$cg,
                state_vec::CuVector{T},
                c1::Int,
                c2::Int,
                ts::Int...,
            ) where {T<:Complex}
                g_mat = $f(matrix_rep($tg()))
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
    h_mat = Matrix{T}(undef, 4 * length(k.matrices), 4)
    @views begin
        for ci = 1:length(k.matrices)
            rows = (1+(ci-1)*4):ci*4
            h_mat[rows, :] .= k.matrices[ci][:, :]
        end
    end
    c_mat = CuMatrix{T}(h_mat)
    @cuda threads = tc blocks = bc apply_noise_kernel!(dm, endian_t1, endian_t2, c_mat)
    return
end

function apply_noise!(k::Kraus, dm::CuMatrix{T}, ts::Vararg{Int,N}) where {T,N}
    n_amps = size(dm, 1)
    nq = Int(log2(n_amps))
    endian_ts = nq - 1 .- ts
    ordered_ts = sort(collect(endian_ts))
    flip_list = map(0:2^N-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    flip_masks = map(flip_list) do fl
        return flip_bits(0, fl)
    end
    total_ix = div(n_amps, 2^N)
    tc, bc = get_launch_dims(total_ix)
    h_mat = Matrix{T}(undef, 2^(2N), length(k.matrices))
    @views begin
        for ci = 1:length(k.matrices)
            h_mat[:, ci] .= k.matrices[ci][:]
        end
    end
    c_mat = CuMatrix{T}(h_mat)
    @cuda threads = tc blocks = bc apply_noise_kernel!(
        dm,
        tuple(ordered_ts...),
        CuVector{Int}(flip_masks),
        c_mat,
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
    # TODO: fix this
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

function calculate(
    p::Braket.Probability,
    sim::S,
) where {S<:Union{CuStateVectorSimulator,CuDensityMatrixSimulator}}
    targets = p.targets
    probs = probabilities(sim)
    qc = qubit_count(sim)
    (isempty(targets) || isnothing(targets) || collect(targets) == collect(0:qc-1)) &&
        return collect(probs)
    mp = marginal_probability(probs, qc, targets)
    return collect(mp)
end

Base.convert(::Type{CuStateVec{T}}, svs::StateVectorSimulator{T,CuVector{T}}) where {T} =
    CuStateVec{T}(svs.state_vector, svs.qubit_count)
Base.convert(::Type{CuStateVec{T}}, dms::DensityMatrixSimulator{T,CuMatrix{T}}) where {T} =
    CuStateVec{T}(
        reshape(dms.density_matrix, length(dms.density_matrix)),
        2 * dms.qubit_count,
    )

function expectation(
    svs::StateVectorSimulator{T,CuVector{T}},
    observable::Braket.Observables.HermitianObservable,
    targets::Int...,
) where {T}
    endian_bits = reverse(collect(svs.qubit_count .- 1 .- targets))
    ev, norm = cuStateVec.expectation(
        CuStateVec{T}(svs.state_vector, svs.qubit_count),
        observable.matrix,
        endian_bits,
    )
    return real(ev)
end
function expectation(
    dms::DensityMatrixSimulator{T,CuMatrix{T}},
    observable::Braket.Observables.HermitianObservable,
    targets::Int...,
) where {T}
    obs_targets = reverse(dms.qubit_count .+ targets)
    dm_copy = copy(dms.density_matrix)
    customApplyMatrix!(dm_copy, transpose(observable.matrix), collect(obs_targets), Int[])
    return sum(real(diag(dm_copy)))
end

Base.convert(::Type{cuStateVec.Pauli}, o::Braket.Observables.I) = cuStateVec.PauliI()
Base.convert(::Type{cuStateVec.Pauli}, o::Braket.Observables.X) = cuStateVec.PauliX()
Base.convert(::Type{cuStateVec.Pauli}, o::Braket.Observables.Y) = cuStateVec.PauliY()
Base.convert(::Type{cuStateVec.Pauli}, o::Braket.Observables.Z) = cuStateVec.PauliZ()

function expectation(
    svs::S,
    observable::Braket.Observables.TensorProduct,
    targets::Int...,
) where {
    T,
    S<:Union{StateVectorSimulator{T,CuVector{T}},DensityMatrixSimulator{T,CuMatrix{T}}},
}
    ev = zero(T)
    norm = zero(T)
    if any(o -> o isa Braket.Observables.HermitianObservable, observable.factors) ||
       any(o -> o isa Braket.Observables.H, observable.factors)
        mat = mapfoldl(
            o -> convert(Matrix{ComplexF64}, o),
            kron,
            observable.factors,
            init = [1.0],
        )
        return expectation(svs, Braket.Observables.HermitianObservable(mat), targets...)
    else
        pauli_ops = map(o->convert(cuStateVec.Pauli, o), observable.factors)
        cu_sv     = convert(CuStateVec{T}, svs)
        nq        = cu_sv.nbits
        endian_bits = nq .- 1 .- collect(targets)
        evs = cuStateVec.expectationsOnPauliBasis(
            cu_sv,
            Vector{cuStateVec.Pauli}[pauli_ops],
            [endian_bits],
        )
        ev = evs[1]
    end
    return real(ev)
end

function calculate(
    ex::Braket.Expectation,
    sim::S,
) where {S<:Union{CuStateVectorSimulator,CuDensityMatrixSimulator}}
    obs = ex.observable
    targets = isnothing(ex.targets) ? collect(0:qubit_count(sim)-1) : ex.targets
    obs_qc = qubit_count(obs)
    length(targets) == obs_qc && return expectation(sim, obs, targets...)
    return [expectation(sim, obs, target) for target in targets]
end

function samples(svs::StateVectorSimulator{T,CuVector{T}}) where {T}
    cu_sv = CuStateVec{T}(svs.state_vector, svs.qubit_count)
    return sample(cu_sv, collect(0:svs.qubit_count-1), svs.shots)
end
function samples(dms::DensityMatrixSimulator{T,CuMatrix{T}}) where {T}
    # this gives the *magnitude* of amplitudes but not their *phases*.
    ps = sqrt.(diag(dms.density_matrix))
    cu_sv = CuStateVec{T}(ps, dms.qubit_count)
    return sample(cu_sv, collect(0:dms.qubit_count-1), dms.shots)
end

end # module
