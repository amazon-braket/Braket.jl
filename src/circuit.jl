const ALL_QUBITS = -1

"""
    Circuit

A representation of a quantum circuit that contains the instructions to be performed on a
quantum device and the requested result types.

See:
  - [Gates](@ref) for all of the supported gates. 
  - [Noises](@ref) for all of the supported noise operations.
  - [Compiler Directives](@ref) for all of the supported compiler directives.
  - [Results](@ref) for all of the supported result types.
"""
mutable struct Circuit
    moments::Moments
    instructions::Vector{Instruction}
    result_types::Vector{Result}
    basis_rotation_instructions::Vector{Instruction}
    qubit_observable_mapping::Dict{Int, Observables.Observable}
    qubit_observable_target_mapping::Dict{Int, Tuple}
    qubit_observable_set::Set{Int}
    parameters::Set{FreeParameter}
    observables_simultaneously_measureable::Bool
    has_compiler_directives::Bool

    @doc """
        Circuit()
    
    Construct an empty `Circuit`.
    """
    Circuit() = new(Moments(), [], [], [], Dict(), Dict(), Set{Int}(), Set(), true, false)
end
"""
    Circuit(m::Moments, ixs::Vector, rts::Vector{Result}, bri::Vector)

Construct a `Circuit` from a set of `Moments`, a vector of [`Instruction`](@ref)s,
a vector of [`Result`](@ref)s, and a vector of basis rotation instructions.
"""
function Circuit(m::Moments, ixs::Vector, rts::Vector{Result}, bri::Vector)
    c = Circuit()
    c.moments = deepcopy(m)
    c.instructions = Instruction.(deepcopy(ixs))
    c.basis_rotation_instructions = Instruction.(deepcopy(bri))
    foreach(rt->add_result_type!(c, rt), rts)
    return c
end
"""
    Circuit(v)

Construct a `Circuit` from a `Vector`-like `v` containing tuples of:
  - a [`Gate`](@ref), [`Noise`](@ref), or [`Result`](@ref)
  - the target qubits on which to apply the operator
  - any construction arguments to the operator, e.g. an angle or [`Observable`](@ref Braket.Observables.Observable)

# Examples
```jldoctest
julia> v = [(H, collect(0:10)), (Rx, 1, 0.2), (BitFlip, 0, 0.1)];

julia> Circuit(v);
```
"""
Circuit(v::AbstractVector) = (c = Circuit(); c(v); return c)
Base.show(io::IO, circ::Circuit) = print(io, "Circuit($(qubit_count(circ)) qubits)")

function build_blob!(lines::Vector{String}, strs, targets, hit_this_round::Set{Int}, qubit_lines, non_qubit_lines) 
    bar_qubits = collect(minimum(targets)+1:maximum(targets)-1)
    is_dis     = isdisjoint(hit_this_round, union(targets, bar_qubits))
    ix_lines   = [3 + targ * 2 for targ in targets]
    bar_lines  = [4 + q * 2 for q in minimum(targets):maximum(targets)-1]
    if !isdisjoint(hit_this_round, union(targets, bar_qubits))
        lines[ix_lines]        .*= "-"
        pad_width               = maximum(length, lines)
        lines[non_qubit_lines] .= (rpad(line, pad_width, " ") for line in lines[non_qubit_lines])
        lines[qubit_lines]     .= (rpad(line, pad_width, "-") for line in lines[qubit_lines])
    end
    lines[ix_lines] .*= strs
    # add | for multi qubit objects
    lines[bar_lines] .*= "|"
    union!(hit_this_round, targets)
    union!(hit_this_round, bar_qubits)
    return lines, hit_this_round
end

function update_border!(lines, header_str, border_lines)
    pad_width     = maximum(length, lines)
    border_length = length(lines[border_lines[1]])
    pad_diff = pad_width - border_length 
    half_pad = border_length + div(pad_width - border_length - length(header_str), 2)
    lines[border_lines] .= (rpad(line, half_pad) for line in lines[border_lines])
    lines[border_lines] .*= (header_str, header_str)
    lines[border_lines] .= (rpad(line, pad_width) for line in lines[border_lines])
    return lines
end


function build_slice!(lines::Vector{String}, strings_and_targets, line_groups, header::String, fallback)
    hit_this_round = Set{Int}()
    qubit_lines, non_qubit_lines, border_lines = line_groups
    for (op_strings, op_targets) in strings_and_targets
        targets = isempty(op_targets) ? fallback : op_targets
        lines, hit_this_round = build_blob!(lines, op_strings, targets, hit_this_round, qubit_lines, non_qubit_lines)
    end
    lines = update_border!(lines, header, border_lines)
    pad_width = maximum(length, lines)
    lines[non_qubit_lines] .= [rpad(line, pad_width) for line in lines[non_qubit_lines]]
    lines[qubit_lines]     .= [rpad(line, pad_width, "-") for line in lines[qubit_lines]]
    lines[border_lines]    .*= "|"
    lines[non_qubit_lines] .*= " "
    lines[qubit_lines]     .*= "-"
    return lines
end

