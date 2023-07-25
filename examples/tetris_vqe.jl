### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 2feb54cc-abd3-11ed-08d0-89d3036b2224
using Braket, PyBraket, PyBraket.PythonCall, CondaPkg

# ╔═╡ 9cd02259-e77a-40d3-89fb-5aceb6c88855
using Braket.Observables: TensorProduct, Observable

# ╔═╡ 7fe2bb2d-4c6a-441d-9743-1471aec6f0b1
md"""
# Implementing TETRIS-ADAPT-VQE with PennyLane and Braket.jl
"""

# ╔═╡ 5a283f0e-76ec-4975-90f1-b824eae4350b
md"""
In this notebook, we demonstrate how to use PennyLane's `qchem` molecule in tandem with [`Braket.jl`](https://github.com/awslabs/Braket.jl), the experimental Julia SDK for Amazon Braket, to implement the [TETRIS-ADAPT-VQE](https://arxiv.org/abs/2209.10562) algorithm for quantum chemistry. First, we install and import the necessary packages. Since we'll be calling PennyLane, which is written in Python, we'll need `PythonCall.jl` which is provided as a dependency of `PyBraket.jl`.

**Note:** if you are using OSX, you may need to set the environment variable `KMP_DUPLICATE_LIB_OK=true` in order to avoid `pyscf` segfaulting. See [this GitHub issue](https://github.com/dmlc/xgboost/issues/1715) for more information. You can set this environment variable in this script by adding a new cell with `ENV["KMP_DUPLICATE_LIB_OK"] = true`.
"""

# ╔═╡ be0d2559-b555-4026-934a-ca4922edb9af
CondaPkg.add_pip("pennylane", version="==0.28.0")

# ╔═╡ d0e4e6bc-92e9-49a6-924d-999db1de14e3
CondaPkg.add_pip("pyscf", version="==2.1.1")

# ╔═╡ bd980a06-718f-4896-9b21-fcad0ec715e5
CondaPkg.add_pip("openfermion", version="==1.5.1")

# ╔═╡ fa7fafac-4529-4c22-9cbe-fc0dfdc15032
CondaPkg.add_pip("openfermionpyscf", version="==0.5")

# ╔═╡ 94712ed6-5489-4973-bc45-5d18017facd7
md"""
We'll also import some data structures from `Braket.jl` for ease of use:
"""

# ╔═╡ cc9358b3-f5f3-44e5-8ffb-078768c79c59
md"""
And of course we'll need PennyLane itself!
"""

# ╔═╡ 655e7ea1-8e68-40d0-8791-22f4addd70e3
# Python package imports
begin
	qml = pyimport("pennylane")
	qchem = pyimport("pennylane.qchem")
end

# ╔═╡ 28857109-96c1-4a34-b376-9dd2ee6c8d80
md"""
## Summary of TETRIS-ADAPT-VQE

TETRIS-ADAPT-VQE is an improvement upon [the original ADAPT-VQE algorithm](https://www.nature.com/articles/s41467-019-10988-2), developed by Grimsley et al., which defines a scheme to filter out molecular excitations so as to expend computational effort only on excitations which contribute significantly to the final groundstate. However, naive ADAPT-VQE can generate circuits which are very deep, which is problematic for near-term quantum devices. The quantum hardware of today has limited "quantum volume", and we expect to achieve better results with shallower rather than deeper circuits. TETRIS-ADAPT-VQE thus develops a method to address as many qubits as possible in each layer of the circuit to be run, decreasing the total parallel gate depth and making the circuits more amenable to be run on NISQ devices.

For an introduction to ADAPT-VQE, see [the PennyLane demo](https://pennylane.ai/qml/demos/tutorial_adaptive_circuits.html) on the algorithm.
"""

# ╔═╡ 09e0a358-fadb-467f-b2c4-3e25c9e711d1
md"""
We begin by choosing a molecule to study. In this notebook, we'll examine $\mathrm{C_2O_2}$, a linear molecule with 28 total electrons. By tuning the number of "active" electrons (those which are excitable), we can control how many qubits we need to perform the quantum chemistry simulation.
"""

# ╔═╡ d7508af5-a21e-4726-bdf5-e90c375bd1c0
begin
	structure = """
	4
	314937
	O         14.77020      -12.25000        0.00000
	O         18.66730      -10.00000        0.00000
	C         16.06920      -11.50000        0.00000
	C         17.36820      -10.75000        0.00000
	"""
	write("c2o2.xyz", structure)
	symbols, coordinates = qchem.read_structure("c2o2.xyz")
