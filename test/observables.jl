using Braket, Braket.Observables, Test, JSON3, StructTypes, LinearAlgebra
using Braket: VIRTUAL, PHYSICAL, OpenQASMSerializationProperties, pauli_eigenvalues
using LinearAlgebra: eigvals

@testset "Observables" begin
    @testset "pauli eigenvalues" begin
        z = [1.0 0.0; 0.0 -1.0]
        @test pauli_eigenvalues(1) == diag(z)
        @test pauli_eigenvalues(2) == diag(kron(z,z))
        @test pauli_eigenvalues(3) == diag(kron(z,z,z,))
    end
    @testset "Hermitian" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        @test qubit_count(o) == 1
        rt = Expectation(o, [0])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
    end
    @testset "TensorProduct" begin
        tp = Observables.TensorProduct(["x", "y", "z"])
        @test ir(tp) == ["x", "y", "z"]
        @test JSON3.write(tp) == replace("""$(Braket.ir(tp))""", " "=>"")
        @test qubit_count(tp) == 3
        rt = Expectation(tp, [0, 1, 2])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
        str = """{"observable": ["x", 1, "z"], "targets": [0, 1, 2], "type": "variance"}"""
        @test_throws ArgumentError JSON3.read(str, Braket.Result)
    end
    @testset "TensorProduct of Hermitians" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        tp = Observables.TensorProduct([o, o])
        @test qubit_count(tp) == 2
        rt = Expectation(tp, [0, 2])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
    end
    @testset "TensorProduct mixed types" begin
        m = [1. -im; im -1.]
        o = Observables.HermitianObservable(m)
        tp = Observables.TensorProduct([Observables.X(), o, Observables.Z()])
        @test qubit_count(tp) == 3
        rt = Expectation(tp, [0, 1, 2])
        @test JSON3.read(JSON3.write(rt), Braket.Result) == rt
    end
    @test_throws ErrorException StructTypes.constructfrom(Observables.Observable, ["x", 1, "z"])
    m = [1 -im; im -1]
    HO = Observables.HermitianObservable(m)
    @test JSON3.write(HO) == replace("""$(Braket.ir(HO))""", " "=>"")
    m_raw = first(ir(HO))
    @test StructTypes.constructfrom(Observables.Observable, m_raw) == HO
    @test copy(HO) == HO
    for typ in (Observables.H, Observables.I, Observables.Z, Observables.X, Observables.Y)
        @test copy(typ()) == typ()
        @test JSON3.write(typ()) == """$(Braket.ir(typ()))"""
        @test ishermitian(typ())
    end

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
            @test eigvals(tp) == convert(Vector{Float64}, evs)
        end
        @testset for typ in (Observables.H(), Observables.X(), Observables.Y(), Observables.Z())
            @test eigvals(typ) == [1.0, -1.0]
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
            ( Observables.HermitianObservable(diagm(ones(Int64, 4))), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [1, 2], "hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) q[1], q[2]"),
            ( Observables.HermitianObservable(diagm(ones(Int64, 4))), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [1, 2], "hermitian([[1+0im, 0im, 0im, 0im], [0im, 1+0im, 0im, 0im], [0im, 0im, 1+0im, 0im], [0im, 0im, 0im, 1+0im]]) \$1, \$2"),
            ( Observables.HermitianObservable(diagm(ones(Int64, 2))), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), nothing, "hermitian([[1+0im, 0im], [0im, 1+0im]]) all"),
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
