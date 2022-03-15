# Tasks

"Tasks" are units of work that run on AWS managed devices, such as managed simulators and QPUs. See the Braket documentation about [how tasks work](https://docs.aws.amazon.com/braket/latest/developerguide/braket-how-it-works.html) and [submitting tasks](https://docs.aws.amazon.com/braket/latest/developerguide/braket-submit-tasks.html) for more information.

```@docs
AwsQuantumTask
AwsQuantumTask(::String, ::Union{Braket.AbstractProgram, Circuit, AnalogHamiltonianSimulation})
AwsQuantumTaskBatch
AwsQuantumTaskBatch(::String, ::Vector{<:Union{Braket.AbstractProgram, Circuit}})
results(::AwsQuantumTaskBatch)
```
