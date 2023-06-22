### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 23aaba4e-3342-4581-a6bf-b039c390062e
using OrderedCollections, Braket, PyBraket, PyBraket.PythonCall, CondaPkg

# ╔═╡ ff4fad96-1970-4fb9-a43a-df02cd5dc643
using Plots

# ╔═╡ 2f49c108-9d9f-11ed-1a79-eb966fa5a322
md"""
# Quantum Chemistry Simulation with Amazon Braket and VQE
"""

# ╔═╡ 2e2c9fce-5d4f-411c-9951-0b5909111155
md"""
In this example, we show how to implement the variational quantum eigensolver using `Braket.jl` and use it to find the groundstate of a simple molecular Hamiltonian with the assistance of the Braket local simulator.

**Note**: This notebook uses the Python software [`pyscf`](https://pyscf.org/) to generate the molecular Hamiltonian and apply a Jordan-Wigner transformation to it.
If you are using OSX, you may need to set the environment variable `KMP_DUPLICATE_LIB_OK=true` in order to avoid `pyscf` segfaulting. See [this GitHub issue](https://github.com/dmlc/xgboost/issues/1715) for more information. You can set this environment variable in this script by adding a new cell with `ENV["KMP_DUPLICATE_LIB_OK"] = true`.
"""

# ╔═╡ 6ada7712-6f03-4f56-8254-085d878d61fc
md"""
## Formulation of the problem

In computational chemistry, we are commonly interested in finding the ground-state energy (i.e., lowest energy) of a molecule for a given configuration of atomic positions. This can be done by finding the smallest eigenvalue(s) and corresponding eigenstate(s) of the molecular Hamiltonian.

### Generating the molecular Hamiltonian

The Hamiltonian for a generic molecule can be written:

```math
H_{full} = - \frac{1}{2}\sum_i \nabla_i^2 - \sum_I \frac{\nabla_I^2}{2 M_I} - \sum_{i,I} \frac{Z_I}{|\mathbf{r}_i - \mathbf{R}_I|} + \frac{1}{2} \sum_{i \neq j} \frac{1}{|\mathbf{r}_i - \mathbf{r}_j|} + \frac{1}{2} \sum_{I \neq J} \frac{1}{|\mathbf{R}_I - \mathbf{R}_J|}
```

where $i$ labels the electrons and $I$ the nuclei. $\mathbb{r}_i$ denotes the $i$-th electron's position and $\mathbb{R}_I$ the position of the $I$-th nucleus. $Z_I$ is the $I$-th nuclear charge and $M_I$ the $I$-th nuclear mass.

The first two terms in $H_{full}$ represent the electronic and nuclear kinetic energies, and the others are Coulomb interactions: between the nuclei and electrons, then among the electrons, then among the nuclei.

Since our focus is on the **electronic** structure (which orbitals the electrons occupy), we'll use the [Born-Oppenheimer approximation](https://en.wikipedia.org/wiki/Born%E2%80%93Oppenheimer_approximation). The approximation is based on the fact that nuclei are over 1000x heavier than an electron and thus their kinetic energy contributes negligibly to the final solution and we can consider their positions fixed. This allows us to simplify $H_{full}$:

```math
H_{B-O} = - \frac{1}{2}\sum_i \nabla_i^2 - \sum_{i,I} \frac{Z_I}{|\mathbf{r}_i - \mathbf{R}_I|} + \frac{1}{2} \sum_{i \neq j} \frac{1}{|\mathbf{r}_i - \mathbf{r}_j|}
```

### Second quantization

**Note**: in this subsection, we give a brief overview of [second quantization](https://en.wikipedia.org/wiki/Second_quantization). For a more in-depth treatment, consider consulting a quantum mechanics or statistical physics textbook.

Finding the groundstate of this simplified Hamiltonian can be done, but there are further simplifications we can make which will make the problem significantly more tractable. We will rewrite this Hamiltonian, which is after all a linear operator, in a new basis of single electron *spin orbitals* $\{ \phi_p(\mathbf{x}_i) \}$, where $\mathbf{x}_i = (\mathbf{r}_i, s_i)$ represents the position and spin of the $i$-th electron.

The many-electron wavefunction is expressed as a [Slater determinant](https://en.wikipedia.org/wiki/Slater_determinant) of these single-electron basis functions, i.e., as an antisymmetrized product, so that the electrons automatically satisfy the [Pauli exclusion principle](https://en.wikipedia.org/wiki/Pauli_exclusion_principle). While the total number of single-electron basis functions, $M$, is typically larger than the total number of electrons, $N$, in the molecule, the electrons can only occupy $N < M$ of these orbitals in a Slater determinant. In other words, a Slater determinant contains only occupied orbitals. 

Since any Slater determinant of the basis functions is uniquely determined by which orbitals are occupied, a Slater determinant can be represented in an abstract vector space, called the Fock space, by an *occupation number vector* $|f\rangle = |f_{M-1}f_{M-2}\ldots f_1 f_0\rangle$ where each $f_i$ is either 0 or 1 depending on whether the $i$-th orbital is unoccupied (0) or occupied (1) in the Slater determinant.

Next, we introduce a set of operators $\{a_p, a^\dagger_p\}$, called the fermion annihilation and creation operators respectively, corresponding to each of the basis functions $\{ \phi_p(\mathbf{x}_i) \}$. These operators satisfy the [anticommutation](https://mathworld.wolfram.com/Anticommutator.html) relations:

```math
\begin{align*}
\{a_p, a_q\} =& 0 \\
\{a^\dagger_p, a^\dagger_q\} =& 0 \\
\{a_p, a^\dagger_q\} =& \delta_{p,q} \\
\end{align*}
```

Where $\delta_{p,q}$ is the [Kronecker delta](https://en.wikipedia.org/wiki/Kronecker_delta), which is 1-valued if and only if $p = q$, and 0-valued otherwise. These relations will enforce the Fermi-Dirac statistics of the electrons.

Using these operators, we can rewrite $H_{B-O}$ in second-quantized form. We define:

```math
\begin{align*}
h_{pq} =& \int d\mathbf{x}\phi_p^*(\mathbf{x}) \left( -\frac{\nabla^2}{2} - \sum_I \frac{Z_I}{|\mathbf{r} - \mathbf{R}_I|} \right) \phi_q(\mathbf{x}) \\
h_{pqrs} =& \int d\mathbf{x}_1 d\mathbf{x}_2 \frac{\phi_p^*(\mathbf{x}_1) \phi_q^*(\mathbf{x}_2)\phi_s(\mathbf{x}_1)\phi_r(\mathbf{x}_2)}{|\mathbf{r}_1 - \mathbf{r}_2|} \\
\end{align*}
```

And finally write the second quantized Hamiltonian:

```math
H_{sq} = \sum_{p,q} h_{pq} a_p^\dagger a_q + \frac{1}{2} \sum_{p,q,r,s} h_{pqrs} a_p^\dagger a_q^\dagger a_r a_s
```

This $H$ includes only 1- and 2-electron terms. In fact, higher order terms do contribute but can often be neglected, so we have made another approximation when writing down $H_{sq}$.

For a more detailed derivation of how this $H_{sq}$ is derived from $H_{B-O}$, see .

### Basis sets

So how does one decide on the specific $\{ \phi_p(\mathbb{x}_i) \}$? In the quantum chemistry literature, there are quite a few varieties that have been developed:

  - [STO-$n$G](https://en.wikipedia.org/wiki/STO-nG_basis_sets) (also called *minimal basis sets*)
  - [Split-valence](https://en.wikipedia.org/wiki/Basis_set_(chemistry))
  - [Correlation-consistent](https://en.wikipedia.org/wiki/Basis_set_(chemistry))
  - [Polarization-consistent](https://en.wikipedia.org/wiki/Basis_set_(chemistry))
  - [Plane-wave](https://en.wikipedia.org/wiki/Basis_set_(chemistry))

## Finding the groundstate Slater determinant: the Hartree-Fock method

The [Hartree-Fock](https://en.wikipedia.org/wiki/Hartree%E2%80%93Fock_method) method is a technique to find the most-dominant Slater determinant that best-approximates the groundstate wavefunction by optimizing the *spatial* form of the spin orbitals $\{\phi_p(\mathbb{x})\}$ in a *self consistent* fashion. The Slater determinant generated by the optimized spin orbitals (also known as canonical orbitals), which are computed by the HF method, is used as the reference state for post Hartree-Fock methods that try to correct for some of the approximations in the HF method itself.

There are a variety of post Hartree-Fock (post-HF) methods employed in classical computational chemistry to improve upon the accuracy of a simple HF computation to varying degrees [1], e.g.,

* [Configuration interaction and Full Configuration Interaction](https://en.wikipedia.org/wiki/Configuration_interaction)
* [Multi-configurational self-consistent field](https://en.wikipedia.org/wiki/Multi-configurational_self-consistent_field)
* [Coupled cluster](https://en.wikipedia.org/wiki/Coupled_cluster)
* [Perturbation theory](https://en.wikipedia.org/wiki/M%C3%B8ller%E2%80%93Plesset_perturbation_theory)

## Mapping the problem to a quantum computer

So far, the entire discussion has concerned *fermions*. We now want to map these fermionic states to *qubits* so that we can simulate them on a quantum computer. To do this, we will use the [Jordan-Wigner transformation](https://en.wikipedia.org/wiki/Jordan%E2%80%93Wigner_transformation). This is the simplest among many techniques for achieving the same end. In the Jordan-Wigner transformation, we store the occupation number of an orbital $f_i$ in the $i$-th qubit as either $|0\rangle$ or $|1\rangle$ depending on whether the orbital is unoccupied or occupied respectively. Correspondingly, the fermionic annihilation and creation operators are mapped to the qubit operators as:

```math
\begin{align*}
a_p =& Q_p \otimes Z_{p-1} \otimes \ldots \otimes Z_0 \\
a^\dagger_p &= Q^\dagger_p \otimes Z_{p-1} \otimes \ldots \otimes Z_0 \\
Q &= |0\rangle\langle 1 | \\
Q^\dagger &= |1\rangle\langle 0 | \\
Z &= |0\rangle\langle 0| - |1\rangle\langle 1| \\
\end{align*}
```

In this encoding, the occupation of an orbital is stored locally, in a single qubit, but the parity is stored non-locally. This makes the Jordan-Wigner transformation not as efficient compared to other encoding techniques, e.g., Bravyi-Kitaev encoding, but for small systems with a few qubits, the efficiency gap is not significant.

## Variational Quantum Eigensolver

Now that we have an approximation of the Hamiltonian that can be represented on a quantum computer, we need a way to find or at least approximate its groundstate (lowest-lying eigenvector). The variational quantum eigensolver (VQE) is a NISQ (noisy intermediate-scale quantum) algorithm, which uses the quantum computer only for a classically intractable subroutine and which has been shown to be robust against noise [2,4] and capable of finding ground-state energies of small molecules using low-depth quantum circuits.

VQE is based on the Raleigh-Ritz variational principle: for a trial wavefunction $|\psi(\vec{\theta})\rangle$, parameterized by a vector of parameters $\vec{\theta}$, for a system with Hamiltonian $H$ with lowest eigenvalue $E_0$,

```math
\left\langle \psi(\vec{\theta}) \right| H \left| \psi(\vec{\theta}) \right\rangle \geq E_0
```

So to approximate $E_0$ we have to optimize $\vec{\theta}$. We can prepare the state $|\psi(\vec{\theta})\rangle$ using some unitary circuit $U(\vec{\theta})$ also parametrized by $\vec{\theta}$:

```math
|\psi(\vec{\theta})\rangle = U(\vec{\theta}) | \psi_{ref} \rangle
```

Where $|\psi_{ref}\rangle$ is some reference state, for example a Hartree-Fock state. We use the quantum computer to prepare $|\psi(\vec{\theta})\rangle$ and compute $\left\langle \psi(\vec{\theta}) \right| H \left| \psi(\vec{\theta}) \right\rangle$, and the classical computer to update $\vec{\theta}$.

How to choose the gates in $U$? This is up to us, and an ongoing area of research, but a popular option is to use the unitary coupled cluster ansatz, truncating it to only consider *single* and *double* excitations (seem familar from our discussion of $H_{sq}$ above?). This ansatz is called UCCSD.

## UCCSD ansatz

The unitary coupled cluster (UCC) method is an extension of the coupled-cluster (CC) method, which is one of the most popular post-HF methods [2]. In the UCC method, the parameterized trial function $U(\vec{\theta})$ is given by:

```math
\begin{align*}
U(\vec{\theta}) =& \exp\{T - T^\dagger\} \\
T &= \sum_{i=1}^{N} T_i \\
T_1 &= \sum_{i \in virt, \alpha \in occ} \theta_{i\alpha} a^\dagger_i a_\alpha \\
T_2 &= \sum_{i,j \in virt, \alpha, \beta \in occ} \theta_{ij\alpha\beta} a^\dagger_ia^\dagger_j a_\alpha a_\beta \\
\end{align*}
```
Where $virt$ is the set of **unoccupied** orbitals and $occ$ is the set of **occupied** orbitals. $T_1$ is the sum of all **single** excitations and $T_2$ is the sum of all **double** excitations (and further with $T_3$, $T_4$, had we included them). By examining them closely you can see each term in $T_1$ excites **one** electron from an occupied orbital into an unoccupied one, and each term in $T_2$ excites **two** electrons.

## Molecular Hamiltonian for the hydrogen molecule

For simplicity, we will use the minimal basis set STO-3G for the $H_2$ molecule, which includes only the $\{1s\}$ orbital for each atom. Since each atom contributes one spin-orbital, and there are 2 possible spins for each orbital (up or down), this leads to a total of 4 single electron orbitals for $H_2$ in the STO-3G basis set [2]:

```math
|1s_{A\uparrow}\rangle, |1s_{A\downarrow}\rangle, |1s_{B\uparrow}\rangle, |1s_{B\downarrow}\rangle
```

where the subscripts $A$ and $B$ label the atom and $\uparrow, \downarrow$ label the electron spin respectively. These can be rewritten into the molecular orbital basis:

```math
\begin{align*}
|\sigma_{g\uparrow}\rangle &= \frac{1}{\sqrt{2}} \left(|1s_{A\uparrow}\rangle + |1s_{B\uparrow}\rangle\right) \\
|\sigma_{g\downarrow}\rangle &= \frac{1}{\sqrt{2}} \left(|1s_{A\downarrow}\rangle + |1s_{B\downarrow}\rangle\right) \\
|\sigma_{u\uparrow}\rangle &= \frac{1}{\sqrt{2}} \left(|1s_{A\uparrow}\rangle - |1s_{B\uparrow}\rangle\right) \\
|\sigma_{u\downarrow}\rangle &= \frac{1}{\sqrt{2}} \left(|1s_{A\downarrow}\rangle - |1s_{B\downarrow}\rangle\right) \\
\end{align*}
```

And we can write the Slater determinant with respect to these new states as:

```math
|\psi\rangle = |f_{u\downarrow}f_{u\uparrow}f_{g\downarrow}f_{g\uparrow}\rangle = |f_3f_2f_1f_0\rangle 
```

Now we can develop our Hamiltonian. In the second quantized basis (see our development of $H_{sq}$ above):

```math
\begin{align*}
H &= H_1 + H_2 + H_3 + H_4 \\
H_1 =& \sum_{i=0}^3 h_{ii}a^\dagger_ia_i \\
H_2 =& \sum_{i=0}^2 h_{i,i+1,i+1,i} a_i^\dagger a^\dagger_{i+1}a_{i+1}a_i \\
H_3 =& \sum_{i=0}^1 (h_{i,i+2,i+2,i} - h_{i,i+2,i,i+2} ) a_i^\dagger a^\dagger_{i+2}a_{i+2}a_i \\
H_4 =& h_{0132}\left(a_0^\dagger a^\dagger_{1}a_{3}a_2 + a_2^\dagger a^\dagger_{3}a_{1}a_0\right) + h_{0312}\left(a_0^\dagger a^\dagger_{3}a_{1}a_2 + a_2^\dagger a^\dagger_{1}a_{3}a_0\right) \\
\end{align*}
```

Applying the Jordan-Wigner transformation, we compute:
```math
\begin{align*}
H_{Q} &= H_{Q1} + H_{Q2} + H_{Q3} \\
H_{Q1} &= h_0 I + h_1 Z_0 + h_2Z_1 + h_3 Z_2 + h_4 Z_3 \\
H_{Q2} &= h_5 Z_0 Z_1 + h_6 Z_0Z_2 + h_7 Z_1Z_2 + h_8 Z_0Z_3 + h_9 Z_1Z_3 + h_{10}Z_2Z_3 \\
H_{Q3} &= h_{11} Y_0 Y_1 X_2 X_3 + h_{12}X_0 Y_1 Y_2 X_3 + h_{13}Y_0X_1X_2Y_3 + h_{14}X_0X_1Y_2Y_3 \\
\end{align*}
```
The specific $h_i$ values can be computed numerically from the positions of the atoms in $H_2$. We'll use `pyscf` to do this.

In the JW encoding, the HF state, which is taken as the reference state for the UCCSD ansatz for VQE, is given by $|\psi_{HF}\rangle = |0011\rangle$. This represents the orbitals $|\sigma_{g\uparrow}\rangle, |\sigma_{g\downarrow}\rangle$ being occupied and $|\sigma_{u\uparrow}\rangle, |\sigma_{u\downarrow}\rangle$ being unoccupied.

The most general wavefunction $|\psi\rangle$ for $H_2$ which preserves charge and spin multiplicity is:

```math
|\psi\rangle = \alpha |0011\rangle + \beta |1100\rangle + \gamma|1001\rangle + \delta |0110\rangle
```

And after some algebra (not shown) we can write the UCCSD ansatz $U(\theta) = \exp\{i\theta X_3X_2X_1Y_0\}$.
"""

