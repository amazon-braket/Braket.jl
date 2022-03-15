### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# ╔═╡ b7719166-12c4-47a6-b501-7bacd7662dd0
using Braket, PyBraket

# ╔═╡ dd486f0e-cc45-41b7-b7db-42ad83121194
using Braket: AtomArrangement, AtomArrangementItem, TimeSeries, DrivingField, AwsDevice, AnalogHamiltonianSimulation, discretize, AnalogHamiltonianSimulationQuantumTaskResult

# ╔═╡ 281a092d-7240-4528-a166-0b3250448a1b
using DataStructures, Statistics, Plots

# ╔═╡ 1a35d23d-2eb0-45a5-b7a6-bbd73e3e7552
md"
Note: to run this notebook you'll need the `Braket.jl` package installed (it comes along with a sub-package, `PyBraket.jl`, for interfacing with Python where necessary). Clone the `Braket.jl` package from GitLab and tell Julia where it can be found by modifying the variable `path_to_braketjl` below.
"

# ╔═╡ 0c324f97-0c92-44d3-9b78-ed89dd55cb79
path_to_braketjl = "/Users/hyatkath/.julia/dev/Braket"

# ╔═╡ 5fa5436f-2ad0-4893-b10e-30643467cb6c
import Pkg; Pkg.develop(Pkg.PackageSpec(path=path_to_braketjl)); Pkg.develop(Pkg.PackageSpec(path=joinpath(path_to_braketjl, "PyBraket"))) 

# ╔═╡ 8b87c6c6-4e6b-4a7c-b050-ef21fb25bffe
Pkg.add("DataStructures"); Pkg.add("Plots"); Pkg.add("Statistics")

# ╔═╡ 93a4afe7-e33f-4acd-9c90-4875d882189b
begin
	a = 5.5e-6
	
	register = AtomArrangement()
	push!(register, AtomArrangementItem((0.5, 0.5 + 1/√2) .* a))
	push!(register, AtomArrangementItem((0.5 + 1/√2, 0.5) .* a))
	push!(register, AtomArrangementItem((0.5 + 1/√2, -0.5) .* a))
	push!(register, AtomArrangementItem((0.5, -0.5 - 1/√2) .* a))
	push!(register, AtomArrangementItem((-0.5, -0.5 - 1/√2) .* a))
	push!(register, AtomArrangementItem((-0.5 -1/√2, -0.5) .* a))
	push!(register, AtomArrangementItem((-0.5 -1/√2, 0.5) .* a))
	push!(register, AtomArrangementItem((-0.5, 0.5 + 1/√2) .* a))
end

# ╔═╡ bcff2464-0f38-45f2-8f01-66e2ebbef869
aquila_qpu   = AwsDevice("arn:aws:braket:us-east-1::device/qpu/quera/Aquila")

# ╔═╡ 1519684c-84ed-4f04-bdc8-7c38fd9fd35d
begin
	C6           = aquila_qpu._properties.paradigm.rydberg.c6Coefficient
	aquila_rg    = aquila_qpu._properties.paradigm.rydberg.rydbergGlobal
	Ω_min, Ω_max = aquila_rg.rabiFrequencyRange
	Ω_slope_max  = aquila_rg.rabiFrequencySlewRateMax
	Δ_min, Δ_max = aquila_rg.detuningRange
	time_max     = Float64(aquila_rg.timeMax)
end

# ╔═╡ 2b1d582b-8de5-499c-badd-da97056eda8e
begin
	Δ_start      = -5 * Float64(Ω_max)
	Δ_end        = 5 * Float64(Ω_max)
	@assert all(Δ_min <= Δ <= Δ_max for Δ in (Δ_start, Δ_end))
	
	time_ramp = 1e-7  # seconds
	@assert Float64(Ω_max) / time_ramp < Ω_slope_max
end

# ╔═╡ 388585cc-4417-11ed-3e99-af78d6112c38
begin
	Ω                       = TimeSeries()
	Ω[0.0]                  = 0.0
	Ω[time_ramp]            = Ω_max
	Ω[time_max - time_ramp] = Ω_max
	Ω[time_max]             = 0.0
	
	Δ                       = TimeSeries()
	Δ[0.0]                  = Δ_start
	Δ[time_ramp]            = Δ_start
	Δ[time_max - time_ramp] = Δ_end
	Δ[time_max]             = Δ_end
	
	ϕ           = TimeSeries()
	ϕ[0.0]      = 0.0
	ϕ[time_max] = 0.0
end

