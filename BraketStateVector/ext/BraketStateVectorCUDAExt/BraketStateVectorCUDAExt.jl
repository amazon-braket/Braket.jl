module BraketStateVectorCUDAExt

using BraketStateVector,
    BraketStateVector.Braket,
    BraketStateVector.StatsBase,
    BraketStateVector.StaticArrays,
    BraketStateVector.Combinatorics,
    CUDA,
    LinearAlgebra,
    CUDA.CUBLAS

import BraketStateVector.Braket:
    LocalSimulator,
    qubit_count,
    _run_internal,
    Instruction,
    Observables,
    AbstractProgramResult,
    ResultTypeValue,
    format_result,
    LocalQuantumTask,
    LocalQuantumTaskBatch,
    GateModelQuantumTaskResult,
    GateModelTaskResult,
    Program,
    Gate,
    AngledGate,
    IRObservable,
    apply_gate!,
    apply_noise!

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
    apply_gate_single_target!,
    evolve!,
    apply_controlled_gate!,
    pad_bit,
    matrix_rep,
    samples,
    probabilities,
    density_matrix,
    apply_observable!,
    marginal_probability,
    reinit!

const DEFAULT_THREAD_COUNT = 512
const CuStateVectorSimulator{T} = StateVectorSimulator{T,CuVector{T}}
const CuDensityMatrixSimulator{T} = DensityMatrixSimulator{T,CuMatrix{T}}

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

function StateVectorSimulator{T,CuVector{T}}(qubit_count::Int, shots::Int) where {T}
    sv = CUDA.zeros(T, 2^qubit_count)
    tc, bc = get_launch_dims(2^qubit_count)
    @cuda threads = tc blocks = bc init_zero_state_kernel!(sv)
    return StateVectorSimulator{T,CuVector{T}}(sv, qubit_count, shots)
end

function DensityMatrixSimulator{T,CuMatrix{T}}(qubit_count::Int, shots::Int) where {T}
    dm = CUDA.zeros(T, 2^qubit_count, 2^qubit_count)
    tc, bc = get_launch_dims(2^qubit_count)
    @cuda threads = tc blocks = bc init_zero_state_kernel!(dm)
    return DensityMatrixSimulator{T,CuMatrix{T}}(dm, qubit_count, shots)
end

function reinit!(
    svs::StateVectorSimulator{T,CuVector{T}},
    qubit_count::Int,
    shots::Int,
) where {T}
    CUDA.unsafe_free!(svs._state_vector_after_observables)
    if length(svs.state_vector) != 2^qubit_count
        CUDA.unsafe_free!(svs.state_vector)
        svs.state_vector = CuVector{T}(undef, 2^qubit_count)
    end
    tc, bc = get_launch_dims(2^qubit_count)
    @cuda threads = tc blocks = bc init_zero_state_kernel!(svs.state_vector)
    svs.qubit_count = qubit_count
    svs.shots = shots
    svs._state_vector_after_observables = CuVector{T}(undef, 0)
    return
end

function reinit!(
    dms::DensityMatrixSimulator{T,CuMatrix{T}},
    qubit_count::Int,
    shots::Int,
) where {T}
    if size(dms.density_matrix) != (2^qubit_count, 2^qubit_count)
        CUDA.unsafe_free!(dms.density_matrix)
        dms.density_matrix = CuMatrix{T}(undef, 2^qubit_count, 2^qubit_count)
    end
    tc, bc = get_launch_dims(2^qubit_count)
    @cuda threads = tc blocks = bc init_zero_state_kernel!(dms.density_matrix)
    dms.qubit_count = qubit_count
    dms.shots = shots
    dms._density_matrix_after_observables = CuMatrix{T}(undef, 0, 0)
    return
end

function _run_internal(
    simulator::StateVectorSimulator{T,CuVector{T}},
    circuit::Program,
    args...;
    shots::Int = 0,
    inputs::Dict{String,Float64} = Dict{String,Float64}(),
    kwargs...,
) where {T}
    if haskey(properties(simulator).action, "braket.ir.jaqcd.program")
        program = circuit
        qubits = qubit_count(circuit)
        r = simulator(program, qubits, args...; shots = shots, kwargs...)
        CUDA.unsafe_free!(simulator.state_vector)
        return format_result(r)
    else
        throw(
            ErrorException(
                "$(typeof(simulator)) does not support qubit gate-based programs.",
            ),
        )
    end
