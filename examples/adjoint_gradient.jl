### A Pluto.jl notebook ###
# v0.19.20

using Markdown
using InteractiveUtils

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

# ╔═╡ 5e2dad4d-173a-474b-9fe7-f34048819ec9
md"""
**Note**: to run the code below, you'll need [valid AWS credentials](http://docs.aws.amazon.com/general/latest/gr/aws-security-credentials.html). You can paste them into the empty code block below if they are not already located in a file.
"""

# ╔═╡ 99a63307-966c-4057-88b2-0f1cf2f26f99
# Enter your AWS credential environment variables below, if needed:


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
We can let `Optim.jl` know that we are able to compute the cost and gradient in one fell swoop by using [`only_fg!`](https://julianlsolvers.github.io/Optim.jl/stable/#user/tipsandtricks/#avoid-repeating-computations). Note that running the code below will submit tasks to an Amazon Braket on-demand simulator, and you may incur charges to your account. For that reason, the cell is disabled by default. Enable it if you wish to run the cell.
"""

# ╔═╡ 0da7d875-c157-4998-bb16-55b949039923
# ╠═╡ disabled = true
#=╠═╡
opt_trace = Optim.optimize(Optim.only_fg!(ac), params_initial, Optim.BFGS())
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Braket = "19504a0f-b47d-4348-9127-acc6cc69ef67"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
GraphPlot = "a2cc645c-3eea-5389-862e-a155d0052231"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
SimpleWeightedGraphs = "47aef6b3-ad0c-573a-a1e2-d07658019622"
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[compat]
Braket = "~0.3.0"
Distributions = "~0.25.80"
GraphPlot = "~0.5.2"
Graphs = "~1.7.4"
Optim = "~1.7.4"
Plots = "~1.38.2"
SimpleWeightedGraphs = "~1.2.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-beta3"
manifest_format = "2.0"
project_hash = "869128a0a9cbe4801755582420a6cd0ddc69526f"

[[deps.AWS]]
deps = ["Base64", "Compat", "Dates", "Downloads", "GitHub", "HTTP", "IniFile", "JSON", "MbedTLS", "Mocking", "OrderedCollections", "Random", "SHA", "Sockets", "URIs", "UUIDs", "XMLDict"]
git-tree-sha1 = "487d6835da9876e0362a83aec169e390872eba64"
uuid = "fbe9abb3-538b-5e4e-ba9e-bc94f4f92ebc"
version = "1.81.0"

[[deps.AWSS3]]
deps = ["AWS", "ArrowTypes", "Base64", "Compat", "Dates", "EzXML", "FilePathsBase", "MbedTLS", "Mocking", "OrderedCollections", "Retry", "SymDict", "URIs", "UUIDs", "XMLDict"]
git-tree-sha1 = "04620168e20f9c922b738fc6b7d6cfb92973ebfb"
uuid = "1c724243-ef5b-51ab-93f4-b0a88ac62a95"
version = "0.10.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterfaceCore]]
deps = ["LinearAlgebra", "SnoopPrecompile", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "e5f08b5689b1aad068e01751889f2f615c7db36d"
uuid = "30b0a656-2188-435a-8636-2ec0e6a096e2"
version = "0.1.29"

[[deps.ArrowTypes]]
deps = ["UUIDs"]
git-tree-sha1 = "a0633b6d6efabf3f76dacd6eb1b3ec6c42ab0552"
uuid = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
version = "1.2.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "1dd4d9f5beebac0c03446918741b1a03dc5e5788"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.6"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "43b1a4a8f797c1cddadf60499a8a077d4af2cd2d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.7"

[[deps.Braket]]
deps = ["AWS", "AWSS3", "AxisArrays", "CSV", "Compat", "DataStructures", "Dates", "DecFP", "Distributed", "Downloads", "Graphs", "HTTP", "InteractiveUtils", "JSON3", "LinearAlgebra", "Logging", "Mocking", "NamedTupleTools", "OrderedCollections", "Random", "Statistics", "StructTypes", "Tar", "UUIDs"]
git-tree-sha1 = "f116c78dbaab8141c121a41962e28f442908051c"
uuid = "19504a0f-b47d-4348-9127-acc6cc69ef67"
version = "0.3.0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "SnoopPrecompile", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "c700cce799b51c9045473de751e9319bdd1c6e94"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.9"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c6d890a52d2c4d55d326439580c3b8d0875a77d9"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.7"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random", "SnoopPrecompile"]
git-tree-sha1 = "aa3edc8f8dea6cbfa176ee12f7c2fc82f0608ed3"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.20.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "00a2cccc7f098ff3b66806862d275ca3db9e6e5a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.5.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.Compose]]
deps = ["Base64", "Colors", "DataStructures", "Dates", "IterTools", "JSON", "LinearAlgebra", "Measures", "Printf", "Random", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "d853e57661ba3a57abcdaa201f4c9917a93487a2"
uuid = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
version = "0.9.4"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "fb21ddd70a051d882a1686a5a550990bbe371a95"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.1"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DecFP]]
deps = ["DecFP_jll", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "a8269e0a6af8c9d9ae95d15dcfa5628285980cbb"
uuid = "55939f99-70c6-5e9b-8bb0-5071ed7d61fd"
version = "1.3.1"

[[deps.DecFP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e9a8da19f847bbfed4076071f6fef8665a30d9e5"
uuid = "47200ebd-12ce-5be5-abb7-8e082af23329"
version = "2.0.3+1"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "c5b6685d53f933c11404a3ae9822afe30d522494"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.12.2"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "74911ad88921455c6afcad1eefa12bd7b1724631"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.80"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "0fa3b52a04a4e210aeb1626def9c90df3ae65268"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.1.0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "d3ba08ab64bdfd27234d3f61956c966266757fe6"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.7"

[[deps.FiniteDiff]]
deps = ["ArrayInterfaceCore", "LinearAlgebra", "Requires", "Setfield", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "04ed1f0029b6b3af88343e439b995141cb0d0b8d"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.17.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "a69dd6db8a809f78846ff259298678f0d6212180"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.34"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "9e23bd6bb3eb4300cb567bdf63e2c14e5d2ffdbc"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.71.5"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "aa23c9f9b7c0ba6baeabe966ea1c7d2c7487ef90"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.71.5+0"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.GitHub]]
deps = ["Base64", "Dates", "HTTP", "JSON", "MbedTLS", "Sockets", "SodiumSeal", "URIs"]
git-tree-sha1 = "5688002de970b9eee14b7af7bbbd1fdac10c9bbe"
uuid = "bc5e4493-9b4d-5f90-b8aa-2b2bcaad7a26"
version = "5.8.2"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.GraphPlot]]
deps = ["ArnoldiMethod", "ColorTypes", "Colors", "Compose", "DelimitedFiles", "Graphs", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "5cd479730a0cb01f880eff119e9803c13f214cab"
uuid = "a2cc645c-3eea-5389-862e-a155d0052231"
version = "0.5.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "ba2d094a88b6b287bd25cfa86f301e7693ffae2f"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.7.4"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "Dates", "IniFile", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "eb5aa5e3b500e191763d35198f859e4b40fff4a6"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.7.3"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions", "Test"]
git-tree-sha1 = "709d864e3ed6e3545230601f94e11ebc65994641"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.11"

[[deps.Inflate]]
git-tree-sha1 = "5cd07aab533df5170988219191dfad0519391428"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.3"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "0cf92ec945125946352f3d46c96976ab972bde6f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.3.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "16c0cc91853084cb5f58a78bd209513900206ce6"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.4"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "f377670cda23b6b7c1c0b3893e37451c5c1a2185"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.5"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "SnoopPrecompile", "StructTypes", "UUIDs"]
git-tree-sha1 = "84b10656a41ef564c39d2d477d7236966d2b5683"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.12.0"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "2422f47b34d4b127720a18f86fa7b1aa2e141f29"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.18"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "946607f84feb96220f480e0422d3484c49c00239"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.19"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "c272302b22479a24d1cf48c114ad702933414f80"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.5"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NamedTupleTools]]
git-tree-sha1 = "90914795fc59df44120fe3fff6742bb0d7adb1d0"
uuid = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
version = "0.14.3"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "6503b77492fd7fcb9379bf73cd31035670e3c509"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.3.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6e9dba33f9f2c44e08a020b0caf6903be540004"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.19+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "1903afc76b7d01719d9c30d3c7d501b61db96721"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.4"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "cf494dca75a69712a72b80bc48f59dcf3dea63ec"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.16"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "8175fc2b118a3755113c8e68084dc1a9e63c61ee"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.3"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "1f03a2d339f42dca4a4da149c7e15e9b896ad899"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.1.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "SnoopPrecompile", "Statistics"]
git-tree-sha1 = "5b7690dd212e026bbab1860016a6601cb077ab66"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.2"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Preferences", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SnoopPrecompile", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "a99bbd3664bb12a775cda2eba7f3b2facf3dad94"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.38.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "de191bc385072cc6c7ed3ffdc1caeed3f22c74d4"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.7.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.RecipesBase]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "261dddd3b862bd2c940cf6ca4d1c8fe593e457c8"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.3"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase", "SnoopPrecompile"]
git-tree-sha1 = "e974477be88cb5e3040009f3767611bc6357846f"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.11"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "90bc7a7c96410424509e4263e277e43250c05691"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Retry]]
git-tree-sha1 = "41ac127cd281bb33e42aba46a9d3b25cd35fc6d5"
uuid = "20febd7b-183b-5ae2-ac4a-720e7ce64774"
version = "0.4.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "f94f779c94e58bf9ea243e77a37e16d9de9126bd"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "c02bd3c9c3fc8463d3591a62a378f90d2d8ab0f3"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.17"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays", "Test"]
git-tree-sha1 = "a8d28ad975506694d59ac2f351e29243065c5c52"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.2.2"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SodiumSeal]]
deps = ["Base64", "Libdl", "libsodium_jll"]
git-tree-sha1 = "80cef67d2953e33935b41c6ab0a178b9987b1c99"
uuid = "2133526b-2bfb-4018-ac12-889fb3908a75"
version = "0.1.1"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "6954a456979f23d05085727adb17c4551c19ecd1"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.12"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "ab6083f09b3e617e34a956b43e9d51b824206932"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.1.1"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "ca4bccb03acf9faaf4137a9abc1881ed1841aa70"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.10.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+0"

[[deps.SymDict]]
deps = ["Test"]
git-tree-sha1 = "0108ccdaea3ef69d9680eeafc8d5ad198b896ec8"
uuid = "2da68c74-98d7-5633-99d6-8493888d7b1e"
version = "0.3.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "c79322d36826aa2f4fd8ecfa96ddb47b174ac78d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[deps.URIs]]
git-tree-sha1 = "ac00576f90d8a259f2c9d823e91d1de3fd44d348"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "ed8d92d9774b077c53e1da50fd81a36af3744c1c"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XMLDict]]
deps = ["EzXML", "IterTools", "OrderedCollections"]
git-tree-sha1 = "d9a3faf078210e477b291c79117676fca54da9dd"
uuid = "228000da-037f-5747-90a9-8195ccbf91a5"
version = "0.4.1"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "868e669ccb12ba16eaf50cb2957ee2ff61261c56"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.29.0+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.2.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsodium_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "848ab3d00fe39d6fbc2a8641048f8f272af1c51e"
uuid = "a9144af2-ca23-56d9-984f-0d03f7b5ccf8"
version = "1.0.20+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9ebfc140cc56e8c2156a15ceac2f0302e327ac0a"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+0"
"""

# ╔═╡ Cell order:
# ╟─471998e8-763b-11ed-0be4-e5293a2b29d4
# ╟─5a45f736-f603-4f01-b3ca-1d415d7864c4
# ╟─dfba9752-1545-4d51-94b6-739954d63afc
# ╟─a516549b-0418-4123-a654-fdd17359493e
# ╟─202ca719-465e-4f4f-b5b2-40f953857288
# ╟─42822b26-269e-4d9e-92a2-cd34ef2ca4be
# ╟─df640675-a439-4074-a6d9-df4f8289e446
# ╠═492616b4-0cea-41fe-8a8e-11c6d60200cb
# ╠═a86cabc6-77ba-4991-a02f-613219e8984c
# ╟─5e2dad4d-173a-474b-9fe7-f34048819ec9
# ╠═99a63307-966c-4057-88b2-0f1cf2f26f99
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
# ╠═0da7d875-c157-4998-bb16-55b949039923
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