end

# ╔═╡ ad4759d4-7e75-4e32-bf9d-b7d50fab4366
n_electrons = 10 # to make the problem fit

# ╔═╡ e386fe38-6034-40e0-8d92-d7a505d717f9
md"""
Using PennyLane's `qchem` module in tandem with `PythonCall.jl`, we're able to generate the appropriate molecular Hamiltonian, which can be applied at the end of the circuit and used in a VQE training procedure.

**Note**: `PythonCall.jl`'s built-in Python package manager, `CondaPkg.jl`, can struggle to install the `openfermionpyscf` package. If this happens to you, install `openfermionpyscf` using `pip` from the command line and [tell `PythonCall.jl` to use your local install](https://cjdoris.github.io/PythonCall.jl/stable/pythoncall/#If-you-already-have-Python-and-required-Python-packages-installed).
"""

# ╔═╡ 24be5c3a-3bc6-4d61-96ee-28cfe0e98ddd
mol_H, n_qubits = qchem.molecular_hamiltonian(symbols, coordinates, method="pyscf", active_electrons=n_electrons, name="c2o2", convert_tol=1e-6)

# ╔═╡ 8d9402e6-a01d-4dc3-a86d-9710b34cd807
md"""
`mol_H` is a Python object. We can write some quick Julia code to convert it to the Julia objects used by `Braket.jl`:
"""

# ╔═╡ 2730bf2b-d010-4358-a176-1a3860bc28b7
"""
	translate_op(op::Py) -> Braket.Observables.Observable

Transform a PennyLane `operation` to a `Braket.jl` `Observable`.
"""
function translate_op(op::Py)
    if pyisinstance(op, qml.Identity)
        return Braket.Observables.I()
    elseif pyisinstance(op, qml.Hadamard)
        return Braket.Observables.H()
    elseif pyisinstance(op, qml.PauliZ)
        return Braket.Observables.Z()
    elseif pyisinstance(op, qml.PauliY)
        return Braket.Observables.Y()
    elseif pyisinstance(op, qml.PauliX)
        return Braket.Observables.X()
    end
end

# ╔═╡ cf977978-c4df-4ce1-9811-875d2832ec3a
"""
	translate_H(py_H::Py) -> (Braket.Observables.Sum, Vector{Vector{Int}})

Translate each term of the `qml.Hamiltonian` `py_H` to a Julia object and track which qubits (or wires, in PennyLane parlance) it applies to, returning a tuple of the `Sum` observable and the targets of each of its terms.
"""
function translate_H(py_H::Py)
    H_list  = Vector{Observable}(undef, length(py_H.ops))
    targets = Vector{Vector{Int}}(undef, length(py_H.ops))
    for (ii, (coeff, op)) in enumerate(zip(py_H.coeffs, py_H.ops))
        jl_coeff = pyconvert(Float64, coeff.numpy())
        H_list[ii] = if pyisinstance(op, qml.operation.Tensor)
            jl_coeff * TensorProduct(Observable[translate_op(o) for o in op.obs])
        else
            jl_coeff * translate_op(op)
        end
        targets[ii] = pyconvert(Vector{Int}, op.wires)
    end
    return sum(H_list[2:end], init=H_list[1]), targets
end

# ╔═╡ 10eaf3c1-2b5d-4346-835e-ccc32e11771d
jl_mol_H, targets = translate_H(mol_H);

# ╔═╡ 4c3496d3-8242-4815-8230-f8e014702740
"Number of H terms: $(length(jl_mol_H))"

# ╔═╡ 2ff67c3c-7317-4733-8f2f-485e827b9f8e
md"""
We can also generate the list of *single* (targeting one electron) and *double*  (targeting two electrons) excitations that can be applied to a given basis state. Each excitation is a list of qubits to which the excitation is applied, and we can convert them from Python lists to Julia `Vector`s.
"""

# ╔═╡ da11146b-75b3-4e19-a570-39c4341f95c4
singles, doubles = qchem.excitations(n_electrons, n_qubits);

# ╔═╡ 4ffe6fc3-864c-4e19-8456-63a27ccd651b
jl_doubles = pyconvert(Vector{Vector{Int}}, doubles);