function build_result_lines!(rts::Vector{Result}, lines::Vector{String}, line_groups, qc::Int)
    strings_and_targets = zip([chars(rt)[1] for rt in rts], [rt.targets for rt in rts])
    return build_slice!(lines, strings_and_targets, line_groups, "Result Types", collect(0:qc-1))
end

function build_left_column(qubit_count::Int)
    qlines = vcat("T", ["q$q" for q in 0:qubit_count-1], "T")
    nlines = ["" for line in qlines[1:end-1]]
    lines  = Vector{String}(undef, 2*length(qlines)-1)
    lines[1:2:end] = qlines[:]
    lines[2:2:end] = nlines[:]
    
    non_qubit_lines = 2:2:length(lines)
    qubit_lines     = 3:2:length(lines)-1
    border_lines    = [1, length(lines)]
    line_groups     = (qubit_lines, non_qubit_lines, border_lines)
    
    pad_width = maximum(length, lines)
    lines[:] .= (rpad(line, pad_width) for line in lines[:])
    lines[border_lines] .*= " : "
    lines[qubit_lines]  .*= " : "
    pad_width = maximum(length, lines)
    lines[:] .= (rpad(line, pad_width) for line in lines[:])

    lines[border_lines]    .*= "|"
    lines[non_qubit_lines] .*= " "
    lines[qubit_lines]     .*= "-"
    return lines, line_groups
end

function Base.show(io::IO, ::MIME"text/plain", circ::Circuit)
    lines, line_groups = build_left_column(qubit_count(circ))
    targeted_rts = filter(r->hasproperty(r, :targets), circ.result_types)
    non_targ_rts = filter(r->!hasproperty(r, :targets), circ.result_types)
    for (t, ixs) in time_slices(circ.moments)
        strings_and_targets = zip((chars(ix.operator) for ix in ixs), (ix.target for ix in ixs))
        lines = build_slice!(lines, strings_and_targets, line_groups, string(t), (0, qubit_count(circ)-1))
    end
    lines = build_result_lines!(targeted_rts, lines, line_groups, qubit_count(circ))

    circ_str = mapreduce(li->li*"\n", *, lines)
    if !isempty(non_targ_rts)
        circ_str *= "\nAdditional result types: "
        circ_str *= join((chars(rt)[1] for rt in non_targ_rts), ", ")
        circ_str *= "\n"
    end
    if !isempty(circ.parameters)
        circ_str *= "\nUnassigned parameters: "
        circ_str *= join((string(p) for p in circ.parameters), ", ") 
        circ_str *= "\n"
    end
    return print(io, circ_str)
end

function make_bound_circuit(c::Circuit, param_values::Dict{Symbol, Number})
    clamped_circ = Circuit()
    foreach(ix->add_instruction!(clamped_circ, bind_value!(ix, param_values)), c.instructions)
    clamped_circ.result_types = deepcopy(c.result_types)
    return clamped_circ
end

(c::Circuit)(::Type{T}, args...) where {T<:Gate}  = apply_gate!(T, c, args...)
(c::Circuit)(::Type{T}, args...) where {T<:Noise} = apply_noise!(T, c, args...)
(c::Circuit)(::Type{T}) where {T<:CompilerDirective} = add_instruction!(c, Instruction(T()))
(c::Circuit)(g::QuantumOperator, args...) = add_instruction!(c, Instruction(g, args...))
(c::Circuit)(g::CompilerDirective) = add_instruction!(c, Instruction(g))
(c::Circuit)(v::AbstractVector) = foreach(vi->c(vi...), v)
(c::Circuit)(rt::Result, args...) = add_result_type!(c, rt, args...)
(c::Circuit)(::Type{T}, args...) where {T<:Result} = T(c, args...)
(c::Circuit)(sub_c::Circuit, args...) = (append!(c, sub_c, args...); return c)

"""
    (c::Circuit)(arg::Number; kwargs...)
    (c::Circuit)(; kwargs...)

Fix all [`FreeParameter`](@ref)s in `c` as specified in `kwargs`
and return a new circuit with the clamped parameters. `c`
is unmodified.

If `arg` is passed, the values of all `FreeParameter`s
*not* listed in `kwargs` will be set to `arg`.

# Examples
```jldoctest
julia> α = FreeParameter(:alpha);

julia> θ = FreeParameter(:theta);

julia> circ = Circuit();

julia> circ = H(circ, 0)

julia> circ = Rx(circ, 1, α)

julia> circ = Ry(circ, 0, θ)

julia> circ = Probability(circ)

julia> new_circ = circ(theta=2.0, alpha=1.0)
```
"""
function (c::Circuit)(arg::Number; kwargs...)
    parameter_values = Dict{Symbol, Number}()
    for param in c.parameters
        parameter_values[param.name] = arg
    end
    return make_bound_circuit(c, parameter_values)
end
function (c::Circuit)(; kwargs...)
    parameter_values = Dict{Symbol, Number}()
    for (k, v) in kwargs 
        parameter_values[Symbol(k)] = v
    end
    return make_bound_circuit(c, parameter_values)
end

