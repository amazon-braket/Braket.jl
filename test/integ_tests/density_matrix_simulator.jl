using Braket, Braket.Observables, Test

function _mixed_states(n_qubits::Int)::Circuit
    noise = PhaseFlip(0.2)
    circ = Circuit()
    for qubit in 0:3:(n_qubits - 2)
        circ([(X, qubit), (Y, qubit + 1), (CNot, qubit, qubit + 2), (X, qubit + 1), (Z, qubit + 2)])
        apply_gate_noise!(circ, noise, [qubit, qubit + 2])
    end

    # attach the result types
    circ(Probability)
    circ(Expectation, Observables.Z(), 0)
    return circ
end

@testset "Density Matrix Simulator" begin
    SHOTS = 1000
    DM1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/dm1"
    num_qubits = 10
    for simulator_arn in (DM1_ARN,)
        circuit = _mixed_states(num_qubits)
        device = AwsDevice(simulator_arn)

        tol = get_tol(SHOTS)
        t = AwsQuantumTask(arn(device), circuit, shots=SHOTS, s3_destination_folder=s3_destination_folder)
        res = result(t)
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