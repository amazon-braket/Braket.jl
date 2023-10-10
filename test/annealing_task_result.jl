using Braket, JSON3, Test

@testset "AnnealingQuantumTaskResult" begin
    solutions = [[-1, -1, -1, -1], [1, -1, 1, 1], [1, -1, -1, 1]]
    values = [0.0, 1.0, 2.0]
    variable_count = 4
    solution_counts = [3, 2, 4]
    problem_type = Braket.ising
    task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 100, "arn1", nothing, nothing, nothing, nothing, nothing)
    dwave_metadata = Braket.DwaveMetadata(Braket.header_dict[Braket.DwaveMetadata],
        [0],
        Braket.DwaveTiming(
            100,
            20,
            274,
            10917,
            3382,
            9342,
            21,
            117,
            117,
            10917,
            1575,
            20,
            274,
        ),
    )
    problem = Braket.Problem(Braket.header_dict[Braket.Problem],
        problem_type,
        Dict(0=>0.3333, 1=>-0.333, 4=>-0.333, 5=>0.333),
        Dict("0,4"=> 0.667, "0,5"=> -1, "1,4"=> 0.667, "1,5"=> 0.667),
    )
    additional_metadata = Braket.AdditionalMetadata(problem, dwave_metadata, nothing, nothing, nothing, nothing, nothing, nothing)
    function result_str_1()
        result = Braket.AnnealingTaskResult(Braket.header_dict[Braket.AnnealingTaskResult],
            solutions,
            solution_counts,
            values,
            variable_count,
            task_metadata,
            additional_metadata,
        )
        return JSON3.write(result)
    end
    function result_str_2()
        result = Braket.AnnealingTaskResult(Braket.header_dict[Braket.AnnealingTaskResult],
            solutions=solutions,
            variableCount=variable_count,
            values=values,
            taskMetadata=task_metadata,
            additionalMetadata=additional_metadata,
        )
        return JSON3.write(result)
    end
    function result_str_3()
        result = Braket.AnnealingTaskResult(Braket.header_dict[Braket.AnnealingTaskResult],
            solutionCounts=[],
            solutions=solutions,
            variableCount=variable_count,
            values=values,
            taskMetadata=task_metadata,
            additionalMetadata=additional_metadata,
        )
        return JSON3.write(result)
    end
    result = Braket.format_result(Braket.parse_raw_schema(result_str_1()))
    @test result.variable_count == variable_count
    @test result.problem_type == problem_type 
    @test result.task_metadata == task_metadata
    @test result.additional_metadata.action == additional_metadata.action
    @test result.additional_metadata.dwaveMetadata == additional_metadata.dwaveMetadata
    @test result.record_array[:, :solution] == solutions 
    @test result.record_array[:, :value] == values 
    @test result.record_array[:, :solution_count] == solution_counts
    @test sprint(show, result) == "AnnealingQuantumTaskResult\n"
    read_in = JSON3.read(JSON3.write(result), Braket.AnnealingQuantumTaskResult)
    # record array needs some JSON3 TLC
    @test read_in.additional_metadata == result.additional_metadata
    @test read_in.variable_count == result.variable_count
    @test read_in.problem_type == result.problem_type
    @test read_in.task_metadata == result.task_metadata
    @test_broken read_in == result
end
