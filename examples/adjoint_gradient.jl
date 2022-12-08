### A Pluto.jl notebook ###
# v0.19.16

using Markdown
using InteractiveUtils

# ╔═╡ 3d3c1591-9bbc-4a2d-b375-049f7d91fe21
begin
	using Pkg
	Pkg.develop("Braket")
end

# ╔═╡ 492616b4-0cea-41fe-8a8e-11c6d60200cb
using Braket, Plots, Optim, Graphs, SimpleWeightedGraphs, Distributions, GraphPlot, SparseArrays, LinearAlgebra

# ╔═╡ 471998e8-763b-11ed-0be4-e5293a2b29d4
md"
# Gradient computations using the adjoint differentiation method on Amazon Braket.

In this notebook, we'll introduce the adjoint differentiation method and show how you can use it to accelerate variational workflows running on Braket.
"

# ╔═╡ 5a45f736-f603-4f01-b3ca-1d415d7864c4
md"""
## Introduction to gradient computation

First we need to develop the concept of a \"gradient\". A [gradient](https://en.wikipedia.org/wiki/Gradient) refers to a vector derivative of a scalar-valued function of multiple variables. If we have a function $f(x)$, which depends only on $x$ and maps $x \to \mathbb{R}$ (maps $x$ to a single real number), then $f$'s gradient is just its derivative with respect to $x$: $\frac{df}{dx}$. The gradient is denoted $\nabla$, so that $\nabla f(x) = \frac{df}{dx}$. However, if $f$ is a function of multiple variables, mapping $\mathbb{R}^n \to \mathbb{R}$, we must take partial derivatives with respect to each variable. For example:

```math
\nabla f(x, y, z) = \left[\frac{\partial f}{\partial x}, \frac{\partial f}{\partial y}, \frac{\partial f}{\partial z}\right]
```

The gradient of \$f\$ is itself a function and can be evaluated on specific values of $x$, $y$, and $z$. In general, for a function $f$ of $n$ independent real variables, $\nabla f$ is a length $n$ vector.

Gradients are of interest to us because many quantum algorithms -- hybrid classical-quantum algorithms such as the quantum approximate optimization algorithm (QAOA) or the variational quantum eigensolver (VQE) especially -- can be formulated as a problem of optimizing parameters (i.e. variables) in a quantum circuit with respect to some cost function, for example an expectation value of a Hamiltonian. To efficiently perform this optimization it's common to use a gradient based optimization method, such as gradient descent (stochastic or not). An efficient means of computing gradients allows us to arrive at a good solution to the optimization problem in fewer circuit evaluations, and thus less cost.
"""

# ╔═╡ dfba9752-1545-4d51-94b6-739954d63afc
md"""
## Computing gradients of parameters in a quantum circuit

Let's make this a little more concrete. Suppose we have a quantum circuit which depends on a set of parameters $\vec{p}$. We can compactly represent this circuit as $U(\vec{p})$, where $U$ is the unitary that represents the action of all the gates in the circuit. Further suppose that after running this circuit, we will compute the expectation value of some operator $\hat{O}$ (for example, a Hamiltonian) and use the result to determine how good our choice of parameters $\vec{p}$ was. This situation arises often when running hybrid algorithms or quantum machine learning workflows. 


**Note:** Although, for the sake of simplicity, we will only discuss measuring expectation values to generate the function to differentiate, one can equally well compute variances or any other scalar valued function.

We can express this whole procedure as:
```math
f(\vec{p}) = \left\langle \psi \right| \hat{O} \left| \psi \right\rangle = \left\langle 0 U^\dagger(\vec{p}) \right| \hat{O} \left| U(\vec{p}) 0 \right\rangle
```


$f(\vec{p})$ is a scalar valued function and we can compute its gradient -- all its partial derivatives with respect to the parameters $\vec{p}$ -- in order to optimize those parameters. There are a variety of methods available to compute these derivatives, three of which will be discussed below. Of the three, the adjoint differentiation method is the fastest and most frugal in circuit executions and should be preferred when available, that is, when running on a state vector simulator in exact (`shots=0`) mode. We'll introduce these other two common approaches to better understand the benefit of using the adjoint differentiation method.
"""

