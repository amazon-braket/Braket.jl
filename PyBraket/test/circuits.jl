using Braket, PyBraket, Test, LinearAlgebra, PythonCall
using PythonCall: pyconvert, Py, pyisTrue, pyisinstance
@testset "PyBraket circuits" begin
    @testset for ir_type in (:JAQCD, :OpenQASM)
        Braket.IRType[] = ir_type 
        @testset "Expectation" begin
            c = Circuit([(H, 0), (CNot, 0, 1), (Expectation, Braket.Observables.Z(), 0)])
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            @test res.values[1] ≈ 0.0 atol=1e-12
        end

        @testset "Variance" begin
            c = Circuit() |> (ci->H(ci, 0)) |> (ci->CNot(ci, 0, 1)) |> (ci->Variance(ci, Braket.Observables.Z(), 0))
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            @test res.values[1] ≈ 1.0 atol=1e-12
        end

        @testset "Probability" begin
            c = Circuit() |> (ci->H(ci, 0)) |> (ci->CNot(ci, 0, 1)) |> (ci->Probability(ci))
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            @test res.values[1] ≈ [0.5, 0.0, 0.0, 0.5] atol=1e-12
        end

        @testset "DensityMatrix" begin
            c = Circuit() |> (ci->H(ci, 0)) |> (ci->CNot(ci, 0, 1)) |> (ci->DensityMatrix(ci))
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            ρ = zeros(ComplexF64, 4, 4)
            ρ[1, 1] = 0.5
            ρ[1, 4] = 0.5
            ρ[4, 1] = 0.5
            ρ[4, 4] = 0.5
            for i in 1:4, j in 1:4
                @test res.values[1][i][j] ≈ ρ[i,j] atol=1e-12
            end
        end

        @testset "Results type" begin
            c = Circuit() |> (ci->H(ci, 0)) |> (ci->CNot(ci, 0, 1)) |> (ci->Expectation(ci, Braket.Observables.Z(), 0))
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            @test res.values[1] ≈ 0.0 atol=1e-12
            @test sprint(show, res) == "GateModelQuantumTaskResult\n"
        end

        @testset "Observable on all qubits" begin
            c = Circuit() |> (ci->H(ci, 0)) |> (ci->CNot(ci, 0, 1)) |> (ci->Expectation(ci, Braket.Observables.Z()))
            dev = LocalSimulator()
            res = result(run(dev, c, shots=0))
            @test pyconvert(Vector{Float64}, res.values[1]) ≈ [0.0, 0.0] atol=1e-12
        end

        @testset "Unitary" begin
            c = Circuit()
            ccz_mat = Matrix(Diagonal(ones(ComplexF64, 2^3)))
            ccz_mat[end,end] = -one(ComplexF64)
            H(c, [0, 1, 2])
            Unitary(c, [0, 1, 2], ccz_mat)
            H(c, [0, 1, 2])
            StateVector(c)
            dev = LocalSimulator()
            braket_task = run(dev, c, shots=0)
            res = result(braket_task)
            @test res.values[1] ≈ ComplexF64[0.75, 0.25, 0.25, -0.25, 0.25, -0.25, -0.25, 0.25] atol=1e-12
        end

        @testset "PyCircuit" begin
            c = Circuit()
            ccz_mat = Matrix(Diagonal(ones(ComplexF64, 2^3)))
            ccz_mat[end,end] = -one(ComplexF64)
            H(c, [0, 1, 2])
            Unitary(c, [0, 1, 2], ccz_mat)
            H(c, [0, 1, 2])
            StateVector(c)
            pc = PyCircuit(c)
            @test qubit_count(c) == PythonCall.pyconvert(Int, pc.qubit_count)
            @test length(c.result_types) == PythonCall.pyconvert(Int, length(getproperty(pc, "_result_types")))
        end
        if ir_type == :JAQCD
            @testset "Conversion of result types" begin
                @testset for (rt, ir_rt) in ((Braket.Expectation, Braket.IR.Expectation), 
                                             (Braket.Variance, Braket.IR.Variance),
                                             (Braket.Sample, Braket.IR.Sample))
                    o = Braket.Observables.H()
                    obs = rt(o, [0])
                    py_obs = Py(obs)
                    ir_obs = ir(obs)
                    @test pyisTrue(py_obs.to_ir() == Py(ir_obs))
                    @test pyconvert(ir_rt, Py(ir_obs)) == ir_obs
                end
                @testset for (rt, ir_rt) in ((Braket.Probability, Braket.IR.Probability),
                                             (Braket.DensityMatrix, Braket.IR.DensityMatrix))
                    obs = rt([0])
                    py_obs = Py(obs)
                    ir_obs = ir(obs)
                    @test pyisTrue(py_obs.to_ir() == Py(ir_obs))
                    @test pyconvert(ir_rt, Py(ir_obs)) == ir_obs

                    obs = rt()
                    py_obs = Py(obs)
                    ir_obs = ir(obs)
                    @test pyisTrue(py_obs.to_ir() == Py(ir_obs))
                    @test pyconvert(ir_rt, Py(ir_obs)) == ir_obs
                end
                @testset "(rt, ir_rt) = (Amplitude, IR.Amplitude)" begin
                    obs = Braket.Amplitude(["0000"])
                    py_obs = Py(obs)
                    ir_obs = ir(obs)
                    @test pyisTrue(py_obs.to_ir() == Py(ir_obs))
                    @test pyconvert(Braket.IR.Amplitude, Py(ir_obs)) == ir_obs
                end
                @testset "(rt, ir_rt) = (StateVector, IR.StateVector)" begin
                    obs = Braket.StateVector()
                    py_obs = Py(obs)
                    ir_obs = ir(obs)
                    @test pyisTrue(py_obs.to_ir() == Py(ir_obs))
                    @test pyconvert(Braket.IR.StateVector, Py(ir_obs)) == ir_obs
                end
                @testset "HermitianObservable and TensorProduct" begin
                    m = [1. -im; im -1.]
                    ho = Braket.Observables.HermitianObservable(kron(m, m))
                    tp = Braket.Observables.TensorProduct([ho, ho])
                    py_obs = Py(tp)
                    @test pyisinstance(py_obs, PyBraket.braketobs.TensorProduct)
                    @test pyisinstance(py_obs.factors[0], PyBraket.braketobs.Hermitian)
                end
                @testset "Coefficient handling" begin
                    o = 3.0 * Braket.Observables.Z()
                    py_obs = Py(o)
                    @test pyisinstance(py_obs, PyBraket.braketobs.Z)
                    @test pyisTrue(py_obs.coefficient == 3.0)
                end
                @testset "Sum" begin
                    m = [1. -im; im -1.]
                    ho = Braket.Observables.HermitianObservable(kron(m, m))
                    tp = Braket.Observables.TensorProduct([Braket.Observables.HermitianObservable(m), Braket.Observables.HermitianObservable(m)])
                    py_obs = Py(2.0*tp + ho)
                    @test pyisinstance(py_obs, PyBraket.braketobs.Sum)
                    @test pyisinstance(py_obs.summands[0], PyBraket.braketobs.TensorProduct)
                    @show py_obs.summands[0].coefficient
                    @test pyconvert(Float64, py_obs.summands[0].coefficient) == 2.0
                    @test pyisinstance(py_obs.summands[1], PyBraket.braketobs.Hermitian)
                end
            end
        end
        @testset "FreeParameter" begin
            α = FreeParameter(:alpha)
            θ = FreeParameter(:theta)
            circ = Circuit()
            circ = H(circ, 0)
            circ = Rx(circ, 1, α)
            circ = Ry(circ, 0, θ)
            circ = Probability(circ)
            new_circ = circ(theta=2.0, alpha=1.0)
            non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 2.0)) |> Probability
            py_c1 = PyCircuit(circ)
            py_c2 = PyCircuit(non_para_circ)
            @test py_c2 == py_c1(theta = 2.0, alpha=1.0)
            
            non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 1.0)) |> Probability
            py_c2 = PyCircuit(non_para_circ)
            @test py_c2 == py_c1(1.0)
            @testset "running with inputs" begin 
                dev = LocalSimulator()
                oq3_circ = ir(circ, Val(:OpenQASM))
                braket_task = run(dev, oq3_circ, shots=0, inputs=Dict(string(α)=>1.0, string(θ)=>2.0))
                res = result(braket_task)
                non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 2.0)) |> Probability
                oq3_circ2 = ir(non_para_circ, Val(:OpenQASM))
                braket_task2 = run(dev, oq3_circ2, shots=0)
                res2 = result(braket_task2)
                @test res.values == res2.values
            end
        end
    end
    Braket.IRType[] = :OpenQASM
end
