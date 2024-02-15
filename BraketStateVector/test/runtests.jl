using Test

@testset "BraketStateVector" begin
    for test in (
        "dm_simulator",
        "sv_simulator",
        "utils",
        "result_types",
        "braket_integration",
    )
        @testset "$test" begin
            include(test * ".jl")
        end
    end
end
