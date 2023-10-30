using Braket, Test

@testset "Queue Information" begin
    @testset "Task Queue Position" begin
        device = AwsDevice(Braket.SV1())
        bell = Circuit([(H, 0), (CNot, 0, 1)])
        task = device(bell, shots=10)

        # call the queue_position method.
        queue_information = queue_position(task)

        # data type validations
        @test queue_information isa Braket.QuantumTaskQueueInfo
        @test queue_information.queue_type isa QueueType
        @test queue_information.queue_position isa String

        # test queue priority
        @test queue_information.queue_type ∈ (Normal, Priority)

        # test message
        if isempty(queue_information.queue_position)
            @test !isempty(queue_information.message)
            @test queue_information.message isa String
        else
            @test isempty(queue_information.message)
        end
    end

    @testset "Job queue position" begin
        job = AwsQuantumJob(
            Braket.SV1(),
            joinpath(@__DIR__, "job_test_script.py"),
            entry_point="job_test_script:start_here",
            wait_until_complete=true,
            hyperparameters=Dict("test_case"=>"completed"),
        )

        # call the queue_position method.
        queue_information = queue_position(job)

        # data type validations
        @test queue_information isa Braket.HybridJobQueueInfo

        # test message
        @test isempty(queue_information.queue_position)
        @test queue_information.message isa String
    end

    @testset "Queue Depth" begin
        device = AwsDevice(Braket.SV1())

        # call the queue_depth method.
        queue_information = queue_depth(device)

        # data type validations
        @test queue_information isa QueueDepthInfo
        @test queue_information.quantum_tasks isa Dict{QueueType, String}
        @test queue_information.jobs isa String

        for (k,v) in queue_information.quantum_tasks
            @test k isa QueueType
            @test v isa String
        end
    end
end
