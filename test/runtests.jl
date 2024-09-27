using Pkg, Test, Aqua, Braket

in_ci = tryparse(Bool, get(ENV, "BRAKET_CI", "false"))
Aqua.test_all(Braket, ambiguities=false, piracies=false, stale_deps=!in_ci, deps_compat=!in_ci, persistent_tasks=!in_ci)
Aqua.test_ambiguities(Braket)
Aqua.test_piracies(Braket, treat_as_own=[Braket.DecFP.Dec128])

const GROUP = get(ENV, "GROUP", "Braket-unit")

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

groups = GROUP == "All" ? ["Braket-integ", "Braket-unit", "PyBraket-unit", "Examples-unit", "Examples-integ"] : GROUP
groups = (groups isa String ? [groups] : groups)
        
subpackage_path(subpackage::String) = joinpath(dirname(@__DIR__), subpackage)
develop_subpackage(subpackage::String) = (Pkg.activate(subpackage_path(subpackage)); Pkg.develop(Pkg.PackageSpec(; path=dirname(@__DIR__))))

for group in groups
    @info "Testing $group"
    pkg_name  = String(split(group, "-")[1])
    test_type = String(split(group, "-")[2])

    set_aws_creds(test_type)

    if pkg_name == "Braket"
        if test_type == "unit"
            include("ahs.jl")
            include("utils.jl")
            include("qubit_set.jl")
            include("dwave_device.jl")
            include("ionq_device.jl")
            include("rigetti_device.jl")
            include("simulator_device.jl")
            include("oqc_device.jl")
            include("iqm_device.jl")
            include("quera_device.jl")
            include("xanadu_device.jl")
            include("translation.jl")
            include("schemas_misc.jl")
            include("device.jl")
            include("circuits.jl")
            include("measure.jl")
            include("circuit_timing.jl")
            include("free_parameter.jl")
            include("gates.jl")
            include("observables.jl")
            include("noises.jl")
            include("noise_model.jl")
            include("compiler_directives.jl")
            include("gate_model_task_result.jl")
            include("photonic_task_result.jl")
            include("annealing_task_result.jl")
            include("tracker.jl")
            include("task.jl")
            include("task_batch.jl")
            include("local_jobs.jl")
            include("job_macro.jl")
            include("jobs.jl")
        elseif test_type == "integ"
            include(joinpath(@__DIR__, "integ_tests", "runtests.jl"))
        end
    elseif pkg_name == "Examples"
        Pkg.activate(joinpath(@__DIR__, "..", "examples"))
        Pkg.develop([PackageSpec(; path=joinpath(@__DIR__, "..")), PackageSpec(; path=joinpath(@__DIR__, "..", "PyBraket"))])
        Pkg.instantiate()
        if test_type == "unit"
            # test example notebooks that don't need AWS devices
            @testset "Local Examples" begin
                include(joinpath(@__DIR__, "..", "examples", "ahs_rabi.jl"))
                include(joinpath(@__DIR__, "..", "examples", "graph_coloring.jl"))
                include(joinpath(@__DIR__, "..", "examples", "qft.jl"))
            end
        elseif test_type == "integ"
            @testset "Examples-integ" begin
                # test example notebooks that do need AWS devices
                include(joinpath(@__DIR__, "..", "examples", "adjoint_gradient.jl"))
                include(joinpath(@__DIR__, "..", "examples", "ahs_nb.jl"))
                include(joinpath(@__DIR__, "..", "examples", "vqe_chemistry.jl"))
                include(joinpath(@__DIR__, "..", "examples", "tetris_vqe.jl"))
            end
        end
    else
        develop_subpackage(pkg_name)
        subpkg_path = subpackage_path(pkg_name)
        # this should inherit the GROUP envvar
        run_coverage = get(ENV, "COVERAGE", "false")
        Pkg.test(PackageSpec(; name=pkg_name, path=subpkg_path); coverage=(run_coverage=="true"))
    end
end
