mutable struct DensityMatrixSimulator{T} <: AbstractSimulator where {T}
    density_matrix::DensityMatrix{T}
    qubit_count::Int
    shots::Int
    _density_matrix_after_observables::DensityMatrix{T}
    function DensityMatrixSimulator{T}(qubit_count::Int, shots::Int) where {T}
        dm      = zeros(complex(T), 2^qubit_count, 2^qubit_count)
        dm[1,1] = complex(1.0)
        return new(dm, qubit_count, shots, zeros(complex(T), 0, 0))
    end
    function DensityMatrixSimulator{T}(density_matrix::DensityMatrix{T}, qubit_count::Int, shots::Int) where {T}
        return new(density_matrix, qubit_count, shots, zeros(complex(T), 0, 0))
    end
end
DensityMatrixSimulator(::T, qubit_count::Int, shots::Int) where {T} = DensityMatrixSimulator{T}(qubit_count, shots)
DensityMatrixSimulator(qubit_count::Int, shots::Int) = DensityMatrixSimulator{ComplexF64}(qubit_count, shots)
Braket.qubit_count(dms::DensityMatrixSimulator) = dms.qubit_count
Braket.properties(d::DensityMatrixSimulator) = dm_props
supported_operations(d::DensityMatrixSimulator)   = dm_props.action["braket.ir.openqasm.program"].supportedOperations
supported_result_types(d::DensityMatrixSimulator) = dm_props.action["braket.ir.openqasm.program"].supportedResultTypes
device_id(dms::DensityMatrixSimulator) = "braket_dm"
Braket.name(dms::DensityMatrixSimulator) = "DensityMatrixSimulator"
Base.show(io::IO, dms::DensityMatrixSimulator) = print(io, "DensityMatrixSimulator(qubit_count=$(qubit_count(dms)), shots=$(dms.shots)")
Base.similar(dms::DensityMatrixSimulator{T}; shots::Int=dms.shots) where {T} = DensityMatrixSimulator{T}(dms.qubit_count, shots)
Base.copy(dms::DensityMatrixSimulator{T}) where {T} = DensityMatrixSimulator{T}(deepcopy(dms.density_matrix), dms.qubit_count, dms.shots)
function Base.copyto!(dst::DensityMatrixSimulator{T}, src::DensityMatrixSimulator{T}) where {T}
    copyto!(dst.density_matrix, src.density_matrix)
    return dst
end

function reinit!(dms::DensityMatrixSimulator{T}, qubit_count::Int, shots::Int) where {T}
    dm = zeros(complex(T), 2^qubit_count, 2^qubit_count)
    dm[1,1] = complex(1.0)
    dms.density_matrix = dm
    dms.qubit_count = qubit_count
    dms.shots = shots
    dms._density_matrix_after_observables = zeros(complex(T), 0, 0)
    return
end

function evolve!(dms::DensityMatrixSimulator{T}, operations::Vector{Instruction}) where {T<:Complex}
    for op in operations
        if op.operator isa Gate
            reshaped_dm = reshape(dms.density_matrix, length(dms.density_matrix))
            apply_gate!(Val(false), op.operator, reshaped_dm, op.target...)
            apply_gate!(Val(true),  op.operator, reshaped_dm, (dms.qubit_count .+ op.target)...)
        elseif op.operator isa Noise
            apply_noise!(op.operator, dms.density_matrix, op.target...)
        end
    end
    return dms
end

for (gate, obs) in ((:X, :(Braket.Observables.X)), (:Y, :(Braket.Observables.Y)), (:Z, :(Braket.Observables.Z)), (:I, :(Braket.Observables.I)), (:H, :(Braket.Observables.H)))
    @eval begin
        function apply_observable!(observable::$obs, dm::DensityMatrix{T}, targets) where {T<:Complex}
            nq = Int(log2(size(dm, 1)))
            reshaped_dm = reshape(dm, length(dm))
            for target in targets
                apply_gate!($gate(), reshaped_dm, target)
            end
            return dm
        end
    end
end
function apply_observable!(observable::Braket.Observables.HermitianObservable, dm::DensityMatrix{T}, targets::Int...) where {T<:Complex}
    nq        = Int(log2(size(dm, 1)))
    n_amps    = 2^nq
    ts        = collect(targets) 
    endian_ts = nq - 1 .- ts
    o_mat     = transpose(observable.matrix)
    
    ordered_ts = sort(collect(endian_ts))
    flip_list  = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix in 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    slim_size = div(n_amps, 2^length(ts))
    Threads.@threads for raw_ix in 0:(slim_size^2)-1
        ix = div(raw_ix, slim_size) 
        jx = mod(raw_ix, slim_size) 
        padded_ix = ix
        padded_jx = jx
        for t in ordered_ts
            padded_ix = pad_bit(padded_ix, t)
            padded_jx = pad_bit(padded_jx, t)
        end
        ixs = map(flip_list) do f
            flipped_ix = padded_ix
            for f_val in f
                flipped_ix = flip_bit(flipped_ix, f_val)
            end
            return flipped_ix + 1
        end
        jxs = map(flip_list) do f
            flipped_jx = padded_jx
            for f_val in f
                flipped_jx = flip_bit(flipped_jx, f_val)
            end
            return flipped_jx + 1
        end
        @views begin
            elems = dm[jxs[:], ixs[:]]
            dm[jxs[:], ixs[:]] = o_mat * elems
        end
    end
    return dm
