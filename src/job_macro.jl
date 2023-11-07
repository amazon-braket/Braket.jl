using CodeTracking, JLD2

"""Sanitize forbidden characters from hyperparameter strings"""
function _sanitize(hyperparameter)
    # replace forbidden characters with close matches
    # , not technically forbidden, but to avoid mismatched parens
    sanitized = replace(hyperparameter, "\n"=>" ", "\$"=>"?", "("=>"{", "&"=>"+", "`"=>"'", ")"=>"}")
    # max allowed length for a hyperparameter is 2500
    # show as much as possible, including the final 20 characters
    length(sanitized) > 2500 && return "$(sanitized[1:2500-23])...$(sanitized[end-19:end])"
    return sanitized
end


function _kwarg_to_string(kw)
    val = kw[2] isa String ? "\""*kw[2]*"\"" : string(kw[2])
    return string(kw[1])*"="*val
end

"""
Captures the arguments and keyword arguments of
`entry_point` as hyperparameters for the Job.
"""
function _log_hyperparameters(f_args, f_kwargs)
    hyperparams = Dict{String, Any}("_jl_args"=>"["*join(string.(f_args), ", ")*"]", "_jl_kwargs"=>_kwarg_to_string.(f_kwargs))
    sanitized_hyperparameters = Dict(name=>_sanitize(param) for (name, param) in hyperparams)
    return sanitized_hyperparameters 
end

function matches(prefix::String)
    possible_paths = readdir(dirname(abspath(prefix)))
    possible_paths = isabspath(prefix) ? [joinpath(dirname(abspath(prefix)), path) for path in possible_paths] : possible_paths
    prefixed_paths = filter(path->startswith(path, prefix), possible_paths)
    @debug "Possible paths: $possible_paths"
    @debug "Prefix: $prefix, Prefixed paths: $prefixed_paths"
    @debug "\n\n"
    return prefixed_paths
end
is_prefix(path::String) = length(matches(path)) > 1 || !ispath(path)
is_prefix(path) = false
function _process_input_data(input_data::Union{String, Dict})
    isempty(input_data) && (input_data = Dict())
    input_data isa Dict || (input_data = Dict("input"=>input_data))
    prefix_channels = Set{String}()
    directory_channels = Set{String}()
    file_channels = Set{String}()
    for (channel, data) in input_data
        @debug "Channel $channel, data $data"
        if is_s3_uri(string(data))
            channel_arg = channel != "input" ? "channel=$channel" : ""
            @warn "Input data channels mapped to an S3 source will not be available in the working directory. Use `get_input_data_dir($channel_arg)` to read input data from S3 source inside the job container."
        elseif is_prefix(data)
            @debug "prefix channel"
            union!(prefix_channels, [channel])
        elseif isdir(data)
            @debug "dir channel"
            union!(directory_channels, [channel])
        else
            @debug "file channel"
            union!(file_channels, [channel])
        end
    end
    @debug "Generating prefix matches"
    for channel in prefix_channels
        @debug "Channel: $channel"
        @debug "Data: $(input_data[channel])"
        @debug "Matches: $( matches(input_data[channel]) )" 
    end
    prefix_matches = Dict(channel=>matches(input_data[channel]) for channel in prefix_channels)
    prefix_matches_str = "{" * join(["$k: $v" for (k,v) in prefix_matches] , ", ")  * "}"
    @debug "Prefix matches: $prefix_matches"
    @debug "Prefix matches string: $prefix_matches_str"

    prefix_channels_str = "{" * join(prefix_channels, ", ") * "}"
    directory_channels_str = "{" * join(directory_channels, ", ") * "}"
    input_data_items = [(channel, relpath(input_data[channel])) for channel in filter(ch->ch∈union(prefix_channels, directory_channels, file_channels), collect(keys(input_data)))]
    @debug "Input data items: $input_data_items"
    @debug "\n\n"
    input_data_items_str = "[" * join(string.(input_data_items), ", ") * "]"
    return """ 
    from pathlib import Path
    from braket.jobs import get_input_data_dir


    \"\"\"Create symlink from input_link_path to input_data_path.\"\"\"
    def make_link(input_link_path, input_data_path, links):
        input_link_path.parent.mkdir(parents=True, exist_ok=True)
        input_link_path.symlink_to(input_data_path)
        print(input_link_path, '->', input_data_path)
        links[input_link_path] = input_data_path


    def link_input():
        links = {}
        dirs = set()
        # map of data sources to lists of matched local files
        prefix_matches = $prefix_matches_str

        for channel, data in $input_data_items_str:

            if channel in $prefix_channels_str:
                # link all matched files
                for input_link_name in prefix_matches[channel]:
                    input_link_path = Path(input_link_name)
                    input_data_path = Path(get_input_data_dir(channel)) / input_link_path.name
                    make_link(input_link_path, input_data_path, links)

            else:
                input_link_path = Path(data)
                if channel in $directory_channels_str:
                    # link directory source directly to input channel directory
                    input_data_path = Path(get_input_data_dir(channel))
                else:
                    # link file source to file within input channel directory
                    input_data_path = Path(get_input_data_dir(channel), Path(data).name)
                    print(f'Channel: {channel}, input_data_path: {input_data_path}, input_link_path: {input_link_path}')

                make_link(input_link_path, input_data_path, links)

        return links


    def clean_links(links):
        for link, target in links.items():
            if link.is_symlink and link.readlink() == target:
                link.unlink()

            if link.is_relative_to(Path()):
                for dir in link.parents[:-1]:
                    try:
                        dir.rmdir()
                    except:
                        # directory not empty
                        pass
    """
