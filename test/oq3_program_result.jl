using Braket, JSON3, Test

bell_qasm = """
OPENQASM 3;

qubit[2] q;
bit[2] c;

h q[0];
cnot q[0], q[1];

c = measure q;
"""
oq3_program() = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], bell_qasm, nothing)

@testset "OQ3ProgramResult" begin
    task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 100, "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(oq3_program(), nothing, nothing, nothing, nothing, nothing, nothing)
    read_in = JSON3.read("""{"taskMetadata": $(JSON3.write(task_metadata)), "additionalMetadata": $(JSON3.write(additional_metadata))}""", Braket.OQ3ProgramResult)
    @test read_in isa Braket.OQ3ProgramResult
    @test read_in.taskMetadata == task_metadata
    @test read_in.additionalMetadata == additional_metadata
    @test isnothing(read_in.resultTypes)
    @test isnothing(read_in.outputVariables)
    @test isnothing(read_in.measurements)
    @test isnothing(read_in.measuredQubits)
end
