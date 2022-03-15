using PyBraket, Braket, Test

@testset "LocalJobs" begin
    sm = joinpath(@__DIR__, "algo_script", "algo_script.py")
    job = LocalJob("local:braket/braket.local.qubit", source_module=sm)
    @test arn(job) isa String
    @test name(job) isa String
    @test state(job) == "COMPLETED" 
end