# ╔═╡ 0280b99d-2769-4f21-9fa4-fcdf4f25fd58
md"""
## Execution on a quantum simulator

Finally we have all the pieces we need:
- an initial guess for the groundstate
- a quantum computer compatible representation of the molecular Hamiltonian
- an algorithm to optimize the initial guess

Now we will try to determine both the groundstate energy and most likely bond length of $H_2$. The bond length with minimal groundstate energy is most likely. To be more concrete, we will:

1. Use `openfermion` and `pyscf` to compute the coefficients $\{h_i\}$ of $H_Q$ for a particular bond length.
2. Implement the UCCSD ansatz in `Braket.jl`.
3. Use VQE to optimize the parameter in the ansatz and obtain a good approximation of $E_0$ for the bond length.
4. Plot the results to determine the most likely bond length.

First, let's write our generic UCCSD ansatz for $|\psi(\theta)\rangle$:
"""

# ╔═╡ af4a74c8-fa8d-4c9a-a29d-27476c80b5e5
function ansatz(θ)
	c = Circuit()
	c(H, 0)
	c(H, 1)
	c(X, 2)
	c(H, 2)
	c(X, 3)
	c(Rx, 3, π/2)
	c(CNot, 3, 2)
	c(CNot, 2, 1)
	c(CNot, 1, 0)
	c(Rz, 0, θ)
	c(CNot, 1, 0)
	c(CNot, 2, 1)
	c(CNot, 3, 2)
	c(Rx, 3, -π/2)
	c(H, 0)
	c(H, 1)
	c(H, 2)
	return c
