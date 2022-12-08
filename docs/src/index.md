# Braket.jl Documentation

**Braket.jl is not an officially supported AWS product.**

## Introduction

This is the documentation for the `Braket.jl` package, a Julia reimplementation of the [`Amazon Braket SDK`](https://github.com/aws/amazon-braket-sdk-python).
Please also refer to the documentation of that package and the [`official Amazon Braket documentation`](https://docs.aws.amazon.com/braket/) - if your question
isn't answered here, it may be at one of those two locations.

This is *experimental* software, and support may be discontinued in the future. For a fully supported SDK, please use
the [Python SDK](https://github.com/aws/amazon-braket-sdk-python). We may change, remove, or deprecate parts of the API when making new releases.
Please review the [CHANGELOG](https://github.com/awslabs/Braket.jl/blob/main/CHANGELOG.md) for information about changes in each release. 

## What is Amazon Braket?

Amazon Braket is a fully-managed AWS service that helps researchers, scientists, and developers get started with quantum computing. Quantum computing has the potential to solve computational problems that are beyond the reach of classical computers because it harnesses the laws of quantum mechanics to process information in new ways.

## Is `Braket.jl` the same thing as Amazon Braket?

No. `Braket.jl` is a "software development kit" (SDK) written in [Julia](https://julialang.org/) which allows you to interact with the Amazon Braket service in a similar way to the [Python SDK](https://github.com/aws/amazon-braket-sdk-python). You can build gate-based quantum circuits, analog Hamiltonian simulations, and other constructs and then submit them to the Amazon Braket service to run on AWS managed devices/infrastructure or run them locally. 

## Quick start

In order to use most features of Amazon Braket, you will *not* need a Python installation or to install the Python SDK or any of its dependencies.
There are some exceptions - if you want to run a [`LocalJob`](https://docs.aws.amazon.com/braket/latest/developerguide/braket-jobs-local-mode.html)
or run a task on one of the [`Braket local simulators`](https://github.com/aws/amazon-braket-default-simulator-python) you will need to use the Python
interoperability package `PyBraket.jl`, which comes with `Braket.jl` as a sub-package in the same repo. Refer to the `PyBraket.jl` `README` for more information.

If you want to run tasks or Amazon Braket Hybrid Jobs on AWS managed devices, you will need to have an AWS account and to [`onboard to Braket`](https://docs.aws.amazon.com/braket/latest/developerguide/braket-enable-overview.html).

## Examples and tutorials

Many examples of quantum workflows are available at the [Amazon Braket Examples repo](https://github.com/aws/amazon-braket-examples/). These tutorials cover most aspects of the service and are written in Python, but a conversion to Julia is usually straightforward. There are also examples provided in the `examples` folder of this repository.
