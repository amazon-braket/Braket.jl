using Test, Braket, JSON3, LinearAlgebra, StructTypes
using Braket: Instruction, OpenQASMSerializationProperties, QubitReferenceType, VIRTUAL, PHYSICAL, I

CCNot_mat = round.(reduce(hcat, [[1.0, 0, 0, 0, 0, 0, 0, 0],
             [0, 1.0, 0, 0, 0, 0, 0, 0],
             [0, 0, 1.0, 0, 0, 0, 0, 0],
             [0, 0, 0, 1.0, 0, 0, 0, 0],
             [0, 0, 0, 0, 1.0, 0, 0, 0],
             [0, 0, 0, 0, 0, 1.0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0, 1.0],
             [0, 0, 0, 0, 0, 0, 1.0, 0]]), digits=8)
ECR_mat = round.(reduce(hcat, [[0, 0, 0.70710678, 0.70710678im],
                        [0, 0, 0.70710678im, 0.70710678],
                        [0.70710678, -0.70710678im, 0, 0],
                        [-0.70710678im, 0.70710678, 0, 0]]), digits=8)
T_mat = round.(reduce(hcat, [[1.0, 0], [0, 0.70710678 + 0.70710678im]]), digits=8)

@testset "Gates" begin
    @testset for g in (H(), Braket.I(), X(), Y(), Z(), S(), Si(), T(), Ti(), V(), Vi())
        @test qubit_count(g) == 1
        ix = Instruction(g, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(g) == Braket.NonParametrized()
        @test Braket.parameters(g) == Braket.FreeParameter[]
    end
    @testset for g in (H, Braket.I, X, Y, Z, S, Si, T, Ti, V, Vi)
        @test qubit_count(g) == 1
        c = Circuit()
        c = g(c, 0)
        @test c.instructions == [Instruction(g(), 0)]
        c = Circuit()
        c = g(c, [0, 1, 2])
        @test c.instructions == [Instruction(g(), 0), Instruction(g(), 1),  Instruction(g(), 2)]
    end
    @testset for g in (CNot(), Swap(), ISwap(), CV(), CY(), CZ(), ECR())
        @test qubit_count(g) == 2
        ix = Instruction(g, [0, 1])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(g) == Braket.NonParametrized()
        @test Braket.parameters(g) == Braket.FreeParameter[]
    end
    @testset for g in (CNot, Swap, ISwap, CV, CY, CZ, ECR)
        @test qubit_count(g) == 2
        c = Circuit()
        c = g(c, 0, 1)
        @test c.instructions == [Instruction(g(), [0, 1])]
        c = Circuit()
        c = g(c, 10, 1)
        @test c.instructions == [Instruction(g(), [10, 1])]
    end
    @testset for g in (CCNot(), CSwap())
        @test qubit_count(g) == 3
        ix = Instruction(g, [0, 1, 2])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(g) == Braket.NonParametrized()
        @test Braket.parameters(g) == Braket.FreeParameter[]
    end
    @testset for g in (CCNot, CSwap)
        @test qubit_count(g) == 3
        c = Circuit()
        c = g(c, 0, 1, 2)
        @test c.instructions == [Instruction(g(), [0, 1, 2])]
        c = Circuit()
        c = g(c, 5, 1, 2)
        @test c.instructions == [Instruction(g(), [5, 1, 2])]
    end
    angle = rand()
    α = FreeParameter(:alpha)
    β = FreeParameter(:beta)
    γ = FreeParameter(:gamma)
    @testset for (angle1, angle2, angle3) in ((rand(), rand(), rand()), (π, rand(), rand()))
        @testset for g in (Rx(angle1), Ry(angle1), Rz(angle1), PhaseShift(angle1))
            @test qubit_count(g) == 1
            ix = Instruction(g, 0)
            @test Braket.Parametrizable(g) == Braket.Parametrized()
            @test Braket.parameters(g) == Braket.FreeParameter[]
        end
        @testset for g in (Rx, Ry, Rz, PhaseShift)
            @test qubit_count(g) == 1
            c = Circuit()
            c = g(c, 0, angle1)
            @test c.instructions == [Instruction(g(angle1), 0)]
            c = Circuit()
            c = g(c, [0, 1, 2], angle1)
            @test c.instructions == [Instruction(g(angle1), 0), Instruction(g(angle1), 1),  Instruction(g(angle1), 2)]
            pg = g(α)
            @test Braket.parameters(pg) == [α]
            ix = Instruction(g(angle1), 0)
            @test JSON3.read(JSON3.write(ix), Instruction) == Instruction(g(Float64(angle1)), 0)
        end
        @testset for g in (PSwap(angle1), XY(angle1), CPhaseShift(angle1), CPhaseShift00(angle1), CPhaseShift01(angle1), CPhaseShift10(angle1), XX(angle1), YY(angle1), ZZ(angle1))
            @test qubit_count(g) == 2
            @test Braket.Parametrizable(g) == Braket.Parametrized()
            @test Braket.parameters(g) == Braket.FreeParameter[]
        end
        @testset for g in (PSwap, XY, CPhaseShift, CPhaseShift00, CPhaseShift01, CPhaseShift10, XX, YY, ZZ)
            @test qubit_count(g) == 2
            c = Circuit()
            c = g(c, 0, 1, angle1)
            @test c.instructions == [Instruction(g(angle1), [0, 1])]
            c = Circuit()
            c = g(c, 10, 1, angle1)
            @test c.instructions == [Instruction(g(angle1), [10, 1])]
            pg = g(α)
            @test Braket.parameters(pg) == [α]
            ix = Instruction(g(angle1), [0, 1])
            @test JSON3.read(JSON3.write(ix), Instruction) == Instruction(g(Float64(angle1)), [0, 1])
        end
        @testset for g in (PRx(angle1, angle2),)
            @test qubit_count(g) == 1
            @test Braket.Parametrizable(g) == Braket.Parametrized()
            @test Braket.parameters(g) == Braket.FreeParameter[]
        end
        @testset for g in (PRx,)
            @test qubit_count(g) == 1
            c = Circuit()
            c = g(c, 0, angle1, angle2)
            @test c.instructions == [Instruction(g(angle1, angle2), 0)]
            c = Circuit()
            c = g(c, 10, angle1, angle2)
            @test c.instructions == [Instruction(g(angle1, angle2), 10)]
            pg = g(α, β)
            @test Braket.parameters(pg) == [α, β]
            pg = Braket.bind_value!(Braket.Parametrized(), pg, Dict(:alpha=>angle1, :beta=>angle2))
            @test pg == g(angle1, angle2)
        end
        @testset for g in (MS(angle1, angle2, angle3),)
            @test qubit_count(g) == 2
            @test Braket.Parametrizable(g) == Braket.Parametrized()
            @test Braket.parameters(g) == Braket.FreeParameter[]
        end
        @testset for g in (MS,)
            @test qubit_count(g) == 2
            c = Circuit()
            c = g(c, 0, 1, angle1, angle2, angle3)
            @test c.instructions == [Instruction(g(angle1, angle2, angle3), [0, 1])]
            c = Circuit()
            c = g(c, 10, 1, angle1, angle2, angle3)
            @test c.instructions == [Instruction(g(angle1, angle2, angle3), [10, 1])]
            pg = g(α, β, γ)
            @test Braket.parameters(pg) == [α, β, γ]
            pg = Braket.bind_value!(Braket.Parametrized(), pg, Dict(:alpha=>angle1, :beta=>angle2, :gamma=>angle3))
            @test pg == g(angle1, angle2, angle3)
        end
        @testset for g in (U(angle1, angle2, angle3),)
            @test qubit_count(g) == 1
            @test Braket.Parametrizable(g) == Braket.Parametrized()
            @test Braket.parameters(g) == Braket.FreeParameter[]
        end
        @testset for g in (U,)
            @test qubit_count(g) == 1
            c = Circuit()
            c = g(c, 0, angle1, angle2, angle3)
            @test c.instructions == [Instruction(g(angle1, angle2, angle3), 0)]
            c = Circuit()
            c = g(c, [0, 1, 2], angle1, angle2, angle3)
            @test c.instructions == [Instruction(g(angle1, angle2, angle3), 0), Instruction(g(angle1, angle2, angle3), 1),  Instruction(g(angle1, angle2, angle3), 2)]
            c = Circuit()
            c = g(c, 0, 1, 2, angle1, angle2, angle3)
            @test c.instructions == [Instruction(g(angle1, angle2, angle3), 0), Instruction(g(angle1, angle2, angle3), 1),  Instruction(g(angle1, angle2, angle3), 2)]
            pg = g(α, β, γ)
            @test Braket.parameters(pg) == [α, β, γ]
            pg = Braket.bind_value!(Braket.Parametrized(), pg, Dict(:alpha=>angle1, :beta=>angle2, :gamma=>angle3))
            @test pg == g(angle1, angle2, angle3)
        end
        @testset "Angled 3 qubit gates" begin
            # build some "fake" (for now) 3 qubit gates to test gate applicators
            struct CCPhaseShift <: Braket.AngledGate{1}
                angle::NTuple{1, Union{Real, FreeParameter}}
                CCPhaseShift(angle::T) where {T<:NTuple{1, Union{Real, FreeParameter}}} = new(angle)
            end
            struct CXX <: Braket.AngledGate{1}
                angle::NTuple{1, Union{Real, FreeParameter}}
                CXX(angle::T) where {T<:NTuple{1, Union{Real, FreeParameter}}} = new(angle)
            end
            c = Circuit()
            c = Braket.apply_gate!(Val(1), Val(2), Val(1), CCPhaseShift, c, 0, 1, 2, angle1)
            @test c.instructions == [Instruction(CCPhaseShift(angle1), [0, 1, 2])]
            c = Circuit()
            c = Braket.apply_gate!(Val(1), Val(2), Val(1), CCPhaseShift, c, [0, 1, 2], angle1)
            @test c.instructions == [Instruction(CCPhaseShift(angle1), [0, 1, 2])]
            c = Circuit()
            c = Braket.apply_gate!(Val(1), Val(1), Val(2), CXX, c, 0, 1, 2, angle1)
            @test c.instructions == [Instruction(CXX(angle1), [0, 1, 2])]
            c = Circuit()
            c = Braket.apply_gate!(Val(1), Val(1), Val(2), CXX, c, [0, 1, 2], angle1)
            @test c.instructions == [Instruction(CXX(angle1), [0, 1, 2])]
        end
    end
    @testset "g = Unitary" begin
        X = complex([0. 1.; 1. 0.])
        Y = [0. -im; im 0.]
        g = Unitary(X)
        @test qubit_count(g) == 1
        ix = Instruction(g, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        g = Unitary(kron(X, X))
        @test qubit_count(g) == 2
        ix = Instruction(g, [0, 1])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        g = Unitary(kron(Y, Y))
        @test qubit_count(g) == 2
        ix = Instruction(g, [0, 1])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        c = Circuit()
        c = Unitary(c, 0, X)
        @test c.instructions == [Instruction(Unitary(X), 0)]
        c = Circuit()
        c = Unitary(c, 0, 1, kron(X, Y))
        @test c.instructions == [Instruction(Unitary(kron(X, Y)), [0, 1])]
    end
    @testset "OpenQASM IR" begin
        fp  = FreeParameter(:alpha)
        fp2 = FreeParameter(:beta)
        fp3 = FreeParameter(:gamma)
        @testset for ir_bolus in [
            (Rx(0.17), [Qubit(4)], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "rx(0.17) q[4];",),
            (Rx(0.17), [Qubit(4)], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "rx(0.17) \$4;",),
            (Rx(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "rx(0.17) q[4];",),
            (Rx(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "rx(0.17) \$4;",),
            (PRx(0.17, 3.45), [Qubit(4)], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "prx(0.17, 3.45) q[4];",),
            (PRx(0.17, 3.45), [Qubit(4)], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "prx(0.17, 3.45) \$4;",),
            (PRx(0.17, 3.45), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "prx(0.17, 3.45) q[4];",),
            (PRx(0.17, 3.45), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "prx(0.17, 3.45) \$4;",),
            (X(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "x q[4];",),
            (X(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "x \$4;",),
            (Z(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "z q[4];",),
            (Z(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "z \$4;",),
            (Y(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "y q[4];",),
            (Y(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "y \$4;",),
            (H(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "h q[4];",),
            (H(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "h \$4;",),
            (Ry(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "ry(0.17) q[4];",),
            (Ry(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "ry(0.17) \$4;",),
            (ZZ(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "zz(0.17) q[4], q[5];",),
            (ZZ(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "zz(0.17) \$4, \$5;",),
            (I(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "i q[4];",),
            (I(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "i \$4;",),
            (V(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "v q[4];",),
            (V(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "v \$4;",),
            (CY(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cy q[0], q[1];",),
            (CY(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cy \$0, \$1;",),
            (Rz(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "rz(0.17) q[4];",),
            (Rz(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "rz(0.17) \$4;",),
            (Rz(fp), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "rz(alpha) q[4];",),
            (Rz(fp), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "rz(alpha) \$4;",),
            (U(0.17, 0.2, 0.1), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "U(0.17, 0.2, 0.1) q[4];",),
            (U(0.17, 0.2, 0.1), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "U(0.17, 0.2, 0.1) \$4;",),
            (U(fp, fp2, fp3), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "U(alpha, beta, gamma) q[4];",),
            (U(fp, fp2, fp3), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "U(alpha, beta, gamma) \$4;",),
            (XX(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "xx(0.17) q[4], q[5];",),
            (XX(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "xx(0.17) \$4, \$5;",),
            (XX(fp), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "xx(alpha) q[4], q[5];",),
            (XX(fp), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "xx(alpha) \$4, \$5;",),
            (T(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "t q[4];",),
            (T(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "t \$4;",),
            (CZ(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cz \$0, \$1;",),
            (CZ(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cz q[0], q[1];",),
            (YY(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "yy(0.17) q[4], q[5];",),
            (YY(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "yy(0.17) \$4, \$5;",),
            (XY(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "xy(0.17) q[4], q[5];",),
            (XY(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "xy(0.17) \$4, \$5;",),
            (GPi(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "gpi(0.17) q[4];",),
            (GPi(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "gpi(0.17) \$4;",),
            (GPi2(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "gpi2(0.17) q[4];",),
            (GPi2(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "gpi2(0.17) \$4;",),
            (ISwap(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "iswap \$0, \$1;",),
            (ISwap(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "iswap q[0], q[1];",),
            (Swap(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "swap \$0, \$1;",),
            (Swap(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "swap q[0], q[1];",),
            (ECR(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "ecr \$0, \$1;",),
            (ECR(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "ecr q[0], q[1];",),
            (CV(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cv \$0, \$1;",),
            (CV(), [0, 1], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cv q[0], q[1];",),
            (Vi(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "vi q[4];",),
            (Vi(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "vi \$4;",),
            (CSwap(), [0, 1, 2], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cswap q[0], q[1], q[2];",),
            (CSwap(), [0, 1, 2], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cswap \$0, \$1, \$2;",),
            (CPhaseShift01(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cphaseshift01(0.17) q[4], q[5];",),
            (CPhaseShift01(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cphaseshift01(0.17) \$4, \$5;",),
            (CPhaseShift00(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cphaseshift00(0.17) q[4], q[5];",),
            (CPhaseShift00(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cphaseshift00(0.17) \$4, \$5;",),
            (CPhaseShift(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cphaseshift(0.17) q[4], q[5];",),
            (CPhaseShift(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cphaseshift(0.17) \$4, \$5;",),
            (S(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "s q[4];",),
            (S(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "s \$4;",),
            (Si(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "si q[4];",),
            (Si(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "si \$4;",),
            (Ti(), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "ti q[4];",),
            (Ti(), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "ti \$4;",),
            (PhaseShift(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "phaseshift(0.17) q[4];",),
            (PhaseShift(0.17), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "phaseshift(0.17) \$4;",),
            (MS(0.17, 0.2, 0.1), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "ms(0.17, 0.2, 0.1) q[4], q[5];",),
            (MS(0.17, 0.2, 0.1), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "ms(0.17, 0.2, 0.1) \$4, \$5;",),
            (CNot(), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cnot q[4], q[5];",),
            (CNot(), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cnot \$4, \$5;",),
            (PSwap(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "pswap(0.17) q[4], q[5];",),
            (PSwap(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "pswap(0.17) \$4, \$5;",),
            (CPhaseShift10(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "cphaseshift10(0.17) q[4], q[5];",),
            (CPhaseShift10(0.17), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "cphaseshift10(0.17) \$4, \$5;",),
            (CCNot(), [4, 5, 6], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "ccnot q[4], q[5], q[6];",),
            (CCNot(), [4, 5, 6], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "ccnot \$4, \$5, \$6;",),
            (Unitary(CCNot_mat), [4, 5, 6], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL),
                "#pragma braket unitary([" *
                "[1.0, 0, 0, 0, 0, 0, 0, 0], " *
                "[0, 1.0, 0, 0, 0, 0, 0, 0], " *
                "[0, 0, 1.0, 0, 0, 0, 0, 0], " *
                "[0, 0, 0, 1.0, 0, 0, 0, 0], " *
                "[0, 0, 0, 0, 1.0, 0, 0, 0], " *
                "[0, 0, 0, 0, 0, 1.0, 0, 0], " *
                "[0, 0, 0, 0, 0, 0, 0, 1.0], " *
                "[0, 0, 0, 0, 0, 0, 1.0, 0]" *
                "]) q[4], q[5], q[6]",
            ),
            (Unitary(CCNot_mat), [4, 5, 6], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL),
                "#pragma braket unitary([" *
                "[1.0, 0, 0, 0, 0, 0, 0, 0], " *
                "[0, 1.0, 0, 0, 0, 0, 0, 0], " *
                "[0, 0, 1.0, 0, 0, 0, 0, 0], " *
                "[0, 0, 0, 1.0, 0, 0, 0, 0], " *
                "[0, 0, 0, 0, 1.0, 0, 0, 0], " *
                "[0, 0, 0, 0, 0, 1.0, 0, 0], " *
                "[0, 0, 0, 0, 0, 0, 0, 1.0], " *
                "[0, 0, 0, 0, 0, 0, 1.0, 0]" *
                "]) \$4, \$5, \$6",
            ),
            (Unitary(ECR_mat), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL),
                "#pragma braket unitary([" *
                "[0, 0, 0.70710678, 0.70710678im], " *
                "[0, 0, 0.70710678im, 0.70710678], " *
                "[0.70710678, -0.70710678im, 0, 0], " *
                "[-0.70710678im, 0.70710678, 0, 0]" *
                "]) q[4], q[5]",
            ),
            (Unitary(ECR_mat), [4, 5], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL),
                "#pragma braket unitary([" *
                "[0, 0, 0.70710678, 0.70710678im], " *
                "[0, 0, 0.70710678im, 0.70710678], " *
                "[0.70710678, -0.70710678im, 0, 0], " *
                "[-0.70710678im, 0.70710678, 0, 0]" *
                "]) \$4, \$5",
            ),
            (Unitary(T_mat), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL),
                "#pragma braket unitary([[1.0, 0], [0, 0.70710678 + 0.70710678im]]) q[4]",
            ),
            (Unitary(T_mat), [4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL),
                "#pragma braket unitary([[1.0, 0], [0, 0.70710678 + 0.70710678im]]) \$4",
            ),
            (Unitary(reduce(hcat, [[1.0, 0], [0, 0.70710678 - 0.70710678im]])), [4], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL),
                "#pragma braket unitary([[1.0, 0], [0, 0.70710678 - 0.70710678im]]) q[4]",
            )
        ]
            gate, target, s_props, expected_ir = ir_bolus
            generated_ir = ir(gate, target, Val(:OpenQASM); serialization_properties=s_props)
            @test generated_ir == expected_ir
        end
    end
    @test StructTypes.StructType(X) == StructTypes.Struct()
    @test StructTypes.StructType(Gate) == StructTypes.AbstractType()
    @test StructTypes.StructType(AngledGate) == StructTypes.AbstractType()
end