# ╔═╡ a516549b-0418-4123-a654-fdd17359493e
md"""
### Finite differences

The [finite difference method](https://en.wikipedia.org/wiki/Finite_difference) is a common technique used to approximate derivatives. Suppose we have a function $f(\vec{p})$ and we want to compute the $i$-th partial derivative of $f$, $\frac{\partial f}{\partial p_i}$. We can do so by approximating:

```math
\frac{\partial f}{\partial p_i} \approx \frac{f(p_1, p_2, ..., p_i + h, ..., p_n) - f(p_1, p_2, ..., p_i, ..., p_n)}{h}
```

Where $h$ is some small real number. This formula might seem familiar from introductory calculus.  The smaller $h$ is the better approximated the derivative is. By keeping all other parameters fixed, we can approximate the partial derivative with respect to $p_i$, but as we can see, computing *each* partial derivative would require *two* full circuit executions (one to compute each value of $f$). Thus, the total number of circuit executions needed to compute the gradient of $f$ for *one* set of values $\vec{p}$ would be $2n$, if the length of $p$ is $n$.

For a quantum circuit there can be additional problems. On a real quantum device, we can't compute the exact expectation value (or variance) of a circuit. We can only run many shots, each of which is a full circuit execution, and approximate the expectation value from the measurement statistics that result. This means that for very small $h$, it may be very difficult to approximate the gradient accurately.
"""

# ╔═╡ 202ca719-465e-4f4f-b5b2-40f953857288
md"""
### Parameter shift rules

Let's return to our original formula for the gradient of $f$:

```math
\nabla f(\vec{p}) = \left(\frac{\partial f}{\partial p_1}, \ldots , \frac{\partial f}{\partial p_n}\right)
```

and examine one of the vector elements a little more closely:

```math
\frac{\partial f}{\partial p_i} = \frac{\partial}{\partial p_i} \left\langle 0 U^\dagger(\vec{p}) \right| \hat{O} \left| U(\vec{p}) 0 \right\rangle = \frac{\partial}{\partial p_i} \left\langle 0 \right| U^\dagger(\vec{p}) \hat{O} U(\vec{p}) \left| 0 \right\rangle
```

We can pull the derivative operator inside the expectation value so that:

```math
\frac{\partial f}{\partial p_i} = \left\langle 0 \left|\frac{\partial}{\partial p_i} \left( U^\dagger(\vec{p}) \hat{O} U(\vec{p})\right) \right| 0 \right\rangle
```

We'll assume that each gate depends on at most one parameter, and each parameter appears in only one gate. What if we have repeated parameters? We can write down a mapping of each repeated parameter to a unique copy and sum the derivatives of those copies at the end using the [product rule](https://en.wikipedia.org/wiki/Product_rule). But for now, for simplicity we will assume that each parameter appears only once and each gate has at most one parameter. Further we'll state that gate $i$ is associated with the $i$-th parameter (every gate has a parameter). If non-parametrized gates are present, we can contract them into parametrized gates to achieve this, or assign them constant parameters (remember, the derivative of a constant is always 0).

We can write that the overall circuit unitary $U$ is a product of individual gates:

```math
U(\vec{p}) = \otimes_{i=1}^N U_{i}(p_i)
```

if there are $N$ gates in the circuit.

Then, using the product rule, we can write:

```math
\frac{\partial f}{\partial p_i} = \left\langle 0 \left| \otimes_{j=1}^{i-1} U^\dagger_j \otimes \frac{\partial U^\dagger_i(p_i)}{\partial p_i} \otimes_{j=i+1}^{n} U^\dagger_j \hat{O} U(\vec{p}) + U^\dagger(\vec{p}) \hat{O}\otimes_{j=i+1}^{n} U_j \otimes \frac{\partial U_i(p_i)}{\partial p_i}\otimes_{j=1}^{i-1} U_j \right| 0 \right\rangle
```

We can absorb the non-differentiated products so that:

```math
\frac{\partial f}{\partial p_i} = \left\langle \phi \left| \frac{\partial U^\dagger_i(p_i)}{\partial p_i} \hat{\mathcal{O}}U_i(p_i) + U^\dagger_i(p_i)\hat{\mathcal{O}}\frac{\partial U_i(p_i)}{\partial p_i}\right| \phi \right\rangle
```

where

```math
\left|\phi\right\rangle = \otimes_{j=1}^{i-1} U_j \left| 0 \right\rangle
```

and 

```math
\hat{\mathcal{O}} = \otimes_{j=i+1}^{n} U^\dagger_j  \hat{O} \otimes_{j=i+1}^{n} U_j
```

Now we can see that

```math
\frac{\partial U^\dagger_i(p_i)}{\partial p_i} \hat{\mathcal{O}}U_i(p_i) + U^\dagger_i(p_i)\hat{\mathcal{O}}\frac{\partial U_i(p_i)}{\partial p_i} = \frac{\partial}{\partial p_i} \left( U_i^\dagger(p_i) \hat{\mathcal{O}} U_i(p_i)\right)
```

so, in sum:

```math
\frac{\partial f}{\partial p_i} = \left\langle \phi \left|\frac{\partial}{\partial p_i} \left( U_i^\dagger(p_i) \hat{\mathcal{O}} U_i(p_i)\right)\right| \phi \right\rangle
```

and in many cases (but not all!) we can define a *shift* $s$ such that:

```math
\frac{\partial}{\partial p_i} \left( U_i^\dagger(p_i) \hat{\mathcal{O}} U_i(p_i)\right) = U_i^\dagger(p_i + s) \hat{\mathcal{O}} U_i(p_i + s) - U_i^\dagger(p_i - s) \hat{\mathcal{O}} U_i(p_i - s)
```

Thus the name "parameter shift". What makes this different from the finite differences method is that $s$ is not necessarily small. Detailed guides to choosing shifts and identifying which gates support the method can be found in Refs. [1](https://arxiv.org/abs/1803.00745) and [2](https://arxiv.org/abs/1811.11184). If a gate does *not* support a parameter shift rule, we can always fall back to the finite difference method.

We can see that the parameter shift method *also* requires two circuit executions to compute the partial derivative of each parametrized gate. The advantage over finite difference is in numerical accuracy. Parameter shift can be used both when `shots=0` or when `shots>0`. Since the introduction of the method, many extensions and generalizations have been published, including Refs. [3](https://arxiv.org/abs/2107.12390), [4](https://arxiv.org/abs/2005.10299), and many more. 
"""