# ╔═╡ 5aebff15-8762-490f-b893-00f245280397
"Number of double excitations: $(length(jl_doubles))"

# ╔═╡ 7cd6c6ef-13d8-4137-94d0-a2aecb84814e
jl_singles = pyconvert(Vector{Vector{Int}}, singles);

# ╔═╡ 38b27b66-bd39-47b2-a3ff-5a7a6cc0618c
"Number of single excitations: $(length(jl_singles))"

# ╔═╡ 653bea2d-0efd-467a-b03e-e6902cf22ae3
md"""
PennyLane can also be used to construct the initial Hartree-Fock state for the molecule, which can then be transformed into a Julia `Circuit`:
"""

# ╔═╡ e0a1e89c-b1e0-4bf5-978b-53683eaad434
hf_state = qchem.hf_state(n_electrons, n_qubits);

# ╔═╡ 0582402e-60ff-41ce-8494-ba0c8b0258ad
"""
Build a circuit which prepares the initial Hartree-Fock state `hf_state`.
"""
BasisState(hf_state::Vector{Int}) = Circuit([(X, collect(findall(i->i>0, hf_state)))])

# ╔═╡ 1c26a144-a2ed-4447-8fc3-0d342ccedca5
"""
Transform the Python representation of the Hartree-Fock state `hf_state` to Julia.
"""
BasisState(hf_state::Py) = BasisState(pyconvert(Vector{Int}, hf_state.numpy()))

# ╔═╡ 31cce126-1934-4abc-bec2-711f7edac6b5
md"""
We also build up some logic to implement the double and single excitations, given the qubits to which they apply.
"""

# ╔═╡ dd0b404b-e257-4198-b078-876b79ee379f
"""
	DoubleExcitation(phis::Tuple{FreeParameter, FreeParameter}) -> Circuit

Construct a `Circuit` representing the application of a double excitation. Two `FreeParameter`s `phis` are needed in order to account for the differing sign in several angled gates (`phi_2` will have the same value as `phi_1`, but negative sign), as the Braket simulator can't yet handle parameter arithmetic.
"""
function DoubleExcitation(phis::Tuple{FreeParameter, FreeParameter})
    phi_1, phi_2 = phis
    c = Circuit()
    c(CNot, 2, 3)
    c(CNot, 0, 2)
    c(H, 3)
    c(H, 0)
    c(CNot, 2, 3)
    c(CNot, 0, 1)
    c(Ry, 1, phi_1)
    c(Ry, 0, phi_2)
    c(CNot, 0, 3)
    c(H, 3)
    c(CNot, 3, 1)
    c(Ry, 1, phi_1)
    c(Ry, 0, phi_2)
    c(CNot, 2, 1)
    c(CNot, 2, 0)
    c(Ry, 1, phi_2)
    c(Ry, 0, phi_1)
    c(CNot, 3, 1)
    c(H, 3)
    c(CNot, 0, 3)
    c(Ry, 1, phi_2)
    c(Ry, 0, phi_1)
    c(CNot, 0, 1)
    c(CNot, 2, 0)
    c(H, 0)
    c(H, 3)
    c(CNot, 0, 2)
    c(CNot, 2, 3)
    return c
end

# ╔═╡ f61bc4cc-7cb4-483a-8454-da60fc824146
"""
	SingleExcitation(phis::Tuple{FreeParameter, FreeParameter}) -> Circuit

Construct a `Circuit` representing the application of a single excitation. Two `FreeParameter`s `phis` are needed in order to account for the differing sign in several angled gates (`phi_2` will have the same value as `phi_1`, but negative sign), as the Braket simulator can't yet handle parameter arithmetic.
"""
function SingleExcitation(phis::Tuple{FreeParameter, FreeParameter})
    phi_1, phi_2 = phis
    c = Circuit()
    c(CNot, 0, 1)
    c(Ry, 0, phi_1)
    c(CNot, 1, 0)
    c(Ry, 0, phi_2)
    c(CNot, 1, 0)
    c(CNot, 0, 1)
    return c
end

# ╔═╡ cb1a9a5c-0711-478a-a855-b988021f3155
begin
	doubles_dict = Dict("d_$ii"=>jl_doubles[ii] for ii in 1:length(jl_doubles));
	singles_dict = Dict("s_$jj"=>jl_singles[jj] for jj in 1:length(jl_singles));
	excitations_dict = merge(doubles_dict, singles_dict);