end

# ╔═╡ 3c46d71a-7d49-4d91-b536-817333b8f284
md"""
Now we can install and load the necessary Python packages:
"""

# ╔═╡ 6626ac70-8fb2-4513-9443-5f90818f7ad4
#install Python packages
begin
	CondaPkg.add_pip("pennylane", version="==0.28.0")
	CondaPkg.add_pip("pyscf", version="==2.1.1")
	CondaPkg.add_pip("openfermion", version="==1.5.1")
	CondaPkg.add_pip("openfermionpyscf", version="==0.5")
end

# ╔═╡ 67b067f4-6375-42fe-aa9d-8b46f9483ed1
#import Python packages
begin
	pyscf = pyimport("pyscf")
	scf = pyimport("pyscf.scf")
	transforms = pyimport("openfermion.transforms")
	of = pyimport("openfermion")
	ofpyscf = pyimport("openfermionpyscf")
end

# ╔═╡ 738480aa-90d3-46e1-9796-340c30290a23
# set parameters for classical computations
begin
	total_charge = 0
	spin_mult = 1
	basis_set = pystr("sto-3g")
	# number of active electrons and orbitals to consider
	# for H2 we consider all electrons and orbitals as active for STO-3G
	occ_ind = nothing
	act_ind = nothing
end

