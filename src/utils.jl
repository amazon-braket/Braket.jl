function parse_s3_uri(s::String)
    m1 = match(r"^https://([^./]+).[sS]3.[^/]+/(.*)$", s)
    m2 = match(r"^[sS]3://([^./]+)/(.*)$", s)
    s3_uri_match = isnothing(m1) ? m2 : m1
    try
        isnothing(s3_uri_match) && throw(ErrorException(""))
        bucket, key = s3_uri_match[1], s3_uri_match[2]
        (isnothing(bucket) || isnothing(key)) && throw(ErrorException(""))
        return String(bucket), String(key)
    catch
        throw(ErrorException("$s is not a valid S3 URI."))
    end
end

function is_s3_uri(s::String)
    try
        parse_s3_uri(s)
        return true
    catch
        return false
    end
end

function construct_s3_uri(bucket::String, dirs::String...)
    isempty(dirs) && throw(ArgumentError("not a valid S3 location: s3://$bucket"))
    return "s3://" * bucket * "/" * chop(prod(d*"/" for d in dirs), tail=1)
end

function default_bucket()
    haskey(ENV, "AMZN_BRAKET_OUT_S3_BUCKET") && return ENV["AMZN_BRAKET_OUT_S3_BUCKET"]
    default = "amazon-braket-" * aws_get_region() * "-" * aws_account_number(global_aws_config())
    default ∉ s3_list_buckets() && s3_create_bucket(default)
    return default
end

function upload_to_s3(fn::String, s3_uri::String)
    bucket, key = parse_s3_uri(s3_uri)
    s3_put(bucket, key, read(fn), "application/octet-stream")
    return
end

function upload_local_data(local_prefix::String, s3_prefix::String)
    base_dir        = isabspath(local_prefix) ? joinpath(splitpath(local_prefix)[1:end-1]...) : pwd()
    relative_prefix = isabspath(local_prefix) ? relpath(local_prefix, base_dir) : local_prefix
    @debug "Uploading local data with relative prefix $relative_prefix and base_dir $base_dir"
    isfile(relative_prefix) && return upload_to_s3(relative_prefix, s3_prefix)
    isdir(base_dir) || throw(ErrorException("uploading data $local_prefix to $s3_prefix failed!"))
    for (root, dirs, files) in walkdir(base_dir)
        fn_to_uri = Dict{String, String}()
        if root == base_dir
            fns = filter(x->startswith(x, relative_prefix), files)
            for fn in fns
                fn_to_uri[joinpath(base_dir, fn)] = replace(fn, relative_prefix=>s3_prefix)
            end
        elseif startswith(relpath(root, base_dir), relative_prefix)
            fns = map(fn->joinpath(relpath(root, base_dir), fn), files)
            for fn in fns
                fn_to_uri[joinpath(base_dir, fn)] = replace(fn, relative_prefix=>s3_prefix)
            end
        end
        for (fn, uri) in fn_to_uri
            @debug "$fn, is file? $(isfile(fn))"
            if !Sys.iswindows()
                @debug "Uploading $fn to S3 URI $uri"
                upload_to_s3(fn, uri)
            else
                upload_to_s3(fn, replace(uri, "\\"=>"/"))
            end
        end
    end
end

function copy_s3_directory(src_path::String, dst_path::String)
    src_path == dst_path && return
    src_bucket, src_prefix = parse_s3_uri(src_path)
    dst_bucket, dst_prefix = parse_s3_uri(dst_path)

    for key in s3_list_keys(src_bucket, src_prefix)
        s3_copy(src_bucket, key, to_bucket=dst_bucket, to_path=replace(key, src_prefix=>dst_prefix, count=1))
    end
    return
end

function complex_matrix_to_ir(m::Matrix{T}) where {T<:Complex}
    mat = Vector{Vector{Vector{real(T)}}}(undef, size(m, 1))
    for row in 1:size(m, 1)
        mat[row] = Vector{Vector{T}}(undef, size(m, 2))
        for col in 1:size(m, 2)
            mat[row][col] = [real(m[row, col]), imag(m[row, col])]
        end
    end
    return mat
end

function complex_matrix_from_ir(mat::Vector{Vector{Vector{T}}}) where {T<:Number}
    m = zeros(complex(T), length(mat), length(mat))
    for ii in 1:length(mat), jj in 1:length(mat)
        m[ii,jj] = complex(mat[ii][jj][1], mat[ii][jj][2])
    end
    return m
end

function complex_matrix_from_ir(mat::Vector{Vector{Vector{Any}}})
    m = zeros(ComplexF64, length(mat), length(mat))
    for ii in 1:length(mat), jj in 1:length(mat)
        m[ii,jj] = complex(mat[ii][jj][1], mat[ii][jj][2])
    end
    return m
end