end

# ╔═╡ 6c2a52c9-4513-4aef-8d8f-1571f1284002
md"""
Now we are ready to build the circuit which applies **all** the single and double excitations and computes their partial derivatives with respect to the molecular Hamiltonian. We'll use these partial derivatives to filter out all the excitations which contribute little to the final groundstate. Since we plan to use the Braket on-demand simulator to filter out the less important excitations, we can use the `AdjointGradient` result type. To learn more about this result type and the benefits of using it, see [this PennyLane-Braket blog post](https://pennylane.ai/blog/2022/12/computing-adjoint-gradients-with-amazon-braket-sv1/).
"""

# ╔═╡ ca19b82b-138b-4470-8a71-e2328b53b9c8
"""
Helper function to map a single parameter to its two constituents in order to implement parameter arithmetic.
"""
map_param(p::FreeParameter) = (FreeParameter(string(p) * "_1"), FreeParameter(string(p) * "_2"))

# ╔═╡ 268e830b-f091-4e9f-8091-55d1c2bf5894
function full_circuit(hf_state, doubles::Vector{Vector{Int}}, singles::Vector{Vector{Int}}, mol_H, H_targets)
	# construct unmapped and mapped parameters
    double_params = (FreeParameter("d_$ii") for ii in 1:length(doubles))
    single_params = (FreeParameter("s_$ii") for ii in 1:length(singles))
    # each double and single param is mapped to two new parameters
    mapped_double_params = Dict(d=>map_param(d) for d in double_params)
    mapped_single_params = Dict(s=>map_param(s) for s in single_params)
	
    # build the initial HF basis state
    c = BasisState(hf_state)
    # apply the excitations
    for (double, param) in zip(doubles, double_params)
		mapped = mapped_double_params[param]
        ex = DoubleExcitation(mapped)
        append!(c, ex, double)
    end
    for (single, param) in zip(singles, single_params)
		mapped = mapped_single_params[param]
        ex = SingleExcitation(mapped)
        append!(c, ex, single)
    end
    params = merge(mapped_double_params, mapped_single_params)
    # add the gradient result type - which also computes the cost
	c(AdjointGradient, mol_H, H_targets, ["all"])
    return c, params
end

# ╔═╡ f5559131-87e5-4b44-80e7-d16d835385ac
c, mapper = full_circuit(hf_state, jl_doubles, jl_singles, jl_mol_H, targets)

# ╔═╡ f536ff35-1d8b-47fd-8802-2e6cdf683000
"Unfiltered parallel gate depth: $(depth(c))"

# ╔═╡ d90c2f51-a521-43f0-bca2-e0994ce80e30
init_params = Dict(string(p)=>0.0 for p in c.parameters)

# ╔═╡ 8e87389c-8dd7-4397-8283-aa4f10208162
md"""
We will run this circuit on the on-demand state vector simulator, SV1. We run in `shots=0` (exact) mode in order to be able to use the `AdjointGradient` result type. We also provide values for all the `FreeParameter`s in the circuit.
"""

# ╔═╡ 1aa3a21e-e968-41ec-a000-9424eb2634ba
dev = AwsDevice("arn:aws:braket:::device/quantum-simulator/amazon/sv1")

# ╔═╡ 661c6780-e3f6-482f-9a03-e38863ee88f7
md"""
**Warning**: This cell can run for about half an hour on SV1, and can incur charges to your AWS account. For this reason, it's been disabled in this notebook. If you want to run it, re-enable the cell.
"""

# ╔═╡ b53c4d8c-2b10-4cd2-8379-42738029f0a9
t = dev(c, shots=0, inputs=init_params)

# ╔═╡ ea21ca72-6d59-4aab-9882-353ee7fbdd3c
res = result(t)

# ╔═╡ 00f94b37-7aa0-4ac7-b842-009ef21e56c3
md"""
Now we need to reconstruct the unmapped gradients and filter those with partial derivative magnitudes less than some cutoff. In this case, we'll pick `1e-8` as the cutoff. Try experimenting with different cutoffs and see how this can affect your results!
"""