# ╔═╡ 824ff10a-8bdc-4206-865a-facaa4b18824
# set of bond lengths to try to simulate ground-state of H2 (in Angstroms)
bond_lengths = range(start=0.24, stop=3.00, step=0.1)

# ╔═╡ 707da214-4ae6-41a7-94b3-7168f3b01f61
# number of shots to use in the simulator
n_shots = 0

# ╔═╡ e2d61370-0229-46a8-90e6-21fac0fb7056
# number of VQE parameter values to scan
n_theta = 24

# ╔═╡ cbbd1b17-e9e5-4e3e-8cc1-fc0c26b8e66f
dev = LocalSimulator()

# ╔═╡ de771faa-96f7-44d0-801b-76fbb9dc8509
md"""
### Classical pre-computation of the electronic Hamiltonian of $H_2$
"""

# ╔═╡ 9617dc3a-49fe-4a0e-85b9-c88c6deb7caf
mol_data = OrderedDict{Number, Py}()

# ╔═╡ 2b291132-3415-49b5-a056-375f36bec59d
# generate OpenFermion MolecularData for each bond length
for rr in bond_lengths
	rounded_rr = round(rr, digits=2)
	@info "Computing molecular data for bond-length $rounded_rr Angstroms"
	geom = pylist([pytuple((pystr("H"), pytuple((0., 0., -rounded_rr/2.)))), pytuple((pystr("H"), pytuple((0., 0., rounded_rr/2.))))])
	desc = pystr("bondlength_"*string(rounded_rr)*"A")
    mol = of.MolecularData(geometry=geom, basis=basis_set, multiplicity=spin_mult,
        description=desc, filename=pystr(""),
        data_directory=pystr(pwd()))
	mol_data[rounded_rr] = mol 
