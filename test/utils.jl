using Braket, Mocking, Random, JSON3, Test

Mocking.activate()

@testset "utils" begin
    @testset "parse_s3_uri" begin
        @test Braket.parse_s3_uri("s3://fake_bucket/fake_path") == ("fake_bucket", "fake_path")
        @test Braket.parse_s3_uri("https://fake_bucket.s3.fake_bucket/fake_path") == ("fake_bucket", "fake_path")
        @test_throws ErrorException Braket.parse_s3_uri("s3:/fake/bad")
    end
    @testset "copy_s3_directory" begin
        function f(http_backend, request, response_stream)
            xml_str = ""
            if request.request_method == "GET"
                xml_str = """
                <?xml version="1.0" encoding="UTF-8"?>
                    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                        <Name>bucket</Name>
                        <Prefix/>
                        <KeyCount>205</KeyCount>
                        <MaxKeys>1000</MaxKeys>
                        <IsTruncated>false</IsTruncated>
                        <Contents>
                            <Key>my_blob.dat</Key>
                            <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                            <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
                            <Size>434234</Size>
                            <StorageClass>STANDARD</StorageClass>
                        </Contents>
                    </ListBucketResult>
                """
            else
                xml_str = """
                <?xml version="1.0" encoding="UTF-8"?>
                <CopyObjectResult>
                   <LastModified>2009-10-12T17:50:30.000Z</LastModified>
                   <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
                </CopyObjectResult>
                """
            end
            return Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/xml"]), IOBuffer(xml_str))
        end
        req_patch  = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = f(http_backend, request, response_stream)
        apply(req_patch) do
            r = Braket.copy_s3_directory("s3://fake_source/my_blob", "s3://fake_dest/my_blob")
            @test isnothing(r)
        end
    end
    @testset "is_s3_uri" begin
        @test Braket.is_s3_uri("s3://fake_bucket/fake_path")
        @test !Braket.is_s3_uri("not.a.real.uri")
    end
    @testset "default_bucket" begin
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
                db = Braket.default_bucket()
                @test db == "amazon-braket-fake_region-000000"
            end
        end
    end
    @testset "upload_to_s3" begin
        mktemp() do fn, f
            uri = "s3://fake_bucket/fake_path"
            write(f, "blah")
            req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer())
            apply(req_patch) do
                r = Braket.upload_to_s3(fn, uri)
                @test isnothing(r)
            end
        end
    end
    @testset "upload_local_data" begin
        @testset "directory prefix" begin
            to_upload = ["input.csv", "input-2.csv", joinpath("input", "data.txt"), joinpath("input-dir", "data.csv")]
            no_upload = ["my-input.csv", joinpath("my-dir", "input.csv")]
            upload_uri = ["s3://my-bucket/dir/input.csv", "s3://my-bucket/dir/input-2.csv", "s3://my-bucket/dir/input/data.txt", "s3://my-bucket/dir/input-dir/data.csv"]
            s3_prefix  = "s3://my-bucket/dir/input"
            cd(mktempdir()) do
                mkdir("input")
                mkdir("input-dir")
                mkdir("my-dir")
                write("input.csv", "a,b,c\n")
                write("input-2.csv", "d,e,f\n")
                write(joinpath("input","data.txt"), "my_data\n")
                write(joinpath("input-dir", "data.csv"), "g,h,i\n")
                write("my-input.csv", "j,k,l\n")
                write(joinpath("my-dir", "input.csv"), "m,n,o\n")
                @testset "local path" begin
                    all_counted = 0
                    req_patch   = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = ("s3:/"*request.resource ∈ upload_uri && (all_counted += 1); return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer()))
                    apply(req_patch) do
                        Braket.upload_local_data("input", s3_prefix)
                    end
                    @test all_counted == length(upload_uri)
                end
                @testset "absolute path" begin
                    all_counted = 0
                    req_patch   = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = ("s3:/"*request.resource ∈ upload_uri && (all_counted += 1); return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer()))
                    apply(req_patch) do
                        Braket.upload_local_data(joinpath(pwd(), "input"), s3_prefix)
                    end
                    @test all_counted == length(upload_uri)
                end
            end
        end
        @testset "file prefix" begin
            to_upload = ["input.py"]
            no_upload = [joinpath("input", "input.py"), "input.csv"]
            upload_uri = ["s3://my-bucket/dir/input.py"]
            s3_prefix  = "s3://my-bucket/dir/input.py"
            cd(mktempdir()) do
                mkdir("input")
                write("input.py", "print('hello world')\n")
                write(joinpath("input", "input.py"), "print('hello world2')\n")
                @testset "local path" begin
                    all_counted = 0
                    req_patch   = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = ("s3:/"*request.resource ∈ upload_uri && (all_counted += 1); return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer()))
                    apply(req_patch) do
                        Braket.upload_local_data("input.py", s3_prefix)
                    end
                    @test all_counted == length(upload_uri)
                end
                @testset "absolute path" begin
                    all_counted = 0
                    req_patch   = @patch Braket.AWS._http_request(http_backend, request::Braket.AWS.Request, response_stream::IO) = ("s3:/"*request.resource ∈ upload_uri && (all_counted += 1); return Braket.AWS.Response(Braket.HTTP.Response(200), IOBuffer()))
                    apply(req_patch) do
                        Braket.upload_local_data(joinpath(pwd(), "input.py"), s3_prefix)
                    end
                    @test all_counted == length(upload_uri)
                end
            end
        end
        @testset "error" begin
            prefix = joinpath("/", randstring(10), randstring(10))
            @test_throws ErrorException Braket.upload_local_data(prefix, randstring(10))
        end
    end
end
