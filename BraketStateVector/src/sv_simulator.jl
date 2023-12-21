mutable struct StateVectorSimulator{T} <: AbstractSimulator where {T}
    state_vector::StateVector{T}
    qubit_count::Int
    shots::Int
    _state_vector_after_observables::StateVector{T}
    function StateVectorSimulator{T}(state_vector::StateVector{T}, qubit_count::Int, shots::Int) where {T}
        return new(state_vector, qubit_count, shots, zeros(complex(T), 0))
    end
    function StateVectorSimulator{T}(qubit_count::Int, shots::Int) where {T}
        sv    = zeros(complex(T), 2^qubit_count)
        sv[1] = complex(1.0)
        return new(sv, qubit_count, shots, zeros(complex(T), 0))
    end
end
StateVectorSimulator(::T, qubit_count::Int, shots::Int) where {T} = StateVectorSimulator{T}(qubit_count, shots)
StateVectorSimulator(qubit_count::Int, shots::Int) = StateVectorSimulator{ComplexF64}(qubit_count, shots)
Braket.qubit_count(svs::StateVectorSimulator) = svs.qubit_count
Braket.properties(svs::StateVectorSimulator) = sv_props
supported_operations(svs::StateVectorSimulator)   = sv_props.action["braket.ir.openqasm.program"].supportedOperations
supported_result_types(svs::StateVectorSimulator) = sv_props.action["braket.ir.openqasm.program"].supportedResultTypes
device_id(svs::StateVectorSimulator) = "braket_sv"
Braket.name(svs::StateVectorSimulator) = "StateVectorSimulator"
Base.show(io::IO, svs::StateVectorSimulator) = print(io, "StateVectorSimulator(qubit_count=$(qubit_count(svs)), shots=$(svs.shots)")
Base.similar(svs::StateVectorSimulator{T}; shots::Int=svs.shots) where {T} = StateVectorSimulator{T}(svs.qubit_count, shots)
Base.copy(svs::StateVectorSimulator{T}) where {T} = StateVectorSimulator{T}(deepcopy(svs.state_vector), svs.qubit_count, svs.shots)
function Base.copyto!(dst::StateVectorSimulator{T}, src::StateVectorSimulator{T}) where {T}
    copyto!(dst.state_vector, src.state_vector)
    return dst
end

function reinit!(svs::StateVectorSimulator{T}, qubit_count::Int, shots::Int) where {T}
    sv = zeros(complex(T), 2^qubit_count)
    sv[1] = complex(1.0)
    svs.state_vector = sv
    svs.qubit_count = qubit_count
    svs.shots = shots
    svs._state_vector_after_observables = zeros(complex(T), 0)
    return
end

function evolve!(svs::StateVectorSimulator{T}, operations::Vector{Instruction}) where {T<:Complex}
    for (oix, op) in enumerate(operations)
        apply_gate!(op.operator, svs.state_vector, op.target...)
    end
    return svs
end

state_vector(svs::StateVectorSimulator)   = svs.state_vector
density_matrix(svs::StateVectorSimulator) = kron(svs.state_vector, adjoint(svs.state_vector))

for (gate, obs) in ((:X, :(Braket.Observables.X)),
                    (:Y, :(Braket.Observables.Y)),
                    (:Z, :(Braket.Observables.Z)),
                    (:I, :(Braket.Observables.I)),
                    (:H, :(Braket.Observables.H)))
    @eval begin
        function apply_observable!(observable::$obs, sv::StateVector{T}, target::Int) where {T<:Complex}
            apply_gate!($gate(), sv, target)
            return sv
        end
    end
end
function apply_observable!(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, target::Int) where {T<:Complex}
    n_amps  = length(sv)
    mat     = observable.matrix
    nq      = Int(log2(n_amps))
    endian_qubit = nq-target-1
    Threads.@threads for ix in 0:div(n_amps, 2)-1
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) 
        ix_pair    = [lower_ix + 1, higher_ix + 1]
        @views begin
            sv[ix_pair] = mat * sv[ix_pair]
        end
    end
    return sv
end
function apply_observable!(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, t1::Int, t2::Int) where {T<:Complex}
    n_amps    = length(sv)
    nq        = Int(log2(n_amps))
    endian_t1 = nq-1-t1
    endian_t2 = nq-1-t2
    mat       = observable.matrix
    small_t, big_t = minmax(endian_t1, endian_t2)
    Threads.@threads for ix in 0:div(n_amps, 4)-1
        # bit shift to get indices
        ix_00   = pad_bit(pad_bit(ix, small_t), big_t)
        ix_10   = flip_bit(ix_00, endian_t2)
        ix_01   = flip_bit(ix_00, endian_t1)
        ix_11   = flip_bit(ix_10, endian_t1)
        @views begin
            ind_vec = SVector{4, Int}(ix_00+1, ix_10+1, ix_01+1, ix_11+1)
            sv[ind_vec] = mat * sv[ind_vec]
        end
    end
    return sv
end

function apply_observable!(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, t1::Int, t2::Int, targets::Int...) where {T<:Complex}
    n_amps    = length(sv)
    nq        = Int(log2(n_amps))
    ts        = [t1, t2, targets...]
    endian_ts = nq - 1 .- ts
    o_mat     = observable.matrix
    
    ordered_ts = sort(collect(endian_ts))
    flip_list  = map(0:2^length(ts)-1) do t
        f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix in 0:length(ts)-1]
        return ordered_ts[f_vals]
    end
    Threads.@threads for ix in 0:div(n_amps, 2^length(ts))-1
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
            amps = sv[ixs[:]]
            sv[ixs[:]] = o_mat * amps
        end
    end
    return sv
end

function expectation(svs::StateVectorSimulator, observable::Observables.Observable, targets::Int...)
    bra = svs.state_vector
    ket = apply_observable(observable, svs.state_vector, targets...)
    ev  = dot(bra, ket)
    return real(ev)
end

function state_with_observables(svs::StateVectorSimulator)
    isempty(svs._state_vector_after_observables) && error("observables have not been applied.")
    return svs._state_vector_after_observables
end

function apply_observables!(svs::StateVectorSimulator, observables)
    !isempty(svs._state_vector_after_observables) && error("observables have already been applied.")
    svs._state_vector_after_observables = deepcopy(svs.state_vector)
    operations = reduce(vcat, diagonalizing_gates(obs...) for obs in observables)
    for op in operations
        apply_gate!(op.operator, svs._state_vector_after_observables, op.target...)
    end
    return svs
end
probabilities(svs::StateVectorSimulator) = abs2.(svs.state_vector)
samples(svs::StateVectorSimulator) = sample(0:(2^svs.qubit_count-1), Weights(probabilities(svs)), svs.shots)
