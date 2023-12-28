module BraketStateVectorCUDAExt

using BraketStateVector, BraketStateVector.Braket, CUDA

import BraketStateVector.Braket: LocalSimulator, qubit_count, _run_internal, Instruction, Observables, AbstractProgramResult, ResultTypeValue, format_result, LocalQuantumTask, LocalQuantumTaskBatch, GateModelQuantumTaskResult, GateModelTaskResult, Program, Gate, AngledGate, IRObservable, apply_gate!, apply_noise!
import BraketStateVector: AbstractSimulator, classical_shadow, AbstractStateVector, AbstractDensityMatrix, get_amps_and_qubits, pad_bits, flip_bits, flip_bit, DoubleExcitation, SingleExcitation, apply_gate_single_target!, evolve!, apply_controlled_gate!, gate_kernel

const DEFAULT_THREAD_COUNT        = 512
const CuStateVectorSimulator{T}   = StateVectorSimulator{T, CuVector{T}}
const CuDensityMatrixSimulator{T} = DensityMatrixSimulator{T, CuMatrix{T}}

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

function apply_gate_single_target_kernel!(::Val{V}, g::G, state_vec::CuVector{T}, endian_qubit::Int) where {V, G<:Gate, T<:Complex}
    ix         = threadIdx().x + blockIdx().x * blockDim().x
    lower_ix   = pad_bit(ix, endian_qubit)
    higher_ix  = flip_bit(lower_ix, endian_qubit) + 1
    lower_ix  += 1
    lower_amp  = state_vec[lower_ix]
    higher_amp = state_vec[higher_ix]
    state_vec[lower_ix], state_vec[higher_ix] = gate_kernel(Val(V), g, lower_amp, higher_amp)
    return
end
function apply_gate_single_target!(::Val{V}, g::G, state_vec::CuVector{T}, qubit::Int) where {V, G<:Gate, T<:Complex}
    n_amps, endian_qubit = get_amps_and_qubits(state_vec, qubit)
    total_ix = div(n_amps, 2)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_gate_single_target_kernel!(Val(V), g, state_vec, endian_qubit)
    return
end

# generic two-qubit non controlled unitaries
function apply_gate_kernel!(::Val{V}, g_mat::CuMatrix{T}, state_vec::CuVector{T}, endian_t1::Int, endian_t2::Int) where {V, T<:Complex}
    small_t, big_t = minmax(endian_t1, endian_t2)
    ix      = threadIdx().x + blockIdx().x * blockDim().x
    # bit shift to get indices
    ix_00   = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10   = flip_bit(ix_00, endian_t2)
    ix_01   = flip_bit(ix_00, endian_t1)
    ix_11   = flip_bit(ix_10, endian_t1)
    ind_vec = [ix_00+1, ix_01+1, ix_10+1, ix_11+1]
    state_vec[ind_vec] = gate_kernel(Val(V), g_mat, state_vec[ind_vec])
    return
end
function apply_gate!(::Val{V}, g::G, state_vec::CuVector{T}, t1::Int, t2::Int) where {V, G<:Gate, T<:Complex}
    n_amps, (endian_t1, endian_t2) = get_amps_and_qubits(state_vec, t1, t2)
    g_mat    = matrix_rep(g)
    total_ix = div(n_amps, 4)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_gate_kernel!(Val(V), cu(g_mat), state_vec, endian_t1, endian_t2)
    return
end

