using Braket, JSON3, Test, StructTypes
using Braket: operator, target

@testset "IR Translation" begin
    @testset "Schema header translation" begin
        json_str = """{"name": "braket.ir.openqasm.program", "version": "1"}"""
        @test JSON3.read(json_str, Braket.braketSchemaHeader) == Braket.braketSchemaHeader("braket.ir.openqasm.program", "1")
        fi = open(joinpath(@__DIR__, "header.json"), "r")
        @test JSON3.read(fi, Braket.braketSchemaHeader) == Braket.braketSchemaHeader("braket.ir.openqasm.program", "1")
    end

    @testset "Results translation" begin
        json_str = """[{"observable":["i"],"targets":[0],"type":"expectation"},{"observable":["z"],"targets":[0],"type":"expectation"}]"""
        parsed = JSON3.read(json_str, Vector{Braket.AbstractProgramResult})
        raw = Braket.AbstractProgramResult[Braket.IR.Expectation(convert(Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, ["i"]), [0], "expectation"), Braket.IR.Expectation(convert(Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, ["z"]), [0], "expectation")]
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

    @testset "enum translation" begin
        for e in [Braket.SafeUUID, Braket.PaymentCardBrand,
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
    @testset "AbstractProgram constructfrom" begin
        para_ps = Braket.GateModelSimulatorParadigmProperties(Braket.header_dict[Braket.GateModelSimulatorParadigmProperties], 1)
        input = JSON3.read(JSON3.write(para_ps))
        @testset for prog in (oq3_program, bb_program, problem)
            p = prog()
            raw = JSON3.read(JSON3.write(p))
            @test StructTypes.constructfrom(Braket.AbstractProgram, raw) == p
        end
    end
    @testset "ir fallbacks" begin
        @test ir(X(), 1) == ir(X(), 1, Val(Braket.IRType[]))
    end
end