end

function _serialize_function(f_name::String, f_source::String, included_pkgs::Union{String, Vector{String}}="")
    include_list = isempty(included_pkgs) ? "JLD2, Braket" : join(vcat(included_pkgs, ["JLD2", "Braket"]), ", ")
    return """
import os
import json
from juliacall import Main as jl
from juliacall import Pkg as jlPkg
from braket.jobs import get_results_dir, save_job_result
from braket.jobs_data import PersistedJobDataFormat

jlPkg.activate(".")
jlPkg.instantiate()
jl.seval(f'using $include_list')

# set working directory to results dir
results_dir = get_results_dir()
os.chdir(results_dir)

# create symlinks to input data
links = link_input()

def main():
    result = None
    # load and run serialized entry point
    hyperparams = {}
    hp_file = os.environ.get("AMZN_BRAKET_HP_FILE")
    if hp_file:
        with open(hp_file, "r") as f:
            hyperparams = json.load(f)
    hyperparams = hyperparams or {}
    try:
        jl.seval('$f_source\\n')
        load_str_loc = get_input_data_dir("jl_args") + '/job_f_args.jld2'
        load_str = f'j_args = load("{load_str_loc}")'
        jl.seval(load_str)
        jl_func_str = f'$f_name(j_args["jl_args"]...; j_args["jl_kwargs"]...)'
        result = jl.seval(jl_func_str)
    except Exception as e:
        print('An exception occured running the Julia code: ', e, flush=True)
        raise e
    finally:
        clean_links(links)
    if result is not None:
        save_job_result(result, data_format=PersistedJobDataFormat.PICKLED_V4)
    return result

if __name__ == "__main__":
    main()
"""
end

function parse_macro_args(args)
    has_device   = length(args) == 0 || occursin("=", string(args[1]))
    device = has_device ? string(args[1]) : ""
    raw_kwargs   = has_device ? args : args[2:end]
    return device, raw_kwargs
end

function _process_call_args(args)
    n_arguments = length(args)
    code = quote end

    splatted_args = [Meta.isexpr(arg, :(...)) for arg in args]
    new_args = [splatted_args[a_ix] ? args[a_ix].args[1] : args[a_ix] for a_ix in 1:n_arguments]
    new_kwargs = filter(arg->Meta.isexpr(arg, :kw), new_args)
    new_args = filter(arg->!Meta.isexpr(arg, :kw), new_args)
    # handle kwargs
    new_kwargs = [(arg.args[1], arg.args[2]) for arg in new_kwargs]

    # match arguments with variables
    vars = [gensym() for v_ix in 1:length(new_args)]
    for v_ix in 1:length(new_args)
        push!(code.args, :($(vars[v_ix]) = $(new_args[v_ix])))
    end
    kw_vars = [gensym() for v_ix in 1:length(new_kwargs)]
    for v_ix in 1:length(new_kwargs)
        push!(code.args, :($(kw_vars[v_ix]) = $(new_kwargs[v_ix])))
    end
    # convert the arguments
    # while keeping the original arguments alive
    var_expressions = [splatted_args[v_ix] ? Expr(:(...), vars[v_ix]) : vars[v_ix] for v_ix in 1:length(new_args)] 
    kw_var_expressions = [kw_vars[v_ix] for v_ix in 1:length(new_kwargs)]
    return code, vars, var_expressions, kw_var_expressions
