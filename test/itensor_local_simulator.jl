using Test
using Braket
using ITensors
using ITensorMPS

@testset "ITensorSimulator Tests" begin
    # Test: Basic DMRG simulation with flexible Hamiltonian
    @testset "DMRG Simulation" begin
        # Create an instance of ITensorSimulator
        simulator = ITensorSimulator("itensor_backend")

        # Define a task specification with Hamiltonian terms
        N = 10
        sites = siteinds("S=1",N)
        os = OpSum()
        for j=1:N-1
            os += "Sz",j,"Sz",j+1
            os += 1/2,"S+",j,"S-",j+1
            os += 1/2,"S-",j,"S+",j+1
        end
        # Run the simulation
        result = simulate(simulator, sites, os, method=:DMRG, N=N, sites_type="S=1/2", linkdims=10, nsweeps=2, maxdim=[10, 20], cutoff=1e-8)
     end
end