# ╔═╡ 9f607ec4-6337-4946-ae6d-842f1b02259c
begin
	drive                   = DrivingField(Ω, ϕ, Δ)
	ahs_program             = AnalogHamiltonianSimulation(register, drive)
	discretized_ahs_program = discretize(ahs_program, aquila_qpu)
end

# ╔═╡ a27acb82-5690-4a7b-bc6d-7104ccf54fbf
ahs_local    = LocalSimulator("braket_ahs")

# ╔═╡ e097f2f3-e2a6-4fc5-83e9-c0a0de70e9f6
local_result = result(run(ahs_local, discretized_ahs_program, shots=1_000_000))

# ╔═╡ 583c8ff8-ea3c-465b-a368-c6b33abadd33
"""
    get_counts(result)

Aggregates state counts from AHS shot results.
Strings of length = # of atoms are returned, where
each character denotes the state of an atom (site):
   e: empty site
   g: ground state atom
   r: Rydberg state atom

Returns an `Accumulator` containing the number of times each state configuration is measured.
"""
function get_counts(result::AnalogHamiltonianSimulationQuantumTaskResult)
    state_counts = Accumulator{String, Int}()
    states = ["e", "r", "g"]
    for shot in result.measurements
        pre       = convert(Vector{Int}, shot.pre_sequence)
        post      = convert(Vector{Int}, shot.post_sequence)
        state_idx = (pre .* (1 .+ post)) .+ 1
        state     = prod([states[s_idx] for s_idx in state_idx])
        inc!(state_counts, state)
    end
    return state_counts
end

# ╔═╡ 7695a2a0-a82e-4389-abd1-7180420272d6
counts = get_counts(local_result)

# ╔═╡ 25e25003-873f-4d09-8df2-c723871a3c00
function has_neighboring_rydberg_states(state::String)
    occursin("rr", state) && return true
    first(state) == 'r' && state[end] == 'r' && return true
    return false
end

# ╔═╡ cf84bdcc-729d-4cd9-bcc7-a3818cfb93e4
number_of_rydberg_states(state::String) = counter(state)['r']

# ╔═╡ 835d9653-db06-4997-8efb-c1b3729cd2d3
non_blockaded = []

# ╔═╡ 7fecba19-3dbb-48ed-b856-92ab5a22db8a
blockaded     = []

# ╔═╡ 3b9133e0-46a6-488a-8250-556b20bd0474
for (state, count) in counts
    collection = has_neighboring_rydberg_states(state) ? blockaded : non_blockaded
    push!(collection, (state, count, number_of_rydberg_states(state)))
end

# ╔═╡ c72408bc-901d-47a9-9fdf-3be2aac424a0
begin
	println("non-blockaded states:")
	println(join(["#r", "state", "\tshot_count"], '\t'))
	for (state, count, _) in sort(non_blockaded, by=(x->first(x)), rev=true)
	    println(join([string(number_of_rydberg_states(state)), string(state), string(count)], '\t'))
	end
end

# ╔═╡ 60304f9b-0821-4ba6-a80a-dd5d35fecc71
begin
	println()
	println("blockaded states:")
	println(join(["#r", "state", "\tshot_count"], '\t'))
	for (state, count, _) in sort(blockaded, by=(x->first(x)), rev=true)
	    println(join([string(number_of_rydberg_states(state)), string(state), string(count)], '\t'))
	end
end

# ╔═╡ 175d2e0f-582a-4dc2-95c1-25bf7e233b23
function marginals(counts)
    total_counts = sum(values(counts))
    atoms = fill(0, length(first(keys(counts))))
    for (state, count) in counts
        for (atom_idx, atom_state) in enumerate(state)
            atom_state == 'r' && (atoms[atom_idx] += count)
        end
    end
    return atoms ./ total_counts
end

# ╔═╡ c6e7bd83-1b88-454c-9684-1ae893a6684f
bar(1:length(register), marginals(counts), xlabel="atom index", ylabel="probability of\nRydberg state", ylim=[0, 1])

