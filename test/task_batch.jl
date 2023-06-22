using Braket, Test, Mocking, JSON3
Mocking.activate()

mock_result(c) = Braket.GateModelTaskResult(
            Braket.header_dict[Braket.GateModelTaskResult],
            nothing,
            nothing,
            [Braket.ResultTypeValue(Braket.IR.Amplitude(["011000"], "amplitude"), Dict("011000"=>0.9999999999999982))],
            collect(0:5),
            Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 0, "arn1", nothing, nothing, nothing, nothing, nothing),
            Braket.AdditionalMetadata(Braket.Program(c), nothing, nothing, nothing, nothing, nothing, nothing)
        )

RIGETTI_ARN = "arn:aws:braket:::device/qpu/rigetti/Aspen-11"
IONQ_ARN = "arn:aws:braket:::device/qpu/ionq/ionQdevice"
SV1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
OQC_ARN = "arn:aws:braket:eu-west-2::device/qpu/oqc/Lucy"
XANADU_ARN = "arn:aws:braket:us-east-1::device/qpu/xanadu/Borealis"

@testset "Batched tasks" begin
    c = CNot(Circuit(), 0, 1)
    @testset for dev in (SV1_ARN,) 
        resp_dict = Dict("quantumTaskArn"=>"arn/fake", "status"=>"COMPLETED")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            t = Braket.AwsQuantumTaskBatch(dev, [c, c], s3_destination_folder=("fake_bucket", "fake_prefix"))
            @test arn.(Braket.tasks(t)) == ["arn/fake", "arn/fake"]
            @test t isa Braket.AwsQuantumTaskBatch
            @test length(t) == 2
        end
    end
    @testset "inputs" begin
        dev = SV1_ARN
        α = FreeParameter(:α)
        c_params = Circuit([(H, [0, 1]), (CNot, 0, 1), (Rx, 0, α)])
        @testset "one dict for multiple circuits" begin
            resp_dict = Dict("quantumTaskArn"=>"arn/fake", "status"=>"COMPLETED")
            req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            apply(req_patch) do
                t = Braket.AwsQuantumTaskBatch(dev, [c, c], s3_destination_folder=("fake_bucket", "fake_prefix"), inputs=Dict("α"=>0.2))
                @test arn.(Braket.tasks(t)) == ["arn/fake", "arn/fake"]
                @test t isa Braket.AwsQuantumTaskBatch
                @test length(t) == 2
            end
        end
        @testset "one dict per circuit" begin
            resp_dict = Dict("quantumTaskArn"=>"arn/fake", "status"=>"COMPLETED")
            req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            apply(req_patch) do
                t = Braket.AwsQuantumTaskBatch(dev, [c, c], s3_destination_folder=("fake_bucket", "fake_prefix"), inputs=[Dict("α"=>0.2), Dict("α"=>0.1)])
                @test arn.(Braket.tasks(t)) == ["arn/fake", "arn/fake"]
                @test t isa Braket.AwsQuantumTaskBatch
                @test length(t) == 2
            end
        end
        @testset "wrong vector of dicts length" begin
            @test_throws DimensionMismatch Braket.AwsQuantumTaskBatch(dev, [c, c], s3_destination_folder=("fake_bucket", "fake_prefix"), inputs=[Dict("α"=>0.2), Dict("α"=>0.1),  Dict("α"=>0.1)])
        end
        @testset "invalid inputs" begin
            @test_throws ArgumentError Braket.AwsQuantumTaskBatch(dev, [c, c], s3_destination_folder=("fake_bucket", "fake_prefix"), inputs=Set(1))
        end
    end
    @testset "unfinished" begin
        resp_dict = Dict("status"=>"RUNNING")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            n_tasks = 10
            tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
            specs = [c for ix in 1:n_tasks]
            t = Braket.AwsQuantumTaskBatch(tasks, nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 10, 1, 10)
            @test Braket.unfinished(t) == Set(arn.(tasks))
        end
    end
    @testset "unsuccessful" begin
        resp_dict = Dict("status"=>"FAILED")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            n_tasks = 10
            tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
            specs = [c for ix in 1:n_tasks]
            t = Braket.AwsQuantumTaskBatch(tasks, nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 10, 1, 10)
            @test isempty(Braket.unsuccessful(t))
            _ = Braket.unfinished(t)
            @test Braket.unsuccessful(t) == Set(arn.(tasks))
            @test_throws ErrorException Braket.retry_unsuccessful_tasks(t)
        end
    end
    @testset "retry_unsuccessful_tasks" begin
        n_tasks = 10
        raw_tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
        specs = [c for ix in 1:n_tasks]
        t = Braket.AwsQuantumTaskBatch(deepcopy(raw_tasks), nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 100, 1, 10)
        t._results = fill("fake_result", n_tasks)
        @test isnothing(Braket.retry_unsuccessful_tasks(t))
        t._results = convert(Vector{Any}, fill(nothing, n_tasks))
        t._results[2] = "hello"
        t._results[5] = "world"
        new_arns = ["arn:fake:$i" for i in n_tasks+1:2*n_tasks+1]
        function f(http_backend, request, response_stream)
            if request.service == "s3"
                return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(JSON3.write(mock_result(c))))
            else
                if request.request_method == "POST"
                    mtd_dict = Dict("quantumTaskArn"=>popfirst!(new_arns), "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                elseif request.request_method == "GET"
                    mtd_dict = Dict("status"=>"COMPLETED", "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                end
            end
        end
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
        apply(req_patch) do
            Braket.retry_unsuccessful_tasks(t)
            @test isempty(t._unsuccessful)
            @test arn(Braket.tasks(t)[2]) == "arn:fake:2"
            @test arn(Braket.tasks(t)[5]) == "arn:fake:5"
            for ix in [1, 3, 4, 6, 7, 8, 9, 10]
                @test arn(Braket.tasks(t)[ix]) ∉ arn.(raw_tasks)
            end
        end
    end
    @testset "result" begin
        @testset "success" begin
            mtd_dict = Dict("status"=>"COMPLETED", "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(JSON3.write(mock_result(c))))
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                n_tasks = 10
                tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
                specs = [c for ix in 1:n_tasks]
                t = Braket.AwsQuantumTaskBatch(tasks, nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 0, 1, 10)
                rs = Braket.results(t)
                @test length(rs) == n_tasks
                @test all(r isa Braket.GateModelQuantumTaskResult for r in rs)
                for r in rs
                    raw = Braket.format_result(Braket.parse_raw_schema(JSON3.write(mock_result(c))))
                    @test r.values == raw.values
                end
            end
        end
        @testset "failure" begin
            mtd_dict = Dict("status"=>"FAILED", "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(JSON3.write(mock_result(c))))
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                n_tasks = 10
                tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
                specs = [c for ix in 1:n_tasks]
                t = Braket.AwsQuantumTaskBatch(tasks, nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 0, 1, 10)
                @test_throws ErrorException Braket.results(t, max_retries=0, fail_unsuccessful=true)
                @test Braket.results(t, max_retries=0, fail_unsuccessful=false) == fill(nothing, 10)
            end
        end
        @testset "retries" begin
            n_tasks = 10
            # test retries
            new_arns = ["arn:fake:$i" for i in n_tasks+1:2*n_tasks+1]
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(JSON3.write(mock_result(c))))
                else
                    if request.request_method == "POST"
                        mtd_dict = Dict("quantumTaskArn"=>popfirst!(new_arns), "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
                        return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                    elseif request.request_method == "GET"
                        mtd_dict = Dict("status"=>"FAILED", "outputS3Bucket"=>"fake_bucket", "outputS3Directory"=>"fake_dir")
                        return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(mtd_dict)))
                    end
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                tasks = [Braket.AwsQuantumTask("arn:fake:$i") for i in 1:n_tasks]
                specs = [c for ix in 1:n_tasks]
                t = Braket.AwsQuantumTaskBatch(tasks, nothing, Set{String}(), "fake_device", specs, ("fake_bucket", "fake_prefix"), 100, 1, 10)
                @test Braket.results(t, max_retries=1) == fill(nothing, 10)
            end
        end
    end
end
