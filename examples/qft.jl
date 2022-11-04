### A Pluto.jl notebook ###
# v0.19.12

using Markdown
using InteractiveUtils

# ╔═╡ d928ee56-0f14-426c-b669-356627382f8f
using Braket, PyBraket

# ╔═╡ ab9771de-a268-4df8-811d-9310a12a7d79
using Plots

# ╔═╡ 5ed4321a-467d-11ed-23c2-c19a80e0d7f1
path_to_braketjl = joinpath(ENV["HOME"], ".julia/dev/Braket")

# ╔═╡ b6659bc6-2166-4cc0-ab33-197d0cb7588c
import Pkg; Pkg.develop(Pkg.PackageSpec(path=path_to_braketjl)); Pkg.develop(Pkg.PackageSpec(path=joinpath(path_to_braketjl, "PyBraket")))

# ╔═╡ 608cf437-7493-494b-a4d7-1e852bcae8d9
"""
	qft_no_swap(qubits) -> Circuit

Subroutine of the QFT excluding the final SWAP gates, applied to the `qubits` argument.

"""
function qft_no_swap(qubits)
    # On a single qubit, the QFT is just a Hadamard.
    length(qubits) == 1 && return Circuit([(H, qubits)])
    
    # For more than one qubit, we define the QFT recursively
    qftcirc = Circuit()
	# First add a Hadamard gate
	qftcirc(H, first(qubits))
	# Then apply the controlled rotations, with weights (angles) defined by the distance to the control qubit.
	for (k, qubit) in enumerate(qubits[2:end])
		qftcirc(CPhaseShift, qubit, first(qubits), 2π/2^(k+1))
	end
	# Now apply the above gates recursively to the rest of the qubits
	qftcirc(qft_no_swap(qubits[2:end]))
    return qftcirc
end

# ╔═╡ 2c612fa4-1a8d-404a-8b3e-5e1907e20d84
"""
	qft_recursive(qubits)

Construct a circuit object corresponding to the Quantum Fourier Transform (QFT)
algorithm, applied to the argument `qubits`.
"""
function qft_recursive(qubits)
    qftcirc = Circuit()
    
    # First add the QFT subroutine above
    qftcirc(qft_no_swap(qubits))
    
    # Then add SWAP gates to reverse the order of the qubits:
    for i in 1:div(length(qubits), 2)
        qftcirc(Swap, qubits[i], qubits[end-i-1])
	end
    return qftcirc
end

# ╔═╡ 3ccc5bb1-16ec-4fd5-b82f-31da2734223e
"""
	qft(qubits)

Construct a circuit object corresponding to the Quantum Fourier Transform (QFT)
algorithm, applied to the argument `qubits`.  Does not use recursion to generate the QFT.
"""
function qft(qubits)   

    qftcirc = Circuit()
    
    # get number of qubits
    num_qubits = length(qubits)
    
    for k in 1:num_qubits
        # First add a Hadamard gate
        qftcirc(H, qubits[k])
        # Then apply the controlled rotations, with weights (angles) defined by the distance to the control qubit.
        # Start on the qubit after qubit k, and iterate until the end.  When num_qubits==1, this loop does not run.
        for j in 1:(num_qubits - k - 1)
            angle = 2π/2^(j+1)
            qftcirc(CPhaseShift, qubits[k+j], qubits[k], angle)
		end
	end
            
    # Then add SWAP gates to reverse the order of the qubits:
    for i in 1:div(num_qubits, 2)
        qftcirc(Swap, qubits[i], qubits[end-i])
	end
        
    return qftcirc
end

# ╔═╡ 55a3b85b-6d3c-43b9-9c89-5af3f5c57629
"""
	inverse_qft(qubits)

Construct a circuit object corresponding to the inverse Quantum Fourier Transform (QFT)
algorithm, applied to the argument `qubits`.  Does not use recursion to generate the circuit.
"""
function inverse_qft(qubits)

    # instantiate circuit object
    qftcirc = Circuit()
    
    # get number of qubits
    num_qubits = length(qubits)
    
    # First add SWAP gates to reverse the order of the qubits:
    for i in 1:div(num_qubits, 2)
        qftcirc(Swap, qubits[i], qubits[end-i+1])
	end
        
    # Start on the last qubit and work to the first.
    for k in reverse(1:num_qubits)
        # Apply the controlled rotations, with weights (angles) defined by the distance to the control qubit.
        # These angles are the negative of the angle used in the QFT.
        # Start on the last qubit and iterate until the qubit after k.  
        # When num_qubits==1, this loop does not run.
        for j in reverse(1:num_qubits - k)
            angle = -2π/2^(j+1)
            qftcirc(CPhaseShift, qubits[k+j], qubits[k], angle)
		end
        # Then add a Hadamard gate
        qftcirc(H, qubits[k])
	end
    return qftcirc
