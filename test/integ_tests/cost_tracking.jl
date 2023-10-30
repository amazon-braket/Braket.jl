using Braket, Braket.AWS, Dates, Test
using AWS: @service, AWSConfig, global_aws_config
@service BRAKET use_response_type=true

@testset "Cost tracking" begin
    @testset "QPU tracking" begin
        circuit = Circuit([(H, 0)])
        t = Braket.Tracker()
        n_available = 0
        for arn = ("arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy", "arn:aws:braket:us-west-1::device/qpu/rigetti/Aspen-M-3", "arn:aws:braket:us-east-1::device/qpu/ionq/Harmony")
            d = AwsDevice(arn)
            if Braket.isavailable(d)
                d(circuit, shots=10)
                n_available += 1
            end
        end
        if n_available > 0
            @test qpu_tasks_cost(t) > 0.0
        else
            @test qpu_tasks_cost(t) == 0.0
        end
    end
    @testset "Simulator tracking" begin
        circuit = Circuit([(H, 0), (CNot, 0, 1)])
        device = AwsDevice("arn:aws:braket:::device/quantum-simulator/amazon/sv1")

        let t = Braket.Tracker()
            task0 = device(circuit, shots=100)
            task1 = device(circuit, shots=100)
            @test Braket.quantum_task_statistics(t) == Dict("arn:aws:braket:::device/quantum-simulator/amazon/sv1"=>Dict("shots"=>200, "tasks"=>Dict("CREATED"=>2)))
            result(task0)
            result(task1)

            task = device(circuit, shots=100)
            cancel(task)
            quantum_stats = Braket.quantum_task_statistics(t)[arn(device)]
            @test quantum_stats["shots"] == 300
            @test quantum_stats["tasks"] == Dict("COMPLETED"=>2, "CANCELLING"=>1)
            @test quantum_stats["execution_duration"] > Millisecond(0)
            @test quantum_stats["billed_execution_duration"] >= quantum_stats["execution_duration"]
            @test quantum_stats["billed_execution_duration"] >= 2 * Braket.MIN_SIMULATOR_DURATION

            @test qpu_tasks_cost(t) == 0
            @test simulator_tasks_cost(t) > 0
        end
    end
    @testset "All devices price search" begin
        devices = get_devices(statuses=["ONLINE", "OFFLINE"])
        tasks = Dict{String, Any}()
        for region in Braket.REGIONS
            withenv("AWS_DEFAULT_REGION" => region) do
                for device in devices
                    try
                        config = Braket.AWS.global_aws_config()
                        region_config = Braket.AWS.AWSConfig(config.credentials, region, config.output)
                        d = BRAKET.get_device(Braket.HTTP.escapeuri(arn(device)), aws_config=region_config)
                        # If we are here, device can create tasks in region
                        details = Dict{String, Any}(
                            "shots"=>100,
                            "device"=>arn(device),
                            "billed_duration"=>Braket.MIN_SIMULATOR_DURATION,
                            "job_task"=>false,
                            "status"=>"COMPLETED",
                        )
                        tasks["task:for:$(name(device)):$region"] = copy(details)
                        details["job_task"] = true
                        tasks["jobtask:for:$(name(device)):$region"] = details
                    catch
                        # device does not exist in region, so nothing to test
                        continue
                    end
                end
            end
        end
        t = Braket.Tracker()
        t._resources = tasks
        @test qpu_tasks_cost(t) + simulator_tasks_cost(t) > 0
    end
end
