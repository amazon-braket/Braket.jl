using Dates, DecFP, Test, Braket
using Braket: TaskCreationEvent, TaskStatusEvent, TaskCompletionEvent, Tracker, quantum_task_statistics, receive!, simulator_tasks_cost, qpu_tasks_cost

CREATE_EVENTS = [
    TaskCreationEvent("task1:::region", 100, true, "qpu/foo"),
    TaskCreationEvent("task2:::region", 100, false, "qpu/foo"),
    TaskCreationEvent("job_sim_task:::region", 0, true, "simulator/bar"),
    TaskCreationEvent("notjob_sim_task:::region", 0, false, "simulator/bar"),
    TaskCreationEvent("task_fail:::region", 0, false, "simulator/tn1"),
    TaskCreationEvent("task_cancel:::region", 0, false, "simulator/baz"),
    TaskCreationEvent("2000qtask:::region", 100, false, "qpu/2000Qxyz"),
    TaskCreationEvent("adv_task:::region", 100, false, "qpu/Advantage_system123"),
    TaskCreationEvent("unfinished_sim_task:::region", 1000, false, "simulator/bar"),
    TaskCreationEvent("no_price:::region", 1000, false, "something_else")]

GET_EVENTS = [
    TaskStatusEvent("untracked_task:::region", "FOO"),
    TaskStatusEvent("task1:::region", "BAR"),
    TaskStatusEvent("task2:::region", "FAILED"),
]
COMPLETE_EVENTS = [
    TaskCompletionEvent("untracked_task:::region", "BAR", 999999),
    TaskCompletionEvent("task1:::region", "COMPLETED", nothing),
    TaskCompletionEvent("job_sim_task:::region", "COMPLETED", 123),
    TaskCompletionEvent("notjob_sim_task:::region", "COMPLETED", 1729),
    TaskCompletionEvent("task_fail:::region", "FAILED", 12345),
    TaskCompletionEvent("task_cancel:::region", "CANCELLED", nothing),
]

@testset "Cost tracker" begin
    tracker = Braket.Tracker()
    foreach(e->receive!(tracker, e), CREATE_EVENTS)
    foreach(e->receive!(tracker, e), GET_EVENTS)
    foreach(e->receive!(tracker, e), COMPLETE_EVENTS)

    @testset "quantum task statistics" begin
        stats = quantum_task_statistics(tracker)
        expected = Dict( 
            "qpu/foo"=>Dict("shots"=> 200, "tasks"=> Dict("COMPLETED"=> 1, "FAILED"=> 1)),
            "simulator/bar"=>Dict(
                "shots"=>1000,
                "tasks"=>Dict("COMPLETED"=> 2, "CREATED"=> 1),
                "execution_duration"=>(Second(1) + Microsecond(852000)),
                "billed_execution_duration"=> Second(6),
            ),
            "simulator/tn1"=> Dict(
                "shots"=> 0,
                "tasks"=> Dict("FAILED"=> 1),
                "execution_duration"=> (Second(12) + Microsecond(345000)),
                "billed_execution_duration"=> (Second(12) + Microsecond(345000)),
            ),
            "simulator/baz"=> Dict("shots"=> 0, "tasks"=> Dict("CANCELLED"=> 1)),
            "qpu/2000Qxyz"=> Dict("shots"=> 100, "tasks"=> Dict("CREATED"=> 1)),
            "qpu/Advantage_system123"=> Dict("shots"=> 100, "tasks"=> Dict("CREATED"=> 1)),
            "something_else"=> Dict("shots"=> 1000, "tasks"=> Dict("CREATED"=> 1)),
        )
        for (k, v) in expected
            @test v == stats[k]
        end
        @test stats == expected
    end
    @testset "simulator task cost" begin
        Braket.price_search(; kwargs...) = [Dict("Unit"=>"minutes", "PricePerUnit"=>"6.0", "Currency"=>"USD")]
        cost = simulator_tasks_cost(tracker)
        expected = Dec128("0.0001") * (3000 + 3000 + 12345)
        @test cost == expected
        Braket.price_search(; kwargs...) = []
        @test_throws ErrorException simulator_tasks_cost(tracker)
        Braket.price_search(; kwargs...) = [Dict("Unit"=>"minutes", "PricePerUnit"=>"6.0", "Currency"=>"BAD")]
        @test_throws ErrorException simulator_tasks_cost(tracker)
    end
    @testset "qpu task cost" begin
        function Braket.price_search(; kwargs...)
            haskey(kwargs, Symbol("Product Family")) && occursin("Shot", kwargs[Symbol("Product Family")]) && return [Dict("PricePerUnit"=>"0.001", "Currency"=>"USD")]
            return [Dict("PricePerUnit"=>"1.0", "Currency"=>"USD")]
        end
        @test qpu_tasks_cost(tracker) == Dec128("3.3")
        Braket.price_search(; kwargs...) = []
        @test_throws ErrorException qpu_tasks_cost(tracker)

        Braket.price_search(; kwargs...) = [[Dict()], [Dict(), Dict()]]
        @test_throws ErrorException qpu_tasks_cost(tracker)

        Braket.price_search(; kwargs...) = [Dict("Currency"=>"BAD")]
        @test_throws ErrorException qpu_tasks_cost(tracker)
    end
end
