using Braket, Test, Random, Dates, Tar, JSON3
using Mocking
Mocking.activate()

@testset "Job macro" begin
    @testset "Macro defaults" begin
        resp_dict = Dict("jobArn"=>"arn:job/fake")
        req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
        apply(req_patch) do
            function my_job_func(a, b; c)
                println(2)
                return 0
            end
            j = @hybrid_job my_job_func(0, 1, c=1)
            @test arn(j) == "arn:job/fake"
        end
    end
    @testset "Non-default macro options" begin

    end
    @testset "Hyperparameter sanitization" for (hyperparameter, expected) in (("with\nnewline", "with newline"),
                                                                              ("with weird chars: (&$`)", "with weird chars: {+?'}"),
                                                                              (repeat('?', 2600), repeat('?', 2477)*"..."*repeat('?', 20)))
        @test Braket._sanitize(hyperparameter) == expected
    end
end
