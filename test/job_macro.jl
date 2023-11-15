using Braket, Test, Random, Dates, Tar, JSON3
using Mocking
Mocking.activate()

@testset "Job macro" begin
    @testset "Macro defaults" begin
        resp_dict = Dict("jobArn"=>"arn:job/fake", "GetCallerIdentityResult"=>Dict("Arn"=>"fake_arn", "Account"=>"000000"), "ListRolesResult"=>Dict("Roles"=>Dict("member"=>[Dict("RoleName"=>"AmazonBraketJobsExecutionRoleFake", "Arn"=>"fake_arn")])))
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
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO; kwargs...) = f(http_backend, request, response_stream)
        apply(req_patch) do
            function my_job_func(a, b; c)
                println(2)
                return 0
            end
            ENV["AMZN_BRAKET_OUT_S3_BUCKET"] = "fake_bucket"
            j = @hybrid_job my_job_func(0, 1, c=1)
            delete!(ENV, "AMZN_BRAKET_OUT_S3_BUCKET")
            @test arn(j) == "arn:job/fake"
        end
    end
    @testset "Hyperparameter sanitization" for (hyperparameter, expected) in (("with\nnewline", "with newline"),
                                                                              ("with weird chars: (&\$`)", "with weird chars: {+?'}"),
                                                                              (repeat('?', 2600), repeat('?', 2477)*"..."*repeat('?', 20)))
        @test Braket._sanitize(hyperparameter) == expected
    end
end
