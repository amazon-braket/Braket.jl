using Braket, Dates, Test

@testset "Cost tracking" begin
    @testset "QPU tracking" begin
        problem = Problem(ProblemType("QUBO"), Dict(35=>1), Dict((35, 36)=> -1))
        device = AwsDevice("arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6")
        r = result(run(device, problem, shots=50))
        other_device = AwsDevice("arn:aws:braket:us-west-2::device/qpu/d-wave/Advantage_system6")

        Braket.Tracker() do t
            r_ = result(run(device, problem, shots=100))
            or = result(run(other_device, problem, shots=400))
            t_partial_cost = qpu_tasks_cost(t)
            @test t_partial_cost > 0
            Braket.Tracker() do s
                task = run(device, problem, shots=200)
                @test quantum_task_statistics(s) == Dict("arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6"=>Dict("shots"=>200, "tasks"=>Dict("CREATED"=> 1)))
                result(task)
            end
        end

        @test simulator_tasks_cost(s) == 0
        @test simulator_tasks_cost(t) == 0

        @test quantum_tasks_statistics(s) == Dict("arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6"=>Dict("shots"=>200, "tasks"=>Dict("COMPLETED"=>1)))
        @test quantum_tasks_statistics(t) == Dict(
            "arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6"=>Dict("shots"=>300, "tasks"=>Dict("COMPLETED"=>2)),
            "arn:aws:braket:us-west-2::device/qpu/d-wave/Advantage_system6"=>Dict("shots"=>400, "tasks"=>Dict("COMPLETED"=>1))
            )

        @test qpu_tasks_cost(s) > 0
        @test qpu_tasks_cost(t) > qpu_tasks_cost(s)
        @test qpu_tasks_cost(t) > t_partial_cost

        circuit = Circuit([(H, 0)])
        Braket.Tracker() do t
            run(AwsDevice("arn:aws:braket:::device/qpu/ionq/ionQdevice"), circuit, shots=10)
            run(AwsDevice("arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy"), circuit, shots=10)
            run(AwsDevice("arn:aws:braket:us-west-1::device/qpu/rigetti/Aspen-M-2"), circuit, shots=10)
        end
        @test qpu_tasks_cost(t) > 0
    end
    @testset "Simulator tracking" begin
        circuit = Circuit([(H, 0), (CNot, 0, 1)])
        device = AwsDevice("arn:aws:braket:::device/quantum-simulator/amazon/sv1")

        Braket.Tracker() do t
            task0 = run(device, circuit, shots=100)
            task1 = run(device, circuit, shots=100)
            @test quantum_tasks_statistics(t) == Dict("arn:aws:braket:::device/quantum-simulator/amazon/sv1"=>Dict("shots"=>200, "tasks"=>Dict("CREATED"=>2)))
            result(task0)
            result(task1)

            cancel(run(device, circuit, shots=100))
        end

        quantum_stats = t.quantum_tasks_statistics()[device.arn]
        @test quantum_stats["shots"] == 300
        @test quantum_stats["tasks"] == Dict("COMPLETED"=>2, "CANCELLING"=>1)
        @test quantum_stats["execution_duration"] > Millisecond(0)
        @test quantum_stats["billed_execution_duration"] >= quantum_stats["execution_duration"]
        @test quantum_stats["billed_execution_duration"] >= 2 * Braket.MIN_SIMULATOR_DURATION

        @test qpu_tasks_cost(t) == 0
        @test simulator_tasks_cost(t) > 0
    end
    # TODO FIX ME
    #=@testset "All devices price search" begin
        devices = get_devices(statuses=["ONLINE", "OFFLINE"])

        tasks = Dict()
        for region in Braket.REGIONS
            withenv("AWS_DEFAULT_REGION" => region) do
                for device in devices
                    try
                        get_device(device.arn)

                        # If we are here, device can create tasks in region
                        details = Dict(
                            "shots"=>100,
                            "device"=>device.arn,
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

        t = Braket.Tracker()
        t._resources = tasks
        @test qpu_tasks_cost(t) + simulator_tasks_cost(t) > 0
    end=#
end