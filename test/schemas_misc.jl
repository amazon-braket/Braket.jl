using Braket, Braket.IR, Test, JSON3, StructTypes

@testset "Schemas" begin
    @testset "NativeQuilMetadata" begin
        nqm = Braket.NativeQuilMetadata([32, 21], 5, 6, 1, 300.1, 0.8989, 191.21, 0)
        read_result = JSON3.read(JSON3.write(nqm), Braket.NativeQuilMetadata)
        for fn in fieldnames(Braket.NativeQuilMetadata)
            @test getproperty(read_result, fn) == getproperty(nqm, fn)
        end
    end

    @testset "Braket Schema Base headers" begin
        @testset for T in values(StructTypes.subtypes(Braket.BraketSchemaBase))
            @test StructTypes.defaults(T)[:braketSchemaHeader] == Braket.header_dict[T]
        end
    end

    @testset "AbstractProgram bad construction" begin
        @test_throws ErrorException StructTypes.constructfrom(Braket.AbstractProgram, Dict(:braketSchemaHeader=>Dict(:name=>"not_a_program")))
    end

    @testset "Reading and writing JAQCD instructions" begin
        for T in (IR.I, IR.X, IR.Y, IR.Z, IR.H, IR.S, IR.Si, IR.V, IR.Vi, IR.T, IR.Ti)
            targ = 0
            raw_str = """{"target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.Rx, IR.Ry, IR.Rz, IR.PhaseShift)
            targ = 0
            angle = rand()
            raw_str = """{"target": $targ, "angle": $angle}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.angle == angle
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.CNot, IR.CY, IR.CZ, IR.CV)
            targ = 0
            ctrl = 1
            raw_str = """{"control": $ctrl, "target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.control == ctrl
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.CPhaseShift, IR.CPhaseShift00, IR.CPhaseShift10, IR.CPhaseShift01)
            targ = 0
            ctrl = 1
            angle = rand()
            raw_str = """{"control": $ctrl, "target": $targ, "angle": $angle}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.control == ctrl
            @test read_T.angle == angle
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.Swap, IR.ISwap, IR.ECR)
            targs = [0, 1]
            raw_str = """{"targets": $targs}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.XX, IR.XY, IR.YY, IR.ZZ, IR.PSwap)
            targs = [0, 1]
            angle = rand()
            raw_str = """{"targets": $targs, "angle": $angle}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test read_T.angle == angle
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.CSwap,)
            targs = [0, 1]
            ctrl = 2
            raw_str = """{"targets": $targs, "control": $ctrl}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test read_T.control == ctrl
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.CCNot,)
            ctrls = [0, 1]
            targ = 2
            raw_str = """{"target": $targ, "controls": $ctrls}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.controls == ctrls
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.Expectation, IR.Sample, IR.Variance)
            targs = [0, 1]
            obs = ["h"]
            raw_str = """{"targets": $targs, "observable": $obs}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test read_T.observable == obs
            @test Braket.IR.Target(T) == Braket.IR.OptionalMultiTarget()
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.Probability, IR.DensityMatrix)
            targs = [0, 1]
            raw_str = """{"targets": $targs}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test Braket.IR.Target(T) == Braket.IR.OptionalMultiTarget()
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.StateVector,)
            raw_str = """{}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.GeneralizedAmplitudeDamping,)
            prob  = rand()
            gamma = rand()
            targ  = 0
            raw_str = """{"probability": $prob, "gamma": $gamma, "target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.probability == prob
            @test read_T.gamma == gamma
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.PhaseDamping, IR.AmplitudeDamping)
            gamma = rand()
            targ  = 0
            raw_str = """{"gamma": $gamma, "target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.gamma == gamma
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.BitFlip, IR.PhaseFlip, IR.Depolarizing)
            prob  = rand()
            targ  = 0
            raw_str = """{"probability": $prob, "target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.probability == prob
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.TwoQubitDepolarizing, IR.TwoQubitDephasing)
            prob  = rand()
            targs = [0, 1]
            raw_str = """{"probability": $prob, "targets": $targs}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test read_T.probability == prob
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.PauliChannel,)
            probx = rand()
            proby = rand()
            probz = rand()
            targ  = 0
            raw_str = """{"probX": $probx, "probY": $proby, "probZ": $probz, "target": $targ}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.target == targ
            @test read_T.probX == probx
            @test read_T.probY == proby
            @test read_T.probZ == probz
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.MultiQubitPauliChannel,)
            targs = [0, 1]
            probs = Dict("XX"=>rand(), "YY"=>rand())
            raw_str = """{"probabilities": $(JSON3.write(probs)), "targets": $targs}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == targs
            @test read_T.probabilities == probs
            @test JSON3.read(JSON3.write(read_T), Braket.IR.AbstractIR) == read_T
        end
        for T in (IR.Kraus, IR.Unitary)
            mat = complex([0. 1.; 1. 0.])
            targ = 0
            vec = Braket.complex_matrix_to_ir(mat)
            raw_str = T == IR.Kraus ? """{"matrices": [$(JSON3.write(vec))], "targets": [$targ]}""" : """{"matrix": $(JSON3.write(vec)), "targets": [$targ]}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test read_T.targets == [targ]
            @test vec == ((read_T.type == "kraus") ? read_T.matrices[1] : read_T.matrix)
        end
        for T in (IR.StartVerbatimBox, IR.EndVerbatimBox)
            raw_str = """{}"""
            read_T = JSON3.read(raw_str, T)
            @test read_T isa T
            @test JSON3.read(JSON3.write(read_T), Braket.IR.CompilerDirective) == read_T
        end
    end

    @testset "Device metadata" begin
        @testset for T in (Braket.OqcMetadata, Braket.XanaduMetadata, Braket.RigettiMetadata)
            raw = """{"compiledProgram": "fake_program"}"""
            read_in = JSON3.read(raw, T)
            @test read_in isa T
            @test read_in.compiledProgram == "fake_program"
        end
        @testset "T = Braket.SimulatorMetadata" begin
            duration = 100
            T = Braket.SimulatorMetadata
            raw = """{"executionDuration": $duration}"""
            read_in = JSON3.read(raw, T)
            @test read_in isa T
            @test read_in.executionDuration == duration
        end
    end

    @testset "OpenQASMDeviceActionProperties" begin
        input = """{
            "actionType": "braket.ir.openqasm.program",
            "version": ["1"],
            "supportedOperations": ["x", "y"],
            "supportedResultTypes": [
                {"name": "resultType1", "observables": ["observable1"], "minShots": 2, "maxShots": 4}
            ],
            "supportPhysicalQubits": true,
            "supportedPragmas": ["braket_bit_flip_noise"],
            "forbiddenPragmas": ["braket_kraus_operator"],
            "forbiddenArrayOperations": ["concatenation", "range", "slicing"],
            "requiresAllQubitsMeasurement": false,
            "requiresContiguousQubitIndices": false,
            "supportsPartialVerbatimBox": true
        }"""
        read_in = JSON3.read(input, Braket.DeviceActionProperties)
        @test read_in isa Braket.OpenQASMDeviceActionProperties
    end

    @testset "Reading BraketSchemaBase" begin
        t = Braket.GateModelParameters(Braket.header_dict[Braket.GateModelParameters], 10, false)
        str = JSON3.write(t)
        read_in = JSON3.read(str, Braket.BraketSchemaBase)
        @test read_in isa Braket.GateModelParameters
    end
end
