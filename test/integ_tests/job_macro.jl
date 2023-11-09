using AWS, AWSS3, Braket, JSON3, Test

struct MyStruct
    attribute::String
end
MyStruct() = MyStruct("value")
Base.show(io::IO, s::MyStruct) = print(io, "MyStruct($(s.attribute))")

@testset "Job creation macro" begin
    @testset "Local" for local_mode ∈ (true, false)
        function my_job_func(a, b::Int; c=0, d::Float64=1.0, kwargs...)
            Braket.save_job_result(job_helper())
            py_reqs = read(joinpath(Braket.get_input_data_dir(), "requirements.txt"), String)
            @assert occursin("pytest", py_reqs)
            @assert a.attribute == "value"
            @assert b == 2
            @assert c == 0
            @assert d == 5
            @assert kwargs[:extra_kwarg] == "extra_value"
            # ensure using LinearAlgebra worked
            @assert size(triu(rand(2,2))) == (2,2)

            hyperparameters = Braket.get_hyperparameters()
            @assert isempty(hyperparameters)
            write("test/output_file.txt", "hello")
            return 0
        end

        py_deps = joinpath(@__DIR__, "requirements.txt")
        jl_deps = joinpath(@__DIR__, "JobProject.toml")
        input_data = joinpath(@__DIR__, "requirements")
        include_jl_files = joinpath(@__DIR__, "job_test_script.jl")
        j = @hybrid_job Braket.SV1() wait_until_complete=true as_local=local_mode include_modules="job_test_script" using_jl_pkgs="LinearAlgebra" include_jl_files=include_jl_files py_dependencies=py_deps jl_dependencies=jl_deps input_data=input_data my_job_func(MyStruct(), 2, d=5.0, extra_kwarg="extra_value")
        logs(j)
        @test_broken result(j)["status"] == "SUCCESS"
        try
            j_res = download_result(j)
            @test isdir(name(j))
            cd(name(j)) do
                res_str = read(joinpath("test", "output_file.txt"), String)
                @test res_str == "hello"
                @test ispath("results.json")
                @test ispath("test")
                @test_broken ispath(joinpath("test", "integ_tests"))
            end
         finally
            rm(name(j), recursive=true)
         end
     end
end
