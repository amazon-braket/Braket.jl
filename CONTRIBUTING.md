# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional
documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary
information to effectively respond to your bug report or contribution.

## Table of Contents

* [Report Bugs/Feature Requests](#report-bugsfeature-requests)
* [Contribute via Pull Requests (PRs)](#contribute-via-pull-requests-prs)
  * [Pull Down the Code](#pull-down-the-code)
  * [Run the Unit Tests](#run-the-unit-tests)
  * [Run the Integration Tests](#run-the-integration-tests)
  * [Make and Test Your Change](#make-and-test-your-change)
  * [Commit Your Change](#commit-your-change)
  * [Send a Pull Request](#send-a-pull-request)
* [Documentation Guidelines](#documentation-guidelines)
  * [API References (docstrings)](#api-references-docstrings)
  * [Build and Test Documentation](#build-and-test-documentation)
* [Find Contributions to Work On](#find-contributions-to-work-on)
* [Code of Conduct](#code-of-conduct)
* [Security Issue Notifications](#security-issue-notifications)
* [Licensing](#licensing)

## Report Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check existing open and recently closed issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

* A reproducible test case or series of steps.
* The version of our code being used.
* Any modifications you've made relevant to the bug.
* A description of your environment or deployment.


## Contribute via Pull Requests (PRs)

Contributions via pull requests are much appreciated.

Before sending us a pull request, please ensure that:

* You are working against the latest source on the *main* branch.
* You check the existing open and recently merged pull requests to make sure someone else hasn't already addressed the problem.
* You open an issue to discuss any significant work - we would hate for your time to be wasted.


### Pull Down the Code

  1. If you do not already have one, create a GitHub account by following the prompts at [Join Github](https://github.com/join).
  2. Create a fork of this repository on GitHub. You should end up with a fork at `https://github.com/<username>/Braket.jl`.
    i. Follow the instructions at [Fork a Repo](https://help.github.com/en/articles/fork-a-repo) to fork a GitHub repository.
  3. Clone your fork of the repository: `git clone https://github.com/<username>/Braket.jl` where `<username>` is your github username.


### Run the Unit Tests

You can run the package tests using Julia's built-in unit testing sytem. To run the Braket unit tests:

`julia -e 'using Pkg; Pkg.test("Braket")'`

To run with coverage tracking:

`julia -e 'using Pkg; Pkg.test("Braket", coverage=true)'`

You do not need fresh AWS credentials to run the unit tests.

### Run the Integration Tests

Run the integration tests to make sure that the system as a whole still works.

  1. Follow the instructions at [Set Up the AWS Command Line Interface (AWS CLI)](https://docs.aws.amazon.com/polly/latest/dg/setup-aws-cli.html).
  2. Set the `AWS_PROFILE` information
    ```bash
    export AWS_PROFILE=Your_Profile_Name
    ```
  3. Run the following Julia commands and verify that integ tests pass:
    ```julia
    julia --project=<path_to_Braketjl> test/integ_tests/runtests.jl`
    julia --project=<path_to_Braketjl>/PyBraket test/integ_tests/runtests.jl`
    ```

### Make and Test Your Change

  1. Create a new git branch:
    ```shell
    git checkout -b my-fix-branch main
    ```
  2. Make your changes, **including unit tests** and, if appropriate, integration tests.
    i. Include unit tests when you contribute new features or make bug fixes, as they help to:
      a. Prove that your code works correctly.
      b. Guard against future breaking changes to lower the maintenance cost.
  3. Please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
  4. Run unit and integration tests for both `Braket.jl` and `PyBraket.jl`.
  5. If your changes include documentation changes, please see the [Documentation Guidelines](#documentation-guidelines).


### Commit Your Change

We use commit messages to update the project version number and generate changelog entries, so it's important for them to follow the right format. Valid commit messages include a prefix, separated from the rest of the message by a colon and a space. Here are a few examples:

```
feature: support new parameter for `xyz`
fix: fix whitespace errors
documentation: add documentation for `xyz`
```

Valid prefixes are listed in the table below.

| Prefix          | Use for...                                                                                     |
|----------------:|:-----------------------------------------------------------------------------------------------|
| `breaking`      | Incompatible API changes.                                                                      |
| `deprecation`   | Deprecating an existing API or feature, or removing something that was previously deprecated.  |
| `feature`       | Adding a new feature.                                                                          |
| `fix`           | Bug fixes.                                                                                     |
| `change`        | Any other code change.                                                                         |
| `documentation` | Documentation changes.                                                                         |

Some of the prefixes allow abbreviation ; `break`, `feat`, `depr`, and `doc` are all valid. If you omit a prefix, the commit will be treated as a `change`.

For the rest of the message, use imperative style and keep things concise but informative. See [How to Write a Git Commit Message](https://chris.beams.io/posts/git-commit/) for guidance.


### Send a Pull Request

GitHub provides additional documentation on [Creating a Pull Request](https://help.github.com/articles/creating-a-pull-request/).

Please remember to:
* Use commit messages (and PR titles) that follow the guidelines under [Commit Your Change](#commit-your-change).
* Send us a pull request, answering any default questions in the pull request interface.
* Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.


## Documentation Guidelines

We use [`Documenter.jl`](https://github.com/JuliaDocs/Documenter.jl) for most of our documentation.
For a quick primer on the syntax, see [the Documenter documentation](https://juliadocs.github.io/Documenter.jl/stable/).

Here are some general guidelines to follow when writing documentation:
* Use present tense.
  * 👍 "The device has this property..."
  * 👎 "The device will have this property."
* When referring to an AWS product, use its full name in the first invocation.
  (This applies only to prose; use what makes sense when it comes to writing code, etc.)
  * 👍 "Amazon S3"
  * 👎 "s3"
* Provide links to other package documentation pages, AWS documentation, etc. when helpful.
  Try to not duplicate documentation when you can reference it instead.
  * Use meaningful text in a link.
* Julia documentation style is to describe in the present tense what a function does, for example "Returns the device arn." or "Computes the requested observables given a list of shots."


### API References (docstrings)

The API references are generated from docstrings.
A docstring is the comment in the source code that describes a module, struct, function, or variable.

```julia
"""
    f()

Description of `f` here.
"""
function f()
    # function body
end
```

We use [Julia-style docstrings](https://docs.julialang.org/en/v1/manual/documentation/#Writing-Documentation).
There should be a docstring for every public module, struct, and function.
For functions, make sure your docstring covers all of the arguments, exceptions, and any other relevant information.
When possible, link to structs and functions, e.g. use "\[Circuit\]\(@ref\)" rather than just `Circuit`.

If a parameter of a function has a default value, please note what the default is.
If that default value is `nothing`, it can also be helpful to explain what happens when the parameter is `nothing`.
If `kwargs` is part of the function signature, link to the parent function so that the reader knows where to find the available parameters.


### Build and Test Documentation

To build the docs, follow the `Documenter.jl` [package guide](https://juliadocs.github.io/Documenter.jl/stable/man/guide/#Package-Guide).

## Find Contributions to Work On

Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels ((enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.

## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.

## Security Issue Notifications

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.


## Licensing

See the [LICENSE](LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.