end

function __init__()
    BraketStateVector.Braket._simulator_devices[]["braket_sv_cu"] =
        StateVectorSimulator{ComplexF64,CuVector{ComplexF64}}
    BraketStateVector.Braket._simulator_devices[]["braket_dm_cu"] =
        DensityMatrixSimulator{ComplexF64,CuMatrix{ComplexF64}}
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

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    sv::CuVector{T},
    target::Int,
) where {T<:Complex}
    n_amps = length(sv)
    mat = SMatrix{2,2,T}(observable.matrix)
    nq = Int(log2(n_amps))
    endian_qubit = nq - target - 1
    total_ix = div(n_amps, 2)
    tc, bc = get_launch_dims(total_ix)
    @cuda threads = tc blocks = bc apply_observable_kernel!(sv, mat, endian_qubit)
    return sv
end

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    sv::CuVector{T},
    t1::Int,
    t2::Int,
) where {T<:Complex}
    n_amps = length(sv)
    nq = Int(log2(n_amps))
    endian_t1 = nq - 1 - t1
    endian_t2 = nq - 1 - t2
    mat = SMatrix{4,4,T}(observable.matrix)
    small_t, big_t = minmax(endian_t1, endian_t2)
    tc, bc = get_launch_dims(total_ix)
    @cuda threads = tc blocks = bc apply_observable_kernel!(
        sv,
        mat,
        endian_t1,
        endian_t2,
        small_t,
        big_t,
    )
    return sv
end

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    sv::CuVector{T},
    t1::Int,
    t2::Int,
    targets::Vararg{Int,N},
) where {T<:Complex,N}
    n_amps = length(sv)
    nq = N + 2
    ts = [t1, t2, targets...]
    endian_ts = nq - 1 .- ts
    g_mat = SMatrix{2^(N + 2),2^(N + 2),T}(observable.matrix)

    ordered_ts = tuple(sort(collect(endian_ts))...)
    flip_list = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    flip_masks = map(flip_list) do fl
        return flip_bits(0, fl)
    end
    total_ix = div(n_amps, 2^nq)
    tc, bc = get_launch_dims(total_ix)
    @cuda threads = tc blocks = bc apply_observable_kernel!(
        sv,
        g_mat,
        CuVector{Int}(flip_masks),
        ordered_ts,
    )
    return sv
end

function apply_observable!(
    observable::Braket.Observables.HermitianObservable,
    dm::CuMatrix{T},
    targets::Vararg{Int,N},
) where {T<:Complex,N}
    nq = Int(log2(size(dm, 1)))
    n_amps = 2^nq
    ts = collect(targets)
    endian_ts = nq - 1 .- ts
    o_mat = SMatrix{2^N,2^N,T}(transpose(observable.matrix))

    ordered_ts = tuple(sort(collect(endian_ts))...)
    flip_list = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    flip_masks = map(flip_list) do fl
        return flip_bits(0, fl)
    end
    slim_size = div(n_amps, 2^length(ts))
    tc, bc = get_launch_dims(slim_size)
    @cuda threads = (tc, tc) blocks = (bc, bc) apply_observable_kernel!(
        dm,
        o_mat,
        ordered_ts,
        CuVector{Int}(flip_masks),
    )
    return dm
end