# ╔═╡ 69facee7-063e-443c-9e1f-a848b494fe0a
"""
	reconstruct_gradients(raw_gradients, parameter_mapper)

Given the list of *mapped* parameter names and their partial derivatives, reconstruct the *unmapped* parameter and partial derivative pairs, using the known relationships between `phi_1` and `phi_2` for double and single excitations.
"""
function reconstruct_gradients(raw_gradients, parameter_mapper::Dict)
    function rebuild(g, mapped_gs)
        g_name = string(g)
		g_1 = Symbol(g_name*"_1")
		g_2 = Symbol(g_name*"_2")
        p_grads = (raw_gradients[g_1], -raw_gradients[g_2])
        if startswith(g_name, "d")
            return g=>(sum(p_grads) / 8)
        else
            return g=>sum(p_grads)
        end
    end
    return Dict(rebuild(k, v) for (k, v) in parameter_mapper)
end

# ╔═╡ 105feeed-146f-43df-8019-2841fe9b9238
function filter_and_order_excitations(task_result::Braket.GateModelQuantumTaskResult, cutoff::Float64=1e-8)
    raw_grads     = first(res.values)[:gradient]
    rebuilt_grads = reconstruct_gradients(raw_grads, mapper)
	# sort the parameters by absolute value of their partial derivatives
    sorted_keys   = sort(collect(keys(rebuilt_grads)), by=k->abs(rebuilt_grads[k]))
	# filter out those with partial derivatives smaller than the cutoff
    filtered_keys = Iterators.filter(k->abs(rebuilt_grads[k]) > cutoff, sorted_keys)
	# return the corresponding excitations in sorted order
    return [excitations_dict[string(k)] for k in filtered_keys]
end

# ╔═╡ 0c91bbff-31d9-4813-80e8-17cbff3656d0
cutoff = 1e-8

# ╔═╡ 336e4732-20ee-43e7-a49d-1351f9d266a9
ordered_excitations = filter_and_order_excitations(res, cutoff)

# ╔═╡ 0b8ffdea-aeae-4060-a08f-7393086c389d
"Number of filtered excitations: $(length(ordered_excitations))"

# ╔═╡ 5e678047-aeb0-4084-a793-8955b1465868
md"""
## The power of TETRIS

With the excitations filtered and sorted based on their magnitudes, we are ready to try both the naive ADAPT-VQE approach and the TETRIS-ADAPT-VQE scheme. The *results* (energies) of both should be the same, but the circuit depth should be shallower when using the TETRIS-ADAPT-VQE technique.
"""

# ╔═╡ d9ea7c12-fd21-4873-8426-a7b7c5f51e95
"""
Helper function to apply the circuit corresponding to a given excitation to the circuit and map its parameters.
"""
function build_excitation_circ(ex::Vector{Int}, double_ix::Int, single_ix::Int)
    if length(ex) == 4
        d = FreeParameter("d_$(double_ix)")
        mapped = map_param(d)
        return DoubleExcitation(mapped), double_ix + 1, single_ix
    else
        s = FreeParameter("s_$(single_ix)")
        mapped = map_param(s)
        return SingleExcitation(mapped), double_ix, single_ix + 1
    end
end

# ╔═╡ c58eb369-14e1-4d76-88c4-c6b9e96070af
begin
	n_doubles = count(ex->length(ex)==4, ordered_excitations)
    n_singles = count(ex->length(ex)==2, ordered_excitations)
	
    double_ps = [FreeParameter("d_$ii") for ii in 1:n_doubles]
    single_ps = [FreeParameter("s_$ii") for ii in 1:n_singles]
    # each double and single param is mapped to two new parameters
	mapped_doubles = Dict(p=>map_param(p) for p in double_ps)
	mapped_singles = Dict(p=>map_param(p) for p in single_ps)
    mapped_ps = merge(mapped_doubles, mapped_singles)
end

# ╔═╡ f9b9df66-3a25-4e69-97c0-3c178d5a0602
"""
Builds the naive ADAPT-VQE circuit from the selected excitations and molecular Hamiltonian.
"""
function adapt_circuit(hf_state, ordered_excitations, mol_H, H_targets)
    c = BasisState(hf_state)
    d_ix = 1
    s_ix = 1
    for ex in ordered_excitations
        ex_c, d_ix, s_ix = build_excitation_circ(ex, d_ix, s_ix)
        append!(c, ex_c, ex)
    end
    # add the gradient result type - which also computes the cost
    return c(AdjointGradient, mol_H, H_targets, ["all"])
end

