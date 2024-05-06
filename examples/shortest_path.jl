using Braket, LinearAlgebra, SparseArrays, NLopt, Random
using Graphs, SimpleWeightedGraphs, GraphMakie

nv = 5
desired_hops = 4

adj_mat = triu(sprand(nv, nv, 0.75), 1)
#adj_mat = triu([0 5 5 0; 5 0 2 2; 5 2 0 10; 0 2 10 0])
cₑ = sum(adj_mat)
adj_mat += adj_mat'

α = cₑ

function build_hop_Q(s::Int, t::Int, nv::Int, hops::Int, α, A::AbstractMatrix)
    nq = nv * hops
    Q  = zeros(nv*hops, nv*hops) 

    # each vi, vj block is a SymTridiagonal
    @views for vi in 1:nv, vj in vi:nv
        if vi == vj
            #block_mat = diagm(0=>fill(-α, hops), 1=>fill(α, hops-1))
            block_mat = diagm(0=>fill(-α, hops))
            Q[((vi-1)*hops + 1):(vi*hops), ((vi-1)*hops + 1):(vi*hops)] = block_mat[:,:]
        else
            fill_term = A[vi, vj] > 0 ? A[vi, vj] : α 
            block_mat = diagm(-1=>fill(fill_term, hops-1), 0=>fill(α, hops), 1=>fill(fill_term, hops-1))
            Q[((vi-1)*hops + 1):(vi*hops), ((vj-1)*hops + 1):(vj*hops)] = block_mat[:,:]
        end
    end
    # s should be first, t should be last
    # incentivize them and penalize others
    #=for v in 1:nv
        Q[(v-1)*hops + 1, (v-1)*hops + 1] = α
        Q[v*hops, v*hops] = α
    end=#
    Q[(s-1)*hops + 1, (s-1)*hops + 1] = -2α
    Q[t*hops, t*hops] = -2α
    return Q
end

function ZZgate(q1, q2, γ)
    circ_zz = Circuit()
    cnot(circ_zz, q1, q2)
    rz(circ_zz, q2, γ)
    cnot(circ_czz, q1, q2)
    return circ_zz
end

function cost_circuit(γ, nqubits, device, ising)
    cost    = Circuit()
    I, J, V = findnz(sparse(ising))
    for (i, j, int) in zip(I, J, V)
        if i != j
            if device.name == "Rigetti"
                append!(cost, ZZgate(i-1, j-1, γ*int))
            else
                zz(cost, i-1, j-1, -2γ*int)
            end
        end
    end
    return cost
end

function driver_circuit(β, nqubits)
    driver = Circuit()
    for qubit in 1:nqubits
        rx(driver, qubit-1, 2β)
    end
    return driver
end

function qaoa_circuit(params, device, nqubits, ising)
    depth = div(length(params), 2)
    γs    = params[depth+1:end]
    βs    = params[1:depth]

    circ = Circuit() |> (c->x(c, 0:nqubits-1)) |> (c->Braket.h(c, 0:nqubits-1))

    for layer in 1:depth
        cost_circ = cost_circuit(γs[layer], nqubits, device, ising)
        append!(circ, cost_circ)
        driver_circ = driver_circuit(βs[layer], nqubits)
        append!(circ, driver_circ)
    end
    return circ
end

# initializing the optimization
function init_opt(qaoa_depth::Int, n_qubits::Int)
    global_min   = 1e8
    global_state = zeros(n_qubits)
    # initialize with random parameters
    βs           = rand(qaoa_depth)
    γs           = rand(qaoa_depth)
    params       = vcat(βs, γs)
    # tracker for optimization process
    tracker      = Dict("costs"=>[],
                        "params"=>[],
                        "optimal_energy"=>global_min, # best energy so far
                        "optimal_state"=>global_state, # best configuration so far
                        "opt_energies"=>Float64[], # track lowest eigenvalue at every iteration
                        "opt_states"=>[] # track configuration associated with lowest eigenvalue at every iteration
                        )
    return params, tracker
end

# generating the loss & finding the best configuration at each iteration
function apply_qaoa(qaoa_circ, ising, device, nshots::Int)
    task = run(device, qaoa_circ, shots=nshots)
    # the managed simulators store results in Amazon S3
    #    task = device.run(qaoa_circ, s3_folder, nshots)

    # matrix of dimension (nshots, num_qubits)
    result     = Results(task)

    # result comes back as 0s and 1s
    meas_ising = result.measurements
    # but Ising hamiltonian expects values of -1 or 1
    meas_ising = meas_ising

    # generate the energies
    J   = triu(ising)
    xQx = diag(meas_ising * J * transpose(meas_ising)) # computes <x | Q | x> for every result configuration
    all_energies = xQx
    loss = sum(all_energies) / nshots

    # select the best energy
    energy_min    = minimum(all_energies)
    # find the configuration that had that energy
    min_index     = findfirst(x->x==energy_min, all_energies)
    optimal_state = meas_ising[min_index, :]

    return loss, energy_min, optimal_state
end

function train(nqubits::Int, ising, device; depth::Int=3, iterations::Int=100, nshots::Int=100, s3_folder=nothing)
    params, tracker = init_opt(depth, nqubits)
    function f(params, grad)
        # create the circuit
        qaoa_circ = qaoa_circuit(params, device, nqubits, ising)
        loss, energy_min, optimal_state = apply_qaoa(qaoa_circ, ising, device, nshots)

        # update the tracker
        push!(tracker["opt_energies"], energy_min)
        push!(tracker["opt_states"],    optimal_state)
        if energy_min < tracker["optimal_energy"]
            tracker["optimal_energy"] = energy_min
            tracker["optimal_state"]  = optimal_state
        end
        tracker["count"] = tracker["count"] + 1
        push!(tracker["params"], params)


        push!(tracker["costs"], loss)
        return loss
    end

    opt = Opt(:LN_COBYLA, length(params))
    min_objective!(opt, f)
    maxeval!(opt, iterations)
    for i in 1:iterations
        loss, params, info = optimize(opt, params)
    end
    return tracker
end

DEPTH   = 2
SHOTS   = 500

#s, t = shuffle(1:nv)[1:2]
s, t = 1, 4
Q = build_hop_Q(s, t, nv, desired_hops, α, adj_mat)

device  = LocalSimulator()

tracker = train(nv*desired_hops, Q, device; depth=DEPTH, nshots=SHOTS) #s3_folder = (bucket, folder) if using managed simulator
@show s, t 
pvs = collect(1:nv*desired_hops)[Bool.(tracker["optimal_state"])]
path = zeros(Int, desired_hops) 
for pv in pvs
    v = div(pv-1, desired_hops) + 1
    h = mod(pv-1, desired_hops) + 1
    path[h] = v
end
display(Q)
println()
@show nv, desired_hops

display(adj_mat)
println()

@show tracker["optimal_state"]
@show unique(path)

g = SimpleWeightedGraph(adj_mat)
classical_path = enumerate_paths(dijkstra_shortest_paths(g, s), t)
@show classical_path
