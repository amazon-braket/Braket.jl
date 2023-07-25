# PyBraket.jl

**PyBraket.jl is not an officially supported AWS product.**

This package provides Julia-Python interoperability between `Braket.jl` and Python features of the Amazon Braket SDK, such as the Amazon Braket [Local Simulators](https://docs.aws.amazon.com/braket/latest/developerguide/braket-send-to-local-simulator.html) and
[Local Jobs](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-local-mode.html).

This is *experimental* software, and support may be discontinued in the future. For a fully supported SDK, please use
the [Python SDK](https://github.com/aws/amazon-braket-sdk-python). We may change, remove, or deprecate parts of the API when making new releases.
Please review the [CHANGELOG](CHANGELOG.md) for information about changes in each release. 

## Installation & Prerequisites

You'll need [`PythonCall.jl`](https://cjdoris.github.io/PythonCall.jl).

### Use `CondaPkg.jl`

`PyBraket.jl` now supports [`CondaPkg.jl`](https://github.com/cjdoris/CondaPkg.jl)! The package and its tests come with `CondaPkg.toml` files ready to go.
`CondaPkg` will install all necessary dependencies for you.

### Use native Python installation

If you want to use an existing Python installation (a virtual environment you control, for example),
you will need a working installation of the [Amazon Braket SDK](https://github.com/aws/amazon-braket-sdk-python).
You can install the Amazon Braket SDK and all its dependencies through `pip` as documented on its [README](https://github.com/aws/amazon-braket-sdk-python/blob/main/README.md).
 
To use an existing installation through `PyBraket.jl` you will need to [turn off CondaPkg.jl](https://cjdoris.github.io/PythonCall.jl/stable/pythoncall/#If-you-don't-want-to-use-Conda).
In particular, if you already have the SDK and its dependencies installed, you can run:

`export JULIA_PYTHONCALL_EXE=path_to_your_python`

or add it to your `.bash_profile`/`.bashrc`/`.zsh_profile`/`.zshrc`/etc.
This will prevent `PythonCall.jl` and `CondaPkg.jl` from trying to reinstall the SDK and its dependencies.
Note that if you installed the Amazon Braket SDK in a Python virtual environment, you will need to set this environment variable *to the python executable associated with that virtual environment*. You can find the path to that python executable by activating the virtenv and running `which python` if you're on Linux or MacOS.

## Examples

Running a Local Job:

```julia
using PyBraket, Braket
sm = joinpath(@__DIR__, "algo_script", "algo_script.py")
job = LocalJob("local:braket/braket.local.qubit", source_module=sm)
@assert state(job) == "COMPLETED" 
```

Running an analog Hamiltonian simulation on the local AHS simulator:

```julia
using Braket, PyBraket
using Braket: AtomArrangement, AtomArrangementItem, TimeSeries, DrivingField, AwsDevice, AnalogHamiltonianSimulation, discretize, AnalogHamiltonianSimulationQuantumTaskResult

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
# extracted from device paradigm
(C6, Ω_min, Ω_max, Ω_slope_max, Δ_min, Δ_max, time_max) = (5.42e-24, 0.0, 6.3e6, 2.5e14, -1.25e8, 1.25e8, 4.0e-6)

time_max     = Float64(time_max)
Δ_start      = -5 * Float64(Ω_max)
Δ_end        = 5 * Float64(Ω_max)
@test all(Δ_min <= Δ <= Δ_max for Δ in (Δ_start, Δ_end))

time_ramp = 1e-7  # seconds
@test Float64(Ω_max) / time_ramp < Ω_slope_max

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

drive                   = DrivingField(Ω, ϕ, Δ)
ahs_program             = AnalogHamiltonianSimulation(register, [drive])

ahs_local    = LocalSimulator("braket_ahs")
local_result = result(run(ahs_local, ahs_program, shots=1_000))
``` 
