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
end
DensityMatrixSimulator(::T, qubit_count::Int, shots::Int) where {T} = DensityMatrixSimulator{T}(qubit_count, shots)
DensityMatrixSimulator(qubit_count::Int, shots::Int) = DensityMatrixSimulator{ComplexF64}(qubit_count, shots)
Braket.qubit_count(svs::DensityMatrixSimulator) = svs.qubit_count

function evolve!(dms::DensityMatrixSimulator{T}, operations::Vector{Instruction}) where {T<:Complex}
    for op in operations
        if op.operator isa Gate
            reshaped_dm = reshape(dms.density_matrix, length(dms.density_matrix))
            apply_gate!(op.operator, reshaped_dm, op.target...)
            apply_gate!(op.operator, reshaped_dm, (dms.qubit_count .+ op.target)...)
        elseif op.operator isa Noise
            apply_noise!(op.operator, dms.density_matrix, op.target...)
        end
    end
    return dms
end

for (gate, obs) in ((:X, :(Braket.Observables.X)), (:Y, :(Braket.Observables.Y)), (:Z, :(Braket.Observables.Z)), (:I, :(Braket.Observables.I)), (:H, :(Braket.Observables.H)))
    @eval begin
        function apply_observable(observable::$obs, dm::DensityMatrix{T}, targets) where {T<:Complex}
            dm_copy = deepcopy(dm)
            reshaped_dm = reshape(dm_copy, length(dms.density_matrix))
            nq = Int(log2(size(dm, 1)))
            for target in targets
                apply_gate!($gate(), dm_copy, target)
                apply_gate!($gate(), dm_copy, nq + target)
            end
            return dm_copy
        end
    end
end
function apply_observable(observable::Braket.Observables.TensorProduct, dm::DensityMatrix{T}, targets) where {T<:Complex}
    dm_copy = deepcopy(dm)
    for (op, target) in zip(observable.factors, targets)
        apply_observable(op, dm_copy, target)
    end
    return dm_copy
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
        apply_gate!(op.operator, reshaped_dm, op.target...)
        apply_gate!(op.operator, reshaped_dm, (dms.qubit_count .+ op.target)...)
    end
    return dms
end
state_vector(dms::DensityMatrixSimulator)   = isdiag(dms.density_matrix) ? diag(dms.density_matrix) : error("cannot express density matrix with off-diagonal elements as a pure state.") 
density_matrix(dms::DensityMatrixSimulator) = dms.density_matrix
probabilities(dms::DensityMatrixSimulator) = abs.(real.(diag(dms.density_matrix)))
samples(dms::DensityMatrixSimulator) = sample(0:size(dms.density_matrix, 1)-1, Weights(probabilities(dms)), dms.shots)
