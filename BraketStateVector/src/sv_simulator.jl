mutable struct StateVectorSimulator{T} <: AbstractSimulator where {T}
    state_vector::StateVector{T}
    qubit_count::Int
    shots::Int
    _state_vector_after_observables::StateVector{T}
    function StateVectorSimulator{T}(qubit_count::Int, shots::Int) where {T}
        sv = zeros(complex(T), 2^qubit_count)
        sv[1] = complex(1.0)
        return new(sv, qubit_count, shots, zeros(complex(T), 0))
    end
end
StateVectorSimulator(::T, qubit_count::Int, shots::Int) where {T} = StateVectorSimulator{T}(qubit_count, shots)
StateVectorSimulator(qubit_count::Int, shots::Int) = StateVectorSimulator{ComplexF64}(qubit_count, shots)
Braket.qubit_count(svs::StateVectorSimulator) = svs.qubit_count

function evolve!(svs::StateVectorSimulator{T}, operations::Vector{Instruction}) where {T<:Complex}
    foreach(op->apply_gate!(op.operator, svs.state_vector, op.target...), operations)
    return svs
end

state_vector(svs::StateVectorSimulator)   = svs.state_vector
density_matrix(svs::StateVectorSimulator) = kron(svs.state_vector, conj(svs.state_vector))

for (gate, obs) in ((:X, :(Braket.Observables.X)), (:Y, :(Braket.Observables.Y)), (:Z, :(Braket.Observables.Z)), (:I, :(Braket.Observables.I)), (:H, :(Braket.Observables.H)))
    @eval begin
        function apply_observable(observable::$obs, sv::StateVector{T}, targets) where {T<:Complex}
            sv_copy = deepcopy(sv)
            for target in targets
                apply_gate!($gate(), sv_copy, target)
            end
            return sv_copy
        end
    end
end
function apply_observable(observable::Braket.Observables.TensorProduct, sv::StateVector{T}, targets) where {T<:Complex}
    sv_copy = deepcopy(sv)
    for (op, target) in zip(observable.factors, targets)
        apply_observable(op, sv_copy, target)
    end
    return sv_copy
end
function apply_observable(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, target::Int) where {T<:Complex}
    sv_copy = zeros(T, length(sv))
    n_amps = length(sv)
    nq = Int(log2(n_amps))
    endian_qubit = nq-target-1
    Threads.@threads for ix in 0:div(n_amps, 2)-1
        lower_ix   = pad_bit(ix, endian_qubit)
        higher_ix  = flip_bit(lower_ix, endian_qubit) 
        ix_pair    = [lower_ix + 1, higher_ix + 1]
        sv_copy[ix_pair] = observable.matrix * sv[ix_pair]
    end
    return sv_copy
end
function apply_observable(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, t1::Int, t2::Int) where {T<:Complex}
    sv_copy = zeros(T, length(sv))
    nq = Int(log2(n_amps))
    endian_t1 = nq-t1-1
    endian_t2 = nq-t2-1
    small_t, big_t = minmax(endian_t1, endian_t2)
    Threads.@threads for ix in 0:div(n_amps, 2)-1
        # bit shift to get indices
        ix_00 = pad_bit(pad_bit(ix, small_t), big_t)
        ix_10 = flip_bit(ix_00, endian_t2)
        ix_01 = flip_bit(ix_00, endian_t1)
        ix_11 = flip_bit(ix_10, endian_t1)
        ind_vec = [ix_00, ix_01, ix_10, ix_11] .+ 1
        sv_copy[ind_vec] = g.matrix * sv[ind_vec]
    end
    return sv_copy
end
function apply_observable(observable::Braket.Observables.HermitianObservable, sv::StateVector{T}, targets) where {T<:Complex}
    size(observable) = (2, 2) && length(targets) > 1
    sv_copy = zeros(T, length(sv))
    n_amps = length(sv)
    nq = Int(log2(n_amps))
    for t in targets
        endian_qubit = nq-t-1
        Threads.@threads for ix in 0:div(n_amps, 2)-1
            lower_ix   = pad_bit(ix, endian_qubit)
            higher_ix  = flip_bit(lower_ix, endian_qubit) 
            ix_pair    = [lower_ix + 1, higher_ix + 1]
            sv_copy[ix_pair] = observable.matrix * sv[ix_pair]
        end
    end
    return sv_copy
end
function expectation(svs::StateVectorSimulator, observable::Observables.Observable, targets)
    bra = Adjoint(svs.state_vector)
    ket = apply_observable(observable, svs.state_vector, targets) 
    return dot(bra, ket)
end

function state_with_observables(svs::StateVectorSimulator)
    isempty(svs._state_vector_after_observables) && error("observables have not been applied.")
    return svs._state_vector_after_observables
end


function apply_observables!(svs::StateVectorSimulator, observables)
    !isempty(svs._state_vector_after_observables) && error("observables have already been applied.")
    diag_gates = [diagonalizing_gates(obs...) for obs in observables]
    operations = reduce(vcat, diag_gates)
    svs._state_vector_after_observables = deepcopy(svs.state_vector)
    for op in operations
        apply_gate!(op.operator, svs._state_vector_after_observables, op.target...)
    end
    return svs
end
probabilities(svs::StateVectorSimulator) = abs2.(svs.state_vector)
samples(svs::StateVectorSimulator) = sample(0:length(svs.state_vector)-1, Weights(probabilities(svs)), svs.shots)