end

# ╔═╡ e1369cc5-3f74-4399-adbd-8743c3cd67e1
mol_configs = OrderedDict{Number, Vector}()

# ╔═╡ 867967c4-a05b-4f17-ab61-17ceb76376e2
for (rounded_rr, dat) in mol_data
	@info "Running pyscf for bond-length $rounded_rr Angstroms"
	h2_molecule = ofpyscf.run_pyscf(molecule=dat, run_scf=true,
                            run_mp2=false, run_cisd=false,
                            run_ccsd=false, run_fci=true, verbose=false)
	mol_configs[rounded_rr] = Any[h2_molecule]
end

# ╔═╡ 0ae58b97-7f99-4ffe-9a7b-276f1fe0665d
for (rounded_rr, H) in mol_configs
	@info "Computing Hamiltonian for bond-length $rounded_rr Angstroms"
    h2_molecule = H[1]
    mol_H = h2_molecule.get_molecular_hamiltonian(occupied_indices=occ_ind, active_indices=act_ind)
    fermion_op = transforms.get_fermion_operator(mol_H)
    h2_qubit_hamiltonian = transforms.jordan_wigner(fermion_op)
    push!(mol_configs[rounded_rr], h2_qubit_hamiltonian)
end

# ╔═╡ c144939e-a80b-4c85-b991-271dc8a8b0db
md"""
### Computing the expectation value of $H_Q$

We compute the expectation value of each term in the Hamiltonian separately as they are not mutually commuting. This is inexpensive to do because the qubit count is small and we're using the local simulator.
"""