for (G, cos_g, sin_g, g_mat, c_g_mat) in (
    (
        :PhaseShift,
        :(cos(g.angle[1])),
        :(sin(g.angle[1])),
        (1.0, 0.0, 0.0, :(cos_g + im * sin_g)),
        (1.0, 0.0, 0.0, :(cos_g - im * sin_g)),
    ),
    (
        :Rx,
        :(cos(g.angle[1] / 2.0)),
        :(sin(g.angle[1] / 2.0)),
        (:cos_g, :(-im * sin_g), :(-im * sin_g), :cos_g),
        (:cos_g, :(im * sin_g), :(im * sin_g), :cos_g),
    ),
    (
        :Ry,
        :(cos(g.angle[1] / 2.0)),
        :(sin(g.angle[1] / 2.0)),
        (:cos_g, :sin_g, :(-sin_g), :cos_g),
        (:cos_g, :sin_g, :(-sin_g), :cos_g),
    ),
    (
        :Rz,
        :(cos(g.angle[1] / 2.0)),
        :(sin(g.angle[1] / 2.0)),
        (:(cos_g - im * sin_g), 0.0, 0.0, :(cos_g + im * sin_g)),
        (:(cos_g + im * sin_g), 0.0, 0.0, :(cos_g - im * sin_g)),
    ),
)
    @eval begin
        function apply_gate_single_target!(
            ::Val{false},
            g::$G,
            state_vec::CuVector{T},
            qubit::Int,
        ) where {T<:Complex}
            n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
            total_ix = div(n_amps, 2)
            tc, bc = get_launch_dims(total_ix)
            g_00, g_10, g_01, g_11 = matrix_rep(g)
            @cuda threads = tc blocks = bc apply_gate_single_target_kernel!(
                g_00,
                g_01,
                g_10,
                g_11,
                state_vec,
                endian_qubit,
            )
            return
        end
        function apply_gate_single_target!(
            ::Val{true},
            g::$G,
            state_vec::CuVector{T},
            qubit::Int,
        ) where {T<:Complex}
            n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
            total_ix = div(n_amps, 2)
            tc, bc = get_launch_dims(total_ix)
            g_00, g_10, g_01, g_11 = conj(matrix_rep(g))
            @cuda threads = tc blocks = bc apply_gate_single_target_kernel!(
                g_00,
                g_01,
                g_10,
                g_11,
                state_vec,
                endian_qubit,
            )
            return
        end
    end
end