"""
    depth(c::Circuit)

Returns the number of moments in `c`.
Also known as the "parallel gate depth".

# Examples
```jldoctest
julia> c = Circuit();

julia> H(c, 0);

julia> CNot(c, 0, 1);

julia> depth(c)
2
```
"""
depth(c::Circuit)       = length(c.moments)
"""
    qubits(c::Circuit) -> QubitSet

Returns a [`QubitSet`](@ref) containing all qubits
that `c` is defined on.

# Examples
```jldoctest
julia> c = Circuit();

julia> H(c, 0);

julia> CNot(c, 0, 1);

julia> qubits(c)
QubitSet(0, 1)
```
"""
qubits(c::Circuit) = (qs = union!(copy(c.moments._qubits), c.qubit_observable_set); QubitSet(qs))
qubits(p::Program) = union(mapreduce(ix->ix.target, union, p.instructions), mapreduce(ix->hasproperty(ix, :target) ? ix.target : Set{Int}(), union, p.results))
"""
    qubit_count(c::Circuit) -> Int

Returns the number of qubits that `c` is defined on.

# Examples
```jldoctest
julia> c = Circuit();

julia> H(c, 0);

julia> CNot(c, 0, 1);

julia> qubit_count(c)
2
```
"""
qubit_count(c::Circuit) = length(qubits(c))
qubit_count(p::Program) = length(qubits(p))

(rt::Result)(c::Circuit) = add_result_type!(c, rt)

Base.convert(::Type{Circuit}, p::Program) = Circuit(Moments(p.instructions), p.instructions, Result[StructTypes.constructfrom(Result, r) for r in p.results], p.basis_rotation_instructions)
Base.convert(::Type{Program}, c::Circuit) = (basis_rotation_instructions!(c); return Program(braketSchemaHeader("braket.ir.jaqcd.program" ,"1"), c.instructions, ir.(c.result_types, Val(:JAQCD)), c.basis_rotation_instructions))
Circuit(p::Program) = convert(Circuit, p)
Program(c::Circuit) = convert(Program, c)

function openqasm_header(c::Circuit, sps::SerializationProperties=OpenQASMSerializationProperties())
    ir_instructions = ["OPENQASM 3.0;"]
    for p in sort(string.(c.parameters))
        push!(ir_instructions, "input float $p;")
    end
    isempty(c.result_types) && push!(ir_instructions, "bit[$(qubit_count(c))] b;")
    if sps.qubit_reference_type == VIRTUAL
        total_qubits = real(maximum(qubits(c))) + 1
        push!(ir_instructions, "qubit[$total_qubits] q;")
    end
    (sps.qubit_reference_type != PHYSICAL && sps.qubit_reference_type != VIRTUAL) && throw(ErrorException("invalid qubit reference type $(sps.qubit_reference_type) supplied."))
    return ir_instructions
end

