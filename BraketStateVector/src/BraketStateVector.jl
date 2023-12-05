module BraketStateVector

using Braket, Braket.Observables, LinearAlgebra, StaticArrays, StatsBase

import Braket: Instruction, X, Y, Z, I, PhaseShift, CNot, CY, CZ, XX, XY, YY, ZZ, CPhaseShift, CCNot, Swap, Rz, Ry, Rx, Ti, T, Vi, V, H

export StateVector, StateVectorSimulator, DensityMatrixSimulator, evolve!

const StateVector{T}   = Vector{T}
const DensityMatrix{T} = Matrix{T}
const AbstractStateVector{T} = AbstractVector{T}

abstract type AbstractSimulator end

include("gate_kernels.jl")
include("noise_kernels.jl")
include("observables.jl")
include("result_types.jl")
include("sv_simulator.jl")
include("dm_simulator.jl")

end # module BraketStateVector