for (V, f) in ((true, :conj), (false, :identity))
    @eval begin
        function apply_gate_single_target!(
            ::Val{$V},
            g::G,
            state_vec::CuVector{T},
            qubit::Int,
        ) where {G<:Gate,T<:Complex}
            n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
            total_ix = div(n_amps, 2)
            tc, bc = get_launch_dims(total_ix)
            g_00, g_10, g_01, g_11 = $f(matrix_rep(g))[:]
            @cuda threads = tc blocks = bc apply_gate_single_target_kernel!(
                g_00,
                g_01,
                g_10,
                g_11,
                state_vec,
                endian_qubit,
            )
            return
        end
        function apply_gate!(
            ::Val{$V},
            g::G,
            state_vec::CuVector{T},
            t1::Int,
            t2::Int,
        ) where {G<:Gate,T<:Complex}
            n_amps, (endian_t1, endian_t2) = get_amps_and_qubits(state_vec, t1, t2)
            g_mat = SMatrix{4,4,T}($f(Matrix(matrix_rep(g))))
            total_ix = div(n_amps, 4)
            tc, bc = get_launch_dims(total_ix)

            @cuda threads = tc blocks = bc apply_gate_kernel!(
                g_mat,
                state_vec,
                endian_t1,
                endian_t2,
            )
            return
        end
        function apply_gate!(
            ::Val{$V},
            g::SingleExcitation,
            state_vec::CuVector{T},
            t1::Int,
            t2::Int,
        ) where {T<:Complex}
            n_amps, (endian_t1, endian_t2) = get_amps_and_qubits(state_vec, t1, t2)
            cosϕ = T(cos(g.angle[1] / 2.0))
            sinϕ = T(sin(g.angle[1] / 2.0))
            total_ix = div(n_amps, 4)
            tc, bc = get_launch_dims(total_ix)
            @cuda threads = tc blocks = bc apply_gate_single_ex_kernel!(
                cosϕ,
                sinϕ,
                state_vec,
                endian_t1,
                endian_t2,
            )
            return
        end
        function apply_gate!(
            ::Val{$V},
            g::DoubleExcitation,
            state_vec::CuVector{T},
            t1::Int,
            t2::Int,
            t3::Int,
            t4::Int,
        ) where {T<:Complex}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, t1, t2, t3, t4)
            cosϕ = T(cos(g.angle[1] / 2.0))
            sinϕ = T(sin(g.angle[1] / 2.0))
            total_ix = div(n_amps, 16)
            ordered_ts = tuple(sort(collect(endian_ts))...)
            tc, bc = get_launch_dims(total_ix)
            @cuda threads = tc blocks = bc apply_gate_double_ex_kernel!(
                cosϕ,
                sinϕ,
                state_vec,
                tuple(endian_ts...),
                ordered_ts,
            )
            return
        end
        function apply_controlled_gate!(
            ::Val{$V},
            ::Val{1},
            g::G,
            tg::TG,
            state_vec::CuVector{T},
            control::Int,
            target::Int,
        ) where {G<:Gate,TG<:Gate,T<:Complex}
            n_amps, (endian_control, endian_target) =
                get_amps_and_qubits(state_vec, control, target)
            total_ix = div(n_amps, 4)
            tc, bc = get_launch_dims(total_ix)
            g_00, g_10, g_01, g_11 = $f(matrix_rep(tg))
            @cuda threads = tc blocks = bc apply_controlled_gate_kernel!(
                Val(1),
                g_00,
                g_01,
                g_10,
                g_11,
                state_vec,
                endian_control,
                endian_target,
            )
            return
        end
        function apply_controlled_gate!(
            ::Val{$V},
            ::Val{1},
            g::G,
            tg::TG,
            state_vec::CuVector{T},
            control::Int,
            t1::Int,
            t2::Int,
        ) where {G<:Gate,TG<:Gate,T<:Complex}
            n_amps, (endian_control, endian_t1, endian_t2) =
                get_amps_and_qubits(state_vec, control, t1, t2)
            small_t, mid_t, big_t = sort([endian_control, endian_t1, endian_t2])
            total_ix = div(n_amps, 8)
            tc, bc = get_launch_dims(total_ix)
            tg_mat = SMatrix{8,8,T}($f(matrix_rep(tg)))
            @cuda threads = tc blocks = bc apply_controlled_gate_kernel!(
                Val(1),
                tg_mat,
                state_vec,
                endian_control,
                endian_t1,
                endian_t2,
                small_t,
                mid_t,
                big_t,
            )
            return
        end
        # doubly controlled unitaries
        function apply_controlled_gate!(
            ::Val{$V},
            ::Val{2},
            g::G,
            tg::TG,
            state_vec::CuVector{T},
            c1::Int,
            c2::Int,
            t::Int,
        ) where {G<:Gate,TG<:Gate,T<:Complex}
            n_amps, (endian_c1, endian_c2, endian_t) =
                get_amps_and_qubits(state_vec, c1, c2, t)
            total_ix = div(n_amps, 8)
            tc, bc = get_launch_dims(total_ix)
            small_t, mid_t, big_t = sort([endian_c1, endian_c2, endian_t])
            g_00, g_10, g_01, g_11 = $f(matrix_rep(tg))
            @cuda threads = tc blocks = bc apply_controlled_gate_kernel!(
                Val(2),
                g_00,
                g_01,
                g_10,
                g_11,
                state_vec,
                endian_c1,
                endian_c2,
                endian_t,
                small_t,
                mid_t,
                big_t,
            )
            return
        end
        # arbitrary number of targets
        function apply_gate!(
            ::Val{$V},
            g::Unitary,
            state_vec::CuVector{T},
            ts::Vararg{Int,NQ},
        ) where {T<:Complex,NQ}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, ts...)
            endian_ts isa Int && (endian_ts = (endian_ts,))
            ordered_ts = tuple(sort(collect(endian_ts))...)
            nq = NQ
            g_mat = SMatrix{2^NQ,2^NQ,T}($f(matrix_rep(g)))
            #use a mask here
            flip_list = map(0:2^nq-1) do t
                f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:nq-1]
                return ordered_ts[f_vals]
            end
            flip_masks = map(flip_list) do fl
                return flip_bits(0, fl)
            end
            total_ix = div(n_amps, 2^nq)
            tc, bc = get_launch_dims(total_ix)
            @cuda threads = tc blocks = bc apply_gate_kernel!(
                g_mat,
                SVector{2^NQ,Int}(flip_masks),
                state_vec,
                ordered_ts,
                Val(length(flip_masks)),
            )
            return
        end
    end
