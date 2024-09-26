using Braket, Test

RIGETTI_ARN = "arn:aws:braket:::device/qpu/rigetti/Ankaa-2"
IONQ_ARN = "arn:aws:braket:us-east-1::device/qpu/ionq/Aria-1"
SIMULATOR_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
IQM_ARN = "arn:aws:braket:eu-north-1::device/qpu/iqm/Garnet"

@testset "Device Creation" begin
    @testset for dev_arn in (RIGETTI_ARN, IONQ_ARN, IQM_ARN, SIMULATOR_ARN)
        device = AwsDevice(dev_arn)
        @test arn(device) == dev_arn
        @test !isnothing(name(device)) && !isempty(name(device))
        @test !isnothing(provider_name(device)) && !isempty(provider_name(device))
        @test !isnothing(status(device)) && !isnothing(status(device))
        @test !isnothing(type(device)) && !isnothing(type(device))
        @test !isnothing(properties(device))
    end
    @testset "get_devices" begin
        @testset for dev_arn in [RIGETTI_ARN, IONQ_ARN, IQM_ARN, SIMULATOR_ARN]
            results = get_devices(arns=[dev_arn])
            @test arn(first(results)) == dev_arn
        end
        @testset "others" begin
            provider_names = ["Amazon Braket"]
            types = ["SIMULATOR"]
            statuses = ["ONLINE"]
            results = get_devices(types=types, statuses=statuses)
            @test !isempty(results)
            for result in results
                @test provider_name(result) ∈ provider_names
                @test type(result) ∈ types
                @test status(result) ∈ statuses
            end
        end
        @testset "all" begin
            result_arns = arn.(get_devices())
            for dev_arn in [RIGETTI_ARN, IONQ_ARN, SIMULATOR_ARN, IQM_ARN]
                @test dev_arn ∈ result_arns
            end
        end
    end
end
