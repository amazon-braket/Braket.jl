using Braket, JSON3, Test

@testset "PhotonicQuantumTaskResult" begin
    task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 100, "arn1", nothing, nothing, nothing, nothing, nothing)
    xanadu_metadata = Braket.XanaduMetadata(Braket.header_dict[Braket.XanaduMetadata], "DECLARE ro BIT[2];")
    blackbird_program = Braket.BlackbirdProgram(Braket.header_dict[Braket.BlackbirdProgram], "Vac | q[0]")
    additional_metadata = Braket.AdditionalMetadata(blackbird_program, nothing, nothing, nothing, nothing, xanadu_metadata, nothing, nothing)
    measurements = [[[1, 2, 3, 4]], [[4, 3, 2, 1]], [[0, 0, 0, 0]]]
    function result_1()
        Braket.PhotonicModelTaskResult(Braket.header_dict[Braket.PhotonicModelTaskResult], measurements, task_metadata, additional_metadata)
    end
    result = Braket.format_result(Braket.parse_raw_schema(JSON3.write(result_1())))
    @test result.task_metadata == task_metadata
    @test result.additional_metadata == additional_metadata
    @test result.measurements == measurements
    @test sprint(show, result) == "PhotonicModelQuantumTaskResult\n"
    result = Braket.PhotonicModelQuantumTaskResult(task_metadata, additional_metadata, nothing)
    @test JSON3.read("""{"task_metadata": $(JSON3.write(task_metadata)), "additional_metadata": $(JSON3.write(additional_metadata))}""", Braket.PhotonicModelQuantumTaskResult) == result
end
