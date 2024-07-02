using AWS, Braket, Test

SHOTS = 8000

IONQ_ARN = "arn:aws:braket:us-east-1::device/qpu/ionq/Harmony"
SIMULATOR_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
OQC_ARN = "arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy"
IQM_ARN = "arn:aws:braket:eu-north-1::device/qpu/iqm/Garnet"

@testset "Measure operator" begin
    @testset "Unsupported devices" begin
        @testset "Arn $arn" for arn in (IONQ_ARN, SIMULATOR_ARN)
            device = AwsDevice(arn)
            status(device) == "OFFLINE" && continue
            circ = Circuit([(H, 0), (CNot, 0, 1), (H, 2), (Measure, 0, 1)])
            # TODO check error message
            @test_throws AWS.AWSExceptions.AWSException device(circ, shots=1000)
        end
    end
    @testset "Supported devices" begin
        @testset "Arn $arn" for arn in (OQC_ARN, IQM_ARN)
            device = AwsDevice(arn)
            status(device) == "OFFLINE" && continue
            circ = Circuit([(H, 0), (CNot, 0, 1), (Measure, 0)])
            res  = result(device(circ, shots=SHOTS))
            @test all(m->length(m) == 1, res.measurements)
            @test res.measured_qubits == [0]
        end
    end
end
