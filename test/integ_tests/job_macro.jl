using AWS, AWSS3, Braket, JSON3, Test

struct MyStruct
    attribute::String
end
MyStruct() = MyStruct("value")
Base.show(io::IO, s::MyStruct) = print(io, "MyStruct($(s.attribute))")

@testset "Job creation macro" begin
    function my_job_func(a, b::Int; c=0, d::Float64=1.0, kwargs...)
        Braket.save_job_result(Dict("status"=>"SUCCESS"))
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
        @assert hyperparameters == Dict{String, Any}("_jl_args" => "[MyStruct{value}, 2]", "_jl_kwargs" => "(\"d=5.0\", \"extra_kwarg=\\\"extra_value\\\"\")")
        write("test/output_file.txt", "hello")
        return 0
    end

    py_deps = abspath(joinpath(@__DIR__, "requirements.txt"))
    jl_deps = abspath(joinpath(@__DIR__, "JobProject.toml"))
    input_data = abspath(joinpath(@__DIR__, "requirements"))
    j = @hybrid_job Braket.SV1() as_local=true include_modules="job_test_script" include_jl_modules="LinearAlgebra" py_dependencies=py_deps jl_dependencies=jl_deps input_data=input_data my_job_func(MyStruct(), 2, d=5.0, extra_kwarg="extra_value")
    logs(j)
    @test_broken result(j)["status"] == "SUCCESS"
    try
        cd(name(j)) do
            j_res = download_result(j)
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
