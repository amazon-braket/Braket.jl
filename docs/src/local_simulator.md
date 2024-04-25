# Local Simulators

Local simulators allow you to *classically* simulate your [`Circuit`](@ref) or `OpenQasmProgram`
on local hardware, rather than sending it to the cloud for on-demand execution. Local simulators
can run task *batches* in parallel using multithreading.

```@docs
LocalQuantumTask
LocalQuantumBatch
LocalSimulator
simulate
```
