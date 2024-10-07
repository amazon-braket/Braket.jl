using Braket, Test
using Braket: Instruction, VIRTUAL, PHYSICAL, OpenQASMSerializationProperties 

@testset "Measure operator" begin
    @test Measure() isa Braket.QuantumOperator
    @test Braket.Parametrizable(Measure()) == Braket.NonParametrized()
    @test qubit_count(Measure()) == 1
    @testset "Equality" begin
        measure1 = Measure()
        measure2 = Measure()
        non_measure = "non measure"
        @test measure1 == measure2
        @test measure1 != non_measure
    end
    @test Braket.chars(Measure()) == ("M",)
    circ = Circuit([(H, 0), (CNot, 0, 1)])
    circ = measure(circ, 0)
    @test circ.instructions == [Instruction{H}(H(), QubitSet(0)), Instruction{CNot}(CNot(), QubitSet(0, 1)), Instruction{Measure}(Measure(0), QubitSet(0))]

    @testset "To IR" begin
        @testset "Invalid ir_type $ir_type" for (ir_type, message) in ((:JAQCD, "measure instructions are not supported with JAQCD."),
                                                                      )
            @test_throws ErrorException(message) ir(Measure(), QubitSet([0]), Val(ir_type))
        end
        @testset "OpenQASM, target $target, serialization properties $sps" for (target, sps, expected_ir) in (
                                                                                                              ([0], OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), "b[0] = measure q[0];"),
                                                                                                              ([4], OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), "b[0] = measure \$4;"),
                                                                                                         )

                    
            @test ir(Instruction(Measure(), target), Val(:OpenQASM); serialization_properties=sps) == expected_ir
        end
    end
end