# ╔═╡ 42822b26-269e-4d9e-92a2-cd34ef2ca4be
md"""
### Adjoint differentiation

The two methods we've examined so far, finite differences and parameter shift, both require two full circuit executions per parameter to compute the gradient. This can become very expensive, in both time and charges, for deep circuits and/or circuits with many parameters. Is there a way to compute gradients in a more "execution-frugal" way? For `shots=0`, the answer is yes. First introduced in Ref. [5](https://arxiv.org/abs/2009.02823), the adjoint differentiation method allows us to compute all partial derivatives in "1+1" circuit executions. How does it work? Recall that:

```math
\frac{\partial f}{\partial p_i} = \left\langle 0 \left| \otimes_{j=1}^{i-1} U^\dagger_j \otimes \frac{\partial U^\dagger_i(p_i)}{\partial p_i} \otimes_{j=i+1}^{n} U^\dagger_j \hat{O} U(\vec{p}) + U^\dagger(\vec{p}) \hat{O}\otimes_{j=i+1}^{n} U_j \otimes \frac{\partial U_i(p_i)}{\partial p_i}\otimes_{j=1}^{i-1} U_j \right| 0 \right\rangle
```

In the adjoint method, we take a different approach to computing this derivative. We realize that:

```math
\left( \left \langle 0 \left| \otimes_{j=1}^{i-1} U^\dagger_j \otimes \frac{\partial U^\dagger_i(p_i)}{\partial p_i} \otimes_{j=i+1}^{n} U^\dagger_j \hat{O} U(\vec{p}) \right| 0 \right\rangle \right)^\dagger = \left \langle 0 \left| U^\dagger(\vec{p}) \hat{O}\otimes_{j=i+1}^{n} U_j \otimes \frac{\partial U_i(p_i)}{\partial p_i}\otimes_{j=1}^{i-1} U_j \right| 0 \right\rangle
```

and thus, because all the gates are unitaries and the operator $\hat{O}$ is Hermitian,

```math
\frac{\partial f}{\partial p_i} = 2\Re \left\langle 0 \left| U^\dagger(\vec{p}) \hat{O}\otimes_{j=i+1}^{n} U_j \otimes \frac{\partial U_i(p_i)}{\partial p_i}\otimes_{j=1}^{i-1} U_j \right| 0 \right\rangle
```

where $\Re$ denotes the real part. Now we can absorb some factors so that:

```math
\frac{\partial f}{\partial p_i} = 2\Re \left\langle b_i \left| \frac{\partial U_i(p_i)}{\partial p_i} \right| k_i \right\rangle
```

where

```math
\left\langle b_i \right| = \left\langle 0 \right| U^\dagger(\vec{p}) \hat{O}\otimes_{j=i+1}^{n} U_j(p_j)
```

and

```math
\left | k_i \right\rangle = \otimes_{j=1}^{i-1} U_j(p_j) \left| 0 \right\rangle
```

The basis of the adjoint method is realizing that we can iteratively compute each partial derivative by "back stepping" through the circuit after having applied all its gates once. This is very similar to classical back propagation, if you're familiar with that technique from classical machine learning. We first apply all gates to compute $\left| k_n \right\rangle = \otimes_{j=1}^{n} U_j \left| 0 \right\rangle$, copy the state and apply $\hat{O}$ to acquire:

```math
\left\langle b_n \right| = \left\langle 0 \right| U^\dagger(\vec{p}) \hat{O}
```

then compute $\frac{\partial f}{\partial p_n}$:

```math
\frac{\partial f}{\partial p_n} = \left\langle b_n \left|\frac{\partial U_n(p_n)}{\partial p_n}\right| k_n \right\rangle
```

In a moment we'll address how to find $\frac{\partial U_n(p_n)}{\partial p_n}$. Once we've computed the first partial derivative, we update $\left\langle b_n\right|$ and $\left| k_n \right\rangle$ to generate:

```math
\left\langle b_{n-1} \right| = \left\langle b_n \right| U_n(p_n) \\
\left | k_{n-1} \right\rangle =  U^\dagger_{n-1} \left| k_n \right\rangle
```

By iteratively updating these two states, we can compute all partial derivatives with only one circuit execution plus one "back step" execution, significantly less than what is required by finite differences or parameter shift. The cost is that there is additional memory overhead, as we have to store an additional state vector and compute a third in the expectation value $\left\langle b_i \left|\frac{\partial U_i(p_i)}{\partial p_i}\right| k_i \right\rangle$.

How do we compute the derivative $\frac{\partial U_i(p_i)}{\partial p_i}$? In many cases, if $U_i(p_i)$ is continually differentiable with respect to $p_i$, we can simply take a matrix derivative. In particular, many parametrizable gates can be written as exponentials of Paulis, so that:

```math
\frac{\partial U_i(p_i)}{\partial p_i} = \frac{\partial}{\partial p_i}\exp\left\{ i c p_i \hat{P}\right\} = i c \hat{P} \exp\left\{ i c p_i \hat{P}\right\}
```

where $c$ is some constant, $\hat{P}$ is some Pauli gate, and $i$ is the imaginary number $\sqrt{-1}$. This is easily generalizable to exponents of sums of Paulis through the [chain rule](https://en.wikipedia.org/wiki/Chain_rule). In cases where $U(p_i)$ is **not** continuously differentiable, the derivative can be computed numerically, e.g. through finite differences as discussed above.

**Note:** Because it is formulated **only** for exact computations, the adjoint method can only be used on simulators, such as SV1, when running with `shots=0`.


The adjoint differentiation method is available through the `AdjointGradient` result type on Amazon Braket, which we'll introduce in the next section. With this result type, all derivatives are computed using the adjoint differentiation method.
"""

