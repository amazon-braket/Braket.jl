using Braket, Test, Mocking, OrderedCollections, Base64, JSON3
dev_arn = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"

Mocking.activate()
script_mode_dict = OrderedDict("s3Uri"=>"fake_uri", "entryPoint"=>"fake_entry", "compressionType"=>"fake_type")
@testset "Local Jobs" begin
    @test Braket.get_env_hyperparameters() == Dict("AMZN_BRAKET_HP_FILE"=>"/opt/braket/input/config/hyperparameters.json")
    @test Braket.get_env_input_data()      == Dict("AMZN_BRAKET_INPUT_DIR"=>"/opt/braket/input/data")
    @test Braket.get_env_script_mode_config(script_mode_dict) == Dict("AMZN_BRAKET_SCRIPT_S3_URI"=>"fake_uri", "AMZN_BRAKET_SCRIPT_ENTRY_POINT"=>"fake_entry", "AMZN_BRAKET_SCRIPT_COMPRESSION_TYPE"=>"fake_type")
    @test Braket.is_s3_dir("fake/", ["key"])
    @test Braket.is_s3_dir("fake", ["fake/key"])
    @test !Braket.is_s3_dir("fake", ["fakekey"])
    lj = LocalQuantumJob("local:job/fake", run_log="fake_log\n")
    @test Braket.run_log(lj) == "fake_log\n"
    @test arn(lj) == "local:job/fake"
    @test name(lj) == "fake"
    @test state(lj) == "COMPLETED"
    @test state(lj, Val(true)) == "COMPLETED"
    @test state(lj, Val(false)) == "COMPLETED"
    @test isnothing(cancel(lj))
    @test isnothing(metadata(lj))
    @test isnothing(metadata(lj, Val(true)))
    @test isnothing(Braket.download_result(lj))
    @test_throws ArgumentError LocalQuantumJob("notlocal:job/")
    @test_throws ErrorException LocalQuantumJob("local:job/fake")

    @test Braket.capture_docker_cmd(`echo hello`) == ("hello", "", 0)

    @testset "mocked local job" begin
        # do something bad here
        Braket.capture_docker_cmd(c::Cmd) = ("success", "", 0)
        creds = Braket.AWS.AWSCredentials("fake_access_key_id", "fake_secret_key", "fake_token")
        conf = Braket.AWS.AWSConfig(region="us-west-2", creds=creds)
        job_name = "fake_job_name"
        image_uri = Braket.retrieve_image(Braket.BASE, conf)
        token = "fake_token"
        @test occursin(".dkr.ecr.us-west-2.amazonaws.com/", image_uri)
        @testset "pull_image" begin
            resp_dict = Dict("authorizationData"=>[Dict("authorizationToken"=>base64encode(token))])
            f(http_backend, request, response_stream) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                Braket.pull_image(image_uri, conf)
            end
        end
        @testset "Successful input data download" begin
            args = (algo_spec=Dict("scriptModeConfig"=>script_mode_dict),
                    params=Dict("hyperParameters"=>Dict("cool"=>"beans"), "checkpointConfig"=>Dict("localPath"=>"fake_local_path"), "inputDataConfig"=>[Dict("channelName"=>"fake_channel", "dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>"s3://fake_bucket/fake_input")))]),
                    job_name=job_name,
                    out_conf=Dict("s3Path"=>"s3://fake_s3_bucket/fake_s3_path"),
                    dev_conf=Dict("device"=>"fake_device")
                )
            function f(http_backend, request, response_stream)
                xml_str = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                        <Name>fake_bucket</Name>
                        <Prefix>fake_channel</Prefix>
                        <KeyCount>205</KeyCount>
                        <MaxKeys>1000</MaxKeys>
                        <IsTruncated>false</IsTruncated>
                        <Contents>
                            <Key>fake_input</Key>
                            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                            <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                            <Size>434234</Size>
                            <StorageClass>STANDARD</StorageClass>
                        </Contents>
                    </ListBucketResult>
                    """
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                ljc = Braket.LocalJobContainer(image_uri, args, config=conf)
                @test name(ljc) == "success"
                ref_dict = Dict("AWS_ACCESS_KEY_ID"=>creds.access_key_id,
                                "AWS_SECRET_ACCESS_KEY"=>creds.secret_key,
                                "AWS_SESSION_TOKEN"=>creds.token,
                                "AWS_DEFAULT_REGION"=>Braket.AWS.region(conf),
                                "AMZN_BRAKET_JOB_NAME"=>job_name,
                                "AMZN_BRAKET_DEVICE_ARN"=>"fake_device",
                                "AMZN_BRAKET_JOB_RESULTS_DIR"=>"/opt/braket/model",
                                "AMZN_BRAKET_CHECKPOINT_DIR"=>"fake_local_path",
                                "AMZN_BRAKET_OUT_S3_BUCKET"=>"fake_s3_bucket",
                                "AMZN_BRAKET_TASK_RESULTS_S3_URI"=>"s3://fake_s3_bucket/jobs/$job_name/tasks",
                                "AMZN_BRAKET_JOB_RESULTS_S3_PATH"=>joinpath("fake_s3_path", job_name, "output"),
                                "AMZN_BRAKET_HP_FILE"=>"/opt/braket/input/config/hyperparameters.json",
                                "AMZN_BRAKET_SCRIPT_S3_URI"=>script_mode_dict["s3Uri"],
                                "AMZN_BRAKET_SCRIPT_ENTRY_POINT"=>script_mode_dict["entryPoint"],
                                "AMZN_BRAKET_SCRIPT_COMPRESSION_TYPE"=>script_mode_dict["compressionType"],
                                "AMZN_BRAKET_INPUT_DIR"=>"/opt/braket/input/data",
                            )
                for k in keys(ljc.env)
                    @test ljc.env[k] == ref_dict[k]
                end
                for k in keys(ref_dict)
                    @test ljc.env[k] == ref_dict[k]
                end
                @test ljc.env == ref_dict
                ljc = Braket.run_local_job!(ljc)
                @test ljc.run_log == "successsuccesssuccesssuccesssuccess"
            end
        end
        @testset "Successful input data download with force_update" begin
            args = (algo_spec=Dict("scriptModeConfig"=>script_mode_dict),
                    params=Dict("hyperParameters"=>Dict("cool"=>"beans"), "checkpointConfig"=>Dict("localPath"=>"fake_local_path"), "inputDataConfig"=>[Dict("channelName"=>"fake_channel", "dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>"s3://fake_bucket/fake_input")))]),
                    job_name=job_name,
                    out_conf=Dict("s3Path"=>"s3://fake_s3_bucket/fake_s3_path"),
                    dev_conf=Dict("device"=>"fake_device")
                )
            function f(http_backend, request, response_stream)
                xml_str = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                        <Name>fake_bucket</Name>
                        <Prefix>fake_channel</Prefix>
                        <KeyCount>205</KeyCount>
                        <MaxKeys>1000</MaxKeys>
                        <IsTruncated>false</IsTruncated>
                        <Contents>
                            <Key>fake_input</Key>
                            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                            <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                            <Size>434234</Size>
                            <StorageClass>STANDARD</StorageClass>
                        </Contents>
                    </ListBucketResult>
                    """
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                ljc = Braket.LocalJobContainer(image_uri, args, config=conf, force_update=true)
                @test name(ljc) == "success"
                ref_dict = Dict("AWS_ACCESS_KEY_ID"=>creds.access_key_id,
                                "AWS_SECRET_ACCESS_KEY"=>creds.secret_key,
                                "AWS_SESSION_TOKEN"=>creds.token,
                                "AWS_DEFAULT_REGION"=>Braket.AWS.region(conf),
                                "AMZN_BRAKET_JOB_NAME"=>job_name,
                                "AMZN_BRAKET_DEVICE_ARN"=>"fake_device",
                                "AMZN_BRAKET_JOB_RESULTS_DIR"=>"/opt/braket/model",
                                "AMZN_BRAKET_CHECKPOINT_DIR"=>"fake_local_path",
                                "AMZN_BRAKET_OUT_S3_BUCKET"=>"fake_s3_bucket",
                                "AMZN_BRAKET_TASK_RESULTS_S3_URI"=>"s3://fake_s3_bucket/jobs/$job_name/tasks",
                                "AMZN_BRAKET_JOB_RESULTS_S3_PATH"=>joinpath("fake_s3_path", job_name, "output"),
                                "AMZN_BRAKET_HP_FILE"=>"/opt/braket/input/config/hyperparameters.json",
                                "AMZN_BRAKET_SCRIPT_S3_URI"=>script_mode_dict["s3Uri"],
                                "AMZN_BRAKET_SCRIPT_ENTRY_POINT"=>script_mode_dict["entryPoint"],
                                "AMZN_BRAKET_SCRIPT_COMPRESSION_TYPE"=>script_mode_dict["compressionType"],
                                "AMZN_BRAKET_INPUT_DIR"=>"/opt/braket/input/data",
                            )
                for k in keys(ljc.env)
                    @test ljc.env[k] == ref_dict[k]
                end
                for k in keys(ref_dict)
                    @test ljc.env[k] == ref_dict[k]
                end
                @test ljc.env == ref_dict
            end
        end
        @testset "Duplicate channel name" begin
            args = (algo_spec=Dict("scriptModeConfig"=>script_mode_dict),
                    params=Dict("hyperParameters"=>Dict("cool"=>"beans"), "checkpointConfig"=>Dict("localPath"=>"fake_local_path"),
                                "inputDataConfig"=>[Dict("channelName"=>"fake_channel", "dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>"s3://fake_bucket/fake_input"))), Dict("channelName"=>"fake_channel", "dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>"s3://fake_bucket/fake_input2")))]),
                    job_name=job_name,
                    out_conf=Dict("s3Path"=>"s3://fake_s3_bucket/fake_s3_path"),
                    dev_conf=Dict("device"=>"fake_device")
                )
            function f(http_backend, request, response_stream)
                xml_str = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                        <Name>fake_bucket</Name>
                        <Prefix>fake_channel</Prefix>
                        <KeyCount>205</KeyCount>
                        <MaxKeys>1000</MaxKeys>
                        <IsTruncated>false</IsTruncated>
                        <Contents>
                            <Key>fake_input</Key>
                            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                            <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                            <Size>434234</Size>
                            <StorageClass>STANDARD</StorageClass>
                        </Contents>
                    </ListBucketResult>
                    """
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                @test_throws ErrorException("Duplicate channel names not allowed for input data: fake_channel") Braket.LocalJobContainer(image_uri, args, config=conf)
            end
        end
        @testset "run a facsimile LocalQuantumJob" begin
            function f(http_backend, request, response_stream)
                xml_str = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                        <Name>fake_bucket</Name>
                        <Prefix>fake_channel</Prefix>
                        <KeyCount>205</KeyCount>
                        <MaxKeys>1000</MaxKeys>
                        <IsTruncated>false</IsTruncated>
                        <Contents>
                            <Key>fake_input</Key>
                            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                            <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                            <Size>434234</Size>
                            <StorageClass>STANDARD</StorageClass>
                        </Contents>
                    </ListBucketResult>
                    """
                return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
            end
            req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
            apply(req_patch) do
                cd(mktempdir()) do
                    write("local_module.py", "print(1)\n")
                    lqj = LocalQuantumJob("local:fake_dev", "local_module.py", code_location="s3://fake_bucket/fake_code", checkpoint_config=Braket.CheckpointConfig("/opt/jobs/checkpoints", nothing), output_data_config=Braket.OutputDataConfig("s3://fake_bucket/fake_path"), config=conf)
                    @test state(lqj) == "COMPLETED"
                    mktemp() do f, io
                        redirect_stdout(io) do
                            Braket.logs(lqj)
                        end
                        seekstart(io)
                        str = read(io, String)
                        @test str == "successsuccesssuccesssuccesssuccesssuccesssuccess\n"
                    end
                    @testset "Metrics" begin
                        lqj.run_log = "Metrics - timestamp=\"2000-01-01T00:00:00\"; FakeKey=1;" * "\n" * "Metrics - timestamp=\"2000-01-01T00:01:00\"; FakeKey=2;\n"
                        mets = Braket.metrics(lqj)
                        @test mets["FakeKey"] == ["1", "2"]
                    end
                end
            end
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
                job_name = "fake_name"
                fake_arn = "local:job/"*job_name
                cd(mktempdir()) do
                    mkdir(job_name)
                    write(joinpath(job_name, "results.json"), res)
                    lj = LocalQuantumJob(fake_arn)
                    r   = result(lj)
                    raw = Braket.parse_raw_schema(res)
                    @test r == raw.dataDictionary
                end
            end
            @testset "unsuccessfully get results" begin
                res = """{
                    "braketSchemaHeader": {
                        "name": "braket.jobs_data.persisted_job_data",
                        "version": "1"
                    },
                    "dataDictionary": {"converged": true, "energy": -0.2},
                    "dataFormat": "plaintext"
                }"""
                buf = ""
                job_name = "fake_name"
                fake_arn = "local:job/"*job_name
                cd(mktempdir()) do
                    mkdir(job_name)
                    write(joinpath(job_name, "results.json"), res)
                    lj = LocalQuantumJob(fake_arn)
                    rm(joinpath(job_name, "results.json"))
                    @test_throws ErrorException("unable to find results in the local job directory $job_name.") result(lj)
                end
            end
        end
    end
    @testset "errors in run_local_job!" begin
        Braket.capture_docker_cmd(c::Cmd) = ("success", "", 0)
        creds = Braket.AWS.AWSCredentials("fake_access_key_id", "fake_secret_key", "fake_token")
        conf = Braket.AWS.AWSConfig(region="us-west-2", creds=creds)
        job_name = "fake_job_name"
        image_uri = Braket.retrieve_image(Braket.BASE, conf)
        token = "fake_token"
        args = (algo_spec=Dict("scriptModeConfig"=>script_mode_dict),
                    params=Dict("hyperParameters"=>Dict("cool"=>"beans"), "checkpointConfig"=>Dict("localPath"=>"fake_local_path"), "inputDataConfig"=>[Dict("channelName"=>"fake_channel", "dataSource"=>Dict("s3DataSource"=>Dict("s3Uri"=>"s3://fake_bucket/fake_input")))]),
                    job_name=job_name,
                    out_conf=Dict("s3Path"=>"s3://fake_s3_bucket/fake_s3_path"),
                    dev_conf=Dict("device"=>"fake_device")
                )
        function f(http_backend, request, response_stream)
            xml_str = """
                <?xml version="1.0" encoding="UTF-8"?>
                <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                    <Name>fake_bucket</Name>
                    <Prefix>fake_channel</Prefix>
                    <KeyCount>205</KeyCount>
                    <MaxKeys>1000</MaxKeys>
                    <IsTruncated>false</IsTruncated>
                    <Contents>
                        <Key>fake_input</Key>
                        <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                        <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                        <Size>434234</Size>
                        <StorageClass>STANDARD</StorageClass>
                    </Contents>
                </ListBucketResult>
                """
            return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
        end
        ljc = nothing
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
        apply(req_patch) do
            ljc = Braket.LocalJobContainer(image_uri, args, config=conf)
            @test name(ljc) == "success"
        end
        Braket.capture_docker_cmd(c::Cmd) = ("braket_container.py", "sadness", 1)
        apply(req_patch) do
            ljc = Braket.run_local_job!(ljc)
            @test ljc.run_log == "successsuccesssuccesssuccessRun local job process exited with code: 1sadness"
        end
        @testset "errors in copying to/from container" begin
            ljc.run_log = ""
            Braket.capture_docker_cmd(c::Cmd) = ("", "copy_from sadness", 1)
            @test_throws ErrorException("copy_from sadness") Braket.copy_from_container!(ljc, "fake_src", "fake_dst")
            ljc.run_log = ""
            Braket.capture_docker_cmd(c::Cmd) = ("", "copy_to sadness", 1)
            @test_throws ErrorException("copy_to sadness") Braket.copy_to_container!(ljc, "fake_src", "fake_dir/fake_dst")
            ljc.run_log = ""
            Braket.capture_docker_cmd(c::Cmd) = c[2] == "cp" ? ("", "copy_to sadness", 1) : ("", "", 0)
            @test_throws ErrorException("copy_to sadness") Braket.copy_to_container!(ljc, "fake_src", "fake_dir/fake_dst")
        end
    end
    @testset "start_container" begin
        call_count = 0
        Braket.pull_image(image_uri::String, config::Braket.AWS.AWSConfig) = nothing
        function Braket.capture_docker_cmd(c::Cmd)
            if call_count == 0
                call_count += 1
                return ("", "", 0)
            elseif call_count == 1
                call_count += 1
                return ("fake_name", "", 0)
            elseif call_count == 2
                return ("fake_container_name", "", 0)
            else
                return ("", "", 0)
            end
        end
        job_name = "fake_job_name"
        args = (algo_spec=Dict("scriptModeConfig"=>script_mode_dict),
            params=Dict("hyperParameters"=>Dict("cool"=>"beans"),
                        "checkpointConfig"=>Dict("localPath"=>"fake_local_path")),
            job_name=job_name,
            out_conf=Dict("s3Path"=>"s3://fake_s3_bucket/fake_s3_path"),
            dev_conf=Dict("device"=>"fake_device")
        )
        ljc = Braket.LocalJobContainer("fake_uri", args)
        @test name(ljc) == "fake_container_name"
    end
end
