using Braket, Braket.Dates, Test
using Braket: Instruction, VIRTUAL, PHYSICAL, OpenQASMSerializationProperties 

@testset "Barrier, reset, and delay operators" begin
    @test Barrier() isa Braket.QuantumOperator
    @test Reset()   isa Braket.QuantumOperator
    @test Braket.Parametrizable(Reset()) == Braket.NonParametrized()
    @test Braket.Parametrizable(Barrier()) == Braket.NonParametrized()
    @test Braket.Parametrizable(Delay(Microsecond(200))) == Braket.NonParametrized()
    @test qubit_count(Reset()) == 1
    @test qubit_count(Barrier()) == 1
    @test qubit_count(Delay(Microsecond(200))) == 1
    @test Delay(Microsecond(200)) isa Braket.QuantumOperator
    @testset "Equality" for t in (Barrier, Reset) 
        t1 = t()
        t2 = t()
        non_t = Measure()
        @test t1 == t2
        @test t1 != non_t
    end
    @test Delay(Nanosecond(10))     != Delay(Microsecond(10))
    @test Delay(Nanosecond(10_000)) == Delay(Microsecond(10))
    @test Braket.chars(Barrier()) == ("Barrier",)
    @test Braket.chars(Reset())   == ("Reset",)
    @test Braket.chars(Delay(Nanosecond(4))) == ("Delay(4ns)",)
    @test Braket.chars(Delay(Microsecond(4))) == ("Delay(4ms)",)
    @testset "To IR" for (t, str) in ((Barrier(), "barrier"),
                                      (Reset(), "reset"),
                                      (Delay(Second(1)), "delay[1s]"),
                                     )
        @testset "Invalid ir_type $ir_type" for (ir_type, message) in ((:JAQCD, "$str instructions are not supported with JAQCD."),
                                                                      )
            @test_throws ErrorException(message) ir(t, QubitSet([0]), Val(ir_type))
        end
        @testset "OpenQASM, target $target, serialization properties $sps" for (target, sps, expected_ir) in (
                                                                                                              ([0], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "$str q[0];"),
                                                                                                              ([4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "$str \$4;"),
                                                                                                         )

                    
            @test ir(Instruction(t, target), Val(:OpenQASM); serialization_properties=sps) == expected_ir
        end
    end
end