end

function jobify_f(f, job_f_types, job_f_arguments, job_f_kwargs, device; jl_dependencies="", py_dependencies="", as_local=false, include_modules="", include_jl_modules="", job_opts_kwargs...)
    mktempdir(pwd(), prefix="decorator_job_") do temp_path
        j_opts = Braket.JobsOptions(; job_opts_kwargs...)
        entry_point_file = joinpath(temp_path, "entry_point.py")
        # create JLD2 file with function arguments and kwargs
        save(joinpath(temp_path, "job_f_args.jld2"), "jl_args", job_f_arguments, "jl_kwargs", Dict(kw[1]=>kw[2] for kw in job_f_kwargs))

        raw_input_data = Dict{String, Any}()
        if j_opts.input_data isa String
            raw_input_data = Dict("input"=>j_opts.input_data, "jl_args"=>joinpath(temp_path, "job_f_args.jld2"))
            j_opts.input_data = raw_input_data
        else
            raw_input_data = merge(j_opts.input_data, Dict("jl_args"=>joinpath(temp_path, "job_f_args.jld2")))
            j_opts.input_data = raw_input_data
        end
        input_data = _process_input_data(raw_input_data)
        
        f_source = code_string(f, job_f_types)
        if isempty(f_source)
            t = precompile(f, job_f_types)
            f_source = code_string(f, job_f_types)
        end
        isempty(f_source) && error("no method instance for $f found with types $job_f_types")
        f_source = String(escape_string(f_source))
        serialized_f = _serialize_function(string(Symbol(f)), f_source, include_jl_modules)
        file_contents = join((input_data, serialized_f), "\n")
        write(entry_point_file, file_contents)
        
        if !isempty(py_dependencies)
            cp(py_dependencies, joinpath(temp_path, "requirements.txt"))
        else
            write(joinpath(temp_path, "requirements.txt"), "juliacall")
        end
        if !isempty(jl_dependencies)
            cp(jl_dependencies, joinpath(temp_path, "Project.toml"))
        else
            write(joinpath(temp_path, "Project.toml"), "[deps]\nBraket = \"19504a0f-b47d-4348-9127-acc6cc69ef67\"\nJLD2 = \"033835bb-8acc-5ee8-8aae-3f567f8a3819\"\n")
        end
        device = isempty(device) ? "local:none/none" : string(device)
        hyperparams = _log_hyperparameters(job_f_arguments, job_f_kwargs)
        j_opts.hyperparameters = hyperparams
        j_opts.entry_point = "$(relpath(temp_path)).entry_point"
        T = as_local ? LocalQuantumJob : AwsQuantumJob
        return T(device, relpath(temp_path), j_opts)
    end
end

macro hybrid_job(args...)
    # peel apart `args`
    entry_point = args[end]
    Meta.isexpr(entry_point, :call) || throw(ArgumentError("final argument to @hybrid_job must be a function call"))
    device, jobify_kwargs = parse_macro_args(args[1:end-1])
    f = entry_point.args[1]
    f_args = entry_point.args[2:end]
    # need to transform f to launch as a Job
    # and transform its arguments to be properly passed to the new call
    code, vars, var_expressions, kw_var_expressions = _process_call_args(f_args)
    @gensym job_f job_f_args job_f_kwargs job_f_types wrapped_f
    # now build up the actual call
    push!(code.args,
            quote
                $job_f_args = ($(var_expressions...),)
                $job_f_kwargs = ($(kw_var_expressions...),)
                $job_f_types = tuple(map(Core.Typeof, $job_f_args)...)
                $wrapped_f = $jobify_f($f, $job_f_types, $job_f_args, $job_f_kwargs, $device; $(jobify_kwargs...))
                $wrapped_f
            end
           )
    # use this let block to avoid leaking out of scope
    return esc(quote
        let
            $code
        end
    end)
end
