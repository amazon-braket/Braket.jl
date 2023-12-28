using Test, LinearAlgebra, Braket, BraketStateVector, DataStructures

import Braket: Instruction

funcs = CUDA.functional() ? (identity, cu) : (identity,)

@testset "Density matrix simulator" begin
    for f in funcs
        sx = [0 1; 1 0]
        si = [1 0; 0 1]
        matrix_3q = kron(sx, kron(si, si))
        matrix_4q = kron(kron(sx, si), kron(si, si))
        matrix_5q = kron(sx, kron(kron(sx, si), kron(si, si)))
        density_matrix_3q = zeros(ComplexF64, 8, 8)
        density_matrix_3q[5, 5] = 1.0
        density_matrix_4q = zeros(ComplexF64, 16, 16)
        density_matrix_4q[9, 9] = 1.0
        density_matrix_5q = zeros(ComplexF64, 32, 32)
        density_matrix_5q[25, 25] = 1.0
      
        XX = kron([0 1; 1 0], [0 1; 1 0])
        YZ = kron([0 -im; im 0], [1 0; 0 -1])
        tqcp_kraus = Kraus([√0.7 * diagm(ones(4)), √0.1 * XX, √0.2 * YZ])
        simulation = f(DensityMatrixSimulator(2, 0))
        simulation = evolve!(simulation, [Instruction(X(), [0]), Instruction(X(), [1]), Instruction(tqcp_kraus, [0, 1])])
        tqcp_dm    = simulation.density_matrix

        @testset "Simple circuits $instructions" for (instructions, qubit_count, density_matrix, probability_amplitudes) in [
            (
                [Instruction(X(), [0]), Instruction(BitFlip(0.1), [0])],
                1,
                [0.1 0.0; 0.0 0.9],
                [0.1, 0.9],
            ),
            (
                [Instruction(H(), [0]), Instruction(PhaseFlip(0.1), [0])],
                1,
                [0.5 0.4; 0.4 0.5],
                [0.5, 0.5],
            ),
            (
                [Instruction(X(), [0]), Instruction(Depolarizing(0.3), [0])],
                1,
                [0.2 0.0; 0.0 0.8],
                [0.2, 0.8],
            ),
            (
                [Instruction(X(), [0]), Instruction(AmplitudeDamping(0.15), [0])],
                1,
                [0.15 0.0; 0.0 0.85],
                [0.15, 0.85],
            ),
            (
                [Instruction(X(), [0]), Instruction(GeneralizedAmplitudeDamping(0.15, 0.2), [0])],
                1,
                [0.03 0.0; 0.0 0.97],
                [0.03, 0.97],
            ),
            (
                [Instruction(X(), [0]), Instruction(PauliChannel(0.15, 0.16, 0.17), [0])],
                1,
                [0.31 0.0; 0.0 0.69],
                [0.31, 0.69],
            ),
            (
                [Instruction(X(), [0]), Instruction(X(), [1]), Instruction(TwoQubitPauliChannel(Dict("XX"=>0.1, "YZ"=>0.2)), [0, 1])],
                2,
                tqcp_dm,
                diag(tqcp_dm),
            ),
            (
                [Instruction(H(), [0]), Instruction(PhaseDamping(0.36), [0]), Instruction(H(), [0])],
                1,
                [0.9 0.0; 0.0 0.1],
                [0.9, 0.1],
            ),
            (
                [Instruction(X(), [0]), Instruction(Kraus([[0.8 0; 0 0.8], [0 0.6; 0.6 0]]), [0])],
                1,
                [0.36 0.0; 0.0 0.64],
                [0.36, 0.64],
            ),
            (
                [Instruction(X(), [0]), Instruction(X(), [1]), Instruction(TwoQubitDepolarizing(0.1), [0, 1])],
                2,
                [0.026666667 0.0 0.0 0.0; 0.0 0.026666667 0.0 0.0; 0.0 0.0 0.026666667 0.0; 0.0 0.0 0.0 0.92],
                [0.026666667, 0.026666667, 0.026666667, 0.92],
            ),
            (
                [Instruction(H(), [0]), Instruction(H(), [1]), Instruction(TwoQubitDephasing(0.1), [0, 1]), Instruction(H(), [0]), Instruction(H(), [1])],
                2,
                [0.8999999999 0.0 0.0 0.0; 0.0 0.033333333333333 0.0 0.0; 0.0 0.0 0.03333333333333331 0.0; 0.0 0.0 0.0 0.03333333333333331],
                [0.8999999999, 0.03333333333333, 0.03333333333333, 0.033333333333],
            ),
            (
                [Instruction(Unitary(matrix_3q), (0, 1, 2))],
                3,
                density_matrix_3q,
                [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
            ),
            (
                [Instruction(Unitary(matrix_4q), (0, 1, 2, 3))],
                4,
                density_matrix_4q,
                [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            ),
            (
                [Instruction(Kraus([matrix_5q]), [0, 1, 2, 3, 4])],
                5,
                density_matrix_5q,
                [
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                ],
            ),
        ]
            simulation = f(DensityMatrixSimulator(qubit_count, 0))
            simulation = evolve!(simulation, instructions)
            @test density_matrix ≈ simulation.density_matrix
            @test probability_amplitudes ≈ BraketStateVector.probabilities(simulation)
        end

        @testset "Apply observables $obs" for (obs, equivalent_gates, qubit_count) in [ 
                                                                                       ([(Braket.Observables.X(), [0])], [Instruction(H(), [0])], 1),
                                                                                       ([(Braket.Observables.Z(), [0])], Instruction[], 1),
                                                                                       ([(Braket.Observables.I(), [0])], Instruction[], 1),
                                                                                       ([(Braket.Observables.X(), [0]), (Braket.Observables.Z(), [3]), (Braket.Observables.H(), [2])], [Instruction(H(), [0]), Instruction(Ry(-π/4), [2])], 5),
                                                                                       ([(Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.Z(), Braket.Observables.H(), Braket.Observables.I()]), [0,3,2,1])], [Instruction(H(), [0]), Instruction(Ry(-π/4), [2])], 5,),
                                                                                       ([(Braket.Observables.X(), [0, 1])], [Instruction(H(), [0]), Instruction(H(), [1])], 2),
                                                                                       ([(Braket.Observables.Z(), [0, 1])], Instruction[], 2),
                                                                                       ([(Braket.Observables.I(), [0, 1])], Instruction[], 2),
                                                                                       ([(Braket.Observables.TensorProduct([Braket.Observables.I(), Braket.Observables.Z()]), [2, 0])], Instruction[], 3),
                                                                                       ([(Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.Z()]), [2, 0])], [Instruction(H(), [2])], 3),
        ]
            sim_observables = f(DensityMatrixSimulator(qubit_count, 0))
            sim_observables = BraketStateVector.apply_observables!(sim_observables, obs)
            sim_gates = f(DensityMatrixSimulator(qubit_count, 0))
            sim_gates = evolve!(sim_gates, equivalent_gates)
            @test BraketStateVector.state_with_observables(sim_observables) ≈ sim_gates.density_matrix
        end
        @testset "Apply observables fails at second call" begin
            simulation = f(DensityMatrixSimulator(4, 0))
            simulation = BraketStateVector.apply_observables!(simulation, [(Braket.Observables.X(), [0])])
            @test_throws ErrorException BraketStateVector.apply_observables!(simulation, [(Braket.Observables.X(), [0])])
        end
        @testset "state_with_observables fails before any observables are applied" begin
            simulation = f(DensityMatrixSimulator(4, 0))
            @test_throws ErrorException BraketStateVector.state_with_observables(simulation)
        end
        @testset "QFT simulation" begin
            function qft_circuit_operations(qubit_count::Int)
                qft_ops = Instruction[]
                for target_qubit in 0:qubit_count-1
                    angle = π / 2
                    push!(qft_ops, Instruction(H(), [target_qubit]))
                    for control_qubit in target_qubit + 1:qubit_count-1
                        push!(qft_ops, Instruction(CPhaseShift(angle), [control_qubit, target_qubit]))
                        angle /= 2
                    end
                end
                return qft_ops
            end
            qubit_count = 6
            simulation = f(DensityMatrixSimulator(qubit_count, 0))
            operations = qft_circuit_operations(qubit_count)
            simulation = evolve!(simulation, operations)
            @assert BraketStateVector.probabilities(simulation) ≈ fill(1.0 / (2^qubit_count), 2^qubit_count)
        end
        @testset "samples" begin
            simulation = f(DensityMatrixSimulator(2, 10000))
            simulation = evolve!(simulation, [Instruction(H(), [0]), Instruction(CNot(), [0, 1])])
            samples = counter(BraketStateVector.samples(simulation))
            
            @test qubit_count(simulation) == 2
            @test collect(keys(samples)) == [0, 3]
            @test 0.4 < samples[0] / (samples[0] + samples[3]) < 0.6
            @test 0.4 < samples[3] / (samples[0] + samples[3]) < 0.6
            @test samples[0] + samples[3] == 10000
        end
    end
end
