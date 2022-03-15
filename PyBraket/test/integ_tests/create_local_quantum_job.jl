using Braket, JSON3, PyBraket, PythonCall, Test

using PythonCall: pybuiltins

@testset "Local Quantum Job" begin
    @testset "Completed" begin
        absolute_source_module = joinpath(@__DIR__, "job_test_script.py")
        current_dir = pwd()
        cd(mktempdir()) do
            job = LocalJob(
                "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
                source_module=absolute_source_module,
                entry_point="job_test_script:start_here",
                hyperparameters=Dict("test_case"=>"completed")
            )

            job_name = name(job)
            pattern = Regex("^local:job/$(job_name)")
            match(pattern, arn(job))

            @test state(job) == "COMPLETED"
            @test isdir(job_name)

            # Check results match the expectations.
            @test ispath("$(job_name)/results.json")
            res = result(job)
            @test PythonCall.pyconvert(Bool, (res == pydict(Dict("converged"=>true, "energy"=>-0.2))))

            # Validate checkpoint files and data
            @test ispath("$(job_name)/checkpoints/$(job_name).json")
            @test ispath("$(job_name)/checkpoints/$(job_name)_plain_data.json")
            for (file_name, expected_data) in [
                (
                    "$(job_name)/checkpoints/$(job_name)_plain_data.json",
                    """{
                        "braketSchemaHeader": {
                            "name": "braket.jobs_data.persisted_job_data",
                            "version": "1"
                        },
                        "dataDictionary": {"some_data": "abc"},
                        "dataFormat": "plaintext"
                    }""",
                ),
                (
                    "$(job_name)/checkpoints/$(job_name).json",
                    """{
                        "braketSchemaHeader": {
                            "name": "braket.jobs_data.persisted_job_data",
                            "version": "1"
                        },
                        "dataDictionary": {"some_data": "gASVBwAAAAAAAACMA2FiY5Qu\n"},
                        "dataFormat": "pickled_v4"
                    }""",
                ),
            ]
                @test JSON3.read(read(file_name, String), Dict) == JSON3.read(expected_data, Dict)
            end
            # Capture logs
            @test ispath("$(job_name)/log.txt")
            mktempdir() do temp_dir
                redirect_stdio(stdout=joinpath(temp_dir, "out.txt"), stderr=joinpath(temp_dir, "err.txt")) do
                    logs(job)
                end
                log_data = read(joinpath(temp_dir, "out.txt"), String)
                errors = read(joinpath(temp_dir, "err.txt"), String)
                logs_to_validate = [
                    "Beginning Setup",
                    "Running Code As Process",
                    "Test job started!!!!!",
                    "Test job completed!!!!!",
                    "Code Run Finished",
                ]
    
                for data in logs_to_validate
                    @test occursin(data, log_data)
                end
            end
        end
    end
    @testset "failed" begin
        absolute_source_module = joinpath(@__DIR__, "job_test_script.py")
        current_dir = pwd()
        cd(mktempdir()) do
            job = LocalJob(
                "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
                source_module=absolute_source_module,
                entry_point="job_test_script:start_here",
                hyperparameters=Dict("test_case"=>"failed")
            )

            job_name = name(job)
            pattern = Regex("^local:job/$(job_name)")
            match(pattern, arn(job))

            @test state(job) == "COMPLETED"
            @test isdir(job_name)

            # Check no files are populated in checkpoints folder.
            @test isempty(readdir("$(job_name)/checkpoints"))

            # Check results match the expectations.
            error_message = "Unable to find results in the local job directory $(job_name)."
            try
                result(job)
            catch e
                @test PythonCall.pyisinstance(e, pybuiltins.ValueError)
                @test PythonCall.pyconvert(String, pystr(e)) == error_message
            end

            # Capture logs
            @test ispath("$(job_name)/log.txt")
            mktempdir() do temp_dir
                redirect_stdio(stdout=joinpath(temp_dir, "out.txt"), stderr=joinpath(temp_dir, "err.txt")) do
                    logs(job)
                end
                log_data = read(joinpath(temp_dir, "out.txt"), String)
                errors = read(joinpath(temp_dir, "err.txt"), String)
                logs_to_validate = [
                    "Beginning Setup",
                    "Running Code As Process",
                    "Test job started!!!!!",
                    "Code Run Finished",
                ]
                for data in logs_to_validate
                    @test occursin(data, log_data)
                end
            end
        end
    end
end