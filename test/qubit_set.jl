using Braket, Test, JSON3

@testset "QubitSet and Qubit" begin
    @testset "ctors" begin
        @test Qubit(1) == Qubit(1.0)
        @test Qubit(BigFloat(1.0)) == Qubit(1.0)
        @test Qubit(Qubit(1)) == Qubit(1.0)
    end
    @testset "equality" begin
        @test Qubit(1) == Int8(1)
        @test BigInt(10) == Qubit(10)
        @test Qubit(10) == BigInt(10)
    end
    @testset "Convert to Int" begin
        @test Int(Qubit(1)) == 1
    end
    @testset "show" begin
        s = sprint(show, Qubit(1))
        @test s == "Qubit(1)"
    end
    @testset "QubitSet indexing" begin
        qs = QubitSet(0, 1, 2)
        @test length(qs) == 3
        @test lastindex(qs) == 3
        @test 3 ∉ qs
        @test !isempty(qs)
        o = popfirst!(qs)
        @test o == 0
        @test length(qs) == 2
    end
end
