export ITensorSimulator, simulate

struct ITensorSimulator
    backend::String
end

function simulate(d::ITensorSimulator, sites::Any, os::Any; method::Symbol=:DMRG, kwargs...)
    if method == :DMRG
        return simulate_dmrg(d, sites, os; kwargs...)
    else
        throw(ArgumentError("Unsupported simulation method: $method"))
    end
end

function simulate_dmrg(d::ITensorSimulator, sites::Any, os::Any; kwargs...)
    config = Dict(kwargs...)

    # Set default values if not provided in kwargs
    N = get(config, :N, 100)
    sites_type = get(config, :sites_type, "S=1/2")
    linkdims = get(config, :linkdims, 10)
    nsweeps = get(config, :nsweeps, 5)
    maxdim = get(config, :maxdim, [10, 20, 100, 100, 200])
    cutoff = get(config, :cutoff, [1e-10])
    H = MPO(os, sites)

    # Initialize MPS
    psi0 = random_mps(sites; linkdims=linkdims)

    # Run DMRG
    energy, psi = dmrg(H, psi0; nsweeps=nsweeps, maxdim=maxdim, cutoff=cutoff)

    # Return results in the appropriate format : something like LocalQuantumTask("dmrg_task", GateModelQuantumTaskResult(energy, psi)) maybe
    return energy, psi
end