# Braket.jl

**Braket.jl is not an officially supported AWS product.**

This package is a Julia implementation of the [Amazon Braket SDK](https://github.com/aws/amazon-braket-sdk-python).

This is *experimental* software, and support may be discontinued in the future. For a fully supported SDK, please use
the [Python SDK](https://github.com/aws/amazon-braket-sdk-python). We may change, remove, or deprecate parts of the API when making new releases.
Please review the [CHANGELOG](CHANGELOG.md) for information about changes in each release. 

[![Stable docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://awslabs.github.io/braket-jl/stable)
[![Latest docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://awslabs.github.io/braket-jl/dev)
[![CI](https://github.com/awslabs/braket-jl/actions/workflows/CI.yml/badge.svg)](https://github.com/awslabs/braket-jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/awslabs/braket-jl/branch/main/graph/badge.svg?token=QC9P7HQY4V)](https://codecov.io/gh/awslabs/braket-jl)

## Installation & Prerequisites

You do *not* need a Python installation or the Python Amazon Braket SDK installed to use this package.
However, to use the Amazon Braket [Local Simulators](https://docs.aws.amazon.com/braket/latest/developerguide/braket-send-to-local-simulator.html) or
[Local Jobs](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-local-mode.html), you'll need to install the sub-package `PyBraket.jl`,
included in this repository. See its [`README`](PyBraket/README.md) for more information.
 
All necessary Julia packages will be installed for you when you run `Pkg.add("Braket")`
or `] instantiate` (if you're doing a `dev` install).

If you want to run tasks on Amazon Braket's [managed simulators or QPUs](https://docs.aws.amazon.com/braket/latest/developerguide/braket-devices.html) or run
[managed jobs](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-works.html),
you will need an AWS account and to have [onboarded](https://docs.aws.amazon.com/braket/latest/developerguide/braket-enable-overview.html) with the Amazon Braket service.
`Braket.jl` can load your AWS credentials from your environment variables or your `~/.aws/config` file thanks to the [`AWS.jl`](https://github.com/JuliaCloud/AWS.jl) package.

## Usage Notes

Keep in mind that the first qubit has index `0`, **not** index `1`.
Some Amazon Braket Hybrid Jobs return results as pickled objects, which are currently not decompressible using `Braket.jl`.
In such cases you may need to download and extract the results using `PyBraket.jl` and the Amazon Braket SDK.

## Examples

Constructing a simple circuit:

```julia
using Braket

c = Circuit()
c = H(c, 0) # qubits are 0-indexed
c = CNot(c, 0, 1)
c = Probability(c)
```

Measuring expectation values on a QPU:

```julia
using Braket, Braket.Observables

c = Circuit()
c = H(c, 0)
c = CNot(c, 0, 1)
c = Expectation(c, Observables.X()) # measure X on all qubits

dev = IonQ()
res = result(run(dev, c, shots=0))
```

## TODO and development roadmap

What's currently implemented in *pure* Julia:

- All of the [`Amazon Braket schemas`](https://github.com/aws/amazon-braket-schemas-python).
- Submitting [`Amazon Braket Hybrid Jobs`](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs.html)
- Building and submitting circuits to managed simulators and QPUs
- Reading results from managed simulators and QPUs
- Cancelling tasks and jobs
- Fetching quantum task and device information from AWS
- Searching device information and looking up availability windows
- Noise models
- Convenience `Circuit` features
- Cost tracking
- All gates and noise operations
- Analog Hamiltonian Simulation

Features which we still need to add:
- Support for pickled jobs results
- Local jobs
- More robust entry point verification for jobs
- Pretty printing of circuits
- Pulse control

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.