# ╔═╡ 3b4891c3-9e21-4bb0-9dac-62dfbcc390ab
"""
	calculate_observable_expectation(gates_and_inds::Vector{Tuple{Int, Braket.Observable}}, c::Circuit, dev, shots::Integer)

Calculates the expectation value of the given observable.
"""
function calculate_observable_expectation(gates_and_inds, θ, d::Device, shots::Integer)
	# this is the constant term of the Hamiltonian
    isempty(gates_and_inds) && return 1.0
    c_with_obs = ansatz(θ) 
    n_qubits = qubit_count(c_with_obs)
	# N.B.: Convert from OpenFermion's little-endian convention
	# to Braket's big-endian convention
    factors = Dict{Int, String}()
    for (ind, factor) in gates_and_inds
        qubit = n_qubits - 1 - pyconvert(Int, ind)
		factors[qubit] = pyconvert(String, factor)
	end
    qubits = sort(collect(keys(factors)))
    observable = Braket.Observables.TensorProduct([factors[qubit] for qubit in qubits])
    # initialize circuit and add expectation measurement
    c_with_obs(Expectation, observable, qubits)
    # compute expectation value
    res = result(d(c_with_obs, shots=shots))
	exp = first(res.values)
    return exp
end

# ╔═╡ ea391b9a-13fb-4952-80df-a590a23ea741
function exp_H(Hq, θ, d::Device, shots::Integer)
	E = 0.0
    for (gates_and_inds, term) in Hq.items()
        coeff = real(pyconvert(Float64, term))
        exp = calculate_observable_expectation(gates_and_inds, θ, d, shots)
		E += coeff * exp
	end
	return E
