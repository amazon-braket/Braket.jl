using Test, Braket, JSON3, LinearAlgebra
using Braket: Instruction, VIRTUAL, PHYSICAL, OpenQASMSerializationProperties

struct CustomNoise <: Braket.Noise end

@testset "Noises" begin
    @testset for noise in (BitFlip, PhaseFlip, AmplitudeDamping, PhaseDamping, Depolarizing)
        n = noise(0.1)
        @test qubit_count(n) == 1
        ix = Instruction(n, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset "noise = PauliChannel" begin
        n = PauliChannel(0.1, 0.2, 0.1)
        @test qubit_count(n) == 1
        ix = Instruction(n, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset "noise = MultiQubitPauliChannel{1}" begin
        n = MultiQubitPauliChannel{1}(Dict("X"=>0.1, "Y"=>0.2))
        @test qubit_count(n) == 1
        ix = Instruction(n, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset "noise = TwoQubitPauliChannel" begin
        n = TwoQubitPauliChannel(Dict("XX"=>0.1, "YY"=>0.2))
        @test qubit_count(n) == 2
        ix = Instruction(n, [0, 1])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset for noise in (TwoQubitDephasing, TwoQubitDepolarizing)
        n = noise(0.4)
        @test qubit_count(n) == 2
        ix = Instruction(n, [0, 1])
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset "noise = GeneralizedAmplitudeDamping" begin
        n = GeneralizedAmplitudeDamping(0.1, 0.2)
        @test qubit_count(n) == 1
        ix = Instruction(n, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.Parametrized()
    end
    @testset "noise = Kraus" begin
        mat = complex([0 1; 1 0])
        n = Kraus([mat])
        @test qubit_count(n) == 1
        ix = Instruction(n, 0)
        @test JSON3.read(JSON3.write(ix), Instruction) == ix
        @test Braket.Parametrizable(n) == Braket.NonParametrized()
    end
    @testset "fallback" begin
        n = CustomNoise()
        @test Braket.bind_value!(n, Dict(:theta=>0.1)) === n
        @test Braket.parameters(n) == Braket.FreeParameter[]
        @test Braket.Parametrizable(n) == Braket.NonParametrized()
    end
    @test Braket.StructTypes.StructType(Noise) == Braket.StructTypes.AbstractType()
    @testset "OpenQASM" begin
        kraus_1 = [diagm(fill(√0.9, 4)), √0.1 * kron(diagm(ones(Float64, 2)), [0.0 1.0; 1.0 0.0])]
        kraus_2 = [[0.9486833im 0.0; 0.0 0.9486833im], [0.0 0.31622777; 0.31622777 0.0]]
        @testset for ir_bolus in [
            (BitFlip(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise bit_flip(0.5) q[3]",),
            (BitFlip(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise bit_flip(0.5) \$3",),
            (PhaseFlip(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise phase_flip(0.5) q[3]",),
            (PhaseFlip(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise phase_flip(0.5) \$3",),
            (PauliChannel(0.1, 0.2, 0.3), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise pauli_channel(0.1, 0.2, 0.3) q[3]",),
            (PauliChannel(0.1, 0.2, 0.3), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise pauli_channel(0.1, 0.2, 0.3) \$3",),
            (Depolarizing(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise depolarizing(0.5) q[3]",),
            (Depolarizing(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise depolarizing(0.5) \$3",),
            (TwoQubitDepolarizing(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 5], "#pragma braket noise two_qubit_depolarizing(0.5) q[3], q[5]",),
            (TwoQubitDepolarizing(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 5], "#pragma braket noise two_qubit_depolarizing(0.5) \$3, \$5",),
            (TwoQubitDephasing(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 5], "#pragma braket noise two_qubit_dephasing(0.5) q[3], q[5]",),
            (TwoQubitDephasing(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 5], "#pragma braket noise two_qubit_dephasing(0.5) \$3, \$5",),
            (AmplitudeDamping(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise amplitude_damping(0.5) q[3]",),
            (AmplitudeDamping(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise amplitude_damping(0.5) \$3",),
            (GeneralizedAmplitudeDamping(0.5, 0.1), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise generalized_amplitude_damping(0.5, 0.1) q[3]",),
            (GeneralizedAmplitudeDamping(0.5, 0.1), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise generalized_amplitude_damping(0.5, 0.1) \$3",),
            (PhaseDamping(0.5), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3], "#pragma braket noise phase_damping(0.5) q[3]",),
            (PhaseDamping(0.5), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3], "#pragma braket noise phase_damping(0.5) \$3",),
            (Kraus(kraus_1), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3, 5],
                "#pragma braket noise kraus([" *
                "[0.9486832980505138, 0, 0, 0], " *
                "[0, 0.9486832980505138, 0, 0], " *
                "[0, 0, 0.9486832980505138, 0], " *
                "[0, 0, 0, 0.9486832980505138]], [" *
                "[0, 0.31622776601683794, 0, 0], " *
                "[0.31622776601683794, 0, 0, 0], " *
                "[0, 0, 0, 0.31622776601683794], " *
                "[0, 0, 0.31622776601683794, 0]]) q[3], q[5]",
            ),
            (Kraus(kraus_1), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3, 5],
                "#pragma braket noise kraus([" *
                "[0.9486832980505138, 0, 0, 0], " *
                "[0, 0.9486832980505138, 0, 0], " *
                "[0, 0, 0.9486832980505138, 0], " *
                "[0, 0, 0, 0.9486832980505138]], [" *
                "[0, 0.31622776601683794, 0, 0], " *
                "[0.31622776601683794, 0, 0, 0], " *
                "[0, 0, 0, 0.31622776601683794], " *
                "[0, 0, 0.31622776601683794, 0]]) \$3, \$5",
            ),
            (Kraus(kraus_2), OpenQASMSerializationProperties(qubit_reference_type=VIRTUAL), [3],
                "#pragma braket noise kraus([" *
                "[0.9486833im, 0], [0, 0.9486833im]], [" *
                "[0, 0.31622777], [0.31622777, 0]]) q[3]",
            ),
            (Kraus(kraus_2), OpenQASMSerializationProperties(qubit_reference_type=PHYSICAL), [3],
                "#pragma braket noise kraus([" *
                "[0.9486833im, 0], [0, 0.9486833im]], [" *
                "[0, 0.31622777], [0.31622777, 0]]) \$3",
            ),
        ]
            n, sps, targets, expected_ir = ir_bolus
            @test ir(n, targets, Val(:OpenQASM); serialization_properties=sps) == expected_ir
        end
    end
end