# ╔═╡ 490eb0e1-4d8e-47c1-9ce6-6c8aa43e72d6
# computing pairwise Matthews coefficient
function pairwise_matthews_phi(counts)
    # ref: https://en.wikipedia.org/wiki/Phi_coefficient
    atoms = length(first(keys(counts)))
    ϕs    = zeros(atoms, atoms)
    for j in 1:atoms, k in 1:atoms
        Ngg = 0
        Nrr = 0
        Nrg = 0
        Ngr = 0
        Ng_ = 0
        Nr_ = 0
        N_g = 0
        N_r = 0
        for (state, count) in counts
            state[j] == 'r' && (Nr_ += count)
            state[j] == 'g' && (Ng_ += count)
            state[k] == 'r' && (N_r += count)
            state[k] == 'g' && (N_g += count)
            (state[j] == 'r') && (state[k] == 'r') && (Nrr += count)
            (state[j] == 'r') && (state[k] == 'g') && (Nrg += count)
            (state[j] == 'g') && (state[k] == 'r') && (Ngr += count)
            (state[j] == 'g') && (state[k] == 'g') && (Ngg += count)
        end
        ϕ = (Nrr * Ngg - Nrg * Ngr) / √(Int128(Nr_) * Int128(Ng_) * Int128(N_r) * Int128(N_g))
        ϕs[j, k] = ϕ
    end
    return ϕs
end

# ╔═╡ bc250627-06ed-4380-aea0-250834192907
ϕs = pairwise_matthews_phi(counts)

# ╔═╡ 3d6d9440-2068-4c23-bd2e-3027473648fe
function correlation_function(ϕs)
    atoms    = size(ϕs, 1)
    ϕ_1d     = Float64[]
    distance = -div(atoms, 2):div(atoms, 2)
    for d in distance
        ϕ_d = zeros(Float64, atoms)
        for atom_idx in 0:atoms-1
            j = atom_idx + d < 0 ? mod(atom_idx+d+atoms, atoms) + 1 : mod(atom_idx+d, atoms) + 1
            ϕ_d[atom_idx+1] = ϕs[atom_idx+1, j]
        end
        push!(ϕ_1d, mean(ϕ_d))
    end
    return distance, ϕ_1d
end

# ╔═╡ b0d3f31c-52f6-4a24-9ebc-f9af151a23a9
distance, ϕ_1d = correlation_function(ϕs)

# ╔═╡ fbee7ea7-398c-4344-adb6-ecf9bf04d967
bar(distance, ϕ_1d, ylim=[-1.05, 1.05], xlabel="separation\n(in units of nearest neighbor distance)", ylabel="Matthews\ncorrelation coefficient")

# ╔═╡ Cell order:
# ╟─1a35d23d-2eb0-45a5-b7a6-bbd73e3e7552
# ╠═0c324f97-0c92-44d3-9b78-ed89dd55cb79
# ╠═5fa5436f-2ad0-4893-b10e-30643467cb6c
# ╠═b7719166-12c4-47a6-b501-7bacd7662dd0
# ╠═dd486f0e-cc45-41b7-b7db-42ad83121194
# ╠═388585cc-4417-11ed-3e99-af78d6112c38
# ╠═93a4afe7-e33f-4acd-9c90-4875d882189b
# ╠═bcff2464-0f38-45f2-8f01-66e2ebbef869
# ╠═1519684c-84ed-4f04-bdc8-7c38fd9fd35d
# ╠═2b1d582b-8de5-499c-badd-da97056eda8e
# ╠═9f607ec4-6337-4946-ae6d-842f1b02259c
# ╠═a27acb82-5690-4a7b-bc6d-7104ccf54fbf
# ╠═e097f2f3-e2a6-4fc5-83e9-c0a0de70e9f6
# ╠═8b87c6c6-4e6b-4a7c-b050-ef21fb25bffe
# ╠═281a092d-7240-4528-a166-0b3250448a1b
# ╠═583c8ff8-ea3c-465b-a368-c6b33abadd33
# ╠═7695a2a0-a82e-4389-abd1-7180420272d6
# ╠═25e25003-873f-4d09-8df2-c723871a3c00
# ╠═cf84bdcc-729d-4cd9-bcc7-a3818cfb93e4
# ╠═835d9653-db06-4997-8efb-c1b3729cd2d3
# ╠═7fecba19-3dbb-48ed-b856-92ab5a22db8a
# ╠═3b9133e0-46a6-488a-8250-556b20bd0474
# ╠═c72408bc-901d-47a9-9fdf-3be2aac424a0
# ╠═60304f9b-0821-4ba6-a80a-dd5d35fecc71
# ╠═175d2e0f-582a-4dc2-95c1-25bf7e233b23
# ╠═c6e7bd83-1b88-454c-9684-1ae893a6684f
# ╠═490eb0e1-4d8e-47c1-9ce6-6c8aa43e72d6
# ╠═bc250627-06ed-4380-aea0-250834192907
# ╠═3d6d9440-2068-4c23-bd2e-3027473648fe
# ╠═b0d3f31c-52f6-4a24-9ebc-f9af151a23a9
# ╠═fbee7ea7-398c-4344-adb6-ecf9bf04d967
