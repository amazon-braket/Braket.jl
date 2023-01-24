using Braket, Test

get_tol(shots::Int) = return (shots > 0 ? Dict("atol"=> 0.1, "rtol"=>0.15) : Dict("atol"=>0.01, "rtol"=>0))
s3_destination_folder = Braket.default_task_bucket()

include("adjoint_gradient.jl")
include("create_quantum_job.jl")
include("cost_tracking.jl")
include("device_creation.jl")
include("density_matrix_simulator.jl")
include("simulator_quantum_task.jl")
include("tensor_network_simulator.jl")
