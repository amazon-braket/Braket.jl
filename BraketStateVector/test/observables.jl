using Test, LinearAlgebra, Braket, Braket.Observables, BraketStateVector
import Braket: Instruction, pauli_eigenvalues

herm_mat = [-0.32505758-0.32505758im -0.88807383; 0.62796303+0.62796303im -0.45970084]

single_qubit_tests = [(Observables.H(), (Ry(-π/4),) , pauli_eigenvalues(1)),
                      (Observables.X(), (H(),), pauli_eigenvalues(1)),
                      #(Observables.Y(), (Unitary([1 -im; 1 im] ./ √2),) , pauli_eigenvalues(1))),
                      (Observables.Y(), (Z(), S(), H()) , pauli_eigenvalues(1)),
                      (Observables.Z(), (), pauli_eigenvalues(1)),
                      (Observables.I(), (), [1, 1]),
                      (Observables.HermitianObservable([1 1-im; 1+im -1]), (Unitary(herm_mat),), [-√3, √3])]

@testset "Observables" begin
    @testset "Single qubit $obs" for (obs, expected_gates, eigenvalues) in single_qubit_tests
        actual_gates       = Braket.basis_rotation_gates(obs)
        @test actual_gates == expected_gates
        @test eigvals(obs) ≈ eigenvalues
    end
    @testset "Tensor product of standard gates" begin
        tensor = Observables.TensorProduct( [Observables.H(), Observables.X(), Observables.Z(), Observables.Y()])
        @test eigvals(tensor) == pauli_eigenvalues(4)

        actual_gates = Braket.basis_rotation_gates(tensor)
        @test length(actual_gates) == 4
        @test actual_gates[1] == Braket.basis_rotation_gates(Observables.H())
        @test actual_gates[2] == Braket.basis_rotation_gates(Observables.X())
        @test actual_gates[4] == Braket.basis_rotation_gates(Observables.Y())
    end
    @testset "Tensor product of nonstandard gates" begin
        tensor = Observables.TensorProduct([Observables.H(), Observables.I(), Observables.X(), Observables.Z(), Observables.Y()])
        @test eigvals(tensor) == [1, -1, 1, -1, -1, 1, -1, 1, -1, 1, -1, 1, 1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, -1, 1, -1, 1, -1, -1, 1, -1, 1]
        actual_gates = Braket.basis_rotation_gates(tensor)
        @test length(actual_gates) == 5
        @test actual_gates[1] == Braket.basis_rotation_gates(Observables.H())
        @test actual_gates[3] == Braket.basis_rotation_gates(Observables.X())
        @test actual_gates[5] == Braket.basis_rotation_gates(Observables.Y())
    end
end
