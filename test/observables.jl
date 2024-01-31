using Braket, Braket.Observables, Test, JSON3, StructTypes, LinearAlgebra
using Braket: VIRTUAL, PHYSICAL, OpenQASMSerializationProperties, PauliEigenvalues, IRObservable
using LinearAlgebra: eigvals

@testset "Observables" begin
    Braket.IRType[] = :JAQCD
    @testset "pauli eigenvalues" begin
        z = [1.0 0.0; 0.0 -1.0]
        for n in 2:6
            pe  = PauliEigenvalues(Val(n))
            mat = kron(ntuple(i->diag(z), n)...)
            for ix in 1:2^n
                @test pe[ix] == mat[ix]
            end
        end
    end
    @testset "Hermitian" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        @test qubit_count(o) == 1
        rt = Expectation(o, [0])
        read_rt = JSON3.read(JSON3.write(rt), Braket.Result)
        @test read_rt == rt
        @test ir(o) isa IRObservable
        mult_h = 2.0 * o
        @test mult_h.matrix == 2.0 * m
    end
    @testset "TensorProduct" begin
        tp = Observables.TensorProduct(["x", "y", "z"])
        @test ir(tp) == ["x", "y", "z"]
        @test JSON3.write(tp) == JSON3.write(ir(tp))
        @test qubit_count(tp) == 3
        rt = Expectation(tp, [0, 1, 2])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
        str = """{"observable": ["x", 1, "z"], "targets": [0, 1, 2], "type": "variance"}"""
        @test_throws ArgumentError JSON3.read(str, Braket.Result)
        tp2 = 2.0 * tp
        @test Braket.Observables.unscaled(tp) == tp
    end
    @testset "TensorProduct of Hermitians" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        tp = Observables.TensorProduct([o, o])
        @test qubit_count(tp) == 2
        rt = Expectation(tp, [0, 2])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
        @test ir(tp) isa IRObservable
    end
    @testset "TensorProduct mixed types" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        tp = Observables.TensorProduct([Observables.X(), o, Observables.Z()])
        @test qubit_count(tp) == 3
        rt = Expectation(tp, [0, 1, 2])
        @test ir(tp) isa IRObservable
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
    end
    @testset "TensorProduct doesn't accept Sum" begin
        s = 2.0 * Observables.X() * Observables.X() + 3.0 * Observables.Z() * Observables.Z()
        @test_throws ArgumentError Observables.TensorProduct([Observables.X(), s])
    end
    @testset "Sum" begin
        s = 2.0 * Observables.X() * Observables.X() + 3.0 * Observables.Z() * Observables.Z()
        @test length(s) == 2
        @test s.summands[1].coefficient == 2.0
        @test s.summands[2].coefficient == 3.0
        @test_throws ErrorException ir(s, [1, 2], Val(:JAQCD))
        @test_throws ErrorException ir(s, [QubitSet(1, 2)], Val(:JAQCD))
        @test Braket.chars(s) == ("Sum",)
        s2 = -1.0 * s
        @test length(s2) == 2
        @test s2.summands[1].coefficient == -2.0
        @test s2.summands[2].coefficient == -3.0
        s3 = Observables.Y() * Observables.Y() + s
        @test length(s3) == 3
        s4 = Observables.Y() * Observables.Y() + 2.0 * Observables.X() * Observables.X() + 3.0 * Observables.Z() * Observables.Z()
        @test s3 == s4
        s5 = Observables.Sum([Observables.X()])
        @test s5 == Observables.X()
        @test Observables.X() == s5
    end
    @test_throws ErrorException StructTypes.constructfrom(Observables.Observable, ["x", 1, "z"])
    m = [1 -im; im -1]
    HO = Observables.HermitianObservable(m)
    @test Braket.chars(HO) == ("Hermitian",)
    HO_ir = ir(HO)
    @test JSON3.write(HO) == JSON3.write(ir(HO)) 
    @test StructTypes.constructfrom(Observables.Observable, convert(IRObservable, HO_ir)) == HO
    @test copy(HO) == HO
    for (typ, char) in zip((Observables.H, Observables.I, Observables.Z, Observables.X, Observables.Y), ("H", "I", "Z", "X", "Y"))
        @test copy(typ()) == typ()
        @test JSON3.write(typ()) == JSON3.write(ir(typ()))
        @test ishermitian(typ())
        @test Braket.chars(typ()) == (char,)
    end
    Braket.IRType[] = :OpenQASM
    @testset "eigenvalues" begin
        mat = [1.0 1.0 - im; 1.0 + 1im -1.0]
        h = Observables.HermitianObservable(mat)
        @test eigvals(h) ≈ [-√3, √3]
        ho = Observables.HermitianObservable(convert(Matrix{Float64}, [-1 0 0 0; 0 -1 0 0; 0 0 1 0; 0 0 0 1]))
        @testset for (tp, evs) in (
            (Observables.TensorProduct(["x", "y"]), [1, -1, -1, 1]),
            (Observables.TensorProduct(["x", "y", "z"]),[1, -1, -1, 1, -1, 1, 1, -1]),
            (Observables.TensorProduct(["x", "y", "i"]),[1, 1, -1, -1, -1, -1, 1, 1]),
            (Observables.TensorProduct([Observables.X(), ho, Observables.Y()]),[-1, 1, -1, 1, 1, -1, 1, -1, 1, -1, 1, -1, -1, 1, -1, 1])
        )
            for ix in 1:length(evs)
                @test eigvals(tp)[ix] == convert(Float64, evs[ix])
            end
        end
        @testset for typ in (Observables.H(), Observables.X(), Observables.Y(), Observables.Z())
            @test eigvals(typ)[[1, 2]] == [1.0, -1.0]
        end
        @testset for (mat, evs) in [([1.0 0.0; 0.0 1.0], [1, 1]), ([0 -im; im 0], [-1.0, 1.0]), ([1 1-im; 1+im -1], [-sqrt(3), sqrt(3)])]
            @test eigvals(Observables.HermitianObservable(mat)) ≈ evs
        end
    end
    @testset "OpenQASM" begin
        @testset for ir_bolus in [
            (Observables.I(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "i(q[3])"),
            ( Observables.I(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "i(\$3)"),
            ( Observables.I(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "i all"),
            ( Observables.X(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "x(q[3])"),
            ( Observables.X(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "x(\$3)"),
            ( Observables.X(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "x all"),
            ( Observables.Y(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "y(q[3])"),
            ( Observables.Y(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "y(\$3)"),
            ( Observables.Y(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "y all"),
            ( Observables.Z(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "z(q[3])"),
            ( Observables.Z(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "z(\$3)"),
            ( Observables.Z(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "z all"),
            ( Observables.H(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "h(q[3])"),
            ( Observables.H(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "h(\$3)"),
            ( Observables.H(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "h all"),
            ( 2.0 * Observables.H() - 5.0 * Observables.Z() * Observables.X(), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [[2], [3, 4]], "2.0 * h(\$2) - 5.0 * z(\$3) @ x(\$4)"),
            ( 2.0 * Observables.H() - 5.0 * Observables.Z() * Observables.X(), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [[2], [3, 4]], "2.0 * h(q[2]) - 5.0 * z(q[3]) @ x(q[4])"),
            ( Observables.HermitianObservable(diagm(ones(Int64, 4))), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [1, 2], "hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) q[1], q[2]"),
            ( Observables.HermitianObservable(diagm(ones(Int64, 4))), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [1, 2], "hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) \$1, \$2"),
            ( Observables.HermitianObservable(diagm(ones(Int64, 2))), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "hermitian([[1+0im, 0im], [0im, 1+0im]]) all"),
            ( Observables.HermitianObservable([1 1-im; 1+im 1]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "hermitian([[1+0im, 1-1im], [1+1im, 1+0im]]) all"),
            ( Observables.TensorProduct([Observables.H(), Observables.Z()]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 0], "h(q[3]) @ z(q[0])"),
            ( Observables.TensorProduct([Observables.H(), Observables.Z()]), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 0], "h(\$3) @ z(\$0)"),
            ( Observables.TensorProduct([Observables.H(), Observables.Z(), Observables.I()]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 0, 1], "h(q[3]) @ z(q[0]) @ i(q[1])"),
            ( Observables.TensorProduct([Observables.H(), Observables.Z(), Observables.I()]), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 0, 1], "h(\$3) @ z(\$0) @ i(\$1)"),
            ( Observables.TensorProduct([Observables.HermitianObservable(diagm(ones(Int64, 4))), Observables.I()]), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 0, 1], "hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) q[3], q[0] @ i(q[1])"),
            ( Observables.TensorProduct([Observables.I(), Observables.HermitianObservable(diagm(ones(Int64, 4)))]), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 0, 1], "i(\$3) @ hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) \$0, \$1"),
        ]
            obs, sps, target, expected_ir = ir_bolus
            @test ir(obs, target, Val(:OpenQASM); serialization_properties=sps) == expected_ir
        end
    end
end