end

# ╔═╡ b3a750d1-7a2b-4de6-9e6c-166336ba6cec
device = LocalSimulator()

# ╔═╡ 7127d624-fb0d-41b9-a8cd-6cae7d34d55f
function prettify_state_vector(state_vector)
	state_vec_pretty = complex.(trunc.(real.(state_vector), digits=3), trunc.(imag.(state_vector), digits=3))

	state_vec_pretty = map(ampl->abs(ampl)>1e-5 ? ampl : zero(ampl), state_vec_pretty)
	return state_vec_pretty
end

# ╔═╡ 83b78b1a-3935-4ca7-88f6-7a15cc523591
function run_and_plot_qft(c::Circuit)
	num_qubits = qubit_count(c)
	bitstring_keys = [prod(string.(digits(ii, base=2, pad=num_qubits))) for ii in 0:(2^num_qubits)-1]
	# specify desired result types
	c(StateVector)
	c(Probability)

	# Run the task
	task = run(device, c, shots=0)
	res  = result(task)
	state_vector = res.values[1]
	probs_values = res.values[2]
	p = bar(bitstring_keys, probs_values, xlabel="bitstrings", ylabel="probability", legend=false)
	return p
end

# ╔═╡ 256bb268-e2fc-4483-a6f7-4a76028fcf80
# check output for input |0,0,0> -> expect uniform distribution
run_and_plot_qft(qft(collect(0:2)))

# ╔═╡ 20cfa5e8-d4ad-4720-9d27-f7c161ea09e3
begin
	nqs1 = 3
	qbs1 = collect(0:nqs1-1)
	circ2 = Circuit([(H, qbs1)])
	for ii in 1:nqs1 - 1
	    circ2(Rz, ii, π/2^(ii-1))
	end
	# add iQFT circuit
	circ2(inverse_qft(qbs1))
	run_and_plot_qft(circ2)
end

# ╔═╡ 0508acef-1de0-42e4-9bbc-9127c2a162b5
begin
	# test that the iQFT circuit works for larger qubit counts
	nqs2 = 4
	qbs2 = collect(0:nqs2-1)
	circ3 = Circuit(vcat((H, qbs2), [(Rz, ii, π/2^(ii-1)) for ii in 1:nqs2-1]))
	# add iQFT circuit   
	circ3(inverse_qft(qbs2))
	run_and_plot_qft(circ3)
end

# ╔═╡ ae77c39f-9f7e-4c45-8823-a16a38c33e0d
begin
	#test that the QFT and iQFT circuits cancel each other
	nqs3 = 3
	qbs3 = collect(0:nqs3-1)
	circ4 = qft(qbs3)
	circ4(inverse_qft(qbs3))
	
	run_and_plot_qft(circ4)
end

# ╔═╡ Cell order:
# ╠═5ed4321a-467d-11ed-23c2-c19a80e0d7f1
# ╠═b6659bc6-2166-4cc0-ab33-197d0cb7588c
# ╠═d928ee56-0f14-426c-b669-356627382f8f
# ╠═608cf437-7493-494b-a4d7-1e852bcae8d9
# ╠═2c612fa4-1a8d-404a-8b3e-5e1907e20d84
# ╠═3ccc5bb1-16ec-4fd5-b82f-31da2734223e
# ╠═55a3b85b-6d3c-43b9-9c89-5af3f5c57629
# ╠═b3a750d1-7a2b-4de6-9e6c-166336ba6cec
# ╠═7127d624-fb0d-41b9-a8cd-6cae7d34d55f
# ╠═ab9771de-a268-4df8-811d-9310a12a7d79
# ╠═83b78b1a-3935-4ca7-88f6-7a15cc523591
# ╠═256bb268-e2fc-4483-a6f7-4a76028fcf80
# ╠═20cfa5e8-d4ad-4720-9d27-f7c161ea09e3
# ╠═0508acef-1de0-42e4-9bbc-9127c2a162b5
# ╠═ae77c39f-9f7e-4c45-8823-a16a38c33e0d