end

function state_with_observables(dms::DensityMatrixSimulator)
    isempty(dms._density_matrix_after_observables) && error("observables have not been applied.")
    return dms._density_matrix_after_observables
end

function apply_observables!(dms::DensityMatrixSimulator, observables)
    !isempty(dms._density_matrix_after_observables) && error("observables have already been applied.")
    diag_gates = [diagonalizing_gates(obs...) for obs in observables]
    operations = reduce(vcat, diag_gates)
    dms._density_matrix_after_observables = deepcopy(dms.density_matrix)
    reshaped_dm = reshape(dms._density_matrix_after_observables, length(dms.density_matrix))
    for op in operations
        apply_gate!(Val(false), op.operator, reshaped_dm, op.target...)
        apply_gate!(Val(true), op.operator, reshaped_dm, (dms.qubit_count .+ op.target)...)
    end
    return dms
end

function expectation(dms::DensityMatrixSimulator, observable::Observables.Observable, targets::Int...)
    dm_copy = apply_observable(observable, dms.density_matrix, targets...)
    return real(sum(diag(dm_copy)))
end
state_vector(dms::DensityMatrixSimulator)   = isdiag(dms.density_matrix) ? diag(dms.density_matrix) : error("cannot express density matrix with off-diagonal elements as a pure state.") 
density_matrix(dms::DensityMatrixSimulator) = dms.density_matrix
probabilities(dms::DensityMatrixSimulator) = real.(diag(dms.density_matrix))
samples(dms::DensityMatrixSimulator) = sample(0:size(dms.density_matrix, 1)-1, Weights(probabilities(dms)), dms.shots)

function swap_bits(ix::Int, qubit_map::Dict{Int, Int})
    # only flip 01 and 10
    for (in_q, out_q) in qubit_map
        if in_q < out_q
            in_val  = ((1 << in_q)  & ix) >> in_q
            out_val = ((1 << out_q) & ix) >> out_q
            if in_val != out_val
                ix = flip_bit(flip_bit(ix, in_q), out_q)
            end
        end
    end
    return ix
end

function partial_trace(ρ::AbstractMatrix{ComplexF64}, output_qubits=collect(0:Int(log2(size(ρ, 1)))-1))
    isempty(output_qubits) && return sum(diag(ρ))
    n_amps = size(ρ, 1)
    nq = Int(log2(n_amps))
    length(unique(output_qubits)) == nq && return ρ
    
    qubits        = setdiff(collect(0:nq-1), output_qubits)
    endian_qubits = sort(nq .- qubits .- 1)
    q_combos      = vcat([Int[]], collect(combinations(endian_qubits)))
    final_ρ       = zeros(ComplexF64, 2^(nq-length(qubits)), 2^(nq-length(qubits)))
    # handle possibly permuted targets
    needs_perm           = !issorted(output_qubits)
    final_nq             = length(output_qubits)
    output_qubit_mapping = needs_perm ? Dict(zip(final_nq.-output_qubits.-1, final_nq.-collect(0:final_nq-1).-1)) : Dict{Int, Int}()
    for raw_ix in 0:length(final_ρ)-1
        ix = div(raw_ix, size(final_ρ, 1))
        jx = mod(raw_ix, size(final_ρ, 1))
        padded_ix = pad_bits(ix, endian_qubits) 
        padded_jx = pad_bits(jx, endian_qubits) 
        flipped_inds = Vector{CartesianIndex{2}}(undef, length(q_combos))
        for (c_ix, flipped_qs) in enumerate(q_combos)
            flipped_ix = padded_ix
            flipped_jx = padded_jx
            for flip_q in flipped_qs
                flipped_ix = flip_bit(flipped_ix, flip_q)
                flipped_jx = flip_bit(flipped_jx, flip_q)
            end
            flipped_inds[c_ix] = CartesianIndex{2}(flipped_ix + 1, flipped_jx + 1)
        end
        out_ix = needs_perm ? swap_bits(ix, output_qubit_mapping) : ix
        out_jx = needs_perm ? swap_bits(jx, output_qubit_mapping) : jx
        @views begin
            @inbounds trace_val = sum(ρ[flipped_inds])
            final_ρ[out_ix+1, out_jx+1] = trace_val
        end
    end
    return final_ρ
end
