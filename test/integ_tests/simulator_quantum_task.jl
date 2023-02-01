using Braket, Braket.Observables, Distributions, LinearAlgebra, Random, Statistics, Test
using Braket: I

SHOTS = 8000
SV1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
DM1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/dm1"
SIMULATOR_ARNS = [SV1_ARN, DM1_ARN]
ARNS_WITH_SHOTS = [(SV1_ARN, SHOTS), (SV1_ARN, 0), (DM1_ARN, SHOTS), (DM1_ARN, 0)]

bell_circ() = Circuit([(H, 0), (CNot, 0, 1)])
three_qubit_circuit(θ::Float64, ϕ::Float64, φ::Float64, obs::Observables.Observable, obs_targets::Vector{Int}) = Circuit([(Rx, 0, θ), (Rx, 1, ϕ), (Rx, 2, φ), (CNot, 0, 1), (CNot, 1, 2), (Variance, obs, obs_targets), (Expectation, obs, obs_targets)])
function many_layers(n_qubits::Int, n_layers::Int)
    d       = Uniform(0, 2π)
    qubits  = collect(0:(n_qubits-1))
    circuit = Circuit()  # instantiate circuit object
    circuit(H, qubits)
    for layer in 0:n_layers-1
        if mod(layer + 1, 100) != 0
            for qubit in qubits
                angle = rand(d)
                gate = rand([Rx, Ry, Rz, H])
                if gate isa AngledGate
                    circuit(gate, qubit, angle)
                else
                    circuit(gate, qubit)
                end
            end
        else
            for q in 0:2:(n_qubits-1)
                circuit(CNot, q, q + 1)
            end
            for q in 1:2:(n_qubits - 2)
                circuit(CNot, q, q + 1)
            end
        end
    end
    return circuit
end

@inline function variance_expectation_sample_result(res::Braket.GateModelQuantumTaskResult, shots::Int, expected_var::Float64, expected_mean::Float64, expected_eigs::Vector{Float64})
    tol = get_tol(shots)
    variance = res.values[1]
    expectation = res.values[2]
    if shots > 0
        samples = res.values[3]
        sign_fix(x) = iszero(x) ? 0.0 : x
        @test isapprox(sort(collect(unique(sign_fix, samples))), sort(collect(unique(sign_fix, expected_eigs))), rtol=tol["rtol"], atol=tol["atol"])
        @test isapprox(mean(samples), expected_mean, rtol=tol["rtol"], atol=tol["atol"])
        @test isapprox(var(samples), expected_var, rtol=tol["rtol"], atol=tol["atol"])
    end
    @test isapprox(expectation, expected_mean, rtol=tol["rtol"], atol=tol["atol"])
    @test isapprox(variance, expected_var, rtol=tol["rtol"], atol=tol["atol"])
end