end

# ╔═╡ cddbf3ee-61fe-4ca8-a30d-a04fa10ff88c
# Now we can loop over all the possible bond lengths we want to try and compute the ground state energies:
for (r, v) in mol_configs
	@info "Computing ground-state energy for bond-length $r A"
	# Initialize energy guess
	push!(mol_configs[r], 1e5)
    for θ ∈ LinRange(-π, π, n_theta+1)
        # get expectation value of this config's Hamiltonian for this parameter value
        E_θ = exp_H(v[2].terms, θ, dev, n_shots)
        # if this expectation value is less than min found so far, update it
        if E_θ < mol_configs[r][end]
            mol_configs[r][end] = E_θ
        end
	end
	@info "min <H(R=$r A)> = $(mol_configs[r][end]) Ha"
end

# ╔═╡ be543735-ad3b-4c59-8203-a5799f9dc933
md"""
Now we can plot the energies we computed using VQE and compare with the results from HF and FCI.
"""

# ╔═╡ 08327003-60e4-4d10-9554-ebbc23a5cde7
begin
	p = plot()
	xs = collect(keys(mol_configs))
	hf_es = [pyconvert(Float64, val[1].hf_energy) for val in values(mol_configs)]
	fci_es = [pyconvert(Float64, val[1].fci_energy) for val in values(mol_configs)]
	plot!(p, xs, hf_es, label="HF")
	plot!(p, xs, fci_es, label="FCI")
	plot!(p, xs, [val[end] for val in values(mol_configs)], marker=:x, label="VQE")
	title!(p, "VQE computed ground-state energy of H2 \n vs bond-length for STO-3G basis vs HF and FCI")
	xlabel!(p, "Bond length of H2 [A]")
	ylabel!(p, "Ground-state energy for H2 [Ha]")
end