"""
    ir(c::Circuit; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())

Convert a [`Circuit`](@ref) into IR that can be consumed by the
Amazon Braket service, whether local simulators, on-demand simulators, or QPUs.
The IR format to convert to by default is controlled by the global variable [`IRType`](@ref),
which can be modified. Currently `:JAQCD` and `:OpenQASM` are supported for `Circuit`s.
If writing to `OpenQASM` IR, optional [`OpenQASMSerializationProperties`](@ref) may be specified.
"""
ir(c::Circuit; serialization_properties::SerializationProperties=OpenQASMSerializationProperties()) = ir(c, Val(IRType[]), serialization_properties=serialization_properties)
function ir(c::Circuit, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    header = openqasm_header(c, serialization_properties)
    ixs = map(ix->ir(ix, Val(:OpenQASM); serialization_properties=serialization_properties), c.instructions)
    if !isempty(c.result_types)
        rts = map(rt->ir(rt, Val(:OpenQASM); serialization_properties=serialization_properties), c.result_types)
    else
        rts = ["b[$(idx-1)] = measure $(format(Int(qubit), serialization_properties));" for (idx, qubit) in enumerate(qubits(c))]
    end
    return OpenQasmProgram(header_dict[OpenQasmProgram], join(vcat(header, ixs, rts), "\n"), nothing)
end
ir(c::Circuit, ::Val{:JAQCD}; kwargs...) = convert(Program, c)
ir(p::Program, ::Val{:JAQCD}; kwargs...) = p
ir(p::Program; kwargs...) = ir(p, Val(:JAQCD); kwargs...)

# convenience ctor for OpenQasmProgram
OpenQasmProgram(source::String; inputs::Union{Nothing, Dict}=nothing) = OpenQasmProgram(header_dict[OpenQasmProgram], source, inputs)

function Base.append!(c1::Circuit, c2::Circuit)
    foreach(ix->add_instruction!(c1, ix), c2.instructions)
    foreach(rt->add_result_type!(c1, rt), c2.result_types)
    return c1
end

Base.append!(c1::Circuit, c2::Circuit, target) = append!(c1, c2, Dict(q=>t for (q,t) in zip(sort(qubits(c2)), target)))

function Base.append!(c1::Circuit, c2::Circuit, target_mapping::Dict{<:Integer, <:Integer})
    foreach(ix->add_instruction!(c1, ix, target_mapping), c2.instructions)
    foreach(rt->add_result_type!(c1, rt, target_mapping), c2.result_types)
    return c1
end

extract_observable(rt::ObservableResult) = rt.observable
extract_observable(p::Probability) = Observables.Z()
extract_observable(rt::Result) = nothing 

function _encounter_noncommuting_observable!(c::Circuit)
    c.observables_simultaneously_measureable = false
    empty!(c.qubit_observable_mapping)
    empty!(c.qubit_observable_target_mapping)
    return c
end

function tensor_product_index_dict(o::Observables.TensorProduct, obs_targets::QubitSet)
    factors  = copy(o.factors)
    total    = qubit_count(first(factors))
    obj_dict = Dict{Int, Any}()
    i        = 0
    while length(factors) > 0
        if i >= total
            popfirst!(factors)
            if !isempty(factors)
                total += qubit_count(first(factors))
            end
        end
        if !isempty(factors)
            front = total - qubit_count(first(factors))
            obj_dict[i] = (first(factors), tuple([obs_targets[ii] for ii in front+1:total]...))
        end
        i += 1
    end
    return obj_dict
end

basis_rotation_gates(o::Observables.H) = (Ry(-π/4),)
basis_rotation_gates(o::Observables.X) = (H(),)
basis_rotation_gates(o::Observables.I) = ()
basis_rotation_gates(o::Observables.Z) = ()
basis_rotation_gates(o::Observables.Y) = (Z(), S(), H())
basis_rotation_gates(o::Observables.TensorProduct) = tuple(reduce(vcat, basis_rotation_gates.(o.factors))...)
basis_rotation_gates(o::Observables.HermitianObservable) = (Unitary(Matrix(adjoint(eigvecs(o.matrix)))),)


_observable_to_instruction(observable::Observables.Observable, target_list)::Vector{Instruction} = [Instruction(gate, target_list) for gate in basis_rotation_gates(observable)]

"""
    basis_rotation_instructions!(c::Circuit)

Gets a list of basis rotation instructions and stores them in the circuit `c`.
These basis rotation instructions are added if result types are requested for
an observable other than Pauli-Z.

This only makes sense if all observables are simultaneously measurable;
if not, this method will return an empty list.
"""
function basis_rotation_instructions!(c::Circuit)
    # Note that basis_rotation_instructions can change each time a new instruction
    # is added to the circuit because `self._moments.qubits` would change
    basis_rotation_instructions = Instruction[]
    all_qubit_observable = get(c.qubit_observable_mapping, ALL_QUBITS, nothing)
    if !isnothing(all_qubit_observable)
        c.basis_rotation_instructions = reduce(vcat, _observable_to_instruction(all_qubit_observable, target) for target in qubits(c))
        return c
    end

    unsorted = collect(Set(values(c.qubit_observable_target_mapping)))
    target_lists = sort(unsorted)
    for target_list in target_lists
        observable = c.qubit_observable_mapping[first(target_list)]
        append!(basis_rotation_instructions, _observable_to_instruction(observable, target_list))
    end
    c.basis_rotation_instructions = basis_rotation_instructions
    return c
end

function add_to_qubit_observable_mapping!(c::Circuit, o::Observables.Observable, obs_targets::QubitSet)
    targets = length(obs_targets) > 0 ? obs_targets : collect(c.qubit_observable_set)
    all_qubits_observable = get(c.qubit_observable_mapping, ALL_QUBITS, nothing)
    id = Observables.I()
    for ii in 1:length(targets)
        target             = targets[ii]
        new_observable     = o
        current_observable = !isnothing(all_qubits_observable) ? all_qubits_observable : get(c.qubit_observable_mapping, target, nothing)
        add_observable     = isnothing(current_observable) || (current_observable == id && new_observable != id)
        !add_observable && current_observable != id && new_observable != id && new_observable != current_observable && return _encounter_noncommuting_observable!(c)
        if !isempty(obs_targets)
            new_targets = tuple(obs_targets...)
            if add_observable
                c.qubit_observable_target_mapping[target] = new_targets
                c.qubit_observable_mapping[target] = new_observable
            elseif qubit_count(new_observable) > 1
                current_target = get(c.qubit_observable_target_mapping, target, nothing)
                !isnothing(current_target) && current_target != new_targets && _encounter_noncommuting_observable!(c)
            end
        end
    end
    if isempty(obs_targets)
        !isnothing(all_qubits_observable) && all_qubits_observable != o && return _encounter_noncommuting_observable!(c)
        c.qubit_observable_mapping[ALL_QUBITS] = o
    end
    return c
end
add_to_qubit_observable_mapping!(c::Circuit, o::Observables.Observable, obs_targets::Nothing) = add_to_qubit_observable_mapping!(c, o, qubits(c))

function add_to_qubit_observable_mapping!(c::Circuit, o::Observables.TensorProduct, obs_targets::QubitSet)
    targets = length(obs_targets) != 0 ? obs_targets : collect(c.qubit_observable_set)
    all_qubits_observable = get(c.qubit_observable_mapping, ALL_QUBITS, nothing)
    tensor_product_dict = length(targets) > 0 ? tensor_product_index_dict(o, QubitSet(targets)) : Dict()
    id = Observables.I()
    for ii in 1:length(targets)
        target             = targets[ii]
        new_observable     = tensor_product_dict[ii-1][1]
        current_observable = !isnothing(all_qubits_observable) ? all_qubits_observable : get(c.qubit_observable_mapping, target, nothing)
        add_observable     = isnothing(current_observable) || (current_observable == id && new_observable != id)
        !add_observable && current_observable != id && new_observable != id && new_observable != current_observable && return _encounter_noncommuting_observable!(c)
        if !isempty(obs_targets)
            new_targets = tensor_product_dict[ii-1][2]
            if add_observable
                c.qubit_observable_target_mapping[target] = new_targets
                c.qubit_observable_mapping[target] = new_observable
            elseif qubit_count(new_observable) > 1
                current_target = get(c.qubit_observable_target_mapping, target, nothing)
                !isnothing(current_target) && current_target != new_targets && return _encounter_noncommuting_observable!(c)
            end
        end
    end
    if isempty(obs_targets)
        !isnothing(all_qubits_observable) && all_qubits_observable != o && return _encounter_noncommuting_observable!(c)
        c.qubit_observable_mapping[ALL_QUBITS] = o
    end
    return c
end
add_to_qubit_observable_mapping!(c::Circuit, o::Observables.Observable, obs_targets::Vector) = add_to_qubit_observable_mapping!(c, o, QubitSet(obs_targets))
add_to_qubit_observable_set!(c::Circuit, rt::ObservableResult) = union!(c.qubit_observable_set, Set(rt.targets))
add_to_qubit_observable_set!(c::Circuit, rt::AdjointGradient)  = union!(c.qubit_observable_set, Set(reduce(union, rt.targets)))
add_to_qubit_observable_set!(c::Circuit, rt::Result) = c.qubit_observable_set

function add_result_type!(c::Circuit, rt::Result)
    rt_to_add = rt
    if rt_to_add ∉ c.result_types
        if rt_to_add isa AdjointGradient && any(rt_ isa AdjointGradient for rt_ in c.result_types)
            throw(ArgumentError("only one AdjointGradient result can be present on a circuit."))
        end
        obs = extract_observable(rt_to_add)
        if !isnothing(obs) && c.observables_simultaneously_measureable && !(rt isa AdjointGradient)
            add_to_qubit_observable_mapping!(c, obs, rt_to_add.targets)
        end
        add_to_qubit_observable_set!(c, rt_to_add)
        push!(c.result_types, rt_to_add)
    end
    return c
end
add_result_type!(c::Circuit, rt::Result, target) = add_result_type!(c, remap(rt, target))
add_result_type!(c::Circuit, rt::Result, target_mapping::Dict{<:Integer, <:Integer}) = add_result_type!(c, remap(rt, target_mapping))

function add_instruction!(c::Circuit, ix::Instruction)
    to_add = [ix]
    if ix.operator isa QuantumOperator && Parametrizable(ix.operator) == Parametrized()
        for param in parameters(ix.operator)
            union!(c.parameters, (param,))
        end
    end
    push!(c.moments, to_add)
    push!(c.instructions, ix)
    return c
end

function add_instruction!(c::Circuit, ix::Instruction, target)
    to_add = Instruction[]
    if qubit_count(ix.operator) == 1
        to_add = [remap(ix, q) for q in target]
    else
        to_add = [remap(ix, collect(target))]
    end
    foreach(ix->add_instruction!(c, ix), to_add)
    return c
end

function add_instruction!(c::Circuit, ix::Instruction, target_mapping::Dict{<:Integer, <:Integer})
    to_add = [remap(ix, target_mapping)]
    foreach(ix->add_instruction!(c, ix), to_add)
    return c
end

function add_verbatim_box!(c::Circuit, verbatim_circuit::Circuit, target_mapping::Dict{<:Integer, <:Integer}=Dict{Int, Int}())
    !isempty(verbatim_circuit.result_types) && throw(ErrorException("verbatim subcircuit is not measured and cannot have result types."))
    isempty(verbatim_circuit.instructions) && return c
    c = add_instruction!(c, Instruction(StartVerbatimBox()))
    for ix in verbatim_circuit.instructions
        c = isempty(target_mapping) ? add_instruction!(c, ix) : add_instruction!(c, ix, target_mapping) 
    end
    c = add_instruction!(c, Instruction(EndVerbatimBox()))
    c.has_compiler_directives = true
    return c
end

function add_verbatim_box!(c::Circuit, verbatim_circuit::Circuit, target)
    sorted_qs = sort(collect(qubits(verbatim_circuit)))
    target_mapping = Dict(zip(sorted_qs, target))
    return add_verbatim_box!(c, verbatim_circuit, target_mapping)
end

function apply_noise_to_gates(noise::Vector{<:Noise}, target_qubits, instruction::Instruction, noise_index::Int, intersection, noise_applied::Bool, new_noise_ix::Vector)
    for noise_channel in noise
        if qubit_count(noise_channel) == 1
            for qubit in intersection
                noise_index += 1
                push!(new_noise_ix, (Instruction(noise_channel, qubit), noise_index))
                noise_applied = true
            end
        else
            if qubit_count(instruction.operator) == qubit_count(noise_channel) && instruction.target ⊆ target_qubits
                noise_index += 1
                push!(new_noise_ix, (Instruction(noise_channel, instruction.target), noise_index))
                noise_applied = true
            end
        end
    end
    return new_noise_ix, noise_index, noise_applied
end

function apply_gate_noise!(c::Circuit, noise::Vector{<:Noise}, target_gates::Vector{<:Gate}, target_qubits)
    qubit_count(c) == 0 && throw(ArgumentError("cannot apply noise to an empty circuit!"))
    t_gates       = unique(target_gates)
    new_moments   = Moments()
    noise_applied = false
    for moment_key in keys(c.moments)
        ix = c.moments[moment_key]
        if ix.operator isa Noise
            add_noise!(new_moments, ix, MomentType_tostr[moment_key.moment_type], moment_key.noise_index)
        else
            new_noise_ix = []
            noise_index = moment_key.noise_index
            if isempty(t_gates) || any(ix.operator isa typeof(g) for g in t_gates)
                overlap = intersect(ix.target, target_qubits)
                new_noise_ix, noise_index, noise_applied = apply_noise_to_gates(noise, target_qubits, ix, noise_index, overlap, noise_applied, new_noise_ix)
            end
            mt = ix.operator isa Gate ? mtGate : mtCompilerDirective
            push!(new_moments, [ix], mt, noise_index)
            for (nix, noise_index) in new_noise_ix
                add_noise!(new_moments, nix, "gate_noise", noise_index)
            end
        end
    end
    noise_applied == false && @warn "no noise applied" 
    c.moments = new_moments
    c.instructions = collect(values(c.moments._moments))
    return c
end
apply_gate_noise!(c::Circuit, noise::Noise, target_gates::Vector{<:Gate}, target_qubits) = apply_gate_noise!(c, [noise], target_gates, target_qubits)
apply_gate_noise!(c::Circuit, noise::Vector{<:Noise}, target_gates::Gate, target_qubits) = apply_gate_noise!(c, noise, [target_gates], target_qubits)
apply_gate_noise!(c::Circuit, noise::Noise, target_gates::Gate, target_qubits)           = apply_gate_noise!(c, [noise], [target_gates], target_qubits)
apply_gate_noise!(c::Circuit, noise::Noise, target_gates::Gate, target_qubit::IntOrQubit) = apply_gate_noise!(c, [noise], [target_gates], QubitSet(target_qubit))
apply_gate_noise!(c::Circuit, noise::Noise, target_gates::Gate) = apply_gate_noise!(c, [noise], [target_gates], qubits(c))
apply_gate_noise!(c::Circuit, noise, target_qubit) = apply_gate_noise!(c, noise, Gate[], target_qubit)
apply_gate_noise!(c::Circuit, noise) = apply_gate_noise!(c, noise, Gate[], qubits(c))

function apply_gate_noise!(c::Circuit, noise::Vector{<:Noise}, target_unitary::Matrix{<:Complex}, target_qubits)
    qubit_count(c) == 0 && throw(ArgumentError("cannot apply noise to an empty circuit!"))
    new_moments = Moments()
    noise_applied = false
    for moment_key in keys(c.moments)
        ix = c.moments[moment_key]
        if ix.operator isa Noise
            add_noise!(new_moments, ix, MomentType_tostr[moment_key.moment_type], moment_key.noise_index)
        else
            new_noise_ix = []
            noise_index = moment_key.noise_index
            if ix.operator isa Unitary && ix.operator.matrix ≈ target_unitary
                intersec = intersect(ix.target, target_qubits)
                new_noise_ix, noise_index, noise_applied = apply_noise_to_gates(noise, target_qubits, ix, noise_index, intersec, noise_applied, new_noise_ix)
            end
            push!(new_moments, [ix], moment_key.moment_type, noise_index)
            for (nix, noise_index) in new_noise_ix
                add_noise!(new_moments, nix, "gate_noise", noise_index)
            end
        end
    end
    noise_applied == false && @warn "no noise applied" 
    c.moments = new_moments
    c.instructions = collect(values(c.moments._moments))
    return c
end
apply_gate_noise!(c::Circuit, noise::Noise, target_unitary::Matrix{<:Complex}, target_qubits) = apply_gate_noise!(c, [noise], target_unitary, target_qubits)
apply_gate_noise!(c::Circuit, noise::Noise, target_unitary::Matrix{<:Complex}, target_qubit::IntOrQubit) = apply_gate_noise!(c, [noise], target_unitary, [target_qubit])
apply_gate_noise!(c::Circuit, noise, target_unitary::Matrix{<:Complex}) = apply_gate_noise!(c, noise, target_unitary, qubits(c))

function apply_noise_to_moments!(c::Circuit, noise::Vector{<:Noise}, target_qubits, ::Val{:readout})
    noise_ixs = []
    for noise_channel in noise
        if qubit_count(noise_channel) == 1
            new_ix = [Instruction(noise_channel, qubit) for qubit in target_qubits]
            append!(noise_ixs, new_ix)
        else
            append!(noise_ixs, [Instruction(noise_channel, target_qubits)])
        end
    end
    new_moments = Moments()
    for moment_key in keys(c.moments)
        ix = c.moments[moment_key]
        if ix.operator isa Noise
            push!(new_moments, ix, moment_key.moment_type, moment_key.noise_index)
        else
            push!(new_moments, [ix], moment_key.moment_type, moment_key.noise_index)
        end
    end
    for noise in noise_ixs
        add_noise!(new_moments, noise, "readout_noise")
    end
    c.moments = new_moments
    c.instructions = collect(values(c.moments._moments))
    return c
end

function apply_noise_to_moments!(c::Circuit, noise::Vector{<:Noise}, target_qubits, ::Val{:initialization})
    noise_ixs = []
    for noise_channel in noise
        if qubit_count(noise_channel) == 1
            new_ix = [Instruction(noise_channel, qubit) for qubit in target_qubits]
            append!(noise_ixs, new_ix)
        else
            append!(noise_ixs, [Instruction(noise_channel, target_qubits)])
        end
    end
    new_moments = Moments()
    for noise in noise_ixs
        add_noise!(new_moments, noise, "initialization_noise")
    end
    for moment_key in keys(c.moments)
        ix = c.moments[moment_key]
        if ix.operator isa Noise
            push!(new_moments, ix, moment_key.moment_type, moment_key.noise_index)
        else
            push!(new_moments, [ix], moment_key.moment_type, moment_key.noise_index)
        end
    end
    c.moments = sort_moments!(new_moments)
    c.instructions = collect(values(c.moments._moments))
    return c
end

apply_initialization_noise!(c::Circuit, noise::Vector{<:Noise}, target_qubits) = apply_noise_to_moments!(c, noise, target_qubits, Val(:initialization))
apply_initialization_noise!(c::Circuit, noise::Noise, target_qubits) = apply_initialization_noise!(c, [noise], target_qubits)
apply_initialization_noise!(c::Circuit, noise::Noise, target_qubit::Union{Int, Qubit}) = apply_initialization_noise!(c, [noise], [target_qubit])
apply_initialization_noise!(c::Circuit, noise::Vector{<:Noise}) = apply_initialization_noise!(c, noise, qubits(c))
apply_initialization_noise!(c::Circuit, noise::Noise) = apply_initialization_noise!(c, [noise], qubits(c))

apply_readout_noise!(c::Circuit, noise::Vector{<:Noise}, target_qubits) = apply_noise_to_moments!(c, noise, target_qubits, Val(:readout))
apply_readout_noise!(c::Circuit, noise::Noise, target_qubits) = apply_readout_noise!(c, [noise], target_qubits)
apply_readout_noise!(c::Circuit, noise::Noise, target_qubit::Union{Int, Qubit}) = apply_readout_noise!(c, [noise], [target_qubit])
apply_readout_noise!(c::Circuit, noise::Vector{<:Noise}) = apply_readout_noise!(c, noise, qubits(c))
apply_readout_noise!(c::Circuit, noise::Noise) = apply_readout_noise!(c, [noise], qubits(c))

obs_union = Union{String, Vector{String}, Observables.Observable}
for T in (:Expectation, :Variance, :Sample)
    @eval begin
        @doc """
            $($T)(c::Circuit, o, targets) -> Circuit
            $($T)(c::Circuit, o) -> Circuit
        
        Constructs a `$($T)` of an observable `o` on qubits `targets`
        and adds it as a result to [`Circuit`](@ref) `c`.
        
        `o` may be one of:
          - Any [`Observable`](@ref Braket.Observables.Observable)
          - A `String` corresponding to an `Observable` (e.g. \"x\")
          - A `Vector{String}` in which each element corresponds to an `Observable`

        `targets` may be one of:
          - A [`QubitSet`](@ref)
          - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
          - An `Int` or `Qubit`
          - Absent, in which case the observable `o` will be applied to all qubits provided it is a single qubit observable.

        # Examples
        ```jldoctest
        julia> c = Circuit();

        julia> c = H(c, collect(0:10));

        julia> c = $($T)(c, Braket.Observables.Z(), 0);

        julia> c = $($T)(c, Braket.Observables.X());
        ```
        """ $T(c::Circuit, o, targets) = add_result_type!(c, $T(o, targets))
        $T(c::Circuit, o, targets::Vararg{IntOrQubit}) = add_result_type!(c, $T(o, QubitSet(targets...)))
        $T(c::Circuit, o::obs_union) = add_result_type!(c, $T(o))
    end
end
"""
    Amplitude(c::Circuit, states) -> Circuit

Constructs an `Amplitude` measurement of `states`
and adds it as a result to [`Circuit`](@ref) `c`.

`states` may be of type:
  - `Vector{String}`
  - `String`
All elements of `states` must be `'0'` or `'1'`.

# Examples
```jldoctest
julia> c = Circuit();

julia> c = H(c, collect(0:3));

julia> c = Amplitude(c, "0000");
```
"""
Amplitude(c::Circuit, states) = (a = Amplitude(states); a(c))
"""
    Probability(c::Circuit, targets) -> Circuit
    Probability(c::Circuit) -> Circuit

Constructs a `Probability` measurement on qubits `targets`
and adds it as a result to [`Circuit`](@ref) `c`.

`targets` may be one of:
  - A [`QubitSet`](@ref)
  - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
  - An `Int` or `Qubit`
  - Absent, in which case the measurement will be applied to all qubits of `c`.

# Examples
```jldoctest
julia> c = Circuit();

julia> c = H(c, collect(0:3));

julia> c = Probability(c, 2);
```
"""
Probability(c::Circuit, targets) = (p = Probability(targets); p(c))
Probability(c::Circuit, targets::Vararg{IntOrQubit}) = (p = Probability(QubitSet(targets...)); p(c))
Probability(c::Circuit) = (p = Probability(); p(c))
"""
    DensityMatrix(c::Circuit, targets) -> Circuit

Constructs a `DensityMatrix` measurement on qubits `targets`
and adds it as a result to [`Circuit`](@ref) `c`.

`targets` may be one of:
  - A [`QubitSet`](@ref)
  - A `Vector` of `Int`s and/or [`Qubit`](@ref)s
  - An `Int` or `Qubit`
  - Absent, in which case the measurement will be applied to all qubits of `c`.

# Examples
```jldoctest
julia> c = Circuit();

julia> c = H(c, collect(0:3));

julia> c = DensityMatrix(c, 2);
```
"""
DensityMatrix(c::Circuit, targets) = (p = DensityMatrix(targets); p(c))
DensityMatrix(c::Circuit, targets::Vararg) = (p = DensityMatrix(QubitSet(targets...)); p(c))
DensityMatrix(c::Circuit) = (dm = DensityMatrix(); dm(c))
"""
    StateVector(c::Circuit) -> Circuit

Constructs a `StateVector` measurement on all qubits of `c`
and adds it as a result to [`Circuit`](@ref) `c`.

# Examples
```jldoctest
julia> c = Circuit();

julia> c = H(c, collect(0:3));

julia> c = StateVector(c);
```
"""
StateVector(c::Circuit) = (sv = StateVector(); sv(c))
        
"""
    AdjointGradient(c::Circuit, o::Observable, targets, parameters) -> Circuit

Constructs an `AdjointGradient` computation with respect to the expectation value of an observable `o`
on qubits `targets`, computing partial derivatives of `parameters`, and adds it as a result to [`Circuit`](@ref) `c`.

`o` may be any `Observable`. `targets` must be a `Vector` of `QubitSet`s (or a single `QubitSet`, if `o` is not a `Sum`),
each of which is the same length as the qubit count of the corresponding term in `o`.
`parameters` can have elements which are [`FreeParameter`](@ref)s or `String`s, or `["all"]`,
in which case the gradient is computed with respect to all parameters in the circuit.

# Examples
```jldoctest
julia> c = Circuit();

julia> α = FreeParameter("alpha");

julia> c = H(c, collect(0:10));

julia> c = Rx(c, collect(0:10), α);

julia> c = AdjointGradient(c, Braket.Observables.Z(), 0, [α]);
```
"""
AdjointGradient(c::Circuit, o::Observable, target::Vector{QubitSet}, parameters) = (ag = AdjointGradient(o, target, parameters); ag(c))
AdjointGradient(c::Circuit, o::Observable, target::Vector{Vector{T}}, parameters) where {T} = (ag = AdjointGradient(o, target, parameters); ag(c))
AdjointGradient(c::Circuit, o::Observable, target::Vector{<:IntOrQubit}, parameters) = (ag = AdjointGradient(o, target, parameters); ag(c))
AdjointGradient(c::Circuit, o::Observable, target::QubitSet, parameters) = (ag = AdjointGradient(o, [target], parameters); ag(c))
AdjointGradient(c::Circuit, o::Observable, target::IntOrQubit, parameters) = (ag = AdjointGradient(o, [target], parameters); ag(c))

function validate_circuit_and_shots(c::Circuit, shots::Int)
    isempty(c.instructions) && throw(ErrorException("Circuit must have instructions to run on a device."))
    shots==0 && isempty(c.result_types) && throw(ErrorException("Shots=0 without result types specified."))
    if shots > 0 && !isempty(c.result_types)
        !c.observables_simultaneously_measureable && throw(ErrorException("Observables cannot be measured simultaneously."))
        for rt in c.result_types
            (rt isa StateVector || rt isa Amplitude || rt isa AdjointGradient) && throw(ErrorException("StateVector or Amplitude cannot be specified when shots>0"))
            if rt isa Probability
                num_qubits = length(rt.targets) == 0 ? qubit_count(c) : length(rt.targets)
                num_qubits > 40 && throw(ErrorException("Probability target must be less than or equal to 40 qubits."))
            end
        end
    end
    return
end

Base.:(==)(c1::Circuit, c2::Circuit) = (c1.instructions == c2.instructions && c1.result_types == c2.result_types)
function Base.show(io::IO, program::OpenQasmProgram)
    print(io, "OpenQASM program")
end
