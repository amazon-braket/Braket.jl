using Test, Aqua, Braket, Braket.AWS, PyBraket

withenv("JULIA_CONDAPKG_VERBOSITY"=>"-1") do
    Aqua.test_all(PyBraket, ambiguities=false, unbound_args=false, piracy=false)
    Aqua.test_ambiguities(PyBraket)
end

function set_aws_creds(test_type)
    if test_type == "unit"
        creds = Braket.AWS.AWSCredentials("", "")
        config = Braket.AWS.AWSConfig(creds, "", "")
        Braket.AWS.global_aws_config(config)
    elseif test_type == "integ"
        # should pickup correct creds from envvars 
        Braket.AWS.global_aws_config()
    else
        throw(ArgumentError("invalid test_type $test_type, must be one of 'integ' or 'unit'"))
    end
end

const GROUP = get(ENV, "GROUP", "PyBraket-unit")

groups = GROUP == "All" ? ["PyBraket-integ", "PyBraket-unit"] : [GROUP]

for group in groups
    @info "Testing $group"
    pkg_name  = String(split(group, "-")[1])
    test_type = String(split(group, "-")[2])

    set_aws_creds(test_type)

    if test_type == "unit"
        include(joinpath(@__DIR__, "circuits.jl"))
        include(joinpath(@__DIR__, "noise.jl"))
        include(joinpath(@__DIR__, "gates.jl"))
        include(joinpath(@__DIR__, "ahs.jl"))
    elseif test_type == "integ"
        include(joinpath(@__DIR__, "integ_tests/runtests.jl"))
    end
end