# ╔═╡ fbea5357-f2a8-4f7f-81e6-50e0855e6b67
md"""
We can see that the energy is minimized around ~0.74 A. This is in fact the [experimentally observed bond length](https://cccbdb.nist.gov/exp2x.asp?casno=1333740) for this molecule, so our simple procedure worked well to find the correct `θ` and bond length. For more complex molecules one can take a more sophisticated approach involving a classical optimization algorithm and the calculation of gradients.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Braket = "19504a0f-b47d-4348-9127-acc6cc69ef67"
CondaPkg = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
OrderedCollections = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PyBraket = "e85266a6-1825-490b-a80e-9b9469c53660"

[compat]
Braket = "~0.3.0"
CondaPkg = "~0.2.15"
OrderedCollections = "~1.4.1"
Plots = "~1.38.2"
PyBraket = "~0.3.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-beta3"
manifest_format = "2.0"
project_hash = "12fb0f992528b965e21985138650b6f99d6004fe"

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

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "00a2cccc7f098ff3b66806862d275ca3db9e6e5a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.5.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.CondaPkg]]
deps = ["JSON3", "Markdown", "MicroMamba", "Pidfile", "Pkg", "TOML"]
git-tree-sha1 = "64dd885fa25c61fdf6b27e90d6adedf564ae363a"
uuid = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
version = "0.2.15"

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

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

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
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

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

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

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

[[deps.MicroMamba]]
deps = ["Pkg", "Scratch", "micromamba_jll"]
git-tree-sha1 = "a6a4771aba1dc8942bc0f44ff9f8ee0f893ef888"
uuid = "0b3b1443-0f03-428d-bdfb-f27f9c1191ea"
version = "0.1.12"

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

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "8175fc2b118a3755113c8e68084dc1a9e63c61ee"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.3"

[[deps.Pidfile]]
deps = ["FileWatching", "Test"]
git-tree-sha1 = "2d8aaf8ee10df53d0dfb9b8ee44ae7c04ced2b03"
uuid = "fa939f87-e72e-5be4-a000-7fc836dbe307"
version = "1.3.0"

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
git-tree-sha1 = "daff8d21e3f4c596387867329be49b8c45f4f0f3"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.3"

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

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.PyBraket]]
deps = ["Braket", "CondaPkg", "DataStructures", "LinearAlgebra", "PythonCall", "Statistics", "StructTypes"]
git-tree-sha1 = "64f9f4e72ef170541eecbb9398906114a33b9a34"
uuid = "e85266a6-1825-490b-a80e-9b9469c53660"
version = "0.3.0"

[[deps.PythonCall]]
deps = ["CondaPkg", "Dates", "Libdl", "MacroTools", "Markdown", "Pkg", "REPL", "Requires", "Serialization", "Tables", "UnsafePointers"]
git-tree-sha1 = "1052188e0a017d4f4f261f12307e1fa1b5b48588"
uuid = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
version = "0.9.10"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

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

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "ca4bccb03acf9faaf4137a9abc1881ed1841aa70"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.10.0"

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

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.UnsafePointers]]
git-tree-sha1 = "c81331b3b2e60a982be57c046ec91f599ede674a"
uuid = "e17b2a0c-0bdf-430a-bd0c-3a23cae4ff39"
version = "1.0.0"

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

[[deps.micromamba_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "80ddb5f510c650de288ecd548ebc3de557ffb3e2"
uuid = "f8abcde7-e9b7-5caa-b8af-a437887ae8e4"
version = "1.2.0+0"

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
# ╟─2f49c108-9d9f-11ed-1a79-eb966fa5a322
# ╟─2e2c9fce-5d4f-411c-9951-0b5909111155
# ╟─6ada7712-6f03-4f56-8254-085d878d61fc
# ╟─0280b99d-2769-4f21-9fa4-fcdf4f25fd58
# ╠═af4a74c8-fa8d-4c9a-a29d-27476c80b5e5
# ╟─3c46d71a-7d49-4d91-b536-817333b8f284
# ╠═23aaba4e-3342-4581-a6bf-b039c390062e
# ╠═6626ac70-8fb2-4513-9443-5f90818f7ad4
# ╠═67b067f4-6375-42fe-aa9d-8b46f9483ed1
# ╠═738480aa-90d3-46e1-9796-340c30290a23
# ╠═824ff10a-8bdc-4206-865a-facaa4b18824
# ╠═707da214-4ae6-41a7-94b3-7168f3b01f61
# ╠═e2d61370-0229-46a8-90e6-21fac0fb7056
# ╠═cbbd1b17-e9e5-4e3e-8cc1-fc0c26b8e66f
# ╟─de771faa-96f7-44d0-801b-76fbb9dc8509
# ╠═9617dc3a-49fe-4a0e-85b9-c88c6deb7caf
# ╠═2b291132-3415-49b5-a056-375f36bec59d
# ╠═e1369cc5-3f74-4399-adbd-8743c3cd67e1
# ╠═867967c4-a05b-4f17-ab61-17ceb76376e2
# ╠═0ae58b97-7f99-4ffe-9a7b-276f1fe0665d
# ╟─c144939e-a80b-4c85-b991-271dc8a8b0db
# ╠═3b4891c3-9e21-4bb0-9dac-62dfbcc390ab
# ╠═ea391b9a-13fb-4952-80df-a590a23ea741
# ╠═cddbf3ee-61fe-4ca8-a30d-a04fa10ff88c
# ╟─be543735-ad3b-4c59-8203-a5799f9dc933
# ╠═ff4fad96-1970-4fb9-a43a-df02cd5dc643
# ╠═08327003-60e4-4d10-9554-ebbc23a5cde7
# ╟─fbea5357-f2a8-4f7f-81e6-50e0855e6b67
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
