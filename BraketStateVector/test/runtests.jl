using Test

@testset "BraketStateVector" begin
    for test in (
        "dm_simulator",
        "sv_simulator",
        "utils",
        "result_types",
        "braket_integration",
        #"small_test",
    )
        @testset "$test" begin
            include(test * ".jl")
        end
    end
end