# ╔═╡ df640675-a439-4074-a6d9-df4f8289e446
md"""
## The `AdjointGradient` result type

Amazon Braket now supports a result type, `AdjointGradient`, which allows you to conveniently compute gradients of free parameters with respect to the expectation value of some observable on your circuits.

**Note:** Currently, the `AdjointGradient` result type is **only** supported on SV1 when running in `shots=0` mode. All derivatives are computed using the adjoint differentiation method.

Let's see an example of this result type in action:
"""

# ╔═╡ a86cabc6-77ba-4991-a02f-613219e8984c
device_arn = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"

# ╔═╡ 9a9f4565-f094-4352-b54d-fafd391a8e88
device = AwsDevice(device_arn)

# ╔═╡ d57a24ed-1b8d-4195-bdd6-7ab8969627bd
md"""
We can prepare a simple parametrized circuit and compute its gradient with respect to some observable. Note that you supply the observable to the `AdjointGradient` result type. Supported observables are:
  - Any of `Observables.Z()`, `Observables.X()`, `Observables.Y()`, `Observables.H()`, or `Observable.I()`
  - A `TensorProduct`
  - A `HermitianObservable`
  - A `Sum`
  
You can also supply the list of parameters to compute partial derivatives with respect to. If a parameter is present in the circuit, but not in the `parameters` argument to `adjoint_gradient`, its corresponding partial derivative will not be computed. If the list of `parameters` is empty, the gradient will be computed with respect to all free parameters present in the circuit.
"""