end
apply_gate!(
    ::Val{false},
    g::Unitary,
    state_vec::CuVector{T},
    qubit::Int,
) where {T<:Complex} = apply_gate_single_target!(Val(false), g, state_vec, qubit)
apply_gate!(
    ::Val{true},
    g::Unitary,
    state_vec::CuVector{T},
    qubit::Int,
) where {T<:Complex} = apply_gate_single_target!(Val(true), g, state_vec, qubit)

for G in (:CPhaseShift, :CPhaseShift00, :CPhaseShift10, :CPhaseShift01),
    (V, f) in ((true, :conj), (false, :identity))

    @eval begin
        function apply_gate!(
            ::Val{$V},
            g::$G,
            state_vec::CuVector{T},
            t1::Int,
            t2::Int,
        ) where {T<:Complex}
            n_amps, (endian_t1, endian_t2) = get_amps_and_qubits(state_vec, t1, t2)
            g_mat = SVector{4,T}($f(Vector{T}(matrix_rep(g))))
            total_ix = div(n_amps, 4)
            tc, bc = get_launch_dims(total_ix)
            @cuda threads = tc blocks = bc apply_gate_kernel!(
                g_mat,
                state_vec,
                endian_t1,
                endian_t2,
            )
            return
        end
    end
end


# TODO fix this
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
            ::Val{true},
            g::$cg,
            state_vec::CuVector{T},
            qubits::Int...,
        ) where {T<:Complex} =
            apply_controlled_gate!(Val(true), Val($nc), g, $tg(), state_vec, qubits...)
        apply_gate!(
            ::Val{false},
            g::$cg,
            state_vec::CuVector{T},
            qubits::Int...,
        ) where {T<:Complex} =
            apply_controlled_gate!(Val(false), Val($nc), g, $tg(), state_vec, qubits...)
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

#=
function sample_small_n(n::Int, normed_weights::CuVector{T}) where {T}
    function sample_small_n_kernel(sampled_vals::CuDeviceVector{Int}, needles::CuDeviceVector{T}, normed_weights::CuDeviceVector{T}) where {T}
        ix = threadIdx().x + (blockIdx().x - 1)*blockDim().x
        laneId = (threadIdx().x-1) & 0x1f
        for sample in 1:length(sampled_vals)
	    @inbounds begin
		    thread_weight = normed_weights[ix]
		    sample_needle = needles[sample]
		    has_greater   = CUDA.vote_ballot_sync(CUDA.FULL_MASK, thread_weight >= sample_needle)
		    has_lesser    = CUDA.vote_ballot_sync(CUDA.FULL_MASK, thread_weight < sample_needle)
		    low_needle    = 1 << laneId 
		    high_needle   = laneId == 31 ? 0 : 1 << (laneId + 1)
		    low_found     = (has_lesser & low_needle) >> laneId
		    high_found    = laneId == 31 ? (has_greater & high_needle) : (has_greater & high_needle) >> (laneId + 1)
		    #@cushow sample, laneId, sample_needle, thread_weight, low_found, high_found 
		    # first significant bit of has_greater is the lane that has the good threadidx
		    if low_found > 0 && high_found > 0
			sampled_vals[sample] = ix
		    end
	    end
        end
        return
    end
    sampled_inds = CUDA.zeros(Int, n)
    needles   = CUDA.rand(T, n)
    tc, bc    = get_launch_dims(length(normed_weights))
    @cuda threads=tc blocks=bc sample_small_n_kernel(sampled_inds, needles, normed_weights)
    host_inds = collect(sampled_inds)
    return host_inds
end
=#

function samples(svs::StateVectorSimulator{T,CuVector{T}}) where {T}
    #probs   = probabilities(svs)
    #normed_weights = cumsum(probs) ./ sum(probs)
    #host_probs = collect(probs)
    #probs   = nothing
    #samples = sample_small_n(svs.shots, normed_weights)
    #normed_weights = nothing
    #samples = sample(0:(2^svs.qubit_count-1), Weights(host_probs), svs.shots)
    samples = zeros(Int, svs.shots)
    return samples
end
samples(dms::DensityMatrixSimulator{T,CuMatrix{T}}) where {T} =
    sample(0:(2^dms.qubit_count-1), Weights(collect(probabilities(dms))), dms.shots)

end
