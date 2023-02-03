using AWS, AWSS3, Braket, JSON3, Test

@service S3 use_response_type=true

@testset "Quantum Job Creation" begin
    region = aws_get_region()
    account_id = aws_account_number(global_aws_config())
    # Asserts the job is failed with the output, checkpoints,
    # tasks not created in bucket and only input is uploaded to s3. Validate the
    # results/download results have the response raising RuntimeError. Also,
    # check if the logs displays the Assertion Error.
    @testset "Failed Quantum Job" begin
        job = AwsQuantumJob(
            "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
            joinpath(@__DIR__, "job_test_script.py"),
            entry_point="job_test_script:start_here",
            wait_until_complete=true,
            hyperparameters=Dict("test_case"=>"failed"),
        )

        job_name = name(job)
        pattern = Regex("^arn:aws:braket:$region:\\d12:job/$(job_name)")
        pattern_match = match(pattern, arn(job))

        # Check job is in failed state.
        @test state(job) == "FAILED"

        # Check whether the respective folder with files are created for script,
        # output, tasks and checkpoints.
        s3_bucket = "amazon-braket-$region-$(account_id)"
        keys = collect(s3_list_keys(s3_bucket, "jobs/$(job_name)/script/"))
        @test keys == ["jobs/$(job_name)/script/source.tar.gz"]

        # no results saved
        @test result(job) == Dict()

        mktempdir() do temp_dir
            redirect_stdio(stdout=joinpath(temp_dir, "out.txt"), stderr=joinpath(temp_dir, "err.txt")) do
                logs(job, wait=true)
            end
            log_data = read(joinpath(temp_dir, "out.txt"), String)
            errors = read(joinpath(temp_dir, "err.txt"), String)
            @test errors == ""
            logs_to_validate = [
                "Invoking script with the following command:",
                "/usr/local/bin/python3.7 braket_container.py",
                "Running Code As Process",
                "Test job started!!!!!",
                "AssertionError",
                "Code Run Finished",
                "\"user_entry_point\": \"braket_container.py\"",
            ]
            for data in logs_to_validate
                @test occursin(data, log_data)
            end
        end
        @test startswith(metadata(job)["failureReason"], "AlgorithmError: Job at job_test_script:start_here")
    end
    # Asserts the job is completed with the output, checkpoints, tasks and
    # script folder created in S3 for respective job. Validate the results are
    # downloaded and results are what we expect. Also, assert that logs contains all the
    # necessary steps for setup and running the job and is displayed to the user.
    @testset "Completed Quantum Job" begin
        job = AwsQuantumJob(
            "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
            joinpath(@__DIR__, "job_test_script.py"),
            entry_point="job_test_script:start_here",
            wait_until_complete=true,
            hyperparameters=Dict("test_case"=>"completed"),
        )
        job_name = name(job)
        pattern = Regex("^arn:aws:braket:$region:\\d12:job/$(job_name)")
        pattern_match = match(pattern, arn(job))

        # check job is in completed state.
        @test state(job) == "COMPLETED"

        # Check whether the respective folder with files are created for script,
        # output, tasks and checkpoints.
        s3_bucket = "amazon-braket-$region-$(account_id)"
        for (prefix, expected_key) in [
            ("jobs/$(job_name)/script/", Regex("jobs/$(job_name)/script/source.tar.gz")),
            ("jobs/$(job_name)/data/output/", Regex("jobs/$(job_name)/data/output/model.tar.gz")),
            #Regex("jobs/$(job_name)/tasks/[^/]*/results.json"),
            ("jobs/$(job_name)/checkpoints/", Regex("jobs/$(job_name)/checkpoints/$(job_name)_plain_data.json")),
            ("jobs/$(job_name)/checkpoints/", Regex("jobs/$(job_name)/checkpoints/$(job_name).json")),
        ]
            s3_keys = s3_list_keys(s3_bucket, prefix)
            @test any(!isnothing(match(expected_key, key)) for key in s3_keys)
        end

        # Check if checkpoint is uploaded in requested format.
        for (s3_key, expected_data) in [
            (
                "jobs/$(job_name)/checkpoints/$(job_name)_plain_data.json",
                """{
                    "braketSchemaHeader": {
                        "name": "braket.jobs_data.persisted_job_data",
                        "version": "1"
                    },
                    "dataDictionary": {"some_data": "abc"},
                    "dataFormat": "plaintext"
                }"""
            ),
            (
                "jobs/$(job_name)/checkpoints/$(job_name).json",
                """{
                    "braketSchemaHeader": {
                        "name": "braket.jobs_data.persisted_job_data",
                        "version": "1"
                    },
                    "dataDictionary": {"some_data": "gASVBwAAAAAAAACMA2FiY5Qu\n"},
                    "dataFormat": "pickled_v4"
                }"""
            ),
        ]
            @test JSON3.read(s3_get(s3_bucket, s3_key), Dict) == JSON3.read(expected_data, Dict)
        end
        # Check downloaded results exists in the file system after the call.
        downloaded_result = joinpath(job_name, Braket.RESULTS_FILENAME)
        current_dir = pwd()

        cd(mktempdir()) do
            download_result(job)
            @test isfile(Braket.RESULTS_TAR_FILENAME) && ispath(downloaded_result)
            # Check results match the expectations.
            @test result(job) == Dict("converged"=>true, "energy"=>-0.2)
        end
        mktempdir() do temp_dir
            redirect_stdio(stdout=joinpath(temp_dir, "out.txt"), stderr=joinpath(temp_dir, "err.txt")) do
                logs(job, wait=true)
            end
            log_data = read(joinpath(temp_dir, "out.txt"), String)
            errors = read(joinpath(temp_dir, "err.txt"), String)
            @test errors == ""
            logs_to_validate = [
                "Invoking script with the following command:",
                "/usr/local/bin/python3.7 braket_container.py",
                "Running Code As Process",
                "Test job started!!!!!",
                "Test job completed!!!!!",
                "Code Run Finished",
                "\"user_entry_point\": \"braket_container.py\"",
                "Reporting training SUCCESS",
            ]
            for data in logs_to_validate
                @test occursin(data, log_data)
            end
        end 
    end
end