# ╔═╡ ef8fa936-359c-43f2-91b8-50f65324caa3
"""
Builds the TETRIS-ADAPT-VQE circuit from the selected excitations and molecular Hamiltonian.
"""
function tetris_circuit(hf_state, ordered_excitations, mol_H, H_targets)
    c = BasisState(hf_state)
    d_ix = 1
    s_ix = 1
    while length(ordered_excitations) > 0
		next_excitation_ind = 1
		touched_this_round = Set{Int}()
		# find the excitation with the next largest contribution which
		# will not increase the parallel gate depth
        next_excitation_ind = findfirst(ex->isdisjoint(ex, touched_this_round), ordered_excitations)
		# exit once as many qubits are addressed in this moment as possible
        while !isnothing(next_excitation_ind)
            next_ex = popat!(ordered_excitations, next_excitation_ind)
            ex_c, d_ix, s_ix = build_excitation_circ(next_ex, d_ix, s_ix)
            append!(c, ex_c, next_ex)
			
            union!(touched_this_round, next_ex)
			# will be nothing if there is no excitation left which doesn't
			# touch an already-touched-this-round qubit
            next_excitation_ind = findnext(ex->isdisjoint(ex, touched_this_round), ordered_excitations, next_excitation_ind)
        end
    end
    # add the gradient result type - which also computes the cost
    return c(AdjointGradient, mol_H, H_targets, ["all"])
end

# ╔═╡ d6b31724-8862-4c58-b6a5-b82814efb677
adapt_c = adapt_circuit(hf_state, ordered_excitations, jl_mol_H, targets)

# ╔═╡ 28762af7-1426-4ac5-acfe-d2628d68bfab
"Total parallel gate depth for naive ADAPT-VQE ansatz: $(depth(adapt_c))"

# ╔═╡ 9db4967c-46a6-4950-99f6-82b382d3530a
tetris_c = tetris_circuit(hf_state, copy(ordered_excitations), jl_mol_H, targets)

# ╔═╡ 0a8943ce-fb98-4838-b04c-55b5548c0184
"Total parallel gate depth for TETRIS-ADAPT-VQE ansatz: $(depth(tetris_c))"