@testset "Simulator Quantum Task" begin
    @testset "Creating and cancelling a task" begin
        @testset for simulator_arn in SIMULATOR_ARNS
            device = AwsDevice(simulator_arn)
            bell = bell_circ()
            task = device(bell, shots=SHOTS, s3_destination_folder=s3_destination_folder)
            cancel(task)
            @test state(task) ∈ ["CANCELLING", "CANCELLED"]
        end
    end
    @testset "No result types Bell pair" begin
        @testset for simulator_arn in SIMULATOR_ARNS
            device = AwsDevice(simulator_arn)
            bell = bell_circ()
            bell_qasm = ir(bell, Val(:OpenQASM))
            for task in (bell, bell_qasm)
                tol = get_tol(SHOTS)
                res = result(device(task, shots=SHOTS, s3_destination_folder=s3_destination_folder))
                probabilities = res.measurement_probabilities
                expected = Dict("00"=>0.5, "11"=>0.5)
                for (bitstring, val) in probabilities
                    @test isapprox(val, expected[bitstring], rtol=tol["rtol"], atol=tol["atol"])
                end
                @test length(res.measurements) == SHOTS
            end
        end
    end
    @testset "qubit ordering" begin
        @testset for simulator_arn in SIMULATOR_ARNS
            device = AwsDevice(_arn=simulator_arn)
            state_110 = Circuit([(X, 0), (X, 1), (I, 2)])
            state_001 = Circuit([(I, 0), (I, 1), (X, 2)])
            @testset for (state, most_com) in ((state_110, "110"), (state_001, "001"))
                tasks = (state, ir(state, Val(:OpenQASM)))
                @testset for task in tasks
                    res = result(device(task, shots=SHOTS, s3_destination_folder=s3_destination_folder))
                    mc = argmax(res.measurement_counts)
                    @test mc == most_com
                end
            end
        end
    end
    @testset "Result types no shots" begin
        @testset for (simulator_arn, include_amplitude) in zip(SIMULATOR_ARNS, [true, false])
            circuit = bell_circ()
            circuit(Expectation, Observables.H() * Observables.X(), 0, 1)
            include_amplitude && circuit(Amplitude, ["01", "10", "00", "11"])
            tasks = (circuit, ir(circuit, Val(:OpenQASM)))
            @testset for task in tasks
                device = AwsDevice(_arn=simulator_arn)
                res = result(device(task, shots=0, s3_destination_folder=s3_destination_folder))
                @test length(res.result_types) == (include_amplitude ? 2 : 1)
                @test isapprox(res[Expectation(Observables.H() * Observables.X(), [0, 1])], 1/√2)
                if include_amplitude
                    amps = res[Amplitude(["01", "10", "00", "11"])]
                    @test isapprox(amps["01"], 0)
                    @test isapprox(amps["10"], 0)
                    @test isapprox(amps["00"], 1/√2)
                    @test isapprox(amps["11"], 1/√2)
                end
            end
        end
    end
    @testset "Bell pair nonzero shots" begin
        circuit = bell_circ()
        circuit(Expectation, Observables.H() * Observables.X(), [0, 1])
        circuit(Sample, Observables.H() * Observables.X(), [0, 1])
        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            @test length(res.result_types) == 2
            @test 0.6 < res[Expectation(Observables.H() * Observables.X(), [0, 1])] < 0.8
            @test length(res[Sample(Observables.H() * Observables.X(), [0, 1])]) == SHOTS
        end
    end
    @testset "Bell pair full probability" begin
        circuit = bell_circ()
        circuit(Probability)
        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        tol = get_tol(SHOTS)
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            @test length(res.result_types) == 1
            @test isapprox(res[Probability()], [0.5, 0.0, 0.0, 0.5], rtol=tol["rtol"], atol=tol["atol"])
        end
    end
    @testset "Bell pair marginal probability" begin
        circuit = bell_circ()
        circuit(Probability, 0)
        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        tol = get_tol(SHOTS)
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=SHOTS, s3_destination_folder=s3_destination_folder)) 
            @test length(res.result_types) == 1
            @test isapprox(res[Probability(0)], [0.5, 0.5], rtol=tol["rtol"], atol=tol["atol"])
        end
    end
    @testset "Result types x x y" begin
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        obs = Observables.X() * Observables.Y()
        obs_targets = [0, 2]
        circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
        expected_mean = sin(θ) * sin(ϕ) * sin(φ)
        expected_var = (8*sin(θ)^2 * cos(2φ) * sin(ϕ)^2 - cos(2(θ - ϕ))- cos(2(θ + ϕ)) + 2*cos(2θ) + 2*cos(2ϕ) + 14) / 16
        expected_eigs = [-1.0, 1.0]
        @testset for (simulator_arn, shots) in ARNS_WITH_SHOTS
            device = AwsDevice(_arn=simulator_arn)
            circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
            shots > 0 && circuit(Sample, obs, obs_targets)
            tasks = (circuit, ir(circuit, Val(:OpenQASM)))
            for task in tasks
                res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
                variance_expectation_sample_result(res, shots, expected_var, expected_mean, expected_eigs)
            end
        end
    end
    @testset "Result types z x h x y" begin
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        obs = Observables.Z() * Observables.H() * Observables.Y()
        obs_targets = [0, 1, 2]
        circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
        expected_mean = -(cos(φ)*sin(ϕ)+sin(φ)*cos(θ))/√2
        expected_var = (3 + cos(2ϕ)*cos(φ)^2 - cos(2θ)*sin(φ)^2 - 2*cos(θ)*sin(ϕ)*sin(2φ)) / 4
        expected_eigs = [-1.0, 1.0]
        @testset for (simulator_arn, shots) in ARNS_WITH_SHOTS
            device = AwsDevice(_arn=simulator_arn)
            circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
            shots > 0 && circuit(Sample, obs, obs_targets)
            tasks = (circuit, ir(circuit, Val(:OpenQASM)))
            for task in tasks
                res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
                variance_expectation_sample_result(res, shots, expected_var, expected_mean, expected_eigs)
            end
        end
    end
    @testset "Result types z x z" begin
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        obs = Observables.Z() * Observables.Z()
        obs_targets = [0, 2]
        circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
        expected_mean = 0.849694136476246
        expected_var = 0.27801987443788634
        expected_eigs = [-1.0, 1.0]
        @testset for (simulator_arn, shots) in ARNS_WITH_SHOTS
            device = AwsDevice(_arn=simulator_arn)
            circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
            shots > 0 && circuit(Sample, obs, obs_targets)
            tasks = (circuit, ir(circuit, Val(:OpenQASM)))
            for task in tasks
                res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
                variance_expectation_sample_result(res, shots, expected_var, expected_mean, expected_eigs)
            end
        end
    end
    @testset "Result types tensor {y,z,Hermitian} x Hermitian" begin
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        ho_mat = [-6 2+im -3 -5+2im;
                  2-im 0 2-im -5+4im;
                  -3 2+im 0 -4+3im;
                  -5-2im -5-4im -4-3im -6]
        @test ishermitian(ho_mat)
        ho = Observables.HermitianObservable(ho_mat)
        ho_mat2 = [1 2; 2 4]
        ho2 = Observables.HermitianObservable(ho_mat2)

        meany = 1.4499810303182408
        meanz = 0.5 *(-6 * cos(θ) * (cos(φ) + 1) - 2 * sin(φ) * (cos(θ) + sin(ϕ) - 2 * cos(ϕ)) + 3 * cos(φ) * sin(ϕ) + sin(ϕ))
        meanh = -4.30215023196904

        vary = 74.03174647518193
        varz = (1057 - cos(2ϕ) + 12*(27 + cos(2ϕ))*cos(φ) - 2*cos(2φ)*sin(ϕ)*(16*cos(ϕ) + 21*sin(ϕ)) + 16*sin(2ϕ) - 8*(-17 + cos(2ϕ) + 2 * sin(2ϕ)) * sin(φ) - 8 * cos(2θ) * (3 + 3*cos(φ) + sin(φ))^2 - 24*cos(ϕ)*(cos(ϕ) + 2*sin(ϕ)) * sin(2φ) - 8*cos(θ)*(4*cos(ϕ)*(4 + 8*cos(φ) + cos(2φ) - (1 + 6*cos(φ))*sin(φ)) + sin(ϕ)*(15 + 8*cos(φ) - 11*cos(2φ) + 42*sin(φ) + 3*sin(2φ)))) / 16
        varh = 370.71292282796804

        y_array = [0 -im; im 0]
        z_array = diagm([1, -1])
        eigsy = eigvals(kron(y_array, ho_mat))
        eigsz = eigvals(kron(z_array, ho_mat))
        eigsh = [-70.90875406, -31.04969387, 0, 3.26468993, 38.693758]
        obs_targets = [0, 1, 2]
        @testset for (obs, expected_mean, expected_var, expected_eigs) in [(Observables.Y() * ho, meany, vary, eigsy),
                                                                           (Observables.Z() * ho, meanz, varz, eigsz),
                                                                           (ho2 * ho, meanh, varh, eigsh)], (simulator_arn, shots) in ARNS_WITH_SHOTS
            device = AwsDevice(_arn=simulator_arn)
            circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
            shots > 0 && circuit(Sample, obs, obs_targets)
            tasks = (circuit, ir(circuit, Val(:OpenQASM)))
            for task in tasks
                res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
                variance_expectation_sample_result(res, shots, expected_var, expected_mean, expected_eigs)
            end
        end
    end
    @testset "Result types all selected" begin
        θ = 0.543
        ho_mat = [1 2im; -2im 0]
        ho = Observables.HermitianObservable(ho_mat)
        expected_mean = 2*sin(θ) + 0.5*cos(θ) + 0.5
        var_ = 0.25 * (sin(θ) - 4*cos(θ))^2
        expected_var = [var_, var_]
        expected_eigs = eigvals(Hermitian(ho_mat))
        @testset for (simulator_arn, shots) in ARNS_WITH_SHOTS
            device = AwsDevice(_arn=simulator_arn)
            circuit = Circuit([(Rx, 0, θ), (Rx, 1, θ), (Variance, ho), (Expectation, ho, 0)])
            shots > 0 && circuit(Sample, ho, 1)
            for task in (circuit, ir(circuit, Val(:OpenQASM)))
                res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
                tol = get_tol(shots)
                variance = res.values[1]
                expectation = res.values[2]
                if shots > 0
                    samples = res.values[3]
                    @test isapprox(sort(collect(unique(samples))), sort(collect(unique(expected_eigs))), rtol=tol["rtol"], atol=tol["atol"])
                    @test isapprox(mean(samples), expected_mean, rtol=tol["rtol"], atol=tol["atol"])
                    @test isapprox(var(samples), var_, rtol=tol["rtol"], atol=tol["atol"])
                end
                @test isapprox(expectation, expected_mean, rtol=tol["rtol"], atol=tol["atol"])
                @test isapprox(variance, expected_var, rtol=tol["rtol"], atol=tol["atol"])
            end
        end
    end
    @testset "Result types noncommuting" begin
        shots = 0
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        ho_mat = [-6 2+im -3 -5+2im;
                  2-im 0 2-im -5+4im;
                  -3 2+im 0 -4+3im;
                  -5-2im -5-4im -4-3im -6]
        obs1 = Observables.X() * Observables.Y()
        obs1_targets = [0, 2]
        obs2 = Observables.Z() * Observables.Z()
        obs2_targets = [0, 2]
        obs3 = Observables.Y() * Observables.HermitianObservable(ho_mat)
        obs3_targets = [0, 1, 2]
        obs3_targets = [0, 1, 2]
        circuit = three_qubit_circuit(θ, ϕ, φ, obs1, obs1_targets)
        circuit(Expectation, obs2, obs2_targets)
        circuit(Expectation, obs3, obs3_targets)
            
        expected_mean1 = sin(θ) * sin(ϕ) * sin(φ)
        expected_var1 = (8*sin(θ)^2 * cos(2φ) * sin(ϕ)^2 - cos(2(θ - ϕ))- cos(2(θ + ϕ)) + 2*cos(2θ) + 2*cos(2ϕ) + 14) / 16
        expected_mean2 = 0.849694136476246
        expected_mean3 = 1.4499810303182408

        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
            @test isapprox(res.values[1], expected_var1)
            @test isapprox(res.values[2], expected_mean1)
            @test isapprox(res.values[3], expected_mean2)
            @test isapprox(res.values[4], expected_mean3)
        end
    end
    @testset "Result types noncommuting flipped targets" begin
        circuit = bell_circ()
        tp = Observables.TensorProduct(["h", "x"])
        circuit = Expectation(circuit, tp, [0, 1])
        circuit = Expectation(circuit, tp, [1, 0])
        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=0, s3_destination_folder=s3_destination_folder))
            @test isapprox(res.values[1], √2 / 2)
            @test isapprox(res.values[2], √2 / 2)
        end
    end
    @testset "Result types all noncommuting" begin
        circuit = bell_circ()
        ho = [1 2im; -2im 0]
        circuit(Expectation, Observables.HermitianObservable(ho))
        circuit(Expectation, Observables.X())
        tasks = (circuit, ir(circuit, Val(:OpenQASM)))
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=0, s3_destination_folder=s3_destination_folder))
            @test isapprox(res.values[1], [0.5, 0.5])
            @test isapprox(res.values[2], [0, 0])
        end
    end
    @testset "Result types observable not in instructions" begin
        bell = bell_circ()
        bell(Expectation, Observables.X(), 2)
        bell(Variance, Observables.Y(), 3)
        bell_qasm = ir(bell, Val(:OpenQASM))
        @test qubit_count(bell) == 4
        @testset for (simulator_arn, shots) in ARNS_WITH_SHOTS, task in (bell, bell_qasm)
            tol = get_tol(shots)
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(task, shots=shots, s3_destination_folder=s3_destination_folder))
            @test isapprox(res.values[1], 0, rtol=tol["rtol"], atol=tol["atol"])
            @test isapprox(res.values[2], 1, rtol=tol["rtol"], atol=tol["atol"])
        end
    end
    @testset "Multithreaded Bell pair" begin
        tol = get_tol(SHOTS)
        tasks = (bell_circ, (()->ir(bell_circ(), Val(:OpenQASM))))
        @testset for simulator_arn in SIMULATOR_ARNS, task in tasks
            device = AwsDevice(_arn=simulator_arn)
            run_circuit(circuit) = result(device(circuit, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            task_array = [task() for ii in 1:Threads.nthreads()]
            futures = [Threads.@spawn run_circuit(c) for c in task_array]
            future_results = fetch.(futures)
            for r in future_results
                @test isapprox(r.measurement_probabilities["00"], 0.5, rtol=tol["rtol"], atol=tol["atol"])
                @test isapprox(r.measurement_probabilities["11"], 0.5, rtol=tol["rtol"], atol=tol["atol"])
                @test length(r.measurements) == SHOTS
            end
        end
    end
    @testset "Batch Bell pair" begin
        circs = [bell_circ() for _ in 1:10]
        tasks_list = (circs, [ir(c, Val(:OpenQASM)) for c in circs])
        @testset for simulator_arn in SIMULATOR_ARNS, tasks in tasks_list
            device = AwsDevice(_arn=simulator_arn)
            batch = device(tasks, max_parallel=5, shots=SHOTS, s3_destination_folder=s3_destination_folder)
            res = results(batch)
            tol = get_tol(SHOTS)
            for r in res
                @test isapprox(r.measurement_probabilities["00"], 0.5, rtol=tol["rtol"], atol=tol["atol"])
                @test isapprox(r.measurement_probabilities["11"], 0.5, rtol=tol["rtol"], atol=tol["atol"])
                @test length(r.measurements) == SHOTS
            end
            @test [result(task) for task in batch._tasks] == res
        end
    end
    @testset "No result types Bell pair OpenQASM" begin
        expected = Dict("00"=>0.5, "11"=>0.5)
        openqasm_string = """
            OPENQASM 3;
            qubit[2] q;
            bit[2] c;
            h q[0];
            cnot q[0], q[1];
            c[0] = measure q[0];
            c[1] = measure q[1];
            """
        hardcoded_openqasm = OpenQasmProgram(Braket.header_dict[OpenQasmProgram], openqasm_string, nothing)
        circuit = bell_circ()
        generated_openqasm = ir(circuit, Val(:OpenQASM))
        @testset for simulator_arn in SIMULATOR_ARNS, program in (hardcoded_openqasm, generated_openqasm)
            device = AwsDevice(_arn=simulator_arn)
            tol = get_tol(SHOTS)
            res = result(device(program, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            probabilities = res.measurement_probabilities
            for (bitstring, val) in probabilities
                @test isapprox(val, expected[bitstring], rtol=tol["rtol"], atol=tol["atol"])
            end
            @test length(res.measurements) == SHOTS
        end
    end
    @testset "Bell pair OpenQASM results" begin
        openqasm_string = """
        OPENQASM 3;
        qubit[2] q;
        h q[0];
        cnot q[0], q[1];
        #pragma braket result expectation h(q[0]) @ x(q[1])
        #pragma braket result sample h(q[0]) @ x(q[1])
        """
        hardcoded_openqasm = OpenQasmProgram(Braket.header_dict[OpenQasmProgram], openqasm_string, nothing)
        circuit = bell_circ()
        tp = Observables.TensorProduct(["h", "x"])
        circuit = Expectation(circuit, tp, [0, 1])
        circuit = Sample(circuit, tp, [0, 1])
        generated_openqasm = ir(circuit, Val(:OpenQASM))
        @testset for simulator_arn in SIMULATOR_ARNS, program in (hardcoded_openqasm, generated_openqasm)
            device = AwsDevice(_arn=simulator_arn)
            res = result(device(program, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            @test length(res.result_types) == 2
            @test 0.6 < res[Expectation(tp, [0, 1])] < 0.8
            @test length(res[Sample(tp, [0, 1])]) == SHOTS
        end
    end
    @testset "OpenQASM probability results" begin
        device = AwsDevice(_arn="arn:aws:braket:::device/quantum-simulator/amazon/dm1")
        shots = SHOTS
        tol = get_tol(shots)
        openqasm_string = """
            OPENQASM 3;
            qubit[2] q;
            x q[0];
            x q[1];
            #pragma braket noise bit_flip(0.1) q[0]
            #pragma braket result probability q[0], q[1]
            """
        hardcoded_openqasm = OpenQasmProgram(Braket.header_dict[OpenQasmProgram], openqasm_string, nothing)
        circuit = Circuit([(X, 0), (X, 1), (BitFlip, 0, 0.1), (Probability, 0, 1)])
        generated_openqasm = ir(circuit, Val(:OpenQASM))
        for program in (hardcoded_openqasm, generated_openqasm)
            res = result(device(program, shots=shots, s3_destination_folder=s3_destination_folder))
            @test length(res.result_types) == 1
            @test isapprox(res.values[1], [0.0, 0.1, 0, 0.9], rtol=tol["rtol"], atol=tol["atol"])
        end
    end
    @testset "Many layers" begin
        @testset for simulator_arn in SIMULATOR_ARNS, num_layers in [50, 100, 500, 1000]
            num_qubits = 10
            circuit = many_layers(num_qubits, num_layers)
            device = AwsDevice(_arn=simulator_arn)

            tol = get_tol(SHOTS)
            res = result(device(circuit, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            probabilities = res.measurement_probabilities
            probability_sum = 0
            for bitstring in keys(probabilities)
                @test probabilities[bitstring] >= 0
                probability_sum += probabilities[bitstring]
            end
            @test isapprox(probability_sum, 1, rtol=tol["rtol"], atol=tol["atol"])
            @test length(res.measurements) == SHOTS
        end
    end
end
