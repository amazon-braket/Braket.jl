using Braket, Braket.IR, Test, JSON3
using Braket: ResultTypeValue

zero_shots_result(task_mtd, add_mtd) = Braket.GateModelTaskResult(
    Braket.header_dict[Braket.GateModelTaskResult],
    nothing,
    nothing,
    [
        ResultTypeValue(IR.Probability([0], "probability"), [0.5, 0.5]),
        ResultTypeValue(IR.StateVector("statevector"), [complex(0.70710678, 0), 0, 0, complex(0.70710678, 0)]),
        ResultTypeValue(IR.Expectation(["y"], [0], "expectation"), 0.0),
        ResultTypeValue(IR.Variance(["y"], [0], "variance"), 0.1),
        ResultTypeValue(IR.Amplitude(["00"], "amplitude"), Dict("00"=>complex(0.70710678, 0)))
    ],
    [0,1],
    task_mtd,
    add_mtd,
)

non_zero_shots_result(task_mtd, add_mtd) = Braket.GateModelTaskResult(
    Braket.header_dict[Braket.GateModelTaskResult],
    nothing,
    Dict("011000"=>0.9999999999999982),
    nothing,
    collect(0:5),
    task_mtd,
    add_mtd)

@testset "GateModelQuantumTaskResult" begin
    c = CNot(Circuit(), 0, 1)
    action = Braket.Program(c)
    @testset for (shots, result) in zip([0, 100], [zero_shots_result, non_zero_shots_result])
        task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", shots, "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        r = result(task_metadata, additional_metadata)
        g = Braket.format_result(r)
        @test g isa Braket.GateModelQuantumTaskResult
        @test sprint(show, g) == "GateModelQuantumTaskResult\n"
    end
    task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 0, "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
    result = Braket.GateModelQuantumTaskResult(task_metadata, JSON3.read(JSON3.write(additional_metadata), Braket.AdditionalMetadata), nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
    @test JSON3.read("{\"task_metadata\": $(JSON3.write(task_metadata)), \"additional_metadata\": $(JSON3.write(additional_metadata))}", Braket.GateModelQuantumTaskResult) == result
end

@testset "shots>0 results computation" begin
    measurements = [
        [0, 0, 1, 0],
        [1, 1, 1, 1],
        [1, 0, 0, 1],
        [0, 0, 1, 0],
        [1, 1, 1, 1],
        [0, 1, 1, 1],
        [0, 0, 0, 1],
        [0, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 1],
    ]
    mat = [1 0; 0 -1]
    ho = Braket.Observables.HermitianObservable(mat)
    samp = ir(Braket.Sample(ho, Int[2]))
    action = Braket.Program(Braket.header_dict[Braket.Program], [Braket.IR.CNot(0, 1, "cnot"), Braket.IR.CNot(2, 3, "cnot")], [Braket.IR.Probability([1], "probability"), Braket.IR.Expectation(["z"], nothing, "expectation"), Braket.IR.Variance(["x", "x"], [0, 2], "variance"), samp], [])
    task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
    task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
        measurements,
        nothing,
        nothing,
        [0, 1, 2, 3],
        task_metadata_shots,
        additional_metadata,
    )
    quantum_task_result = Braket.format_result(task_result)
    @test quantum_task_result.values[1] ≈ [0.6, 0.4]
    @test quantum_task_result.values[2] ≈ [0.4, 0.2, -0.2, -0.4]
    @test quantum_task_result.values[3] ≈ 1.11111111111
    @test quantum_task_result.values[4] ≈ [1.0, 1.0, -1.0, 1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0]
    @test quantum_task_result.result_types[1].type == Braket.IR.Probability([1], "probability")
    @test quantum_task_result.result_types[2].type == Braket.IR.Expectation(["z"], nothing, "expectation")

    @testset "result without measurements or measurementProbabilities" begin
        task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
            nothing,
            nothing,
            nothing,
            [0, 1, 2, 3],
            task_metadata_shots,
            additional_metadata,
        )
        @test_throws ErrorException Braket.format_result(task_result)
    end
    @testset "bad result type in results for shots > 0" begin
        action = Braket.Program(Braket.header_dict[Braket.Program], [Braket.IR.CNot(0, 1, "cnot"), Braket.IR.CNot(2, 3, "cnot")], [Braket.IR.DensityMatrix([1,3], "densitymatrix")], [])
        task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
            measurements,
            nothing,
            nothing,
            [0, 1, 2, 3],
            task_metadata_shots,
            additional_metadata,
        )
        @test_throws ErrorException Braket.format_result(task_result)
    end
end
