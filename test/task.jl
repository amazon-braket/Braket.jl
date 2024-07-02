using Braket, Braket.IR, Test, JSON3, UUIDs, Mocking
using Braket: ResultTypeValue

Mocking.activate()

zero_shots_result(task_mtd, add_mtd) = Braket.GateModelTaskResult(
    Braket.header_dict[Braket.GateModelTaskResult],
    nothing,
    nothing,
    [
        ResultTypeValue(IR.Probability([0], "probability"), [0.5, 0.5]),
        ResultTypeValue(IR.Expectation(["y"], [0], "expectation"), 0.0),
        ResultTypeValue(IR.Variance(["y"], [0], "variance"), 0.1),
    ],
    [0,1],
    task_mtd,
    add_mtd,
)
@testset "Tasks" begin
    @testset "Task basics" begin
        t1 = AwsQuantumTask("arn:fake1")
        t2 = AwsQuantumTask("arn:fake2")
        @test id(t1) == "arn:fake1"
        @test t1 != t2
        @test t1 == t1
        t1._metadata = Dict("status"=>"fake_state")
        @test metadata(t1, Val(true)) == Dict("status"=>"fake_state")
        @test state(t1, Val(true)) == "fake_state"
        t1._metadata["status"] == "COMPLETED"
        withenv("AMZN_BRAKET_TASK_RESULTS_S3_URI"=>"s3://fake/bucket") do
            @test Braket.default_task_bucket() == ("fake", "bucket")
        end
        @test sprint(show, t1) == """AwsQuantumTask("id/taskArn":"arn:fake1")\n"""
        
        # test creation from NamedTuple and from Circuit
        resp_dict = Dict("quantumTaskArn"=>"arn/fake")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            args = (action="", client_token="", device_arn="", outputS3Bucket="", outputS3KeyPrefix="", shots=0, extra_opts=Dict{String, Any}(), config=Braket.AWS.global_aws_config())
            @test AwsQuantumTask(args) == AwsQuantumTask("arn/fake", client_token="", config=Braket.AWS.global_aws_config())
            c = CNot(Circuit(), 0, 1)
            @test AwsQuantumTask("arn/fake_dev", c, s3_destination_folder=("", "")) == AwsQuantumTask("arn/fake")
        end

        # test count_tasks_with_status
        resp_dict = Dict("quantumTasks"=>["a", "b", "c"], "nextToken"=>"0000")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            @test Braket.count_tasks_with_status("fake_arn", "RUNNING") == length(resp_dict["quantumTasks"])
        end

        # test non-cached metadata
        resp_dict = Dict("status"=>"FAILED", "failureReason"=>"badness")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            t = AwsQuantumTask("fake_arn")
            @test metadata(t, Val(false)) == resp_dict
            if VERSION >= v"1.7"
                @test_warn "Task is in terminal state FAILED and no result is available." state(t, Val(false))
                @test_warn "Task failure reason is: badness." state(t, Val(false))
            end
            @test state(t) == "FAILED"
        end

        c = CNot(Circuit(), 0, 1)
        action = Braket.Program(c)
        task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 0, "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
        s3_req_str = JSON3.write(zero_shots_result(task_metadata, additional_metadata))
        req_patch = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(s3_req_str))
        apply(req_patch) do
            t = AwsQuantumTask("fake_arn")
            t._metadata = Dict("status"=>"COMPLETED", "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_prefix")
            res1 = result(t)
            @test res1 isa Braket.GateModelQuantumTaskResult
            # test getting cached result
            res2 = result(t)
            @test res2.values == res1.values
        end
        # test result timeout
        resp_dict = Dict("status"=>"RUNNING")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            timeout_secs = 5
            t = AwsQuantumTask("fake_arn", poll_timeout_seconds=timeout_secs)
            start = time()
            r = result(t)
            stop = time()
            @test isnothing(r)
            @test stop-start > timeout_secs
        end
        # test cancel
        resp_dict = Dict("cancellationStatus"=>"CANCELLED", "quantumTaskArn"=>"arn:fake")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            t = AwsQuantumTask("arn:fake", client_token="", config=Braket.AWS.global_aws_config())
            @test isnothing(Braket.cancel(t))
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
    bell_circ()   = (c = Circuit(); c=H(c, 0); c=CNot(c, 0, 1); return c)
    bell_prog()   = Braket.Program(bell_circ())
    RIGETTI_ARN = "arn:aws:braket:::device/qpu/rigetti/Aspen-11"
    IONQ_ARN = "arn:aws:braket:::device/qpu/ionq/ionQdevice"
    SV1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
    OQC_ARN = "arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy"
    IQM_ARN = "arn:aws:braket:eu-north-1::device/qpu/iqm/Garnet"
    XANADU_ARN = "arn:aws:braket:us-east-1::device/qpu/xanadu/Borealis"
    @testset for program in (bell_circ, bell_prog), arn in (SV1_ARN, OQC_ARN, IQM_ARN, RIGETTI_ARN, IONQ_ARN)
        shots = 100
        device_params = Dict("fake_param_1"=>2, "fake_param_2"=>"hello")
        s3_folder = ("fake_bucket", "fake_folder")
        task_args = Braket.prepare_task_input(program(), arn, s3_folder, shots, device_params)
        @test task_args[:action] == JSON3.write(ir(program()))
        @test task_args[:device_arn] == arn
        @test UUID(task_args[:client_token]) isa UUID
        @test task_args[:shots] == shots
        @test task_args[:outputS3Bucket] == s3_folder[1]
        @test task_args[:outputS3KeyPrefix] == s3_folder[2]
    end

    @testset "Error Mitigation" for em in (Braket.DeBias(), ir(Braket.DeBias())) 
        shots = 21
        s3_folder = ("fake_bucket", "fake_folder")
        device_params = Braket.IonqDeviceParameters(Braket.header_dict[Braket.IonqDeviceParameters], Braket.GateModelParameters(Braket.header_dict[Braket.GateModelParameters], 0, false), [Braket.Debias(StructTypes.defaults(Braket.Debias)[:type])])
        task_args = Braket.prepare_task_input(oq3_program(), IONQ_ARN, s3_folder, shots, Dict("errorMitigation"=>em))
        @test task_args[:action] == JSON3.write(ir(oq3_program()))
        @test task_args[:device_arn] == IONQ_ARN
        @test UUID(task_args[:client_token]) isa UUID
        @test task_args[:shots] == shots
        @test task_args[:outputS3Bucket] == s3_folder[1]
        @test task_args[:outputS3KeyPrefix] == s3_folder[2]
        @test task_args[:extra_opts]["deviceParameters"] == JSON3.write(device_params)
    end

    @testset for (program, arn) in zip((oq3_program, bb_program), (SV1_ARN, XANADU_ARN))
        shots = 100
        device_params = Dict("fake_param_1"=>2, "fake_param_2"=>"hello")
        s3_folder = ("fake_bucket", "fake_folder")
        task_args = Braket.prepare_task_input(program(), arn, s3_folder, shots, device_params)
        @test task_args[:action] == JSON3.write(ir(program()))
        @test task_args[:device_arn] == arn
        @test UUID(task_args[:client_token]) isa UUID
        @test task_args[:shots] == shots
        @test task_args[:outputS3Bucket] == s3_folder[1]
        @test task_args[:outputS3KeyPrefix] == s3_folder[2]
        # TODO test device parameters
        @test task_args[:extra_opts]["tags"] == Dict{String, String}()
        tags = Dict("fake_tag"=>"fake_val")
        task_args = Braket.prepare_task_input(program(), arn, s3_folder, shots, device_params, tags=tags)
        @test task_args[:extra_opts]["tags"] == tags
    end

    ADVANTAGE_4_ARN = "arn:aws:braket:::device/qpu/d-wave/Advantage_system4"
    ADVANTAGE_6_ARN = "arn:aws:braket:us-west-2::device/qpu/d-wave/Advantage_system6"
    DWAVE_2000Q_ARN = "arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6"
    @testset for (prob, arn) in zip((problem, problem, problem), (ADVANTAGE_4_ARN, ADVANTAGE_6_ARN, DWAVE_2000Q_ARN))
        shots = 100
        device_params = Dict("fake_param_1"=>2, "fake_param_2"=>"hello")
        s3_folder = ("fake_bucket", "fake_folder")
        task_args = Braket.prepare_task_input(prob(), arn, s3_folder, shots, device_params)
        @test task_args[:action] == JSON3.write(prob())
        @test task_args[:device_arn] == arn
        @test UUID(task_args[:client_token]) isa UUID
        @test task_args[:shots] == shots
        @test task_args[:outputS3Bucket] == s3_folder[1]
        @test task_args[:outputS3KeyPrefix] == s3_folder[2]
        # device params handled below
        @test task_args[:extra_opts]["tags"] == Dict{String, String}()
        tags = Dict("fake_tag"=>"fake_val")
        task_args = Braket.prepare_task_input(prob(), arn, s3_folder, shots, device_params, tags=tags)
        @test task_args[:extra_opts]["tags"] == tags 
    end

    @testset "_create_annealing_parameters" begin
        adv_1 = ("""{
                    "providerLevelParameters": {
                        "postprocessingType": "optimization",
                        "annealingOffsets": [3.67, 6.123],
                        "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
                        "annealingDuration": 1,
                        "autoScale": false,
                        "beta": 0.2,
                        "chains": [[0, 1, 5], [6]],
                        "compensateFluxDrift": false,
                        "fluxBiases": [1.1, 2.2, 3.3, 4.4],
                        "initialState": [1, 3, 0, 1],
                        "maxResults": 1,
                        "programmingThermalizationDuration": 625,
                        "readoutThermalizationDuration": 256,
                        "reduceIntersampleCorrelation": false,
                        "reinitializeState": true,
                        "resultFormat": "raw",
                        "spinReversalTransformCount": 100}
                    }""", "arn:aws:braket:::device/qpu/d-wave/Advantage_system1")
        q2k = ("""{
                    "deviceLevelParameters": {
                        "postprocessingType": "optimization",
                        "beta": 0.2,
                        "annealingOffsets": [3.67, 6.123],
                        "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
                        "annealingDuration": 1,
                        "autoScale": false,
                        "chains": [[0, 1, 5], [6]],
                        "compensateFluxDrift": false,
                        "fluxBiases": [1.1, 2.2, 3.3, 4.4],
                        "initialState": [1, 3, 0, 1],
                        "maxResults": 1,
                        "programmingThermalizationDuration": 625,
                        "readoutThermalizationDuration": 256,
                        "reduceIntersampleCorrelation": false,
                        "reinitializeState": true,
                        "resultFormat": "raw",
                        "spinReversalTransformCount": 100}
                    }""", "arn:aws:braket:::device/qpu/d-wave/DW_2000Q_6")
        adv_2 = ("""{
                    "deviceLevelParameters": {
                        "postprocessingType": "optimization",
                        "beta": 0.2,
                        "annealingOffsets": [3.67, 6.123],
                        "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
                        "annealingDuration": 1,
                        "autoScale": false,
                        "chains": [[0, 1, 5], [6]],
                        "compensateFluxDrift": false,
                        "fluxBiases": [1.1, 2.2, 3.3, 4.4],
                        "initialState": [1, 3, 0, 1],
                        "maxResults": 1,
                        "programmingThermalizationDuration": 625,
                        "readoutThermalizationDuration": 256,
                        "reduceIntersampleCorrelation": false,
                        "reinitializeState": true,
                        "resultFormat": "raw",
                        "spinReversalTransformCount": 100}
                    }""", "arn:aws:braket:::device/qpu/d-wave/Advantage_system1")
        @testset for pair in (adv_1, q2k, adv_2)
            dev_params = convert(Dict{Symbol, Any}, JSON3.read(pair[1]))
            annealing_params = Braket._create_annealing_device_params(dev_params, pair[2])
            @test Braket.parse_raw_schema(JSON3.write(annealing_params)) == annealing_params
        end
        @test_throws ArgumentError Braket._create_annealing_device_params(Dict{String, Any}(), "arn:fake")
    end

    @testset "default_task_bucket" begin
        withenv("AWS_DEFAULT_REGION"=>"fake_region") do 
            resp_dict = Dict("GetCallerIdentityResult"=>Dict("Arn"=>"fake_arn", "Account"=>"000000"))
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    xml_str = """
                    <ListAllMyBucketsResult>
                        <Buckets>
                            <Bucket>
                                <CreationDate>2000:01:01T00:00:00</CreationDate>
                                <Name>"amazon-braket-fake_region-000000"</Name>
                            </Bucket>
                        </Buckets>
                        <Owner>
                            <DisplayName>"fake_name"</DisplayName>
                            <ID>000000</ID>
                        </Owner>
                    </ListAllMyBucketsResult>
                    """
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                db = Braket.default_task_bucket()
                @test db == ("amazon-braket-fake_region-000000", "tasks")
            end
        end
    end
    @testset "inputs" begin
        dev = SV1_ARN
        α = FreeParameter(:α)
        c_params = Circuit([(H, [0, 1]), (CNot, 0, 1), (Rx, 0, α)])
        @testset for prog in (c_params, ir(c_params, Val(:OpenQASM)))
            resp_dict = Dict("quantumTaskArn"=>"arn/fake", "status"=>"COMPLETED")
            req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            apply(req_patch) do
                t = Braket.AwsQuantumTask(dev, prog, s3_destination_folder=("fake_bucket", "fake_prefix"), inputs=Dict("α"=>0.2))
                @test arn(t) == "arn/fake"
            end
        end
    end
end