# ╔═╡ 8eea449b-2935-4aa4-9eaf-70d0c0af5c3d
begin
	θ = FreeParameter(:theta)
	γ = FreeParameter(:gamma)
	ag_circuit = Circuit([(H, 0), (CNot, 0, 1), (Rx, 0, θ), (Rx, 1, θ), (XX, 0, 1, γ)])
	# add the adjoint gradient result type

	# we can either explicitly provide a list of parameters
	#ag_circuit(AdjointGradient, Braket.Observables.Z() * Braket.Observables.Z(), [0, 1], [θ, γ])

	# or use the default of all
	ag_circuit(AdjointGradient, Braket.Observables.Z() * Braket.Observables.Z(), [0, 1], [])
end

# ╔═╡ 7621e93a-a14a-47e0-9d49-9ce24ce0b9e0
md"""
Now we can compute the gradient of the circuit with respect to our two free parameters for a given set of parameter values, which we supply to the `device` functor with the `inputs` argument:
"""

# ╔═╡ 59178e2e-707c-4e1f-b2ea-54c3aa718956
grad_1 = result(device(ag_circuit, shots=0, inputs = Dict("theta"=>0.1, "gamma"=>0.05))).values[1]

# ╔═╡ f1279ca2-26a3-4a3d-b50a-0ef6666eca5f
grad_2 = result(device(ag_circuit, shots=0, inputs = Dict("theta"=>0.2, "gamma"=>0.1))).values[1]

# ╔═╡ 12dc5ee9-1636-405b-b095-2a965d0ccaea
md"""
We can immediately see that although `θ` appears twice in the circuit (in two `Rx` gates), it only appears once in the result. `AdjointGradient` computes gradients **per parameter**, and **not** per-gate. We can also see that if `parameters` is empty, derivatives with respect to all free parameters will be computed. This is useful in cases when your circuit has a large number of free parameters.
"""

# ╔═╡ 4ab8a07d-da9b-4ccc-9bce-644f7da6de21
md"""
## Accelerating QAOA with `AdjointGradient`

Now we can see how using the `AdjointGradient` result type can improve performance for a hybrid algorithm such as QAOA. For an introduction to QAOA, see [its example notebook](https://github.com/aws/amazon-braket-examples/blob/main/examples/hybrid_quantum_algorithms/QAOA/QAOA_braket.ipynb). We'll create a `train` function to use `AdjointGradient` and determine a Jacobian, and compare this approach with the Jacobian-free method used in the QAOA notebook. Much of the code here is further explained in that notebook, so we strongly suggest you review it before proceeding. We'll run the entire QAOA workflow in `shots=0` mode so that we can compare with `AdjointGradient`, which means we can directly compute the cost (energy). First, we set up the problem and import the circuit generator and training functions:
"""

# ╔═╡ 4a29e5f3-5b28-41cd-af15-1a3e05ea6e83
begin
	# setup Erdos Renyi graph
	n = 10  # number of nodes/vertices
	m = 20  # number of edges
	seed = 2
	
	# define graph object
	G = SimpleWeightedGraph(erdos_renyi(n, m, seed=seed))
	
	# choose random weights
	weights_d = Uniform(0, 1)
	for edge in edges(G)
	    G.weights[edge.src, edge.dst] = rand(weights_d)
		G.weights[edge.dst, edge.src] = rand(weights_d)
	end
