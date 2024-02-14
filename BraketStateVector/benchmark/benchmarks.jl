using BraketStateVector, Braket, PythonCall, BenchmarkTools

using Braket: Instruction

gate_operations  = pyimport("braket.default_simulator.gate_operations")
noise_operations = pyimport("braket.default_simulator.noise_operations")
local_sv         = pyimport("braket.default_simulator.state_vector_simulation")
local_dm         = pyimport("braket.default_simulator.density_matrix_simulation")
qml              = pyimport("pennylane")
np               = pyimport("numpy")
pnp              = pyimport("pennylane.numpy")
nx               = pyimport("networkx")

suite = BenchmarkGroup()
include("gate_kernels.jl")
include("qaoa.jl")
include("vqe.jl")
include("qft.jl")
include("ghz.jl")

# this is expensive! only do it if we're sure we need to regen parameters
if !isfile("params.json")
    tune!(suite)
    BenchmarkTools.save("params.json", params(suite))
end
loadparams!(suite, BenchmarkTools.load("params.json")[1], :evals, :samples);
results = run(suite, verbose = true)
BenchmarkTools.save("results.json", results)
