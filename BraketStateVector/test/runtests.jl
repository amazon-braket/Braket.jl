using Test

@testset "BraketStateVector" begin
    for test in (
                 "sv_simulator",
                 "dm_simulator",
                 "utils",
                 "result_types",
                 "braket_integration",
                 )
        @testset "$test" begin
            include(test * ".jl")
        end
    end
end