function apply_controlled_gate_kernel!(::Val{V}, ::Val{1}, g::G, tg::TG, state_vec::CuVector{T}, endian_control::Int, endian_target::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    small_t, big_t = minmax(endian_control, endian_target)
    ix    = threadIdx().x + blockIdx().x * blockDim().x
    ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
    ix_10 = flip_bit(ix_00, endian_control)
    ix_01 = flip_bit(ix_00, endian_target)
    ix_11 = flip_bit(ix_01, endian_control)
    lower_ix   = ix_10+1
    higher_ix  = ix_11+1
    lower_amp  = state_vec[lower_ix]
    higher_amp = state_vec[higher_ix]
    state_vec[lower_ix], state_vec[higher_ix] = gate_kernel(Val(V), tg, lower_amp, higher_amp)
    return
end

function apply_controlled_gate!(::Val{V}, ::Val{1}, g::G, tg::TG, state_vec::CuVector{T}, control::Int, target::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    n_amps, (endian_control, endian_target) = get_amps_and_qubits(state_vec, control, target) 
    total_ix = div(n_amps, 4)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_controlled_gate_kernel!(Val(V), Val(1), g, tg, state_vec, endian_control, endian_target)
    return
end

function apply_controlled_gate_kernel!(::Val{V}, ::Val{1}, g::G, tg::TG, state_vec::CuVector{T}, endian_control::Int, endian_t1::Int, endian_t2::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    small_t, mid_t, big_t = sort([endian_control, endian_t1, endian_t2])
    ix    = threadIdx().x + blockIdx().x * blockDim().x
    ix_00 = flip_bit(pad_bits(ix, [small_t, mid_t, big_t]), endian_control)
    ix_10 = flip_bit(ix_00, endian_t2)
    ix_01 = flip_bit(ix_00, endian_t1)
    ix_11 = flip_bit(ix_01, endian_t2)
    ix_vec = [ix_00 + 1, ix_01 + 1, ix_10 + 1, ix_11 + 1]
    state_vec[ix_vec] = gate_kernel(Val(V), tg_mat, state_vec[ix_vec])
    return
end

function apply_controlled_gate!(::Val{V}, ::Val{1}, g::G, tg::TG, state_vec::CuVector{T}, control::Int, t1::Int, t2::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    tg_mat = matrix_rep(tg)
    n_amps, (endian_control, endian_t1, endian_t2) = get_amps_and_qubits(state_vec, control, t1, t2) 
    total_ix = div(n_amps, 8)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_controlled_gate_kernel!(Val(V), Val(1), g, tg, state_vec, endian_control, endian_t1, endian_t2)
    return
end

function apply_controlled_gate_kernel!(::Val{V}, ::Val{2}, g::G, tg::TG, state_vec::CuVector{T}, endian_c1::Int, endian_c2::Int, endiant_t::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    small_t, mid_t, big_t = sort([endian_c1, endian_c2, endian_target])
    ix    = threadIdx().x + blockIdx().x * blockDim().x
    # insert 0 at c1, 0 at c2, 0 at target
    padded_ix  = pad_bits(ix, [small_t, mid_t, big_t])
    # flip c1 and c2
    lower_ix   = flip_bit(flip_bit(padded_ix, endian_c1), endian_c2)
    # flip target
    higher_ix  = flip_bit(lower_ix, endian_target) + 1
    lower_ix  += 1
    lower_amp  = state_vec[lower_ix]
    higher_amp = state_vec[higher_ix]
    state_vec[lower_ix], state_vec[higher_ix] = gate_kernel(Val(V), tg, lower_amp, higher_amp)
    return
end

# doubly controlled unitaries
function apply_controlled_gate!(::Val{V}, ::Val{2}, g::G, tg::TG, state_vec::CuVector{T}, c1::Int, c2::Int, t::Int) where {V, G<:Gate, TG<:Gate, T<:Complex}
    n_amps, (endian_c1, endian_c2, endian_target) = get_amps_and_qubits(state_vec, c1, c2, t) 
    total_ix = div(n_amps, 8)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_controlled_gate_kernel!(Val(V), Val(2), g, tg, state_vec, endian_c1, endian_c2, endian_t)
    return
end

function apply_gate_kernel!(::Val{V}, g_mat::CuMatrix{T}, flip_list::Vector{Vector{Int}}, state_vec::CuVector{T}, ordered_ts::Vector{Int}) where {V, T<:Complex}
    ix    = threadIdx().x + blockIdx().x * blockDim().x
    padded_ix = pad_bits(ix, ordered_ts)
    ixs = [flip_bits(padded_ix, f) + 1 for f in flip_list]
    amps = state_vec[ixs]
    new_amps = gate_kernel(Val(V), g_mat, amps)
    state_vec[ixs] = new_amps
    return
end

# arbitrary number of targets
function apply_gate!(::Val{V}, g::Unitary, state_vec::CuVector{T}, ts::Vararg{Int, NQ}) where {V, T<:Complex, NQ}
    n_amps, endian_ts = get_amps_and_qubits(state_vec, ts...)
    endian_ts isa Int && (endian_ts = (endian_ts,)) 
    ordered_ts = sort(collect(endian_ts))
    g_mat      = cu(matrix_rep(g))
    flip_list  = map(0:2^nq-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix in 0:nq-1]
        return ordered_ts[f_vals]
    end
    total_ix = div(n_amps, 2^nq)
    tc, bc   = get_launch_dims(total_ix)
    @cuda threads=tc blocks=bc apply_gate_kernel!(Val(V), g_mat, flip_list, state_vec, ordered_ts)
    return
end

end
