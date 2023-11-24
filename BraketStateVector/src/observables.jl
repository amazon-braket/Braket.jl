diagonalizing_gates(g::Braket.Observables.I, targets) = Braket.Instruction[] 
diagonalizing_gates(g::Braket.Observables.H, targets) = [Braket.Instruction(Ry(-π/4.0), t) for t in targets]
diagonalizing_gates(g::Braket.Observables.X, targets) = [Braket.Instruction(H(), t) for t in targets]
diagonalizing_gates(g::Braket.Observables.Y, targets) = [Braket.Instruction(Unitary(1/√2*[1.0 -im; 1.0 im]), t) for t in targets]
diagonalizing_gates(g::Braket.Observables.Z, targets) = Braket.Instruction[] 
function diagonalizing_gates(g::Braket.Observables.HermitianObservable, targets)
    size(g.matrix, 1) == 2^length(targets) && return [Braket.Instruction(Unitary(eigvecs(g.matrix)), targets)]
    size(g.matrix, 1) == 2 && length(targets) > 1 && return [Braket.Instruction(Unitary(eigvecs(g.matrix)), target) for target in targets]
end
diagonalizing_gates(g::Braket.Observables.TensorProduct, targets) = reduce(vcat, [diagonalizing_gates(f, t) for (f, t) in zip(g.factors, targets)], init=Braket.Instruction[])
