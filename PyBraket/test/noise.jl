using Test, PyBraket, Braket, Braket.IR, PythonCall
using PythonCall: Py, pyconvert

@testset "Noise" begin
    circ  = CNot(H(Circuit(), 0), 0, 1)
    noise = BitFlip(0.1)
    circ  = Braket.apply_gate_noise!(circ, noise)

    device = PyBraket.LocalSimulator("braket_dm")
    # run the circuit on the local simulator
    task = run(device, circ, shots=1000)

    t_result = result(task)
    measurement = t_result.measurement_counts
    @test haskey(measurement, "10")
    @test haskey(measurement, "01")

    noise = TwoQubitDephasing(0.1)
    circ = Z(X(CNot(Y(X(Circuit(), 0), 1), 0, 1), 1), 0)
    circ = Braket.apply_initialization_noise!(circ, noise)
    @test circ.instructions[1] == Braket.Instruction(TwoQubitDephasing(0.1), [0, 1])
    circ = Braket.apply_readout_noise!(circ, PhaseFlip(0.2))
    @test circ.instructions[end-1] == Braket.Instruction(PhaseFlip(0.2), 0)
    @test circ.instructions[end] == Braket.Instruction(PhaseFlip(0.2), 1)

    orig_len = length(circ.moments)
    ts = Braket.time_slices(circ.moments)
    @test length(circ.moments) == orig_len
    @test length(ts) == orig_len
    @testset "Conversions to/from Python" begin
        Braket.IRType[] = :JAQCD
        @testset for (noise, ir_noise) in ( (BitFlip, IR.BitFlip),
                                            (PhaseFlip, IR.PhaseFlip),
                                            (AmplitudeDamping, IR.AmplitudeDamping), 
                                            (PhaseDamping, IR.PhaseDamping),
                                            (Depolarizing, IR.Depolarizing))
            n = noise(0.1)
            ir_n = Braket.ir(n, 0)
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0]) == Py(ir_n))
            @test pyconvert(ir_noise, Py(ir_n)) == ir_n
        end
        @testset "(noise, ir_noise) = (PauliChannel, IR.PauliChannel)" begin
            n = PauliChannel(0.1, 0.2, 0.1)
            ir_n = Braket.ir(n, 0)
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0]) == Py(ir_n))
            @test pyconvert(IR.PauliChannel, Py(ir_n)) == ir_n
        end
        @testset "(noise, ir_noise) = (MultiQubitPauliChannel{1}, IR.MultiQubitPauliChannel)" begin
            n = MultiQubitPauliChannel{1}(Dict("X"=>0.1, "Y"=>0.2))
            ir_n = Braket.ir(n, 0)
            @test pyconvert(IR.MultiQubitPauliChannel, Py(ir_n)) == ir_n
        end
        @testset "(noise, ir_noise) = (TwoQubitPauliChannel, IR.MultiQubitPauliChannel)" begin
            n = TwoQubitPauliChannel(Dict("XX"=>0.1, "YY"=>0.2))
            ir_n = Braket.ir(n, [0, 1])
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0, 1]) == Py(ir_n))
            @test pyconvert(IR.MultiQubitPauliChannel, Py(ir_n)) == ir_n
        end
        @testset for (noise, ir_noise) in ((TwoQubitDephasing, IR.TwoQubitDephasing),
                                           (TwoQubitDepolarizing, IR.TwoQubitDepolarizing))
            n = noise(0.4)
            ir_n = Braket.ir(n, [0, 1])
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0, 1]) == Py(ir_n))
            @test pyconvert(ir_noise, Py(ir_n)) == ir_n
        end
        @testset "(noise, ir_noise) = (GeneralizedAmplitudeDamping, IR.GeneralizedAmplitudeDamping)" begin
            n = GeneralizedAmplitudeDamping(0.1, 0.2)
            ir_n = Braket.ir(n, 0)
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0]) == Py(ir_n))
            @test pyconvert(IR.GeneralizedAmplitudeDamping, Py(ir_n)) == ir_n
        end
        @testset "(noise, ir_noise) = (Kraus, IR.Kraus)" begin
            mat = complex([0. 1.; 1. 0.])
            n = Kraus([mat])
            ir_n = Braket.ir(n, 0)
            py_n = Py(n)
            @test pyconvert(Bool, py_n.to_ir([0]) == Py(ir_n))
            @test pyconvert(IR.Kraus, Py(ir_n)) == ir_n
        end 
        Braket.IRType[] = :OpenQASM
    end
end
