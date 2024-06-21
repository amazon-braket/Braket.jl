# Local Simulators

Local simulators allow you to *classically* simulate your [`Circuit`](@ref) or `OpenQasmProgram`
on local hardware, rather than sending it to the cloud for on-demand execution. Local simulators
can run task *batches* in parallel using multithreading. Gate-based simulators are provided in the
[`BraketSimulator.jl`](https://github.com/amazon-braket/braketsimulator.jl) package.

Developers wishing to implement their own `LocalSimulator` should extend the `simulate` function.
New simulator backends must be subtypes of the `AbstractLocalSimulator` type.
Additionally, new simulators should "register" themselves in `Braket._simulator_devices` in their
parent module's `__init__` function so that they can be referred to by name, like so:

```julia
module NewLocalSimulator

using Braket

struct NewSimulator <: Braket.AbstractLocalSimulator 
# implementation of a new local simulator backend
# with name "new_simulator"
end

function Braket.simulate()
    # simulation implementation here
end

function __init__()
    Braket._simulator_devices[]["new_simulator"] = NewLocalSimulator()
end

end
```

Then users can use the new simulator like so:

```julia
using NewLocalSimulator, Braket

dev = LocalSimulator("new_simulator")
simulate(dev, task_specification, args...; kwargs...)
```

```@docs
Braket._simulator_devices
Braket.LocalQuantumTask
Braket.LocalQuantumTaskBatch
LocalSimulator
simulate
```