end

# ╔═╡ c3edb0ce-ecef-49a7-a799-b288a3c53d91
gplot(G)

# ╔═╡ ba3d585e-5118-480d-b09f-bbd2616022d3
# build Ising matrix corresponding to G
Jfull = triu(adjacency_matrix(G), 1)

# ╔═╡ f3afc1e5-b9ca-4938-9fd6-33c3a6a1fc87
n_qubits = size(Jfull, 1)

# ╔═╡ 8f0e6be9-440b-44af-8a4f-f8c4aefc2120
md"""
We can now specify hyperparameters for the training. We can choose the number of QAOA layers to use, the maximum iteration number, and the classical optimization algorithm to use.
"""

# ╔═╡ 29039bc9-f52f-4c3f-8457-8ad79a2ebc7a
DEPTH = 2  # circuit depth for QAOA

# ╔═╡ c4a122e2-a94e-4eaa-8c9b-44719b3be8d5
OPT_METHOD = BFGS()

# ╔═╡ 75d93548-30be-4ad7-8e65-de3a8556c224
optim_opts = Optim.Options(iterations = 30, show_trace=true, store_trace=true)

# ╔═╡ 3fe9dbbe-3ef2-44e2-9de8-a460eb06cdb8
md"""
We can also initialize the parameters and the initial guess for the energy (cost):
"""

# ╔═╡ 18d6f499-4c43-4448-ba1f-ccc70761c4cf
begin
	params_d = Uniform(0, 2π)
	γ_initial = rand(params_d, DEPTH)
	β_initial = rand(params_d, DEPTH)
	params_initial = vcat(γ_initial, β_initial)
	# initialize reference solution (simple guess)
	energy_init = 0.0
end

