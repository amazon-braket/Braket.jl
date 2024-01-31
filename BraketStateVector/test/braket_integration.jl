using Test, CUDA, Statistics, LinearAlgebra, Braket, Braket.Observables, BraketStateVector
using Braket: I, name

@testset "Basic integration of local simulators with Braket.jl" begin
    @testset "Simulator $sim_type" for (sim_type, rt) in (
        ("braket_sv", Braket.StateVector),
        ("braket_dm", Braket.DensityMatrix),
    )
        d = LocalSimulator(sim_type)
        @test d.backend == sim_type
        c = Circuit()
        H(c, 0, 1, 2)
        Rx(c, 0, 1, 2, 0.5)
        rt(c)
        if sim_type == "braket_sv"
            Amplitude(c, ["000", "111"])
        end
        r = d(c, shots = 0)
    end
end

@testset "Correctness" begin
    Braket.IRType[] = :JAQCD
    PURE_DEVICE = LocalSimulator("braket_sv")
    NOISE_DEVICE = LocalSimulator("braket_dm")
    SHOT_LIST = (0, 8000)

    get_tol(shots::Int) = return (
        shots > 0 ? Dict("atol" => 0.1, "rtol" => 0.15) : Dict("atol" => 0.01, "rtol" => 0)
    )

    bell_circ() = Circuit([(H, 0), (CNot, 0, 1)])
    three_qubit_circuit(
        θ::Float64,
        ϕ::Float64,
        φ::Float64,
        obs::Observables.Observable,
        obs_targets::Vector{Int},
    ) = Circuit([
        (Rx, 0, θ),
        (Rx, 1, ϕ),
        (Rx, 2, φ),
        (CNot, 0, 1),
        (CNot, 1, 2),
        (Variance, obs, obs_targets),
        (Expectation, obs, obs_targets),
    ])

    @inline function variance_expectation_sample_result(
        res::Braket.GateModelQuantumTaskResult,
        shots::Int,
        expected_var::Float64,
        expected_mean::Float64,
        expected_eigs::Vector{Float64},
    )
        tol = get_tol(shots)
        variance = res.values[1]
        expectation = res.values[2]
        if shots > 0
            samples = res.values[3]
            sign_fix(x) = (iszero(x) || abs(x) < 1e-12) ? 0.0 : x
            fixed_samples = sort(collect(unique(sign_fix, samples)))
            fixed_eigs = sort(collect(unique(sign_fix, expected_eigs)))
            @test isapprox(
                sort(fixed_samples),
                sort(fixed_eigs),
                rtol = tol["rtol"],
                atol = tol["atol"],
            )
            @test isapprox(
                mean(samples),
                expected_mean,
                rtol = tol["rtol"],
                atol = tol["atol"],
            )
            @test isapprox(
                var(samples),
                expected_var,
                rtol = tol["rtol"],
                atol = tol["atol"],
            )
        end
        @test isapprox(expectation, expected_mean, rtol = tol["rtol"], atol = tol["atol"])
        @test isapprox(variance, expected_var, rtol = tol["rtol"], atol = tol["atol"])
    end

    @testset "Local Braket Simulator" begin
        @testset for (backend, device_name) in [
            ("default", "StateVectorSimulator"),
            ("braket_sv", "StateVectorSimulator"),
            ("braket_dm", "DensityMatrixSimulator"),
        ]
            local_simulator_device = LocalSimulator(backend)
            @test name(local_simulator_device) == device_name
        end
        @testset "Device $DEVICE, shots $SHOTS" for DEVICE in (PURE_DEVICE, NOISE_DEVICE),
            SHOTS in SHOT_LIST

            if SHOTS > 0
                @testset "qubit ordering" begin
                    device = DEVICE
                    state_110 = Circuit([(X, 0), (X, 1), (I, 2)])
                    state_001 = Circuit([(I, 0), (I, 1), (X, 2)])
                    @testset for (state, most_com) in
                                 ((state_110, "110"), (state_001, "001"))
                        tasks = (state,)#ir(state, Val(:OpenQASM)))
                        @testset for task in tasks
                            res = result(device(task, shots = SHOTS))
                            mc = argmax(res.measurement_counts)
                            @test mc == most_com
                        end
                    end
                end

                @testset "Bell pair nonzero shots" begin
                    circuit = bell_circ()
                    circuit(Expectation, Observables.H() * Observables.X(), [0, 1])
                    circuit(Sample, Observables.H() * Observables.X(), [0, 1])
                    tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                    @testset for task in tasks
                        device = DEVICE
                        res = result(device(task, shots = SHOTS))
                        @test length(res.result_types) == 2
                        @test 0.6 <
                              res[Expectation(Observables.H() * Observables.X(), [0, 1])] <
                              0.8
                        @test length(
                            res[Sample(Observables.H() * Observables.X(), [0, 1])],
                        ) == SHOTS
                    end
                end
            end
            @testset "Bell pair full probability" begin
                circuit = bell_circ()
                circuit(Probability)
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                tol = get_tol(SHOTS)
                @testset for task in tasks
                    device = DEVICE
                    res = result(device(task, shots = SHOTS))
                    @test length(res.result_types) == 1
                    @test isapprox(
                        res[Probability()],
                        [0.5, 0.0, 0.0, 0.5],
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                end
            end
            @testset "Bell pair marginal probability" begin
                circuit = bell_circ()
                circuit(Probability, 0)
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)),)
                tol = get_tol(SHOTS)
                @testset for task in tasks
                    device = DEVICE
                    res = result(device(task, shots = SHOTS))
                    @test length(res.result_types) == 1
                    @test isapprox(
                        res[Probability(0)],
                        [0.5, 0.5],
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                end
            end
            @testset "Result types x x y" begin
                θ = 0.432
                ϕ = 0.123
                φ = -0.543
                obs_targets = [0, 2]
                expected_mean = sin(θ) * sin(ϕ) * sin(φ)
                expected_var =
                    (
                        8 * sin(θ)^2 * cos(2φ) * sin(ϕ)^2 - cos(2(θ - ϕ)) - cos(2(θ + ϕ)) +
                        2 * cos(2θ) +
                        2 * cos(2ϕ) +
                        14
                    ) / 16
                expected_eigs = [-1.0, 1.0]
                device = DEVICE
                shots = SHOTS
                @testset "Obs $obs" for obs in (
                    Observables.X() * Observables.Y(),
                    Observables.HermitianObservable(kron([0 1; 1 0], [0 -im; im 0])),
                )
                    circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
                    shots > 0 && circuit(Sample, obs, obs_targets)
                    tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                    for task in tasks
                        res = result(device(task, shots = shots))
                        variance_expectation_sample_result(
                            res,
                            shots,
                            expected_var,
                            expected_mean,
                            expected_eigs,
                        )
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
                expected_mean = -(cos(φ) * sin(ϕ) + sin(φ) * cos(θ)) / √2
                expected_var =
                    (
                        3 + cos(2ϕ) * cos(φ)^2 - cos(2θ) * sin(φ)^2 -
                        2 * cos(θ) * sin(ϕ) * sin(2φ)
                    ) / 4
                expected_eigs = [-1.0, 1.0]
                device = DEVICE
                shots = SHOTS
                circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
                shots > 0 && circuit(Sample, obs, obs_targets)
                tasks = (circuit,) # ir(circuit, Val(:OpenQASM)))
                for task in tasks
                    res = result(device(task, shots = shots))
                    variance_expectation_sample_result(
                        res,
                        shots,
                        expected_var,
                        expected_mean,
                        expected_eigs,
                    )
                end
            end
            @testset "Result types z x z" begin
                θ = 0.432
                ϕ = 0.123
                φ = -0.543
                obs_targets = [0, 2]
                expected_mean = 0.849694136476246
                expected_var = 0.27801987443788634
                expected_eigs = [-1.0, 1.0]
                device = DEVICE
                shots = SHOTS
                for obs in (
                    Observables.Z() * Observables.Z(),
                    Observables.HermitianObservable(kron([1 0; 0 -1], [1 0; 0 -1])),
                )
                    circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
                    shots > 0 && circuit(Sample, obs, obs_targets)
                    tasks = (circuit,)# ir(circuit, Val(:OpenQASM)))
                    for task in tasks
                        res = result(device(task, shots = shots))
                        variance_expectation_sample_result(
                            res,
                            shots,
                            expected_var,
                            expected_mean,
                            expected_eigs,
                        )
                    end
                end
            end
            @testset "($DEVICE, $SHOTS) Result types tensor {i,y,z,Hermitian} x Hermitian" begin
                θ = 0.432
                ϕ = 0.123
                φ = -0.543
                ho_mat = [
                    -6 2+im -3 -5+2im
                    2-im 0 2-im -5+4im
                    -3 2+im 0 -4+3im
                    -5-2im -5-4im -4-3im -6
                ]
                @test ishermitian(ho_mat)
                ho = Observables.HermitianObservable(ComplexF64.(ho_mat))
                ho_mat2 = [1 2; 2 4]
                ho2 = Observables.HermitianObservable(ComplexF64.(ho_mat2))
                ho_mat3 = [-6 2+im; 2-im 0]
                ho3 = Observables.HermitianObservable(ComplexF64.(ho_mat3))
                ho_mat4 = kron([1 0; 0 1], [-6 2+im; 2-im 0])
                ho4 = Observables.HermitianObservable(ComplexF64.(ho_mat4))
                meani = -5.7267957792059345
                meany = 1.4499810303182408
                meanz =
                    0.5 * (
                        -6 * cos(θ) * (cos(φ) + 1) -
                        2 * sin(φ) * (cos(θ) + sin(ϕ) - 2 * cos(ϕ)) +
                        3 * cos(φ) * sin(ϕ) +
                        sin(ϕ)
                    )
                meanh = -4.30215023196904
                meanii = -5.78059066879935

                vari = 43.33800156673375
                vary = 74.03174647518193
                varz =
                    (
                        1057 - cos(2ϕ) + 12 * (27 + cos(2ϕ)) * cos(φ) -
                        2 * cos(2φ) * sin(ϕ) * (16 * cos(ϕ) + 21 * sin(ϕ)) + 16 * sin(2ϕ) -
                        8 * (-17 + cos(2ϕ) + 2 * sin(2ϕ)) * sin(φ) -
                        8 * cos(2θ) * (3 + 3 * cos(φ) + sin(φ))^2 -
                        24 * cos(ϕ) * (cos(ϕ) + 2 * sin(ϕ)) * sin(2φ) -
                        8 *
                        cos(θ) *
                        (
                            4 *
                            cos(ϕ) *
                            (4 + 8 * cos(φ) + cos(2φ) - (1 + 6 * cos(φ)) * sin(φ)) +
                            sin(ϕ) *
                            (15 + 8 * cos(φ) - 11 * cos(2φ) + 42 * sin(φ) + 3 * sin(2φ))
                        )
                    ) / 16
                varh = 370.71292282796804
                varii = 6.268315532585994

                i_array = [1 0; 0 1]
                y_array = [0 -im; im 0]
                z_array = diagm([1, -1])
                eigsi = eigvals(kron(i_array, ho_mat))
                eigsy = eigvals(kron(y_array, ho_mat))
                eigsz = eigvals(kron(z_array, ho_mat))
                eigsh = [-70.90875406, -31.04969387, 0, 3.26468993, 38.693758]
                eigsii = eigvals(kron(i_array, kron(i_array, ho_mat3)))
                obs_targets = [0, 1, 2]
                @testset "Obs $obs" for (obs, expected_mean, expected_var, expected_eigs) in
                                        [
                    (Observables.I() * ho, meani, vari, eigsi),
                    (Observables.Y() * ho, meany, vary, eigsy),
                    (Observables.Z() * ho, meanz, varz, eigsz),
                    (ho2 * ho, meanh, varh, eigsh),
                    (
                        Observables.HermitianObservable(kron(ho_mat2, ho_mat)),
                        meanh,
                        varh,
                        eigsh,
                    ),
                    (Observables.I() * Observables.I() * ho3, meanii, varii, eigsii),
                    (Observables.I() * ho4, meanii, varii, eigsii),
                ]
                    device = DEVICE
                    shots = SHOTS
                    circuit = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
                    shots > 0 && circuit(Sample, obs, obs_targets)
                    tasks = (circuit,)# ir(circuit, Val(:OpenQASM)))
                    for task in tasks
                        res = result(device(task, shots = shots))
                        variance_expectation_sample_result(
                            res,
                            shots,
                            expected_var,
                            expected_mean,
                            expected_eigs,
                        )
                    end
                end
            end
            @testset "Result types single Hermitian" begin
                θ = 0.432
                ϕ = 0.123
                φ = -0.543
                ho_mat = [
                    -6 2+im -3 -5+2im
                    2-im 0 2-im -5+4im
                    -3 2+im 0 -4+3im
                    -5-2im -5-4im -4-3im -6
                ]
                @test ishermitian(ho_mat)
                ho = Observables.HermitianObservable(ComplexF64.(ho_mat))
                ho_mat2 = [1 2; 2 4]
                ho2 = Observables.HermitianObservable(ho_mat2)
                ho_mat3 = [-6 2+im; 2-im 0]
                ho3 = Observables.HermitianObservable(ho_mat3)
                ho_mat4 = kron([1 0; 0 1], [-6 2+im; 2-im 0])
                ho4 = Observables.HermitianObservable(ho_mat4)
                h = Observables.HermitianObservable(kron(ho_mat2, ho_mat))
                meani = -5.7267957792059345
                meanh = -4.30215023196904
                meanii = -5.78059066879935

                vari = 43.33800156673375
                varh = 370.71292282796804
                varii = 6.268315532585994

                i_array = [1 0; 0 1]
                eigsi = eigvals(kron(i_array, ho_mat))
                eigsh = [-70.90875406, -31.04969387, 0, 3.26468993, 38.693758]
                eigsii = eigvals(kron(i_array, kron(i_array, ho_mat3)))
                obs_targets = [0, 1, 2]
                @testset "Obs $obs" for (
                    obs,
                    targets,
                    expected_mean,
                    expected_var,
                    expected_eigs,
                ) in [
                    (ho, [1, 2], meani, vari, eigsi),
                    (h, [0, 1, 2], meanh, varh, eigsh),
                    (ho3, [2], meanii, varii, eigsii),
                    (ho4, [1, 2], meanii, varii, eigsii),
                ]
                    device = DEVICE
                    shots = SHOTS
                    circuit = three_qubit_circuit(θ, ϕ, φ, obs, targets)
                    shots > 0 && circuit(Sample, obs, targets)
                    tasks = (circuit,)# ir(circuit, Val(:OpenQASM)))
                    for task in tasks
                        res = result(device(task, shots = shots))
                        variance_expectation_sample_result(
                            res,
                            shots,
                            expected_var,
                            expected_mean,
                            expected_eigs,
                        )
                    end
                end

            end
            @testset "Result types all selected" begin
                θ = 0.543
                ho_mat = [1 2im; -2im 0]
                ho = Observables.HermitianObservable(ho_mat)
                expected_mean = 2 * sin(θ) + 0.5 * cos(θ) + 0.5
                var_ = 0.25 * (sin(θ) - 4 * cos(θ))^2
                expected_var = [var_, var_]
                expected_eigs = eigvals(Hermitian(ho_mat))
                device = DEVICE
                shots = SHOTS
                circuit =
                    Circuit([(Rx, 0, θ), (Rx, 1, θ), (Variance, ho), (Expectation, ho, 0)])
                shots > 0 && circuit(Sample, ho, 1)
                for task in (circuit,)# ir(circuit, Val(:OpenQASM)))
                    res = result(device(task, shots = shots))
                    tol = get_tol(shots)
                    variance = res.values[1]
                    expectation = res.values[2]
                    if shots > 0
                        samples = res.values[3]
                        @test isapprox(
                            sort(collect(unique(samples))),
                            sort(collect(unique(expected_eigs))),
                            rtol = tol["rtol"],
                            atol = tol["atol"],
                        )
                        @test isapprox(
                            mean(samples),
                            expected_mean,
                            rtol = tol["rtol"],
                            atol = tol["atol"],
                        )
                        @test isapprox(
                            var(samples),
                            var_,
                            rtol = tol["rtol"],
                            atol = tol["atol"],
                        )
                    end
                    @test isapprox(
                        expectation,
                        expected_mean,
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                    @test isapprox(
                        variance,
                        expected_var,
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                end
            end
            @testset "Result types noncommuting" begin
                shots = 0
                θ = 0.432
                ϕ = 0.123
                φ = -0.543
                ho_mat = [
                    -6 2+im -3 -5+2im
                    2-im 0 2-im -5+4im
                    -3 2+im 0 -4+3im
                    -5-2im -5-4im -4-3im -6
                ]
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
                expected_var1 =
                    (
                        8 * sin(θ)^2 * cos(2φ) * sin(ϕ)^2 - cos(2(θ - ϕ)) - cos(2(θ + ϕ)) +
                        2 * cos(2θ) +
                        2 * cos(2ϕ) +
                        14
                    ) / 16
                expected_mean2 = 0.849694136476246
                expected_mean3 = 1.4499810303182408

                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                @testset for task in tasks
                    device = DEVICE
                    res = result(device(task, shots = shots))
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
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                @testset for task in tasks
                    device = DEVICE
                    res = result(device(task, shots = 0))
                    @test isapprox(res.values[1], √2 / 2)
                    @test isapprox(res.values[2], √2 / 2)
                end
            end
            @testset "Result types all noncommuting" begin
                circuit = bell_circ()
                ho = [1 2im; -2im 0]
                circuit(Expectation, Observables.HermitianObservable(ho))
                circuit(Expectation, Observables.X())
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                @testset for task in tasks
                    device = DEVICE
                    res = result(device(task, shots = 0))
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
                shots = SHOTS
                device = DEVICE
                @testset for task in (bell,)#bell_qasm)
                    tol = get_tol(shots)
                    res = result(device(task, shots = shots))
                    @test isapprox(res.values[1], 0, rtol = tol["rtol"], atol = tol["atol"])
                    @test isapprox(res.values[2], 1, rtol = tol["rtol"], atol = tol["atol"])
                end
            end
        end
        @testset for DEVICE in (PURE_DEVICE,), SHOTS in SHOT_LIST
            @testset "Result types no shots" begin
                @testset for include_amplitude in [true, false]
                    circuit = bell_circ()
                    circuit(Expectation, Observables.H() * Observables.X(), 0, 1)
                    include_amplitude && circuit(Amplitude, ["01", "10", "00", "11"])
                    tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                    @testset for task in tasks
                        device = DEVICE
                        shots = 0
                        res = result(device(task, shots = 0))
                        @test length(res.result_types) == (include_amplitude ? 2 : 1)
                        @test isapprox(
                            res[Expectation(Observables.H() * Observables.X(), [0, 1])],
                            1 / √2,
                        )
                        if include_amplitude
                            amps = res[Amplitude(["01", "10", "00", "11"])]
                            @test isapprox(amps["01"], 0)
                            @test isapprox(amps["10"], 0)
                            @test isapprox(amps["00"], 1 / √2)
                            @test isapprox(amps["11"], 1 / √2)
                        end
                    end
                end
            end
            if SHOTS > 0
                @testset "Multithreaded Bell pair" begin
                    tol = get_tol(SHOTS)
                    tasks = (bell_circ,)#(()->ir(bell_circ(), Val(:OpenQASM))))
                    device = DEVICE
                    @testset for task in tasks
                        run_circuit(circuit) = result(device(circuit, shots = SHOTS))
                        task_array = [task() for ii = 1:Threads.nthreads()]
                        futures = [Threads.@spawn run_circuit(c) for c in task_array]
                        future_results = fetch.(futures)
                        for r in future_results
                            @test isapprox(
                                r.measurement_probabilities["00"],
                                0.5,
                                rtol = tol["rtol"],
                                atol = tol["atol"],
                            )
                            @test isapprox(
                                r.measurement_probabilities["11"],
                                0.5,
                                rtol = tol["rtol"],
                                atol = tol["atol"],
                            )
                            @test length(r.measurements) == SHOTS
                        end
                    end
                end
            end
        end
        @testset for DEVICE in (NOISE_DEVICE,), SHOTS in SHOT_LIST
            @testset "noisy circuit 1 qubit noise full probability" begin
                shots = SHOTS
                tol = get_tol(shots)
                circuit = Circuit([(X, 0), (X, 1), (BitFlip, 0, 0.1), (Probability,)])
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                device = DEVICE
                for task in tasks
                    res = result(device(task, shots = shots))
                    @test length(res.result_types) == 1
                    @test isapprox(
                        res[Probability()],
                        [0.0, 0.1, 0, 0.9],
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                end
            end
            @testset "noisy circuit 2 qubit noise full probability" begin
                shots = SHOTS
                tol = get_tol(shots)
                K0 = √0.9 * diagm(ones(4))
                K1 = √0.1 * kron([0.0 1.0; 1.0 0.0], [0.0 1.0; 1.0 0.0])
                circuit =
                    Circuit([(X, 0), (X, 1), (Kraus, [0, 1], [K0, K1]), (Probability,)])
                tasks = (circuit,)#ir(circuit, Val(:OpenQASM)))
                device = DEVICE
                for task in tasks
                    res = result(device(task, shots = shots))
                    @test length(res.result_types) == 1
                    @test isapprox(
                        res[Probability()],
                        [0.1, 0.0, 0, 0.9],
                        rtol = tol["rtol"],
                        atol = tol["atol"],
                    )
                end
            end
        end
    end
end
