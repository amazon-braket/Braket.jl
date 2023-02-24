using Braket, Braket.Observables, Test, LinearAlgebra, OrderedCollections, JSON3
using Braket: Instruction, Result, VIRTUAL, PHYSICAL, OpenQASMSerializationProperties, OpenQasmProgram

@testset "Circuit" begin
    @testset "Build basic circuit" begin
        @testset "with Int qubits" begin
            c = Circuit()
            H(c, 0)
            CNot(c, 0, 1)
            @test qubit_count(c) == 2
            @test depth(c) == 2
            c = Circuit()
            H(c, 0, 1, 2)
            Rx(c, 0, 1, 2, 0.5)
            @test qubit_count(c) == 3
            @test depth(c) == 2
            c = Circuit()
            CNot(c, [0, 1])
            CPhaseShift(c, [0, 1], 0.5)
            XX(c, [0, 1], 0.2)
            Swap(c, [0, 1])
            @test qubit_count(c) == 2
            @test depth(c) == 4
            c = Circuit()
            CSwap(c, [0, 1, 2])
            CCNot(c, [0, 1, 2])
            @test qubit_count(c) == 3
            @test depth(c) == 2
        end
        @testset "with Qubit qubits" begin
            c = Circuit()
            H(c, Qubit(0))
            CNot(c, Qubit(0), Qubit(1))
            @test qubit_count(c) == 2
            @test depth(c) == 2
            c = Circuit()
            H(c, Qubit(0), Qubit(1), Qubit(2))
            Rx(c, Qubit(0), Qubit(1), Qubit(2), 0.5)
            @test qubit_count(c) == 3
            @test depth(c) == 2
            c = Circuit()
            CNot(c, [Qubit(0), Qubit(1)])
            CPhaseShift(c, [Qubit(0), Qubit(1)], 0.5)
            XX(c, [Qubit(0), Qubit(1)], 0.2)
            Swap(c, [Qubit(0), Qubit(1)])
            @test qubit_count(c) == 2
            @test depth(c) == 4
            c = Circuit()
            CSwap(c, [Qubit(0), Qubit(1), Qubit(2)])
            CCNot(c, [Qubit(0), Qubit(1), Qubit(2)])
            @test qubit_count(c) == 3
            @test depth(c) == 2
        end
        @testset "with a mix" begin
            c = Circuit()
            H(c, Qubit(0))
            CNot(c, QubitSet([Qubit(0), 1]))
            @test qubit_count(c) == 2
            @test depth(c) == 2
            c = Circuit()
            H(c, QubitSet([Qubit(0), 1, Qubit(2)]))
            Rx(c, [Qubit(0), 1, Qubit(2)], 0.5)
            @test qubit_count(c) == 3
            @test depth(c) == 2
            c = Circuit()
            CNot(c, [Qubit(0), 1])
            CPhaseShift(c, QubitSet([Qubit(0), 1]), 0.5)
            XX(c, [Qubit(0), 1], 0.2)
            Swap(c, [Qubit(0), 1])
            @test qubit_count(c) == 2
            @test depth(c) == 4
            c = Circuit()
            CSwap(c, QubitSet([Qubit(0), 1, Qubit(2)]))
            CCNot(c, [Qubit(0), 1, Qubit(2)])
            @test qubit_count(c) == 3
            @test depth(c) == 2
        end
        @testset "with functors" begin
            c = Circuit()
            CSwap(c, QubitSet([Qubit(0), 1, Qubit(2)]))
            CCNot(c, [Qubit(0), 1, Qubit(2)])
            c1 = Circuit()
            c1(CSwap, QubitSet([Qubit(0), 1, Qubit(2)]))
            c1(CCNot, [Qubit(0), 1, Qubit(2)])
            @test c1 == c

            c = Circuit()
            CNot(c, [Qubit(0), 1])
            CPhaseShift(c, QubitSet([Qubit(0), 1]), 0.5)
            XX(c, [Qubit(0), 1], 0.2)
            Swap(c, [Qubit(0), 1])
            c1 = Circuit()
            c1(CNot, Qubit(0), 1)
            c1(CPhaseShift, QubitSet([Qubit(0), 1]), 0.5)
            c1(XX, [Qubit(0), 1], 0.2)
            c1(Swap, Qubit(0), 1)
            @test c == c1
            gate_list = [(CNot, Qubit(0), 1), (CPhaseShift, QubitSet([Qubit(0), 1]), 0.5), (XX, [Qubit(0), 1], 0.2), (Swap, Qubit(0), 1)]
            c2 = Circuit(gate_list)
            @test c2 == c

            c = Circuit()
            c(H, collect(0:10))
            @test qubits(c) == QubitSet(collect(0:10))
            @test length(c.instructions) == qubit_count(c)
        end
    end

    @testset "Add circuits" begin
        c1 = Circuit()
        c1 = H(c1, 0)
        c1 = CNot(c1, 0, 1)
        c2 = Circuit()
        angle = rand()
        c2 = XX(c2, 1, 2, angle)
        c1 = append!(c1, c2)
        @test qubit_count(c1) == 3
        @test depth(c1) == 3

        c3 = Circuit()
        c3(H, 0)
        c3(CNot, 0, 1)
        c4 = Circuit([(XX, 1, 2, angle)])
        c3(c4)
        @test c3 == c1
    end

    @testset "Add circuits with targets" begin
        c1 = Circuit()
        c1 = H(c1, collect(0:10))
        c1 = CNot(c1, 0, 1)
        c2 = Circuit()
        c2 = XX(c2, 0, 1, rand())
        c1 = append!(c1, c2, QubitSet([5, 6]))
        c3 = Circuit()
        c3 = ZZ(c3, 1, 2, rand())
        c1 = append!(c1, c3, Dict(1=>4, 2=>1))
        @test qubit_count(c1) == 11
        @test depth(c1) == 3
        c1 = Circuit()
        c1 = Braket.add_instruction!(c1, Instruction(H(), 0), OrderedSet(0:10))
        c1 = Braket.add_instruction!(c1, Instruction(CNot(), [1, 2]), OrderedSet([5, 6]))
        @test collect(values(c1.moments))[1:end-1] == [Instruction(H(), q) for q in 0:10]
        @test collect(values(c1.moments))[end] == Instruction(CNot(), [5, 6])
    end

    @testset "Applying result types" begin
        c = Circuit()
        c = H(c, collect(0:10))
        states = [repeat("0", qubit_count(c)), repeat("1", qubit_count(c))]
        c = Amplitude(c, states)
        @test c.result_types == [Amplitude(states)]
        c = Probability(c, [1, 2])
        @test c.result_types == [Amplitude(states), Probability([1, 2])]
        c = Circuit()
        c = H(c, collect(0:10))
        c = DensityMatrix(c)
        @test c.result_types == [DensityMatrix()]
        c = Circuit()
        c = H(c, collect(0:10))
        c = DensityMatrix(c, 1, 2)
        @test c.result_types == [DensityMatrix(1, 2)]

        c = Circuit()
        c(H, collect(0:10))
        c(Amplitude, states)
        @test c.result_types == [Amplitude(states)]
        c(Probability([1, 2]))
        @test c.result_types == [Amplitude(states), Probability([1, 2])]

        c = Circuit()
        c(H, collect(0:10))
        c([(Amplitude, states), (Probability, 1, 2)])
        @test c.result_types == [Amplitude(states), Probability([1, 2])]
    end

    @testset "Observable Results" begin
        @testset "functor application of results" begin
            c = Circuit([(H, collect(0:10))])
            c([(Expectation, Braket.Observables.Z(), 0), (Expectation, Braket.Observables.X(), 1), (Expectation, ["X", "X"], [2, 3])])
            @test length(c.result_types) == 3
            @test c.observables_simultaneously_measureable
            c(Expectation, Braket.Observables.X(), 0)
            @test !c.observables_simultaneously_measureable
        end
        c = Circuit()
        c = H(c, collect(0:10))
        c = Expectation(c, Braket.Observables.Z(), 0)
        c = Expectation(c, Braket.Observables.X(), 1)
        c = Expectation(c, ["X", "X"], [2, 3])
        @test c.observables_simultaneously_measureable
        c = Expectation(c, Braket.Observables.X(), 0)
        @test !c.observables_simultaneously_measureable
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 1)
        c = Circuit()
        c = H(c, collect(0:10))
        c = Expectation(c, Braket.Observables.Z())
        @test c.observables_simultaneously_measureable
        c = Circuit()
        c = H(c, collect(0:10))
        c = Expectation(c, "Z")
        @test c.observables_simultaneously_measureable
        c = Circuit()
        c = H(c, collect(0:10))
        c = Expectation(c, "Z", 1)
        c = Expectation(c, "X", [3, 4, 5])
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        tp = Braket.Observables.TensorProduct([ho, ho])
        c = Variance(c, tp, [6, 7, 8, 9])
        @test c.observables_simultaneously_measureable
        c = Variance(c, Braket.Observables.X())
        @test !c.observables_simultaneously_measureable
        c = Circuit()
        c = H(c, collect(0:1))
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        c = Expectation(c, ho, [0, 1])
        c = Variance(c, ho, [0, 1])
        @test c.observables_simultaneously_measureable

        c = Circuit()
        c = H(c, collect(0:1))
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        c = Expectation(c, ho, [0, 1])
        c = Variance(c, ho, [0, 1])
        @test c.observables_simultaneously_measureable

        c = Circuit()
        c = H(c, collect(0:1))
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        c = Expectation(c, ho, [0, 1])
        c = Variance(c, ho, [0, 1])
        n = [1. -im; im -1.]
        no = Braket.Observables.HermitianObservable(kron(n,n,n))
        c = Z(c, 2)
        c = Variance(c, no, Int[])
        @test !c.observables_simultaneously_measureable

        c = Circuit()
        c = H(c, collect(0:1))
        m = [1. -im; im -1.]
        n = [-1. im; -im 1.]
        ho = Braket.Observables.HermitianObservable(kron(m, n))
        c = Expectation(c, ho, [0, 1])
        c = Expectation(c, ho, [1, 0])
        @test !c.observables_simultaneously_measureable

        c = Circuit()
        c = H(c, collect(0:1))
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        c = Expectation(c, ho, Int[])
        c = Variance(c, ho, Int[])
        @test c.observables_simultaneously_measureable

        tp = Braket.Observables.TensorProduct([ho, ho])
        c = Circuit()
        c = H(c, collect(0:3))
        c = Expectation(c, tp, [0, 1, 2, 3])
        c = Variance(c, tp, [0, 1, 2, 3])
        @test c.observables_simultaneously_measureable

        c = Circuit()
        c = H(c, collect(0:3))
        c = Expectation(c, Braket.Observables.Y(), [0])
        c = Probability(c)
        @test !c.observables_simultaneously_measureable
        c = Circuit()
        c = H(c, collect(0:3))
        c = Expectation(c, Braket.Observables.Z(), [0])
        c = Probability(c)
        @test c.observables_simultaneously_measureable
    end
    @testset "Adjoint gradient" begin
        α = FreeParameter(:alpha)
        op  = 2.0 * Braket.Observables.X() * Braket.Observables.X()
        op2 = 2.0 * Braket.Observables.Y() * Braket.Observables.Y()
        @testset for targets ∈ ([QubitSet(0, 1)], [[0, 1]], [0, 1], QubitSet(0, 1))
            c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)])
            c = AdjointGradient(c, op, targets, [α])
            @test length(c.result_types) == 1
            @test c.result_types[1] isa AdjointGradient
            @test c.result_types[1].observable == op
            @test c.result_types[1].targets == [QubitSet(0, 1)]
            @test c.result_types[1].parameters == ["alpha"]
            @test_throws ArgumentError AdjointGradient(c, op2, [QubitSet(0, 1)], [α])
        end

        c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)])
        op  = 2.0 * Braket.Observables.X() * Braket.Observables.X()
        @test_throws DimensionMismatch AdjointGradient(c, op, [QubitSet(0)], [α])
        op3 = op + op2
        @test_throws DimensionMismatch AdjointGradient(c, op3, [QubitSet(0, 1)], [α])
        
        op  = 2.0 * Braket.Observables.X()
        c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)])
        c = AdjointGradient(c, op, 0, [α])
        @test c.result_types[1].targets == [QubitSet(0)]

        # make sure qubit count is correct
        α = FreeParameter(:alpha)
        c = Circuit([(H, 0), (H, 1), (Rx, 0, α), (Rx, 1, α)])
        op  = 2.0 * Braket.Observables.X() * Braket.Observables.X()
        @test qubit_count(c) == 2
        c = AdjointGradient(c, op, [QubitSet(1, 2)], [α])
        @test qubit_count(c) == 3
    end
    @testset "Basis rotation instructions" begin
        @testset "Basic" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.X(), 0)
            p = Braket.Program(circ)
            expected_ixs = [Instruction(H(), 0), Instruction(CNot(), [0, 1])]
            expected_rts = [Braket.IR.Sample(["x"], [0], "sample")]
            expected_bris = [Instruction(H(), 0)]

            @test p.instructions == expected_ixs
            @test p.results == expected_rts
            @test p.basis_rotation_instructions == expected_bris
            
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.Y(), 0)
            p = Braket.Program(circ)
            expected_ixs = [Instruction(H(), 0), Instruction(CNot(), [0, 1])]
            expected_rts = [Braket.IR.Sample(["y"], [0], "sample")]
            expected_bris = [Instruction(Z(), 0), Instruction(S(), 0), Instruction(H(), 0)]

            @test p.instructions == expected_ixs
            @test p.results == expected_rts
            @test p.basis_rotation_instructions == expected_bris
            
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.Z(), 0)
            p = Braket.Program(circ)
            expected_ixs = [Instruction(H(), 0), Instruction(CNot(), [0, 1])]
            expected_rts = [Braket.IR.Sample(["z"], [0], "sample")]
            expected_bris = Instruction[]

            @test p.instructions == expected_ixs
            @test p.results == expected_rts
            @test p.basis_rotation_instructions == expected_bris

            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.I(), 0)
            p = Braket.Program(circ)
            expected_ixs = [Instruction(H(), 0), Instruction(CNot(), [0, 1])]
            expected_rts = [Braket.IR.Sample(["i"], [0], "sample")]
            expected_bris = Instruction[]

            @test p.instructions == expected_ixs
            @test p.results == expected_rts
            @test p.basis_rotation_instructions == expected_bris

            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.TensorProduct(["x", "h"]), 0, 1)
            p = Braket.Program(circ)
            expected_ixs = [Instruction(H(), 0), Instruction(CNot(), [0, 1])]
            expected_rts = [Braket.IR.Sample(["x", "h"], [0, 1], "sample")]
            expected_bris = [Instruction(H(), 0), Instruction(Ry(-π/4), 1)]

            @test p.instructions == expected_ixs
            @test p.results == expected_rts
            @test p.basis_rotation_instructions == expected_bris
        end
        @testset "Observable on all qubits" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.Y())
            expected = [
                Instruction(Z(), 0),
                Instruction(S(), 0),
                Instruction(H(), 0),
                Instruction(Z(), 1),
                Instruction(S(), 1),
                Instruction(H(), 1),
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "with target" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Expectation, Observables.X(), 0)
            expected = [Instruction(H(), 0)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "tensor product" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Expectation, Observables.X() * Observables.Y() * Observables.Y(), [0, 1, 2])
            expected = [
                Instruction(H(), 0),
                Instruction(Z(), 1),
                Instruction(S(), 1),
                Instruction(H(), 1),
                Instruction(Z(), 2),
                Instruction(S(), 2),
                Instruction(H(), 2),
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "tensor product with shared target" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Expectation, Observables.X() * Observables.Y() * Observables.Y(), [0, 1, 2])
            circ(Expectation, Observables.X() * Observables.Y(), [0, 1])
            expected = [
                Instruction(H(), 0),
                Instruction(Z(), 1),
                Instruction(S(), 1),
                Instruction(H(), 1),
                Instruction(Z(), 2),
                Instruction(S(), 2),
                Instruction(H(), 2),
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "identity" begin
            circ = Circuit([(H, 0), (CNot, 0, 1), (CNot, 1, 2), (CNot, 2, 3), (CNot, 3, 4)])
            circ(Expectation, Observables.X(), 0)
            circ(Expectation, Observables.I(), 2)
            circ(Expectation, Observables.I() * Observables.Y(), [1, 3])
            circ(Expectation, Observables.I(), 0)
            circ(Expectation, Observables.X() * Observables.I(), [1, 3])
            circ(Expectation, Observables.Y(), 2)
            expected = [
                Instruction(H(), 0),
                Instruction(H(), 1),
                Instruction(Z(), 2),
                Instruction(S(), 2),
                Instruction(H(), 2),
                Instruction(Z(), 3),
                Instruction(S(), 3),
                Instruction(H(), 3),
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types different targets" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Expectation, Observables.X(), 0)
            circ(Sample, Observables.H(), 1)
            expected = [Instruction(H(), 0), Instruction(Ry(-π/4), 1)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types same target" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            tp = Observables.H() * Observables.X()
            circ(Expectation, tp, [0, 1])
            circ(Sample, tp, [0, 1])
            circ(Variance, tp, [0, 1])
            expected = [Instruction(Ry(-π/4), 0), Instruction(H(), 1)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, all specified, same targets" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Expectation, Observables.H())
            circ(Sample, Observables.H(), 0)
            expected = [Instruction(Ry(-π/4), 0), Instruction(Ry(-π/4), 1)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, specified, all same targets" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            circ(Sample, Observables.H(), 0)
            circ(Expectation, Observables.H())            
            expected = [Instruction(Ry(-π/4), 0), Instruction(Ry(-π/4), 1)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, same targets, hermitian" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            mat = [1 0; 0 -1]
            ho = Observables.HermitianObservable(mat)
            circ(Sample, ho, 1)
            circ(Expectation, ho, 1)            
            expected = [Instruction(Unitary([0 1; 1 0]), 1)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, multiple targets, multiple hermitian" begin
            circ = Circuit([(H, 0), (CNot, 0, 1)])
            mat1 = [1 0; 0 -1]
            mat2 = [0 1; 1 0]
            ho1 = Observables.HermitianObservable(mat1)
            ho2 = Observables.HermitianObservable(mat2)
            circ(Sample, ho1, 1)
            circ(Expectation, ho2, 0)            
            expected = [
                Instruction(Unitary(1/√2 * [-1.0 1.0; 1.0 1.0]), 0),
                Instruction(Unitary([0 1; 1 0]), 1)
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, tensor product & hermitian" begin
            circ = Circuit([(H, 0), (CNot, 0, 1), (CNot, 1, 2)])
            mat1 = [1 0; 0 -1]
            mat2 = [0 1; 1 0]
            ho1 = Observables.HermitianObservable(mat1)
            ho2 = Observables.HermitianObservable(mat2)
            circ(Sample, ho1 * Observables.H(), [0, 1])
            circ(Variance, ho1 * Observables.H(), [0, 1])     
            circ(Expectation, ho2, 2)

            expected = [
                Instruction(Unitary([0 1; 1 0]), 0),
                Instruction(Ry(-π/4), 1),
                Instruction(Unitary(1/√2 * [-1.0 1.0; 1.0 1.0]), 2)
            ]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, tensor product & 2-qubit hermitian" begin
            circ = Circuit([(H, 0), (CNot, 0, 1), (CNot, 1, 2)])
            ho = Observables.HermitianObservable(diagm(ones(4)))
            circ(Expectation, Observables.I(), 1)
            circ(Sample, ho * Observables.H(), [0, 1, 2])
            circ(Variance, Observables.H(), 2)
            circ(Variance, ho, [0, 1])
            circ(Expectation, Observables.I(), 0)
            expected = [Instruction(Unitary(diagm(ones(4))), [0, 1]), Instruction(Ry(-π / 4), 2)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
        @testset "multiple result types, tensor product, probability" begin
            circ = Circuit([(H, 0), (CNot, 0, 1), (CNot, 1, 2)])
            circ(Probability, 0, 1)
            circ(Sample, Observables.Z() * Observables.Z() * Observables.H(), [0, 1, 2])
            circ(Variance, Observables.H(), 2)
            expected = [Instruction(Ry(-π / 4), 2)]
            Braket.basis_rotation_instructions!(circ)
            @test circ.basis_rotation_instructions == expected
        end
    end
    @testset "Circuit and shots validation" begin
        c = Circuit()
        c = H(c, collect(0:10))
        c = Expectation(c, Braket.Observables.Z(), 0)
        c = Expectation(c, Braket.Observables.X(), 1)
        c = Variance(c, ["X", "X"], [2, 3])
        @test c.observables_simultaneously_measureable
        c = Expectation(c, Braket.Observables.X(), 0)
        @test !c.observables_simultaneously_measureable
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 1)
        c = Circuit()
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 0)
        c = Circuit()
        c = H(c, collect(0:10))
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 0)
        c = Amplitude(c, prod("0" for q in 1:10))
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 10)
        c = Circuit()
        c = H(c, collect(0:10))
        c = StateVector(c)
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 10)
        c = Circuit()
        c = H(c, collect(0:41))
        c = Probability(c)
        @test_throws ErrorException Braket.validate_circuit_and_shots(c, 10)
    end

    @testset "Observables" begin
        @test JSON3.read(JSON3.write(StateVector()), Result) == StateVector()
        states = [repeat("0", 4)]
        @test JSON3.read(JSON3.write(Amplitude(states)), Result) == Amplitude(states)
        targs = [1, 2, 4]
        @test JSON3.read(JSON3.write(Probability(targs)), Result) == Probability(targs)
        @test JSON3.read(JSON3.write(DensityMatrix(targs)), Result) == DensityMatrix(targs)
        @testset for o in ("x", ["x", "y", "z"])
            @test JSON3.read(JSON3.write(Sample(o, targs)), Result) == Sample(o, targs)
            @test JSON3.read(JSON3.write(Expectation(o, targs)), Result) == Expectation(o, targs)
            @test JSON3.read(JSON3.write(Variance(o, targs)), Result) == Variance(o, targs)
        end
        @testset "remap" begin
            for o_typ in [Expectation, Variance, Sample]
                obs = ["x", "y"]
                o = o_typ(obs, [0, 1])
                new_o = Braket.remap(o, Dict(0=>5, 1=>3))
                @test new_o == o_typ(obs, [5, 3])
                new_o = Braket.remap(o, [5, 3])
                @test new_o == o_typ(obs, [5, 3])
                new_o = Braket.remap(o, QubitSet(Qubit(5), Qubit(3)))
                @test new_o == o_typ(obs, QubitSet(Qubit(5), Qubit(3)))
            end 
        end
    end

    @testset "Moments" begin
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        c = XX(c, 1, 2, rand())
        c = Braket.apply_initialization_noise!(c, [BitFlip(0.2), PhaseFlip(0.1)])
        c = Braket.apply_readout_noise!(c, [BitFlip(0.2), PhaseFlip(0.1)])
        ts = Braket.time_slices(c.moments)
        @test length(ts) == depth(c)
        s = sprint(show, c.moments)
        sd = sprint(show, c.moments._max_times)
        @test s == "Circuit moments:\nMax times: $sd\n"
    end

    @testset "Mapped result types" begin
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        c = CNot(c, 1, 2)
        c = Braket.add_result_type!(c, Probability([0, 1]), QubitSet([0, 2]))
        c = Braket.add_result_type!(c, DensityMatrix([0, 1]), Dict(0=>1, 1=>2))
        @test c.result_types == [Probability([0, 2]), DensityMatrix([1, 2])]
    end

    @testset "Noise" begin
        c = Circuit()
        c = H(c, collect(0:4))
        c = Braket.apply_initialization_noise!(c, [BitFlip(0.2), PhaseFlip(0.1)])
        expected = vcat([Instruction(BitFlip(0.2), q) for q in 0:4], [Instruction(PhaseFlip(0.1), q) for q in 0:4], [Instruction(H(), q) for q in 0:4])
        for (ixs, exs) in zip(values(c.moments), expected)
            @test ixs == exs
        end
        c = Circuit()
        c = H(c, collect(0:4))
        c = Braket.apply_initialization_noise!(c, BitFlip(0.2), [0, 4])
        @test collect(values(c.moments)) == vcat([Instruction(BitFlip(0.2), q) for q in [0,4]], [Instruction(H(), q) for q in 0:4])
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        angle = rand()
        c = XX(c, 1, 2, angle)
        c = Braket.apply_initialization_noise!(c, BitFlip(0.2))
        c = Braket.apply_readout_noise!(c, PhaseFlip(0.2))
        c = Braket.apply_gate_noise!(c, PauliChannel(0.2, 0.1, 0.2))
        c = Braket.apply_gate_noise!(c, BitFlip(0.2), XX(angle), 1)
        g_ns = [Instruction(H(), 0), Instruction(PauliChannel(0.2, 0.1, 0.2), 0), Instruction(CNot(), [0, 1]), Instruction(PauliChannel(0.2, 0.1, 0.2), 0), Instruction(PauliChannel(0.2, 0.1, 0.2), 1), Instruction(XX(angle), [1, 2]), Instruction(BitFlip(0.2), 1), Instruction(PauliChannel(0.2, 0.1, 0.2), 1), Instruction(PauliChannel(0.2, 0.1, 0.2), 2)]
        for (ix1, ix2) in zip(values(c.moments), vcat([Instruction(BitFlip(0.2), q) for q in qubits(c)], g_ns, [Instruction(PhaseFlip(0.2), q) for q in qubits(c)]))
            @test ix1 == ix2
        end
        ccz_mat = Matrix(Diagonal(ones(ComplexF64, 2^3)))
        ccz_mat[end,end] = -one(ComplexF64)
        c = Circuit()
        c = H(c, [0, 1, 2])
        c = Unitary(c, [0, 1, 2], ccz_mat)
        c = H(c, [0, 1, 2])
        c = Braket.apply_gate_noise!(c, BitFlip(0.2), ccz_mat)
        c = Braket.apply_gate_noise!(c, PhaseFlip(0.25), ccz_mat, 0)
        g_ns = [Instruction(H(), 0), Instruction(H(), 1), Instruction(H(), 2), Instruction(Unitary(ccz_mat), [0, 1, 2]), Instruction(PhaseFlip(0.25), 0), Instruction(BitFlip(0.2), 0), Instruction(BitFlip(0.2), 1),  Instruction(BitFlip(0.2), 2), Instruction(H(), 0), Instruction(H(), 1), Instruction(H(), 2)]
        for (ix1, ix2) in zip(values(c.moments), g_ns)
            @test ix1 == ix2
        end
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        angle = rand()
        c = XX(c, 1, 2, angle)
        c = Braket.apply_gate_noise!(c, TwoQubitDephasing(0.2), CNot())
        g_ns = [Instruction(H(), 0), Instruction(CNot(), [0, 1]), Instruction(TwoQubitDephasing(0.2), [0, 1]), Instruction(XX(angle), [1, 2])]
        for (ix1, ix2) in zip(values(c.moments), g_ns)
            @test ix1 == ix2
        end
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        c = CNot(c, 1, 2)
        c = Braket.apply_gate_noise!(c, TwoQubitDephasing(0.2), CNot(), [0, 1])
        g_ns = [Instruction(H(), 0), Instruction(CNot(), [0, 1]), Instruction(TwoQubitDephasing(0.2), [0, 1]), Instruction(CNot(), [1, 2])]
        for (ix1, ix2) in zip(values(c.moments), g_ns)
            @test ix1 == ix2
        end
        c = Circuit()
        c = H(c, 0)
        c = CNot(c, 0, 1)
        c = CNot(c, 1, 2)
        c = Braket.apply_gate_noise!(c, [BitFlip(0.1), TwoQubitDephasing(0.2)], CNot(), [0, 1])
        g_ns = [Instruction(H(), 0), Instruction(CNot(), [0, 1]), Instruction(BitFlip(0.1), 0), Instruction(BitFlip(0.1), 1), Instruction(TwoQubitDephasing(0.2), [0, 1]), Instruction(CNot(), [1, 2]), Instruction(BitFlip(0.1), 1)]
        @test collect(values(c.moments)) == g_ns
        g_ns = vcat([Instruction(TwoQubitDephasing(0.2), [0, 2])], g_ns)
        c = Braket.apply_initialization_noise!(c, TwoQubitDephasing(0.2), [0, 2])
        @test collect(values(c.moments)) == g_ns
        c = Braket.apply_readout_noise!(c, TwoQubitDephasing(0.15), [0, 2])
        g_ns = vcat(g_ns, [Instruction(TwoQubitDephasing(0.15), [0, 2])])
        @test collect(values(c.moments)) == g_ns
        c = Braket.apply_readout_noise!(c, [BitFlip(0.2), PhaseFlip(0.3)])
        g_ns = vcat(g_ns, [Instruction(BitFlip(0.2), q) for q in qubits(c)], [Instruction(PhaseFlip(0.3), q) for q in qubits(c)])
        for (ix1, ix2) in zip(values(c.moments), g_ns)
            @test ix1 == ix2
        end

        c = Circuit()
        c = H(c, collect(0:1))
        c = Braket.apply_initialization_noise!(c, BitFlip(0.2))
        c = Braket.apply_initialization_noise!(c, PhaseFlip(0.2))
        @test depth(c) == 1
    end

    @testset "Compiler Directives" begin
        c1 = H(Circuit(), 0)
        c2 = CNot(Circuit(), 0, 1)
        @test !c1.has_compiler_directives
        c1 = Braket.add_verbatim_box!(c1, c2)
        @test c1.instructions == [Instruction(H(), 0), Instruction(Braket.StartVerbatimBox(), Int[]), Instruction(CNot(), [0, 1]), Instruction(Braket.EndVerbatimBox(), Int[])]
        @test c1.has_compiler_directives
        c3 = Circuit([(H, 0)])
        c3(StartVerbatimBox)
        c3(CNot, 0, 1)
        c3(EndVerbatimBox)
        @test c3 == c1

        c2 = StateVector(c2) 
        @test_throws ErrorException Braket.add_verbatim_box!(c1, c2)
        c1 = H(Circuit(), collect(0:6))
        c2 = CNot(Circuit(), 0, 1)
        c1 = Braket.add_verbatim_box!(c1, c2, [5, 6])
        comp_ixs = vcat([Instruction(H(), q) for q in 0:6], Instruction(Braket.StartVerbatimBox(), Int[]), Instruction(CNot(), [5, 6]), Instruction(Braket.EndVerbatimBox(), Int[]))
        @test c1.instructions == comp_ixs
    end

    @testset "add_to_qubit_observable_mapping!" begin
        m = [1. -im; im -1.]
        ho = Braket.Observables.HermitianObservable(kron(m, m))
        tp = Braket.Observables.TensorProduct([ho, ho])
        @testset for o in [ho, tp], targets in [Int[], collect(0:qubit_count(o)-1)]
            c = H(Circuit(), collect(0:qubit_count(o)-1))
            for q in 0:qubit_count(c)-1
                c = Braket.add_result_type!(c, Expectation(Braket.Observables.Z(), [q]))
            end
            @test c.observables_simultaneously_measureable
            c = Braket.add_to_qubit_observable_mapping!(c, o, targets)
            @test isempty(c.qubit_observable_mapping)
            @test isempty(c.qubit_observable_target_mapping)
            @test !c.observables_simultaneously_measureable

            for q in 0:qubit_count(c)-1
                c = Braket.add_result_type!(c, Expectation(Braket.Observables.Z(), [q]))
            end
            xp = Braket.Observables.TensorProduct(fill(Braket.Observables.X(), qubit_count(o)))
            c = H(Circuit(), collect(0:qubit_count(o)-1))
            @test c.observables_simultaneously_measureable
            c = Braket.add_result_type!(c, Expectation(xp, targets))
            c = Braket.add_result_type!(c, Expectation(o, targets))
            @test !c.observables_simultaneously_measureable
        end
    end

    @testset "Result types & OpenQASM" begin
        sum_obs = 2.0 * Observables.H() - 5.0 * Observables.Z() * Observables.X()
        herm = Observables.HermitianObservable(diagm(ones(2)))
        @testset for ir_bolus in [
            (Expectation(Braket.Observables.I(), 0), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result expectation i(q[0])",),
            (Expectation(Braket.Observables.I()), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result expectation i all",),
            (StateVector(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result state_vector",),
            (DensityMatrix(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result density_matrix",),
            (DensityMatrix([0, 2]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result density_matrix q[0], q[2]",),
            (DensityMatrix(0), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "#pragma braket result density_matrix \$0",),
            (Amplitude(["01", "10"]), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "#pragma braket result amplitude \"01\", \"10\"",),
            (AdjointGradient(Observables.H(), 0, ["alpha"]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(h(q[0])) alpha",),
            (AdjointGradient(Observables.H(), 0), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(h(q[0])) all",),
            (AdjointGradient(Observables.X() * Observables.Y(), [0, 1], []), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(x(q[0]) @ y(q[1])) all",),
            (AdjointGradient(Observables.H(), 0, []), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(h(q[0])) all",),
            (AdjointGradient(sum_obs, [[0], [1, 2]], ["alpha"]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(2.0 * h(q[0]) - 5.0 * z(q[1]) @ x(q[2])) alpha",),
            (AdjointGradient(sum_obs, [[0], [1, 2]]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(2.0 * h(q[0]) - 5.0 * z(q[1]) @ x(q[2])) all",),
            (AdjointGradient(sum_obs, [[0], [1, 2]], []), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(2.0 * h(q[0]) - 5.0 * z(q[1]) @ x(q[2])) all",),
            (AdjointGradient(herm, 0, []), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result adjoint_gradient expectation(hermitian([[1.0+0im, 0im], [0im, 1.0+0im]]) q[0]) all",),
            (Probability(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result probability all",),
            (Probability([0, 2]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result probability q[0], q[2]",),
            (Probability(0), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "#pragma braket result probability \$0",),
            (Sample(Braket.Observables.I(), 0), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result sample i(q[0])",),
            (Sample(Braket.Observables.I()), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result sample i all",),
            (Variance(Braket.Observables.I(), 0), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result variance i(q[0])",),
            (Variance(Braket.Observables.I()), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "#pragma braket result variance i all",),
        ]
            rt, sps, expected_ir = ir_bolus
            @test ir(rt, Val(:OpenQASM); serialization_properties=sps) == expected_ir
        end
    end

    @testset "full Circuits to OpenQASM" begin
        header = Braket.header_dict[OpenQasmProgram]
        @testset for ir_bolus in [
            (Rx(Rx(Circuit(), 0, 0.15), 1, 0.3), OpenQASMSerializationProperties(VIRTUAL),
            OpenQasmProgram(header, join( [ "OPENQASM 3.0;", "bit[2] b;", "qubit[2] q;", "rx(0.15) q[0];", "rx(0.3) q[1];", "b[0] = measure q[0];", "b[1] = measure q[1];", ], "\n"), nothing)),
            (Rx(Rx(Circuit(), 0, 0.15), 4, 0.3), OpenQASMSerializationProperties(PHYSICAL), OpenQasmProgram(header, join([ "OPENQASM 3.0;", "bit[2] b;", "rx(0.15) \$0;", "rx(0.3) \$4;", "b[0] = measure \$0;", "b[1] = measure \$4;"], "\n"), nothing)),
            (Expectation(Braket.add_verbatim_box!(Rx(Circuit(), 0, 0.15), Rx(Circuit(), 4, 0.3)), Braket.Observables.I()), OpenQASMSerializationProperties(PHYSICAL),
            OpenQasmProgram(header, join(["OPENQASM 3.0;", "rx(0.15) \$0;", "#pragma braket verbatim", "box{", "rx(0.3) \$4;", "}", "#pragma braket result expectation i all"], "\n"), nothing)),
            (Expectation(BitFlip(Rx(Rx(Circuit(), 0, 0.15), 4, 0.3), 3, 0.2), Braket.Observables.I(), 0), nothing,
            OpenQasmProgram(header, join(["OPENQASM 3.0;", "qubit[5] q;", "rx(0.15) q[0];", "rx(0.3) q[4];", "#pragma braket noise bit_flip(0.2) q[3]", "#pragma braket result expectation i(q[0])"], "\n"), nothing))
        ]
            c, sps, expected_ir = ir_bolus
            if !isnothing(sps)
                @test ir(c, Val(:OpenQASM), serialization_properties=sps) == expected_ir
            else
                @test ir(c, Val(:OpenQASM)) == expected_ir
            end
        end
        @testset "with parameters" begin
            a = FreeParameter("a")
            b = FreeParameter("b")
            c = Circuit([(H, [0, 1, 2]), (Rx, 0, a), (Ry, 1, b)])
            props = OpenQASMSerializationProperties(PHYSICAL)
            expected_ir = OpenQasmProgram(header, join([ "OPENQASM 3.0;", "input float a;", "input float b;", "bit[3] b;", "h \$0;", "h \$1;", "h \$2;", "rx(a) \$0;", "ry(b) \$1;", "b[0] = measure \$0;", "b[1] = measure \$1;", "b[2] = measure \$2;"], "\n"), nothing)
            @test ir(c, Val(:OpenQASM), serialization_properties=props) == expected_ir
        end
    end
    @testset "pretty-printing" begin
        @testset "Circuit with FreeParameter" begin
            a = FreeParameter("α")
            c = Circuit([(H, collect(0:10)), (CNot, 0, 1), (CNot, 1, 3), (H, 2), (H, 2), (Rx, 0, a), (Expectation, Braket.Observables.TensorProduct(["x", "y"]), [0, 2]), (Variance, Braket.Observables.TensorProduct(["z", "x"]), [2, 1]), (Amplitude, "1111"), (Probability,)])
            d = Circuit([(H, 0), (X, 1)])
            c = Braket.add_verbatim_box!(c, d)
            s = sprint((io, x)->show(io, "text/plain", x), c)
            known_s = """
            T   : |0|1|  2   |      3      |4|     5     |                 Result Types                 |
                                                                                                         
            q0  : -H-C--Rx(α)-StartVerbatim-H-EndVerbatim-Expectation(X @ Y)-----------------Probability-
                     |        |               |           |                                  |           
            q1  : -H-X-C--------------------X--------------------------------Variance(Z @ X)-Probability-
                       |      |               |           |                  |               |           
            q2  : -H-H--H---------------------------------Expectation(X @ Y)-Variance(Z @ X)-Probability-
                       |      |               |                                              |           
            q3  : -H---X---------------------------------------------------------------------Probability-
                              |               |                                              |           
            q4  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q5  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q6  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q7  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q8  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q9  : -H-------------------------------------------------------------------------Probability-
                              |               |                                              |           
            q10 : -H----------StartVerbatim---EndVerbatim------------------------------------Probability-
                                                                                                         
            T   : |0|1|  2   |      3      |4|     5     |                 Result Types                 |

            Additional result types: Amplitude(1111)

            Unassigned parameters: α
            """
            @test s == known_s
        end
        @testset "Circuit with Noise" begin
            c = Circuit([(H, collect(0:10)), (BitFlip, 0, 0.2), (AmplitudeDamping, 0, 0.1), (Swap, 5, 9), (TwoQubitDepolarizing, 3, 7, 0.1), (DensityMatrix, [3, 4, 5])])
            s = sprint((io, x)->show(io, "text/plain", x), c)
            @test s == """T   : |            0             | 1  |Result Types |\n                                                     \nq0  : -H-BF(0.2)-AD(0.1)-----------------------------\n                                                     \nq1  : -H---------------------------------------------\n                                                     \nq2  : -H---------------------------------------------\n                                                     \nq3  : -H----------------DEPO(0.1)------Densitymatrix-\n                        |              |             \nq4  : -H-------------------------------Densitymatrix-\n                        |              |             \nq5  : -H--------------------------SWAP-Densitymatrix-\n                        |         |                  \nq6  : -H---------------------------------------------\n                        |         |                  \nq7  : -H----------------DEPO(0.1)--------------------\n                                  |                  \nq8  : -H---------------------------------------------\n                                  |                  \nq9  : -H--------------------------SWAP---------------\n                                                     \nq10 : -H---------------------------------------------\n                                                     \nT   : |            0             | 1  |Result Types |\n"""

        end
        @testset "Circuit with 3 qubit gates" begin
            c = Circuit([(H, [0, 1, 2]), (CCNot, [0, 2, 1]), (CPhaseShift, 1, 0, 0.2), (XX, 0, 2, 0.1)])
            s = sprint((io, x)->show(io, "text/plain", x), c)
            known_s = "T  : |0|1|    2     |  3   |Result Types|\n                                         \nq0 : -H-C-Phase(0.2)-X(0.1)--------------\n        | |          |                   \nq1 : -H-X-C------------------------------\n        |            |                   \nq2 : -H-C------------X(0.1)--------------\n                                         \nT  : |0|1|    2     |  3   |Result Types|\n"
            @test s == known_s
        end
    end
end