# ╔═╡ 301001e8-f48b-4198-aa70-d75b475dda5b
md"
Now we build up the QAOA circuit itself. For an introduction to QAOA, check out the main [Amazon Braket example notebook](https://github.com/aws/amazon-braket-examples/blob/main/examples/hybrid_quantum_algorithms/QAOA/QAOA_braket.ipynb).
"

# ╔═╡ a948c2fe-4c00-4b0d-a3fa-ae8ec0f02cff
"""
Returns circuit for driver Hamiltonian U(Hb, β)
"""
function driver(β, n_qubits)
	# instantiate circuit object
	circ = Circuit()
	# apply parametrized rotation around x to every qubit
	for qubit in 0:n_qubits-1
		circ(Rx, qubit, β)
	end
	return circ
end

# ╔═╡ fba6c5c9-d6af-4a04-8bfa-dd83a1ca99dc
"""
Returns circuit for evolution with cost Hamiltonian.
"""
function cost_circuit(γ, n_qubits, ising)
    # instantiate circuit object
    circ = Circuit()

    # get all non-zero entries (edges) from Ising matrix
    Is, Js, Vs = findnz(ising)
	edges = zip(Is, Js)

    # apply ZZ gate for every edge (with corresponding interaction strength)
    for (ii, qubit_pair) in enumerate(edges)
        circ(ZZ, qubit_pair[1], qubit_pair[2], γ[ii])
	end
    return circ
end

# ╔═╡ 8d011c5e-7924-455b-aac0-63afa674a562
"""
Returns full QAOA circuit of provided depth (inferred from length of `params` argument).
"""
function qaoa_builder(params, n_qubits, ising)
    # initialize qaoa circuit with first Hadamard layer:
	# for minimization start in |->
    circ = Circuit([(H, collect(0:n_qubits-1))])
	
    # setup two parameter families
    circuit_length = div(length(params), 2)
    γs = params[1:circuit_length]
    βs = params[circuit_length+1:end]

    # add QAOA circuit layer blocks
    for mm in 1:circuit_length
        append!(circ, cost_circuit(γs[mm], n_qubits, ising))
        append!(circ, driver(βs[mm], n_qubits))
	end
    return circ
end

# ╔═╡ f941586e-2b88-4f7e-8f5f-a0f93ebe8eee
"""
Builds a `Sum` observable representing the cost Hamiltonian.
"""
function cost_H(ising)
    Is, Js, Vs = findnz(ising)
	edges = collect(zip(Is, Js))

    H_terms = []
    # apply ZZ gate for every edge (with corresponding interaction strength)
    for qubit_pair in edges[2:end]
        # get interaction strength from Ising matrix
        int_strength = ising[qubit_pair[1], qubit_pair[2]]
        push!(H_terms, 2*int_strength * Braket.Observables.Z() * Braket.Observables.Z())
	end
    targets = [QubitSet([edge[1], edge[2]]) for edge in edges]
	H_0 = 2*ising[edges[1][1], edges[1][2]] * Braket.Observables.Z() * Braket.Observables.Z()
	sum_H = sum(H_terms, init=H_0)
    return sum_H, targets
end

# ╔═╡ 0656f232-f00e-4da8-a6a1-2c7156d9d840
"""
Applies the scaling terms to the raw derivatives provided by `AdjointGradient` in order to generate the correct Jacobian.
"""
function form_jacobian(n_params, gradient, ising)
    jac = zeros(Float64, n_params)
    Is, Js, Vs = findnz(ising)
    edges = collect(zip(Is, Js))
    split = div(n_params, 2)
    for i in 1:split
        # handle βs
        jac[split + i] += 2 * gradient[Symbol("beta_$i")]
        # handle γs
        for j in 1:length(edges)
			int_strength = ising[edges[j][1], edges[j][2]]
            jac[i] += 2 * int_strength * gradient[Symbol("gamma_$(i)_$(j)")]
		end
	end
    return jac
end

# ╔═╡ d9505af6-18c8-4381-9574-3c03645a8a11
"""
Creates the dictionary of parameter values to use when running the task.
"""
function form_inputs_dict(params, ising)
    n_params = length(params)
    params_dict = Dict{String, Float64}()
    Is, Js, Vs = findnz(ising)
    edges = collect(zip(Is, Js))
    split = div(n_params, 2)
    for i in 1:split
        params_dict["beta_$i"] = 2 * params[split + i]
        for j in 1:length(edges)
			int_strength = ising[edges[j][1], edges[j][2]]
            params_dict["gamma_$(i)_$(j)"] = 2 * int_strength * params[i]
		end
	end
    return params_dict
end

# ╔═╡ 14fa1f6d-2262-49f0-bc74-05e3974a29ca
md"
Now we have everything we need to define the objective function to pass to `optimize`.
"

# ╔═╡ a277af58-6d4b-4389-8821-5824cc6e71b0
begin 
	mutable struct AdjointClosure
		qaoa_circuit::Circuit
		ising::SparseMatrixCSC
		device::AwsDevice
	end
	"""
	Computes the cost and gradient in one call to SV1.
	"""
	function (oc::AdjointClosure)(F, G, params)
	    # create parameter dict
	    params_dict = form_inputs_dict(params, oc.ising) 
	    # classically simulate the circuit
	    # set the parameter values using the inputs argument
		timeout = 3 * 24 * 60 * 60
	    task = oc.device(oc.qaoa_circuit, shots=0, inputs=params_dict, poll_timeout_seconds=timeout)
	
	    # get result for this task
	    res = result(task)
	    gradient = res.values[1]
	    energy = gradient[:expectation]
	    jac = form_jacobian(length(params), gradient[:gradient], oc.ising)
	    if G != nothing
			copyto!(G, jac)
		end
		if F != nothing
			return energy
		end
	end
	Base.show(io::IO, ac::AdjointClosure) = print(io, "AdjointClosure")
end

# ╔═╡ 2c99922f-86cb-462d-84c4-a4d7793f0716
md"
We build a QAOA circuit which will use the `AdjointGradient` result type.
"

# ╔═╡ 22ebd728-520f-4c85-9198-1c15e1366058
begin
	γ_params = [[FreeParameter(Symbol("gamma_$(i)_$(j)")) for j in 1:nnz(Jfull)] for i in 1:DEPTH]
	β_params = [FreeParameter(Symbol("beta_$i")) for i in 1:DEPTH]
	params = vcat(γ_params, β_params)
	qaoa_circ = qaoa_builder(params, n_qubits, Jfull)
	
	Hamiltonian, targets = cost_H(Jfull)
    qaoa_circ(AdjointGradient, Hamiltonian, targets, [])
end

# ╔═╡ c9d8c32f-4980-4e8c-942a-dce5136b4ad2
ac = AdjointClosure(qaoa_circ, Jfull, device)

# ╔═╡ 591ae7b2-3fda-4301-b1d1-a97817246481
md"""
We can let `Optim.jl` know that we are able to compute the cost and gradient in one fell swoop by using [`only_fg!`](https://julianlsolvers.github.io/Optim.jl/stable/#user/tipsandtricks/#avoid-repeating-computations). Note that running the code below will submit tasks to an Amazon Braket on-demand simulator, and you may incur charges to your account. For that reason, the cell is commented out by default. Un-comment it if you wish to run the cell.
"""

# ╔═╡ Cell order:
# ╟─471998e8-763b-11ed-0be4-e5293a2b29d4
# ╟─5a45f736-f603-4f01-b3ca-1d415d7864c4
# ╟─dfba9752-1545-4d51-94b6-739954d63afc
# ╟─a516549b-0418-4123-a654-fdd17359493e
# ╟─202ca719-465e-4f4f-b5b2-40f953857288
# ╟─42822b26-269e-4d9e-92a2-cd34ef2ca4be
# ╟─df640675-a439-4074-a6d9-df4f8289e446
# ╠═3d3c1591-9bbc-4a2d-b375-049f7d91fe21
# ╠═492616b4-0cea-41fe-8a8e-11c6d60200cb
# ╠═a86cabc6-77ba-4991-a02f-613219e8984c
# ╠═9a9f4565-f094-4352-b54d-fafd391a8e88
# ╟─d57a24ed-1b8d-4195-bdd6-7ab8969627bd
# ╠═8eea449b-2935-4aa4-9eaf-70d0c0af5c3d
# ╟─7621e93a-a14a-47e0-9d49-9ce24ce0b9e0
# ╠═59178e2e-707c-4e1f-b2ea-54c3aa718956
# ╠═f1279ca2-26a3-4a3d-b50a-0ef6666eca5f
# ╟─12dc5ee9-1636-405b-b095-2a965d0ccaea
# ╟─4ab8a07d-da9b-4ccc-9bce-644f7da6de21
# ╠═4a29e5f3-5b28-41cd-af15-1a3e05ea6e83
# ╠═c3edb0ce-ecef-49a7-a799-b288a3c53d91
# ╠═ba3d585e-5118-480d-b09f-bbd2616022d3
# ╠═f3afc1e5-b9ca-4938-9fd6-33c3a6a1fc87
# ╟─8f0e6be9-440b-44af-8a4f-f8c4aefc2120
# ╠═29039bc9-f52f-4c3f-8457-8ad79a2ebc7a
# ╠═c4a122e2-a94e-4eaa-8c9b-44719b3be8d5
# ╠═75d93548-30be-4ad7-8e65-de3a8556c224
# ╟─3fe9dbbe-3ef2-44e2-9de8-a460eb06cdb8
# ╠═18d6f499-4c43-4448-ba1f-ccc70761c4cf
# ╟─301001e8-f48b-4198-aa70-d75b475dda5b
# ╠═a948c2fe-4c00-4b0d-a3fa-ae8ec0f02cff
# ╠═fba6c5c9-d6af-4a04-8bfa-dd83a1ca99dc
# ╠═8d011c5e-7924-455b-aac0-63afa674a562
# ╠═f941586e-2b88-4f7e-8f5f-a0f93ebe8eee
# ╠═0656f232-f00e-4da8-a6a1-2c7156d9d840
# ╠═d9505af6-18c8-4381-9574-3c03645a8a11
# ╟─14fa1f6d-2262-49f0-bc74-05e3974a29ca
# ╠═a277af58-6d4b-4389-8821-5824cc6e71b0
# ╟─2c99922f-86cb-462d-84c4-a4d7793f0716
# ╠═22ebd728-520f-4c85-9198-1c15e1366058
# ╠═c9d8c32f-4980-4e8c-942a-dce5136b4ad2
# ╟─591ae7b2-3fda-4301-b1d1-a97817246481
# ╠═71da8a3a-9632-4bf9-8b45-09b6a99dec60
# ╠═26408581-1132-4705-b401-c73343cd5c7b
