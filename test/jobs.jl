using Braket, Test, Mocking, Random, Dates, Tar, JSON3
Mocking.activate()

Base.parse(d::Dict) = d

dev_arn = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"

@testset "Jobs" begin
    @testset "deserialization errors" begin
        @test_throws ArgumentError Braket.deserialize_values(Dict{String, Any}(), Braket.pickled_v4)
        mktempdir() do d
            job = Braket.AwsQuantumJob("arn:fake")
            @test Braket._read_and_deserialize_results(job, d) == []
            pjd = Braket.PersistedJobData(Braket.header_dict[Braket.PersistedJobData], Dict{String, Any}(), Braket.pickled_v4)
            write(joinpath(d, Braket.RESULTS_FILENAME), JSON3.write(pjd))
            @test_throws ArgumentError Braket._read_and_deserialize_results(job, d)
        end
    end
    @testset "logs" begin
        statuses = ["RUNNING", "COMPLETED", "COMPLETED", "COMPLETED"]
        event_dict = Dict("arn:fake/0" => [Dict("timestamp"=>1,"message"=>"0-message1"), Dict("timestamp"=>2,"message"=>"0-message2")],
                          "arn:fake/1" => [Dict("timestamp"=>1,"message"=>"1-message1"), Dict("timestamp"=>2,"message"=>"1-message2")])

        function events_get(str)
            dict = JSON3.read(str, Dict)
            return haskey(dict, "logStreamName") && !isempty(event_dict[dict["logStreamName"]]) ? [popfirst!(event_dict[dict["logStreamName"]])] : []
        end
        resp_dict(r) = JSON3.write(
                        Dict("instanceConfig"=>Dict("instanceCount"=>2),
                         "logStreams"=>[Dict("logStreamName"=>"arn:fake/0"),
                                        Dict("logStreamName"=>"arn:fake/1")],
                         "nextForwardToken"=>"000000",
                         "events"=>events_get(r),
                         "status"=>isempty(statuses) ? "COMPLETED" : popfirst!(statuses),
                        ))
        req_patch  = @patch Braket.AWS._http_request(a, r, b) = return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(resp_dict(r.content)))
        mktemp() do f, io
            redirect_stdout(io) do
                apply(req_patch) do
                    job = Braket.AwsQuantumJob("job/arn:fake")
                    Braket.logs(job, wait=true, poll_interval_seconds=1)
                end
            end
            seekstart(io)
            str = read(io, String)
            for msg in ["0-message1", "0-message2", "1-message1", "1-message2"]
                @test occursin(msg, str)
            end
        end
    end
    @testset "S3 source module" begin
        log_streams = [Dict("logStreamName"=>"fake_name")]
        events      = []
        resp_dict   = Dict("jobArn"=>"arn:job/fake", "status"=>"COMPLETED", "instanceConfig"=>Dict("instanceCount"=>1), "logStreams"=>log_streams, "nextForwardToken"=>"0", "events"=>events, "GetCallerIdentityResult"=>Dict("Arn"=>"fake_arn", "Account"=>"000000"))
        sm          = "s3://fake_bucket/fake_module" # to avoid tar and upload
        code_loc    = Braket.construct_s3_uri("fake_bucket", "fake_dir")
        @test_throws ArgumentError Braket._process_s3_source_module(sm, "", code_loc) #no entry point
        @test_throws ArgumentError Braket._process_s3_source_module(sm, "a", code_loc) #no tar.gz ending
        sm *= ".tar.gz"
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            output_dc = Braket.OutputDataConfig("s3://fake_bucket/fake_output")
            checkpoint_cf = Braket.CheckpointConfig(nothing, "s3://fake_bucket/fake_checkpoints")
            job = Braket.AwsQuantumJob(dev_arn, sm, entry_point="fake_entry.py", role_arn="arn:fake:role", code_location=code_loc, hyperparameters=Dict("blah"=>1), output_data_config=output_dc, checkpoint_config=checkpoint_cf, wait_until_complete=true)
            @test arn(job) == resp_dict["jobArn"]
            @test name(job) == "fake"
        end
    end
    @testset "local source module" begin
        log_streams = [Dict("logStreamName"=>"fake_name")]
        events      = []
        resp_dict   = Dict("jobArn"=>"arn:job/fake",
                           "status"=>"COMPLETED",
                           "instanceConfig"=>Dict("instanceCount"=>1),
                           "logStreams"=>log_streams,
                           "nextForwardToken"=>"0",
                           "events"=>events,
                           "GetCallerIdentityResult"=>Dict("Arn"=>"fake_arn", "Account"=>"000000")
                        )
        @testset for sm in [joinpath(@__DIR__, "fake_code.jl"), joinpath(@__DIR__, "fake_code.py")]
            code_loc = Braket.construct_s3_uri("fake_bucket", "fake_dir")
            bad_path = randstring(10)
            @test_throws ArgumentError Braket._process_local_source_module(bad_path, sm, code_loc) # is not path
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer())
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                output_dc = Braket.OutputDataConfig("s3://fake_bucket/fake_output")
                checkpoint_cf = Braket.CheckpointConfig(nothing, "s3://fake_bucket/fake_checkpoints")
                job = Braket.AwsQuantumJob(dev_arn, sm, entry_point="", role_arn="arn:fake:role", code_location=code_loc, hyperparameters=Dict("blah"=>1), output_data_config=output_dc, checkpoint_config=checkpoint_cf, wait_until_complete=true)
                @test arn(job)  == resp_dict["jobArn"]
                @test name(job) == "fake"
            end
        end
    end
    @testset "input data handling" begin
        log_streams = [Dict("logStreamName"=>"fake_name")]
        events      = []
        resp_dict   = Dict("jobArn"=>"arn:job/fake", "status"=>"COMPLETED", "instanceConfig"=>Dict("instanceCount"=>1), "logStreams"=>log_streams, "nextForwardToken"=>"0", "events"=>events, "GetCallerIdentityResult"=>Dict("Arn"=>"fake_arn", "Account"=>"000000"))
        sm = joinpath(@__DIR__, "fake_code.jl")
        code_loc = Braket.construct_s3_uri("fake_bucket", "fake_dir")
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
        input_data = relpath(joinpath(pkgdir(Braket), "test", "fake_code.py"), @__DIR__)
        apply(req_patch) do
            output_dc = Braket.OutputDataConfig("s3://fake_bucket/fake_output")
            checkpoint_cf = Braket.CheckpointConfig(nothing, "s3://fake_bucket/fake_checkpoints")
            job = Braket.AwsQuantumJob(dev_arn, sm, entry_point="", input_data=input_data, role_arn="arn:fake:role", code_location=code_loc, hyperparameters=Dict("blah"=>1), output_data_config=output_dc, checkpoint_config=checkpoint_cf, wait_until_complete=true)
            @test arn(job) == "arn:job/fake"
        end
    end
    @testset "status" begin
        resp_dict = Dict("status"=>"COMPLETED")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            job = Braket.AwsQuantumJob("arn:fake")
            @test state(job) == "COMPLETED"
            @test state(job, Val(true)) == "COMPLETED"
        end
    end
    @testset "_get_default_jobs_role" begin
        resp_dict = Dict("ListRolesResult"=>Dict("Roles"=>Dict("member"=>[Dict("RoleName"=>"noMemberHere")])))
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            @test_throws ErrorException Braket._get_default_jobs_role()
        end
    end
    @testset "cancel" begin
        resp_dict = Dict("cancellationStatus"=>"CANCELLED", "quantumJobArn"=>"arn:fake")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            t = AwsQuantumJob("arn:fake")
            @test isnothing(Braket.cancel(t))
        end
    end
    @testset "metrics" begin
        # empty metrics
        j = Braket.AwsQuantumJob("arn:fake")
        resp_dict = Dict("status"=>"Complete", "jobName"=>"fake_job", "queryId"=>"00000", "results"=>[])
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            @test metrics(j) == []
        end
        # not empty
        result_dicts = [Dict("field"=>"@message", "value"=>"Metrics - timestamp=\"2000-01-01T00:00:00\"; FakeKey=1;"),
                        Dict("field"=>"@timestamp", "value"=>"2000-01-01T00:00:00")]
        function f(http_backend, request, response_stream)
            stat = request.service == "braket" ? "COMPLETED" : "Complete"
            resp_dict = Dict("status"=>stat, "jobName"=>"fake_job", "queryId"=>"00000", "startedAt"=>"2000-01-01T00:00:00.0", "endedAt"=>"2000-01-01T10:00:00.0", "results"=>[result_dicts])
            return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        end
        req_patch  = @patch Braket.AWS._http_request(http_backend, request, response_stream) = f(http_backend, request, response_stream)
        apply(req_patch) do
            @test metrics(j) == Dict{String, Vector}("timestamp" => ["2000-01-01T00:00:00"], "FakeKey"=>["1"])
        end
        if VERSION >= v"1.7"
            # test timeout
            resp_dict = Dict("status"=>"Running", "jobName"=>"fake_job", "queryId"=>"00000")
            req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            apply(req_patch) do
                @test_warn "Timed out waiting for query $(resp_dict["queryId"])" metrics(j)
            end
        end
        # test failure
        resp_dict = Dict("status"=>"Failed", "jobName"=>"fake_job", "queryId"=>"00000")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            @test_throws ErrorException metrics(j)
        end
    end
    @testset "log_metric" begin
        str = mktemp() do fname, f
            redirect_stdout(f) do
                Braket.log_metric("fake_name", 0.01, timestamp="2000:01:01T00:00:00", iteration_number=1)
            end
            seekstart(f)
            read(f, String)
        end
        @test str == "Metrics - timestamp=2000:01:01T00:00:00; fake_name=0.01; iteration_number=1;\n"
    end
    @testset "results" begin
        @testset "successfully get results" begin
            res = """{
                "braketSchemaHeader": {
                    "name": "braket.jobs_data.persisted_job_data",
                    "version": "1"
                },
                "dataDictionary": {"converged": true, "energy": -0.2},
                "dataFormat": "plaintext"
            }"""
            buf = ""
            mktempdir() do d
                mkdir(joinpath(d, "results"))
                write(joinpath(d, "results", "results.json"), res)
                Tar.create(joinpath(d, "results"), pipeline(`gzip -9`, joinpath(d, "model.tar.gz")))
                buf = read(joinpath(d, "model.tar.gz"))
            end
            resp_dict = Dict("status"=>"COMPLETED", "jobName" => "fake_name", "outputDataConfig"=>Dict("s3Path"=>"s3://fake_path"))
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(buf))
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                job = Braket.AwsQuantumJob("arn:fake")
                r   = result(job)
                raw = Braket.parse_raw_schema(res)
                @test r == raw.dataDictionary
            end
        end
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = throw(Braket.HTTP.StatusError(404, "", "", Braket.HTTP.Response(404)))
        apply(req_patch) do
            job = Braket.AwsQuantumJob("arn:fake")
            r = result(job)
            @test r == Dict()
        end
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = throw(ErrorException("badness"))
        apply(req_patch) do
            job = Braket.AwsQuantumJob("arn:fake")
            @test_throws ErrorException result(job)
        end
        @testset "job result timeout" begin
            resp_dict = Dict("status"=>"RUNNING", "jobName" => "fake_name", "outputDataConfig"=>Dict("s3Path"=>"s3://fake_path"))
            function f(http_backend, request, response_stream)
                if request.service == "s3"
                    return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer(buf))
                else
                    return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
                end
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                job = Braket.AwsQuantumJob("arn:fake")
                r   = result(job, poll_timeout_seconds=5, poll_interval_seconds=1)
                @test r == []
            end
        end
    end
    @testset "metadata" begin
        resp_dict = Dict("status"=>"COMPLETED")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            job = Braket.AwsQuantumJob("arn:fake")
            @test metadata(job) == resp_dict
        end
    end
    @testset "copying checkpoints" begin
        resp_dict = Dict("status"=>"COMPLETED", "jobArn"=>"job/fake:arn2", "checkpointConfig"=>Dict("s3Uri"=>"s3://fake_old_bucket/fake_path"))
        list_buf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Name>fake_old_bucket</Name>
            <Prefix/>
            <KeyCount>1</KeyCount>
            <MaxKeys>1000</MaxKeys>
            <IsTruncated>false</IsTruncated>
            <Contents>
                <Key>my_fake_file.dat</Key>
                <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                <Size>434234</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            <Contents>
            ...
            </Contents>
            ...
        </ListBucketResult>
        """
        copy_buf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <CopyObjectResult>
            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
            <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
        </CopyObjectResult>
        """
        function f(http_backend, request, response_stream)
            if request.service == "s3"
                if request.request_method == "GET"
                    buf = list_buf
                else
                    buf = copy_buf
                end
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(buf))
            else
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            end
        end
        req_patch  = @patch Braket.AWS._http_request(a, r, b) = f(a, r, b)
        apply(req_patch) do
            sm          = "s3://fake_bucket/fake_module.tar.gz" # to avoid tar and upload
            code_loc    = Braket.construct_s3_uri("fake_bucket", "fake_dir")
            output_dc   = Braket.OutputDataConfig("s3://fake_bucket/fake_output")
            checkpoint_cf = Braket.CheckpointConfig(nothing, "s3://fake_new_bucket/fake_checkpoints")
            job = Braket.AwsQuantumJob(dev_arn, sm, entry_point="fake_entry.py", role_arn="arn:fake:role", code_location=code_loc, copy_checkpoints_from_job="fake:arn", output_data_config=output_dc, checkpoint_config=checkpoint_cf)
            @test arn(job) == "job/fake:arn2"
        end
    end
    @testset "CheckpointConfig" begin
        cc = Braket.CheckpointConfig()
        @test cc.localPath == "/opt/jobs/checkpoints"
        @test isnothing(cc.s3Uri)
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
                cf = Braket.CheckpointConfig("fake_job_name")
                s3path = Braket.construct_s3_uri("amazon-braket-fake_region-000000", "jobs", "fake_job_name", "checkpoints")
                @test cf == Braket.CheckpointConfig("/opt/jobs/checkpoints", s3path)
                read_in = JSON3.read(JSON3.write(cf), Braket.CheckpointConfig)
                @test read_in isa Braket.CheckpointConfig
                @test read_in.localPath == cf.localPath
                @test read_in.s3Uri == cf.s3Uri
            end
        end
    end
    @testset "OutputDataConfig" begin
        odc = Braket.OutputDataConfig()
        @test isnothing(odc.s3Path)
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
                odc = Braket.OutputDataConfig(job_name="fake_job_name")
                s3path = Braket.construct_s3_uri("amazon-braket-fake_region-000000", "jobs", "fake_job_name", "data")
                @test odc == Braket.OutputDataConfig(s3path)
                read_in = JSON3.read("""{"s3Path": "$s3path"}""", Braket.OutputDataConfig)
                @test read_in isa Braket.OutputDataConfig
                @test read_in.s3Path == s3path 
            end
        end
    end
    @testset "S3DataSourceConfig" begin
        s3d = Braket.S3DataSourceConfig("s3://fake_bucket/fake_prefix", "fake_type")
        @test s3d.config["contentType"] == "fake_type"
        @test s3d.config["dataSource"]["s3DataSource"]["s3Uri"] == "s3://fake_bucket/fake_prefix"
        @test Dict(s3d) == Dict("config"=>s3d.config)
        read_in = JSON3.read("""{"config": $(JSON3.write(s3d.config))}""", Braket.S3DataSourceConfig)
        @test read_in isa Braket.S3DataSourceConfig
        @test read_in.config == s3d.config
    end
    @testset "DeviceConfig" begin
        dc = Braket.DeviceConfig("local:lightning")
        read_in = JSON3.read("""{"device": "local:lightning"}""", Braket.DeviceConfig)
        @test read_in.device == dc.device
    end
    @testset "StoppingCondition" begin
        sc = Braket.StoppingCondition(100)
        read_in = JSON3.read("""{"maxRuntimeInSeconds": 100}""", Braket.StoppingCondition)
        @test read_in isa Braket.StoppingCondition
        @test read_in.maxRuntimeInSeconds == sc.maxRuntimeInSeconds
    end
    @testset "InstanceConfig" begin
        ic = Braket.InstanceConfig("ml.m5.large", 30, 2)
        read_in = JSON3.read(JSON3.write(ic), Braket.InstanceConfig)
        @test read_in isa Braket.InstanceConfig
        @test read_in.instanceType == ic.instanceType
        @test read_in.volumeSizeInGb == ic.volumeSizeInGb
        @test read_in.instanceCount == ic.instanceCount
    end
end

