# Gates 

The gates are used to represent various gate operations on qubits.
Gates should implement the following functions:

```julia
label
qubit_count
n_angles
angles
chars
ir_typ
ir_str
targets_and_controls
```

- `label` is used to generate the gate's representation in OpenQASM3.
- `chars` is used when pretty-printing the gate as part of a `Circuit`.
- `n_angles` is the number of angles present in the gate and `angles` is an accessor method for those angles -- gates without angles should return an empty tuple `()`.
- `ir_typ` is a mapping to the gate's sibling in the `IR` submodule.
- `ir_str` is the gate's full OpenQASM3 representation.
- `targets_and_controls` should accept the gate and a `QubitSet` of qubits to apply it to, and generate from this the list of control qubits and target qubits.  

New gates with angle parameters should be subtypes of `AngledGate{N}`, where `N` is the number of angle parameters. They should have one member, `angle::NTuple{N, Union{Float64, FreeParameter}}`.

```@docs
Gate
AngledGate
H
I
X
Y
Z
PhaseShift
Rx
Ry
Rz
V
Vi
T
Ti
S
Si
CNot
CV
CY
CZ
XX
XY
YY
ZZ
ECR
CPhaseShift
CPhaseShift00
CPhaseShift01
CPhaseShift10
Swap
PSwap
ISwap
CSwap
CCNot
Unitary
```