# ╔═╡ dcf89cc2-e9b2-4cc2-8d2c-3c2f4b5c58f1
md"""
We can see that the TETRIS-ADAPT-VQE circuit is more shallow, rendering it more amenable to today's NISQ devices. If you run these two circuits (with the same parameter values!) on SV1, you'll see the energies are the same.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Braket = "19504a0f-b47d-4348-9127-acc6cc69ef67"
CondaPkg = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
PyBraket = "e85266a6-1825-490b-a80e-9b9469c53660"

[compat]
Braket = "~0.4.1"
CondaPkg = "~0.2.17"
PyBraket = "~0.4.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-beta3"
manifest_format = "2.0"
project_hash = "82b1b87d69a608f890b56fda571de2de0ee7a079"

[[deps.AWS]]
deps = ["Base64", "Compat", "Dates", "Downloads", "GitHub", "HTTP", "IniFile", "JSON", "MbedTLS", "Mocking", "OrderedCollections", "Random", "SHA", "Sockets", "URIs", "UUIDs", "XMLDict"]
git-tree-sha1 = "487d6835da9876e0362a83aec169e390872eba64"
uuid = "fbe9abb3-538b-5e4e-ba9e-bc94f4f92ebc"
version = "1.81.0"

[[deps.AWSS3]]
deps = ["AWS", "ArrowTypes", "Base64", "Compat", "Dates", "EzXML", "FilePathsBase", "MbedTLS", "Mocking", "OrderedCollections", "Retry", "SymDict", "URIs", "UUIDs", "XMLDict"]
git-tree-sha1 = "59aa23fae39bf1664fd698ef74b3a46650539b26"
uuid = "1c724243-ef5b-51ab-93f4-b0a88ac62a95"
version = "0.10.3"

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
git-tree-sha1 = "563d60f89fcb730668bd568ba3e752ee71dde023"
uuid = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
version = "2.0.2"

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
git-tree-sha1 = "f82715aca8dd4c9e87ac348e6ab204784b131f2b"
uuid = "19504a0f-b47d-4348-9127-acc6cc69ef67"
version = "0.4.1"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "SnoopPrecompile", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "c700cce799b51c9045473de751e9319bdd1c6e94"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.9"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c6d890a52d2c4d55d326439580c3b8d0875a77d9"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.7"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "61fdd77467a5c3ad071ef8277ac6bd6af7dd4c04"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.CondaPkg]]
deps = ["JSON3", "Markdown", "MicroMamba", "Pidfile", "Pkg", "TOML"]
git-tree-sha1 = "4682a2d28f98aa83be1ed137c0bd7d053f85db79"
uuid = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
version = "0.2.17"

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

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "0fa3b52a04a4e210aeb1626def9c90df3ae65268"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.1.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GitHub]]
deps = ["Base64", "Dates", "HTTP", "JSON", "MbedTLS", "Sockets", "SodiumSeal", "URIs"]
git-tree-sha1 = "5688002de970b9eee14b7af7bbbd1fdac10c9bbe"
uuid = "bc5e4493-9b4d-5f90-b8aa-2b2bcaad7a26"
version = "5.8.2"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "ba2d094a88b6b287bd25cfa86f301e7693ffae2f"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.7.4"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "Dates", "IniFile", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "37e4657cd56b11abe3d10cd4a1ec5fbdb4180263"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.7.4"

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

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "680e733c3a0a9cea9e935c8c2184aea6a63fa0b5"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.21"

    [deps.LogExpFunctions.extensions]
    ChainRulesCoreExt = "ChainRulesCore"
    ChangesOfVariablesExt = "ChangesOfVariables"
    InverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

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

[[deps.MicroMamba]]
deps = ["Pkg", "Scratch", "micromamba_jll"]
git-tree-sha1 = "a6a4771aba1dc8942bc0f44ff9f8ee0f893ef888"
uuid = "0b3b1443-0f03-428d-bdfb-f27f9c1191ea"
version = "0.1.12"

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

[[deps.NamedTupleTools]]
git-tree-sha1 = "90914795fc59df44120fe3fff6742bb0d7adb1d0"
uuid = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
version = "0.14.3"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

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
git-tree-sha1 = "9ff31d101d987eb9d66bd8b176ac7c277beccd09"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.20+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "6f4fbcd1ad45905a5dee3f4256fabb49aa2110c6"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.7"

[[deps.Pidfile]]
deps = ["FileWatching", "Test"]
git-tree-sha1 = "2d8aaf8ee10df53d0dfb9b8ee44ae7c04ced2b03"
uuid = "fa939f87-e72e-5be4-a000-7fc836dbe307"
version = "1.3.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

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
git-tree-sha1 = "ec53c19001d7a603658a750467d25f8c67750f01"
uuid = "e85266a6-1825-490b-a80e-9b9469c53660"
version = "0.4.1"

[[deps.PythonCall]]
deps = ["CondaPkg", "Dates", "Libdl", "MacroTools", "Markdown", "Pkg", "REPL", "Requires", "Serialization", "Tables", "UnsafePointers"]
git-tree-sha1 = "1052188e0a017d4f4f261f12307e1fa1b5b48588"
uuid = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
version = "0.9.10"

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
git-tree-sha1 = "67d3e75e8af8089ea34ce96974d5468d4a008ca6"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.15"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

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

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnsafePointers]]
git-tree-sha1 = "c81331b3b2e60a982be57c046ec91f599ede674a"
uuid = "e17b2a0c-0bdf-430a-bd0c-3a23cae4ff39"
version = "1.0.0"

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

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.2.0+0"

[[deps.libsodium_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "848ab3d00fe39d6fbc2a8641048f8f272af1c51e"
uuid = "a9144af2-ca23-56d9-984f-0d03f7b5ccf8"
version = "1.0.20+0"

[[deps.micromamba_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "f272e9232759cc692f9f4edb70440bcf832a3fe1"
uuid = "f8abcde7-e9b7-5caa-b8af-a437887ae8e4"
version = "1.3.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─7fe2bb2d-4c6a-441d-9743-1471aec6f0b1
# ╟─5a283f0e-76ec-4975-90f1-b824eae4350b
# ╠═2feb54cc-abd3-11ed-08d0-89d3036b2224
# ╠═be0d2559-b555-4026-934a-ca4922edb9af
# ╠═d0e4e6bc-92e9-49a6-924d-999db1de14e3
# ╠═bd980a06-718f-4896-9b21-fcad0ec715e5
# ╠═fa7fafac-4529-4c22-9cbe-fc0dfdc15032
# ╟─94712ed6-5489-4973-bc45-5d18017facd7
# ╠═9cd02259-e77a-40d3-89fb-5aceb6c88855
# ╟─cc9358b3-f5f3-44e5-8ffb-078768c79c59
# ╠═655e7ea1-8e68-40d0-8791-22f4addd70e3
# ╟─28857109-96c1-4a34-b376-9dd2ee6c8d80
# ╟─09e0a358-fadb-467f-b2c4-3e25c9e711d1
# ╠═d7508af5-a21e-4726-bdf5-e90c375bd1c0
# ╠═ad4759d4-7e75-4e32-bf9d-b7d50fab4366
# ╟─e386fe38-6034-40e0-8d92-d7a505d717f9
# ╠═24be5c3a-3bc6-4d61-96ee-28cfe0e98ddd
# ╟─8d9402e6-a01d-4dc3-a86d-9710b34cd807
# ╠═2730bf2b-d010-4358-a176-1a3860bc28b7
# ╠═cf977978-c4df-4ce1-9811-875d2832ec3a
# ╠═10eaf3c1-2b5d-4346-835e-ccc32e11771d
# ╠═4c3496d3-8242-4815-8230-f8e014702740
# ╟─2ff67c3c-7317-4733-8f2f-485e827b9f8e
# ╠═da11146b-75b3-4e19-a570-39c4341f95c4
# ╠═4ffe6fc3-864c-4e19-8456-63a27ccd651b
# ╠═5aebff15-8762-490f-b893-00f245280397
# ╠═7cd6c6ef-13d8-4137-94d0-a2aecb84814e
# ╠═38b27b66-bd39-47b2-a3ff-5a7a6cc0618c
# ╟─653bea2d-0efd-467a-b03e-e6902cf22ae3
# ╠═e0a1e89c-b1e0-4bf5-978b-53683eaad434
# ╠═0582402e-60ff-41ce-8494-ba0c8b0258ad
# ╠═1c26a144-a2ed-4447-8fc3-0d342ccedca5
# ╟─31cce126-1934-4abc-bec2-711f7edac6b5
# ╠═dd0b404b-e257-4198-b078-876b79ee379f
# ╠═f61bc4cc-7cb4-483a-8454-da60fc824146
# ╠═cb1a9a5c-0711-478a-a855-b988021f3155
# ╟─6c2a52c9-4513-4aef-8d8f-1571f1284002
# ╠═ca19b82b-138b-4470-8a71-e2328b53b9c8
# ╠═268e830b-f091-4e9f-8091-55d1c2bf5894
# ╠═f5559131-87e5-4b44-80e7-d16d835385ac
# ╠═f536ff35-1d8b-47fd-8802-2e6cdf683000
# ╠═d90c2f51-a521-43f0-bca2-e0994ce80e30
# ╟─8e87389c-8dd7-4397-8283-aa4f10208162
# ╠═1aa3a21e-e968-41ec-a000-9424eb2634ba
# ╟─661c6780-e3f6-482f-9a03-e38863ee88f7
# ╠═b53c4d8c-2b10-4cd2-8379-42738029f0a9
# ╠═ea21ca72-6d59-4aab-9882-353ee7fbdd3c
# ╟─00f94b37-7aa0-4ac7-b842-009ef21e56c3
# ╠═69facee7-063e-443c-9e1f-a848b494fe0a
# ╠═105feeed-146f-43df-8019-2841fe9b9238
# ╠═0c91bbff-31d9-4813-80e8-17cbff3656d0
# ╠═336e4732-20ee-43e7-a49d-1351f9d266a9
# ╠═0b8ffdea-aeae-4060-a08f-7393086c389d
# ╟─5e678047-aeb0-4084-a793-8955b1465868
# ╠═d9ea7c12-fd21-4873-8426-a7b7c5f51e95
# ╠═c58eb369-14e1-4d76-88c4-c6b9e96070af
# ╠═f9b9df66-3a25-4e69-97c0-3c178d5a0602
# ╠═ef8fa936-359c-43f2-91b8-50f65324caa3
# ╠═d6b31724-8862-4c58-b6a5-b82814efb677
# ╠═28762af7-1426-4ac5-acfe-d2628d68bfab
# ╠═9db4967c-46a6-4950-99f6-82b382d3530a
# ╠═0a8943ce-fb98-4838-b04c-55b5548c0184
# ╟─dcf89cc2-e9b2-4cc2-8d2c-3c2f4b5c58f1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
