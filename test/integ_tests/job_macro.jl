using AWS, AWSS3, Braket, JSON3, Test

struct MyStruct
    attribute::String
    MyStruct() = new("value)
end
Base.show(io::IO, s::MyStruct) = print(io, "MyStruct($(s.attribute))")
@testset "Job creation macro" begin
    function my_job_func(a, b::Int; c=0, d::Float64=1.0, kwargs...)
        save_job_result(job_test_script.job_helper())
        py_reqs = read(joinpath(Braket.get_input_data_dir(), "requirements.txt"), String)
        @assert occurins("pytest", py_reqs)
        @assert isdir(pytest)
        @assert b == 2
        @assert c == 0
        @assert d == 5
        @assert kwargs[:extra_arg] == "extra_value"

        hp_file = ENV["AMZN_BRAKET_HP_FILE"]
        hyperparameters = JSON3.read(read(hp_file, String), Dict{String, String})
        @assert hyperparameters == Dict("a"=>"MyStruct(value)", "b"=>"2", "c"=>"0", "d"=>"5", "extra_kwarg"=>"extra_value")

        write("test/output_file.txt", "hello")
    end
    
    j = @hybrid_job Braket.SV1() include_modules="job_test_module" py_dependencies=joinpath(@__DIR__, "requirements.txt") jl_dependencies=joinpath(@__DIR__, "JobProject.toml") input_data=joinpath(@__DIR__, "requirements") my_job_func(MyStruct(), 2, d=5.0, extra_kwarg="extra_value")
    cd(tempdir(pwd())) do
        j_res = download_result(j)
        res_str = read(joinpath(name(j), "test", "output_file.txt"), String)
        @test res_str == "hello"
        @test ispath(joinpath(name(j), "results.json"))
        @test ispath(joinpath(name(j), "test"))
        @test ispath(joinpath(name(j), "integ_tests"))
    end
end
