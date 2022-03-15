using Braket, JSON3, Test, StructTypes
using Braket: operator, target

@testset "IR Translation" begin
    @testset "Schema header translation" begin
        json_str = """{"name": "braket.ir.jaqcd.program", "version": "1"}"""
        @test JSON3.read(json_str, Braket.braketSchemaHeader) == Braket.braketSchemaHeader("braket.ir.jaqcd.program", "1")
        fi = open(joinpath(@__DIR__, "header.json"), "r")
        @test JSON3.read(fi, Braket.braketSchemaHeader) == Braket.braketSchemaHeader("braket.ir.jaqcd.program", "1")
    end

    @testset "Instruction translation" begin
        inst = Braket.Instruction(H(), 1)
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == H()
        inst = Braket.Instruction(H(), Qubit(1))
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == H()
        @test inst.target == QubitSet(Qubit(1))
        inst = Braket.Instruction(CNot(), [1, 2])
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == CNot()
        inst = Braket.Instruction(CNot(), Qubit.([1, 2]))
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == CNot()
        @test inst.target == QubitSet([Qubit(1), Qubit(2)])
        inst = Braket.Instruction(Rx(1.2), 1)
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == Rx(1.2)
        inst = Braket.Instruction(XX(1.2), [1, 2])
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == XX(1.2)
        inst = Braket.Instruction(CCNot(), [1, 2, 3])
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == CCNot()
        inst = Braket.Instruction(CCNot(), [3, 1, 4])
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == CCNot()
        inst = Braket.Instruction(CSwap(), [1, 2, 3])
        json_str = JSON3.write(inst)
        @test JSON3.read(json_str, Braket.Instruction) == inst
        @test operator(inst) == CSwap()
        json_str = """[{"target": 0, "type": "x"}, {"target": 0, "type": "z"}]"""
        @test JSON3.read(json_str, Vector{Braket.Instruction}) == [Braket.Instruction(X(), 0), Braket.Instruction(Z(), 0)]
    end

    @testset "Results translation" begin
        json_str = """[{"observable":["i"],"targets":[0],"type":"expectation"},{"observable":["z"],"targets":[0],"type":"expectation"}]"""
        parsed = JSON3.read(json_str, Vector{Braket.AbstractProgramResult})
        raw = Braket.AbstractProgramResult[Braket.IR.Expectation(["i"], [0], "expectation"), Braket.IR.Expectation(["z"], [0], "expectation")]
        for (e_r, e_p) in zip(raw, parsed)
            @test e_r == e_p
        end
        written_json = JSON3.write(raw)
        @test written_json == json_str
        json_str = "{\"observable\":[\"y\",\"z\",\"z\",\"z\",\"z\",\"z\",\"z\",\"z\",\"y\"],\"targets\":[0,1,2,3,4,5,6,7,8],\"type\":\"expectation\"}"
        parsed = JSON3.read(json_str, Braket.AbstractProgramResult)
        written_json = JSON3.write(parsed)
        @test written_json == json_str
    end

    @testset "Program translation" begin
        json_str = """{"braketSchemaHeader": {"name": "braket.ir.jaqcd.program", "version": "1"}, "instructions": [{"target": 0, "type": "x"}, {"target": 0, "type": "z"}], "results": [{"observable":["i"],"targets":[0],"type":"expectation"},{"observable":["z"],"targets":[0],"type":"expectation"}], "basis_rotation_instructions": []}"""
        parsed = Braket.parse_raw_schema(json_str)
        raw    = Braket.Program(Braket.braketSchemaHeader("braket.ir.jaqcd.program", "1"), [Braket.Instruction(X(), 0), Braket.Instruction(Z(), 0)], Braket.AbstractProgramResult[Braket.IR.Expectation(["i"], [0], "expectation"), Braket.IR.Expectation(["z"], [0], "expectation")], Braket.Instruction[])
        @test parsed.braketSchemaHeader == raw.braketSchemaHeader
        @test parsed.instructions       == raw.instructions
        @test parsed.results            == raw.results
        @test parsed.basis_rotation_instructions       == raw.basis_rotation_instructions
        @test Braket.parse_raw_schema(JSON3.write(raw)) == raw
        @test Braket.Program(Circuit(raw)) == raw
        @test ir(raw) == ir(Circuit(raw))

        noisy_json_str = """{"braketSchemaHeader": {"name": "braket.ir.jaqcd.program", "version": "1"}, "instructions": [{"target": 0, "type": "x"}, {"gamma": 0.1, "target": 0, "type": "amplitude_damping"}, {"target": 1, "type": "y"}, {"control": 0, "target": 2, "type": "cnot"}, {"gamma": 0.1, "target": 0, "type": "amplitude_damping"}, {"gamma": 0.1, "target": 2, "type": "amplitude_damping"}, {"target": 1, "type": "x"}, {"target": 2, "type": "z"}, {"gamma": 0.1, "target": 2, "type": "amplitude_damping"}], "results": [{"targets": null, "type": "probability"}, {"observable": ["z"], "targets": [0], "type": "expectation"}, {"targets": [0, 1], "type": "densitymatrix"}], "basis_rotation_instructions": []}"""

        parsed = Braket.parse_raw_schema(noisy_json_str)
        raw    = Braket.Program(Braket.braketSchemaHeader("braket.ir.jaqcd.program", "1"), [Braket.Instruction(X(), 0), Braket.Instruction(AmplitudeDamping(0.1), 0), Braket.Instruction(Y(), 1), Braket.Instruction(CNot(), [0, 2]), Braket.Instruction(AmplitudeDamping(0.1), 0), Braket.Instruction(AmplitudeDamping(0.1), 2), Braket.Instruction(X(), 1),  Braket.Instruction(Z(), 2), Braket.Instruction(AmplitudeDamping(0.1), 2)], Braket.AbstractProgramResult[Braket.IR.Probability(nothing, "probability"), Braket.IR.Expectation(["z"], [0], "expectation"), Braket.IR.DensityMatrix([0,1], "densitymatrix")], Braket.Instruction[])
        @test parsed.braketSchemaHeader == raw.braketSchemaHeader
        @test parsed.instructions       == raw.instructions
        @test parsed.results            == raw.results
        @test parsed.basis_rotation_instructions       == raw.basis_rotation_instructions
        @test Braket.parse_raw_schema(JSON3.write(raw)) == raw
        p = Braket.Program(Circuit(raw))
        for (pix, rix) in zip(p.instructions, raw.instructions)
            @test pix == rix
        end
        for (prt, rrt) in zip(p.results, raw.results)
            @test prt == rrt
        end

        @test JSON3.read(ir(raw), Dict) == JSON3.read(ir(Circuit(raw)), Dict)
    end

    @testset "enum translation" begin
        for e in [Braket._CopyMode, Braket.SafeUUID, Braket.PaymentCardBrand,
                Braket.Protocol, Braket.Extra, Braket.DeviceActionType,
                Braket.ExecutionDay, Braket.QubitDirection,
                Braket.PostProcessingType, Braket.ResultFormat,
                Braket.ProblemType, Braket.PersistedJobDataFormat]
            for inst in instances(e)
                @test string(inst) == inst
                @test inst == string(inst)
            end
        end
    end

    problem() = Braket.Problem(Braket.header_dict[Braket.Problem], Braket.ising, Dict(1=>3.14), Dict("(1, 2)"=>10.08))
    bell_qasm = """
    OPENQASM 3;

    qubit[2] q;
    bit[2] c;

    h q[0];
    cnot q[0], q[1];

    c = measure q;
    """
    oq3_program() = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], bell_qasm, nothing)
    bb_program()  = Braket.BlackbirdProgram(Braket.header_dict[Braket.BlackbirdProgram], "Vac | q[0]")
    bell_circ()   = (c = Circuit([(H, 0), (CNot, 0, 1)]); return Braket.Program(c))
    @testset "AbstractProgram constructfrom" begin
        para_ps = Braket.GateModelSimulatorParadigmProperties(Braket.header_dict[Braket.GateModelSimulatorParadigmProperties], 1)
        input = JSON3.read(JSON3.write(para_ps))
        @testset for prog in (oq3_program, bb_program, problem, bell_circ)
            p = prog()
            raw = JSON3.read(JSON3.write(p))
            @test StructTypes.constructfrom(Braket.AbstractProgram, raw) == p
        end
    end

    @testset "parse_raw_schema error" begin
        d = Braket.Detection(0.1, 0.1, 0.1, 0.1)
        @test_throws ArgumentError Braket.parse_raw_schema(JSON3.write(d))
    end
end