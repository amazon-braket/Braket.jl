using BenchmarkTools, Braket, Random

Random.seed!(42)

function circ_list_gen(d::Int, q::Int=20)
    # layer of Hadamards first
    gates = Any[(H, collect(0:q-1))]
    for layer in 2:d
        # single qubit rotations on each gate
        if isodd(layer)
            for qubit in 0:q-1
                θ = rand()
                push!(gates, rand(((Rx, qubit, θ), (Ry, qubit, θ), (Rz, qubit, θ))))
            end
        else
            for qubit in 0:q-2
                push!(gates, (CNot, q, q+1))
            end
        end
    end
    return gates
end

suite = BenchmarkGroup()
include("circuit.jl")
include("noise.jl")
tune!(suite);
results = run(suite; verbose=true, seconds=30)
BenchmarkTools.save(joinpath(@__DIR__, "results.json"), results)

reference_path = joinpath(@__DIR__, "reference.json")
if ispath(reference_path)
    ref_bmarks = BenchmarkTools.load(reference_path)[1]
    comparison = judge(minimum(results), minimum(ref_bmarks))

    println("Improvements:")
    println(improvements(comparison))

    println("Regressions:")
end
