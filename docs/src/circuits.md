# Circuits 

The [`Circuit`](@ref) struct is used to represent a gate-based quantum computation on qubits. `Circuit`s can be built up iteratively by 
applying them as functors to operations like so:

```julia-repl
julia> c = Circuit();

julia> c(H, Qubit(0));

julia> α = FreeParameter(:alpha);

julia> c(Rx, Qubit(1), α);

julia> c(Probability); # measures probability on all qubits
```

This functor syntax can also be used to set the value of free parameters:

```julia-repl
julia> α = FreeParameter(:alpha);

julia> θ = FreeParameter(:theta);

julia> circ = Circuit([(H, 0), (Rx, 1, α), (Ry, 0, θ), (Probability,)]);

julia> new_circ = circ(theta=2.0, alpha=1.0);

julia> new_circ2 = circ(0.5); # sets the value of all FreeParameters to 0.5
```

```@docs
Circuit
Circuit()
Circuit(::Braket.Moments, ::Vector, ::Vector{Result}, ::Vector)
Circuit(::AbstractVector)
Qubit
QubitSet
Braket.Operator
Braket.QuantumOperator
FreeParameter
depth
qubits
qubit_count
```

## Output to IR
`Braket.jl` provides several functions to transform a `Circuit` into IR which
will be transmitted to Amazon managed QPUs or simulators. Currently, two output
formats supported are [OpenQASM](https://docs.aws.amazon.com/braket/latest/developerguide/braket-openqasm.html),
and JAQCD (an Amazon Braket native IR). You can control how IR translation is done
through the global variable [`IRType`](@ref) and, if using OpenQASM,
[`OpenQASMSerializationProperties`](@ref).

```@docs
Braket.Instruction
ir
IRType
OpenQASMSerializationProperties
```
