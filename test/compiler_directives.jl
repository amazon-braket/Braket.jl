using Braket, Test, JSON3
using Braket: Instruction, OpenQASMSerializationProperties

@testset "Compiler directives basics" begin
    @test Braket.counterpart(Braket.StartVerbatimBox()) == Braket.EndVerbatimBox()
    @test Braket.counterpart(Braket.EndVerbatimBox())   == Braket.StartVerbatimBox()
    @testset for (cd, expected_ir) in ((Braket.StartVerbatimBox(), "#pragma braket verbatim\nbox{",), (Braket.EndVerbatimBox(), "}"))
        ix = Instruction(cd, Int[])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test ir(cd, Val(:OpenQASM), serialization_properties=OpenQASMSerializationProperties()) == expected_ir
        @test ir(cd) == expected_ir
    end
end
