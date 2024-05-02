using Dates, NamedTupleTools
import StructTypes

const GateFidelityType = Dict{String, Union{String, Float64}}
const OneQubitType     = Union{Float64, Vector{GateFidelityType}}
const TwoQubitType     = Dict{String, Union{Float64, Dict{String, Int}}}
const QubitType        = Dict{String, Union{OneQubitType, TwoQubitType}}


StructTypes.StructType(::Type{Dec128}) = StructTypes.CustomStruct()
StructTypes.lower(d::Dec128) = string(d)
StructTypes.lowertype(::Type{Dec128}) = String
StructTypes.constructfrom(::Type{Dec128}, x::Number) = Dec128(string(x))
StructTypes.constructfrom(s::StructTypes.CustomStruct, ::Type{Dec128}, x::String) = Dec128(x)
abstract type BraketSchemaBase end
StructTypes.StructType(::Type{BraketSchemaBase}) = StructTypes.AbstractType()
function bsh_f(raw_sym::Symbol)
    raw = String(raw_sym)
    v   = eval(Meta.parse(raw))
    bsh = v["name"] * "_v" * v["version"]
    return type_dict[bsh]
end
StructTypes.subtypes(::Type{BraketSchemaBase}) = StructTypes.SubTypeClosure(bsh_f)

StructTypes.subtypekey(::Type{BraketSchemaBase}) = :braketSchemaHeader

struct braketSchemaHeader
    name::String
    version::String
end
StructTypes.StructType(::Type{braketSchemaHeader}) = StructTypes.UnorderedStruct()

struct DwaveTiming
    qpuSamplingTime::Union{Nothing, Int}
    qpuAnnealTimePerSample::Union{Nothing, Int}
    qpuAccessTime::Union{Nothing, Int}
    qpuAccessOverheadTime::Union{Nothing, Int}
    qpuReadoutTimePerSample::Union{Nothing, Int}
    qpuProgrammingTime::Union{Nothing, Int}
    qpuDelayTimePerSample::Union{Nothing, Int}
    postProcessingOverheadTime::Union{Nothing, Int}
    totalPostProcessingTime::Union{Nothing, Int}
    totalRealTime::Union{Nothing, Int}
    runTimeChip::Union{Nothing, Int}
    annealTimePerRun::Union{Nothing, Int}
    readoutTimePerRun::Union{Nothing, Int}
end
StructTypes.StructType(::Type{DwaveTiming}) = StructTypes.UnorderedStruct()

@enum ProblemType qubo ising
ProblemTypeDict = Dict(string(inst)=>inst for inst in instances(ProblemType))
Base.:(==)(x::ProblemType, y::String) = string(x) == y
Base.:(==)(x::String, y::ProblemType) = string(y) == x
abstract type AbstractProgram <: BraketSchemaBase end
StructTypes.StructType(::Type{AbstractProgram}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{AbstractProgram}) = StructTypes.SubTypeClosure(bsh_f)
StructTypes.subtypekey(::Type{AbstractProgram}) = :braketSchemaHeader

struct NativeQuilMetadata
    finalRewiring::Vector{Int}
    gateDepth::Int
    gateVolume::Int
    multiQubitGateDepth::Int
    programDuration::Float64
    programFidelity::Float64
    qpuRuntimeEstimation::Float64
    topologicalSwaps::Int
end
StructTypes.StructType(::Type{NativeQuilMetadata}) = StructTypes.UnorderedStruct()

struct XanaduMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    compiledProgram::String
end
StructTypes.StructType(::Type{XanaduMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XanaduMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.xanadu_metadata", "1"))

struct IonQMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    sharpenedProbabilities::Union{Nothing, Dict{String, Float64}}
end
StructTypes.StructType(::Type{IonQMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{IonQMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.ionq_metadata", "1"))

struct OqcMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    compiledProgram::String
end
StructTypes.StructType(::Type{OqcMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OqcMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.oqc_metadata", "1"))

struct SimulatorMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    executionDuration::Int
end
StructTypes.StructType(::Type{SimulatorMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{SimulatorMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.simulator_metadata", "1"))

struct DwaveMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    activeVariables::Vector{Int}
    timing::DwaveTiming
end
StructTypes.StructType(::Type{DwaveMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.dwave_metadata", "1"))

struct RigettiMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    nativeQuilMetadata::Union{Nothing, NativeQuilMetadata}
    compiledProgram::String
end
StructTypes.StructType(::Type{RigettiMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{RigettiMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.rigetti_metadata", "1"))

struct QueraMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    numSuccessfulShots::Int
end
StructTypes.StructType(::Type{QueraMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{QueraMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.quera_metadata", "1"))

abstract type DeviceActionProperties <: BraketSchemaBase end
StructTypes.StructType(::Type{DeviceActionProperties}) = StructTypes.AbstractType()
function dap_f(raw_sym::Symbol)
    raw = String(raw_sym)
    occursin("jaqcd", raw) && return JaqcdDeviceActionProperties
    occursin("openqasm", raw) && return OpenQASMDeviceActionProperties
    occursin("blackbird", raw) && return BlackbirdDeviceActionProperties
    return GenericDeviceActionProperties
end
StructTypes.subtypes(::Type{DeviceActionProperties}) = StructTypes.SubTypeClosure(dap_f)
StructTypes.subtypekey(::Type{DeviceActionProperties}) = :actionType

struct TemplateWaveformArgument
    name::String
    value::Union{Nothing, Any}
    type::String
    optional::Bool
end
StructTypes.StructType(::Type{TemplateWaveformArgument}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{TemplateWaveformArgument}) = Dict{Symbol, Any}(:optional => false)

struct TemplateWaveform
    waveformId::String
    name::String
    arguments::Vector{TemplateWaveformArgument}
end
StructTypes.StructType(::Type{TemplateWaveform}) = StructTypes.UnorderedStruct()

struct ArbitraryWaveform
    waveformId::String
    amplitudes::Vector{Tuple{Float64, Float64}}
end
StructTypes.StructType(::Type{ArbitraryWaveform}) = StructTypes.UnorderedStruct()

module IR
import ..Braket: AbstractProgram, braketSchemaHeader, ProblemType, BraketSchemaBase
using DecFP, StructTypes

export Program, AHSProgram, AbstractIR, AbstractProgramResult, CompilerDirective, IRObservable

abstract type AbstractIR end
StructTypes.StructType(::Type{AbstractIR}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{AbstractIR})   = (z=Z, sample=Sample, cphaseshift01=CPhaseShift01, phase_damping=PhaseDamping, rz=Rz, generalized_amplitude_damping=GeneralizedAmplitudeDamping, xx=XX, zz=ZZ, phase_flip=PhaseFlip, vi=Vi, depolarizing=Depolarizing, variance=Variance, two_qubit_depolarizing=TwoQubitDepolarizing, densitymatrix=DensityMatrix, cphaseshift00=CPhaseShift00, ecr=ECR, ccnot=CCNot, unitary=Unitary, bit_flip=BitFlip, y=Y, swap=Swap, cz=CZ, cnot=CNot, adjoint_gradient=AdjointGradient, cswap=CSwap, ry=Ry, i=I, si=Si, amplitude_damping=AmplitudeDamping, statevector=StateVector, iswap=ISwap, h=H, xy=XY, yy=YY, t=T, ahsprogram=AHSProgram, two_qubit_dephasing=TwoQubitDephasing, x=X, ti=Ti, cv=CV, pauli_channel=PauliChannel, pswap=PSwap, expectation=Expectation, probability=Probability, phaseshift=PhaseShift, v=V, cphaseshift=CPhaseShift, s=S, rx=Rx, kraus=Kraus, amplitude=Amplitude, cphaseshift10=CPhaseShift10, multi_qubit_pauli_channel=MultiQubitPauliChannel, cy=CY, ms=MS, gpi=GPi, gpi2=GPi2, prx=PRx)

const IRObservable = Union{Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, String}
Base.convert(::Type{IRObservable}, v::Vector{String}) = convert(Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, v)
Base.convert(::Type{IRObservable}, s::String)         = s
Base.convert(::Type{IRObservable}, v::Vector{Vector{Vector{Vector{Float64}}}}) = convert(Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, v)
Base.:(==)(s::String, iro::IRObservable) = all(iro .== s)
Base.:(==)(iro::IRObservable, s::String) = all(iro .== s)

abstract type CompilerDirective <: AbstractIR end
StructTypes.StructType(::Type{CompilerDirective}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{CompilerDirective}) = (end_verbatim_box=EndVerbatimBox, start_verbatim_box=StartVerbatimBox)

abstract type AbstractProgramResult <: AbstractIR end
StructTypes.StructType(::Type{AbstractProgramResult}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{AbstractProgramResult}) = (amplitude=Amplitude, expectation=Expectation, probability=Probability, sample=Sample, statevector=StateVector, densitymatrix=DensityMatrix, variance=Variance, adjoint_gradient=AdjointGradient)

struct AtomArrangement <: AbstractIR
    sites::Vector{Vector{Dec128}}
    filling::Vector{Int}
end
StructTypes.StructType(::Type{AtomArrangement}) = StructTypes.UnorderedStruct()

struct TimeSeries <: AbstractIR
    values::Vector{Dec128}
    times::Vector{Dec128}
end
StructTypes.StructType(::Type{TimeSeries}) = StructTypes.UnorderedStruct()

struct PhysicalField <: AbstractIR
    time_series::TimeSeries
    pattern::Union{String, Vector{Dec128}}
end
StructTypes.StructType(::Type{PhysicalField}) = StructTypes.UnorderedStruct()

struct DrivingField <: AbstractIR
    amplitude::PhysicalField
    phase::PhysicalField
    detuning::PhysicalField
end
StructTypes.StructType(::Type{DrivingField}) = StructTypes.UnorderedStruct()

struct ShiftingField <: AbstractIR
    magnitude::PhysicalField
end
StructTypes.StructType(::Type{ShiftingField}) = StructTypes.UnorderedStruct()

struct Setup <: AbstractIR
    ahs_register::AtomArrangement
end
StructTypes.StructType(::Type{Setup}) = StructTypes.UnorderedStruct()

struct Hamiltonian <: AbstractIR
    drivingFields::Vector{DrivingField}
    shiftingFields::Vector{ShiftingField}
end
StructTypes.StructType(::Type{Hamiltonian}) = StructTypes.UnorderedStruct()

struct Z <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{Z}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Z}) = Dict{Symbol, Any}(:type => "z")

struct Si <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{Si}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Si}) = Dict{Symbol, Any}(:type => "si")

struct T <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{T}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{T}) = Dict{Symbol, Any}(:type => "t")

struct Program <: AbstractProgram
    braketSchemaHeader::braketSchemaHeader
    instructions::Vector{<:Any}
    results::Union{Nothing, Vector{AbstractProgramResult}}
    basis_rotation_instructions::Union{Nothing, Vector{<:Any}}
end
StructTypes.StructType(::Type{Program}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Program}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.ir.jaqcd.program", "1"))

struct AHSProgram <: AbstractProgram
    braketSchemaHeader::braketSchemaHeader
    setup::Setup
    hamiltonian::Hamiltonian
end
StructTypes.StructType(::Type{AHSProgram}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{AHSProgram}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.ir.ahs.program", "1"))

struct TwoQubitDepolarizing <: AbstractIR
    probability::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{TwoQubitDepolarizing}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{TwoQubitDepolarizing}) = Dict{Symbol, Any}(:type => "two_qubit_depolarizing")

struct CNot <: AbstractIR
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CNot}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CNot}) = Dict{Symbol, Any}(:type => "cnot")

struct Sample <: AbstractProgramResult
    observable::Union{Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, String}
    targets::Union{Nothing, Vector{Int}}
    type::String
end
StructTypes.StructType(::Type{Sample}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Sample}) = Dict{Symbol, Any}(:type => "sample")

struct Kraus <: AbstractIR
    targets::Vector{Int}
    matrices::Vector{Vector{Vector{Vector{Float64}}}}
    type::String
end
StructTypes.StructType(::Type{Kraus}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Kraus}) = Dict{Symbol, Any}(:type => "kraus")

struct CPhaseShift01 <: AbstractIR
    angle::Float64
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CPhaseShift01}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CPhaseShift01}) = Dict{Symbol, Any}(:type => "cphaseshift01")

struct DensityMatrix <: AbstractProgramResult
    targets::Union{Nothing, Vector{Int}}
    type::String
end
StructTypes.StructType(::Type{DensityMatrix}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DensityMatrix}) = Dict{Symbol, Any}(:type => "densitymatrix")

struct PSwap <: AbstractIR
    angle::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{PSwap}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PSwap}) = Dict{Symbol, Any}(:type => "pswap")

struct GPi <: AbstractIR
    angle::Float64
    target::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{GPi}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GPi}) = Dict{Symbol, Any}(:type => "gpi")

struct AmplitudeDamping <: AbstractIR
    gamma::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{AmplitudeDamping}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{AmplitudeDamping}) = Dict{Symbol, Any}(:type => "amplitude_damping")

struct TwoQubitDephasing <: AbstractIR
    probability::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{TwoQubitDephasing}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{TwoQubitDephasing}) = Dict{Symbol, Any}(:type => "two_qubit_dephasing")

struct Expectation <: AbstractProgramResult
    observable::Union{Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, String}
    targets::Union{Nothing, Vector{Int}}
    type::String
end
StructTypes.StructType(::Type{Expectation}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Expectation}) = Dict{Symbol, Any}(:type => "expectation")

struct GPi2 <: AbstractIR
    angle::Float64
    target::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{GPi2}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GPi2}) = Dict{Symbol, Any}(:type => "gpi2")

struct BitFlip <: AbstractIR
    probability::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{BitFlip}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{BitFlip}) = Dict{Symbol, Any}(:type => "bit_flip")

struct Amplitude <: AbstractProgramResult
    states::Vector{String}
    type::String
end
StructTypes.StructType(::Type{Amplitude}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Amplitude}) = Dict{Symbol, Any}(:type => "amplitude")

struct X <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{X}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{X}) = Dict{Symbol, Any}(:type => "x")

struct CPhaseShift10 <: AbstractIR
    angle::Float64
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CPhaseShift10}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CPhaseShift10}) = Dict{Symbol, Any}(:type => "cphaseshift10")

struct PhaseDamping <: AbstractIR
    gamma::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{PhaseDamping}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PhaseDamping}) = Dict{Symbol, Any}(:type => "phase_damping")

struct CPhaseShift00 <: AbstractIR
    angle::Float64
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CPhaseShift00}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CPhaseShift00}) = Dict{Symbol, Any}(:type => "cphaseshift00")

struct Rz <: AbstractIR
    angle::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{Rz}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Rz}) = Dict{Symbol, Any}(:type => "rz")

struct MultiQubitPauliChannel <: AbstractIR
    probabilities::Dict{String, Float64}
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{MultiQubitPauliChannel}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{MultiQubitPauliChannel}) = Dict{Symbol, Any}(:type => "multi_qubit_pauli_channel")

struct CV <: AbstractIR
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CV}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CV}) = Dict{Symbol, Any}(:type => "cv")

struct Y <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{Y}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Y}) = Dict{Symbol, Any}(:type => "y")

struct Ti <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{Ti}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Ti}) = Dict{Symbol, Any}(:type => "ti")

struct StartVerbatimBox <: CompilerDirective
    directive::String
    type::String
end
StructTypes.StructType(::Type{StartVerbatimBox}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{StartVerbatimBox}) = Dict{Symbol, Any}(:directive => "StartVerbatimBox", :type => "start_verbatim_box")

struct Probability <: AbstractProgramResult
    targets::Union{Nothing, Vector{Int}}
    type::String
end
StructTypes.StructType(::Type{Probability}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Probability}) = Dict{Symbol, Any}(:type => "probability")

struct GeneralizedAmplitudeDamping <: AbstractIR
    probability::Float64
    gamma::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{GeneralizedAmplitudeDamping}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GeneralizedAmplitudeDamping}) = Dict{Symbol, Any}(:type => "generalized_amplitude_damping")

struct MS <: AbstractIR
    angle1::Float64
    angle2::Float64
    angle3::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{MS}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{MS}) = Dict{Symbol, Any}(:type => "ms")

struct PRx <: AbstractIR
    angle1::Float64
    angle2::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{PRx}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PRx}) = Dict{Symbol, Any}(:type => "prx")


struct ECR <: AbstractIR
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{ECR}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{ECR}) = Dict{Symbol, Any}(:type => "ecr")

struct PhaseShift <: AbstractIR
    angle::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{PhaseShift}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PhaseShift}) = Dict{Symbol, Any}(:type => "phaseshift")

struct V <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{V}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{V}) = Dict{Symbol, Any}(:type => "v")

struct AdjointGradient <: AbstractProgramResult
    parameters::Union{Nothing, Vector{String}}
    observable::Union{Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, String}
    targets::Union{Nothing, Vector{Vector{Int}}}
    type::String
end
StructTypes.StructType(::Type{AdjointGradient}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{AdjointGradient}) = Dict{Symbol, Any}(:type => "adjoint_gradient")

struct XX <: AbstractIR
    angle::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{XX}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XX}) = Dict{Symbol, Any}(:type => "xx")

struct StateVector <: AbstractProgramResult
    type::String
end
StructTypes.StructType(::Type{StateVector}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{StateVector}) = Dict{Symbol, Any}(:type => "statevector")

struct ZZ <: AbstractIR
    angle::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{ZZ}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{ZZ}) = Dict{Symbol, Any}(:type => "zz")

struct Swap <: AbstractIR
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{Swap}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Swap}) = Dict{Symbol, Any}(:type => "swap")

struct ISwap <: AbstractIR
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{ISwap}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{ISwap}) = Dict{Symbol, Any}(:type => "iswap")

struct CSwap <: AbstractIR
    control::Int
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{CSwap}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CSwap}) = Dict{Symbol, Any}(:type => "cswap")

struct PhaseFlip <: AbstractIR
    probability::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{PhaseFlip}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PhaseFlip}) = Dict{Symbol, Any}(:type => "phase_flip")

struct Vi <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{Vi}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Vi}) = Dict{Symbol, Any}(:type => "vi")

struct H <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{H}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{H}) = Dict{Symbol, Any}(:type => "h")

struct CPhaseShift <: AbstractIR
    angle::Float64
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CPhaseShift}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CPhaseShift}) = Dict{Symbol, Any}(:type => "cphaseshift")

struct XY <: AbstractIR
    angle::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{XY}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XY}) = Dict{Symbol, Any}(:type => "xy")

struct CY <: AbstractIR
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CY}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CY}) = Dict{Symbol, Any}(:type => "cy")

struct Ry <: AbstractIR
    angle::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{Ry}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Ry}) = Dict{Symbol, Any}(:type => "ry")

struct CCNot <: AbstractIR
    controls::Vector{Int}
    target::Int
    type::String
end
StructTypes.StructType(::Type{CCNot}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CCNot}) = Dict{Symbol, Any}(:type => "ccnot")

struct PauliChannel <: AbstractIR
    probX::Float64
    probY::Float64
    probZ::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{PauliChannel}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PauliChannel}) = Dict{Symbol, Any}(:type => "pauli_channel")

struct Unitary <: AbstractIR
    targets::Vector{Int}
    matrix::Vector{Vector{Vector{Float64}}}
    type::String
end
StructTypes.StructType(::Type{Unitary}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Unitary}) = Dict{Symbol, Any}(:type => "unitary")

struct I <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{I}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{I}) = Dict{Symbol, Any}(:type => "i")

struct S <: AbstractIR
    target::Int
    type::String
end
StructTypes.StructType(::Type{S}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{S}) = Dict{Symbol, Any}(:type => "s")

struct Depolarizing <: AbstractIR
    probability::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{Depolarizing}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Depolarizing}) = Dict{Symbol, Any}(:type => "depolarizing")

struct CZ <: AbstractIR
    control::Int
    target::Int
    type::String
end
StructTypes.StructType(::Type{CZ}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{CZ}) = Dict{Symbol, Any}(:type => "cz")

struct EndVerbatimBox <: CompilerDirective
    directive::String
    type::String
end
StructTypes.StructType(::Type{EndVerbatimBox}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{EndVerbatimBox}) = Dict{Symbol, Any}(:directive => "EndVerbatimBox", :type => "end_verbatim_box")

struct YY <: AbstractIR
    angle::Float64
    targets::Vector{Int}
    type::String
end
StructTypes.StructType(::Type{YY}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{YY}) = Dict{Symbol, Any}(:type => "yy")

struct Rx <: AbstractIR
    angle::Float64
    target::Int
    type::String
end
StructTypes.StructType(::Type{Rx}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Rx}) = Dict{Symbol, Any}(:type => "rx")

struct Variance <: AbstractProgramResult
    observable::Union{Vector{Union{String, Vector{Vector{Vector{Float64}}}}}, String}
    targets::Union{Nothing, Vector{Int}}
    type::String
end
StructTypes.StructType(::Type{Variance}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Variance}) = Dict{Symbol, Any}(:type => "variance")



abstract type Control end
struct SingleControl <: Control end
for g in [:CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :CNot, :CV, :CY, :CZ, :CSwap]
    @eval begin
        Control(::Type{$g}) = SingleControl()
    end
end
struct DoubleControl <: Control end
for g in [:CCNot]
    @eval begin
        Control(::Type{$g}) = DoubleControl()
    end
end
struct NoControl <: Control end
Control(::Type{G}) where {G<:AbstractIR} = NoControl()
abstract type Target end
struct DoubleTarget <: Target end
for g in [:Swap, :CSwap, :ISwap, :PSwap, :XY, :ECR, :XX, :YY, :ZZ, :TwoQubitDepolarizing, :TwoQubitDephasing, :MS]
    @eval begin
        Target(::Type{$g}) = DoubleTarget()
    end
end
struct SingleTarget <: Target end
for g in [:H, :I, :X, :Y, :Z, :Rx, :Ry, :Rz, :S, :T, :Si, :Ti, :PhaseShift, :CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :CNot, :CCNot, :CV, :CY, :CZ, :V, :Vi, :BitFlip, :PhaseFlip, :PauliChannel, :Depolarizing, :AmplitudeDamping, :GeneralizedAmplitudeDamping, :PhaseDamping, :GPi, :GPi2, :PRx]
    @eval begin
        Target(::Type{$g}) = SingleTarget()
    end
end
struct OptionalNestedMultiTarget <: Target end
for g in [:AdjointGradient]
    @eval begin
        Target(::Type{$g}) = OptionalNestedMultiTarget()
    end
end
struct OptionalMultiTarget <: Target end
for g in [:Expectation, :Sample, :Variance, :DensityMatrix, :Probability]
    @eval begin
        Target(::Type{$g}) = OptionalMultiTarget()
    end
end
struct MultiTarget <: Target end
for g in [:Unitary, :MultiQubitPauliChannel, :Kraus]
    @eval begin
        Target(::Type{$g}) = MultiTarget()
    end
end
abstract type Angle end
struct Angled <: Angle end
for g in [:Rx, :Ry, :Rz, :PhaseShift, :CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :PSwap, :XY, :XX, :YY, :ZZ, :GPi, :GPi2]
    @eval begin
        Angle(::Type{$g}) = Angled()
    end
end
struct DoubleAngled <: Angle end
for g in [:PRx]
    @eval begin
        Angle(::Type{$g}) = DoubleAngled()
    end
end
struct TripleAngled <: Angle end
for g in [:MS]
    @eval begin
        Angle(::Type{$g}) = TripleAngled()
    end
end
struct NonAngled <: Angle end
Angle(::Type{G}) where {G<:AbstractIR} = NonAngled()
abstract type ProbabilityCount end
struct TripleProbability <: ProbabilityCount end
for g in [:PauliChannel]
    @eval begin
        ProbabilityCount(::Type{$g}) = TripleProbability()
    end
end
struct MultiProbability <: ProbabilityCount end
for g in [:MultiQubitPauliChannel, :Kraus]
    @eval begin
        ProbabilityCount(::Type{$g}) = MultiProbability()
    end
end
struct DoubleProbability <: ProbabilityCount end
for g in [:GeneralizedAmplitudeDamping]
    @eval begin
        ProbabilityCount(::Type{$g}) = DoubleProbability()
    end
end
struct SingleProbability <: ProbabilityCount end
for g in [:BitFlip, :PhaseFlip, :Depolarizing, :TwoQubitDephasing, :TwoQubitDepolarizing, :AmplitudeDamping]
    @eval begin
        ProbabilityCount(::Type{$g}) = SingleProbability()
    end
end
ControlAndTarget(T) = (Control(T), Target(T))
_generate_control_and_target(::NoControl, ::SingleTarget, q) = q[1]
_generate_control_and_target(::NoControl, ::DoubleTarget, q) = ([q[1], q[2]],)
_generate_control_and_target(::NoControl, ::MultiTarget,  q) = (q,)
_generate_control_and_target(::SingleControl, ::SingleTarget, q) = (q[1], q[2])
_generate_control_and_target(::SingleControl, ::DoubleTarget, q) = (q[1], [q[2], q[3]])
_generate_control_and_target(::DoubleControl, ::SingleTarget, q) = ([q[1], q[2]], q[3])


Base.:(==)(o1::T, o2::T) where {T<:AbstractIR} = all(getproperty(o1, fn) == getproperty(o2, fn) for fn in fieldnames(T))

end # module

using .IR
@enum _CopyMode always if_needed never
_CopyModeDict = Dict(string(inst)=>inst for inst in instances(_CopyMode))
Base.:(==)(x::_CopyMode, y::String) = string(x) == y
Base.:(==)(x::String, y::_CopyMode) = string(y) == x
@enum Extra allow ignore forbid
ExtraDict = Dict(string(inst)=>inst for inst in instances(Extra))
Base.:(==)(x::Extra, y::String) = string(x) == y
Base.:(==)(x::String, y::Extra) = string(y) == x
@enum SafeUUID safe unsafe unknown
SafeUUIDDict = Dict(string(inst)=>inst for inst in instances(SafeUUID))
Base.:(==)(x::SafeUUID, y::String) = string(x) == y
Base.:(==)(x::String, y::SafeUUID) = string(y) == x
@enum PaymentCardBrand amex mastercard visa other
PaymentCardBrandDict = Dict(string(inst)=>inst for inst in instances(PaymentCardBrand))
Base.:(==)(x::PaymentCardBrand, y::String) = string(x) == y
Base.:(==)(x::String, y::PaymentCardBrand) = string(y) == x
@enum Protocol json pickle
ProtocolDict = Dict(string(inst)=>inst for inst in instances(Protocol))
Base.:(==)(x::Protocol, y::String) = string(x) == y
Base.:(==)(x::String, y::Protocol) = string(y) == x
@enum DeviceActionType openqasm jaqcd blackbird annealing ahs
DeviceActionTypeDict = Dict(string(inst)=>inst for inst in instances(DeviceActionType))
Base.:(==)(x::DeviceActionType, y::String) = string(x) == y
Base.:(==)(x::String, y::DeviceActionType) = string(y) == x
@enum ExecutionDay everyday weekdays weekends monday tuesday wednesday thursday friday saturday sunday
ExecutionDayDict = Dict(string(inst)=>inst for inst in instances(ExecutionDay))
Base.:(==)(x::ExecutionDay, y::String) = string(x) == y
Base.:(==)(x::String, y::ExecutionDay) = string(y) == x
@enum ExponentType int float
ExponentTypeDict = Dict(string(inst)=>inst for inst in instances(ExponentType))
Base.:(==)(x::ExponentType, y::String) = string(x) == y
Base.:(==)(x::String, y::ExponentType) = string(y) == x
@enum QubitDirection control target
QubitDirectionDict = Dict(string(inst)=>inst for inst in instances(QubitDirection))
Base.:(==)(x::QubitDirection, y::String) = string(x) == y
Base.:(==)(x::String, y::QubitDirection) = string(y) == x
@enum PostProcessingType sampling optimization
PostProcessingTypeDict = Dict(string(inst)=>inst for inst in instances(PostProcessingType))
Base.:(==)(x::PostProcessingType, y::String) = string(x) == y
Base.:(==)(x::String, y::PostProcessingType) = string(y) == x
@enum ResultFormat raw histogram
ResultFormatDict = Dict(string(inst)=>inst for inst in instances(ResultFormat))
Base.:(==)(x::ResultFormat, y::String) = string(x) == y
Base.:(==)(x::String, y::ResultFormat) = string(y) == x
@enum Direction tx rx
DirectionDict = Dict(string(inst)=>inst for inst in instances(Direction))
Base.:(==)(x::Direction, y::String) = string(x) == y
Base.:(==)(x::String, y::Direction) = string(y) == x
@enum PersistedJobDataFormat plaintext pickled_v4
PersistedJobDataFormatDict = Dict(string(inst)=>inst for inst in instances(PersistedJobDataFormat))
Base.:(==)(x::PersistedJobDataFormat, y::String) = string(x) == y
Base.:(==)(x::String, y::PersistedJobDataFormat) = string(y) == x
struct ResultType
    name::String
    observables::Union{Nothing, Vector{String}}
    minShots::Union{Nothing, Int}
    maxShots::Union{Nothing, Int}
end
StructTypes.StructType(::Type{ResultType}) = StructTypes.UnorderedStruct()

struct DeviceExecutionWindow
    executionDay::Union{ExecutionDay, String}
    windowStartHour::Dates.Time
    windowEndHour::Dates.Time
end
StructTypes.StructType(::Type{DeviceExecutionWindow}) = StructTypes.UnorderedStruct()

struct DeviceCost
    price::Float64
    unit::String
end
StructTypes.StructType(::Type{DeviceCost}) = StructTypes.UnorderedStruct()

struct DeviceDocumentation
    imageUrl::Union{Nothing, String}
    summary::Union{Nothing, String}
    externalDocumentationUrl::Union{Nothing, String}
end
StructTypes.StructType(::Type{DeviceDocumentation}) = StructTypes.UnorderedStruct()

struct DeviceConnectivity
    fullyConnected::Bool
    connectivityGraph::Dict
end
StructTypes.StructType(::Type{DeviceConnectivity}) = StructTypes.UnorderedStruct()

struct Control
    name::String
    max_qubits::Union{Nothing, Int}
end
StructTypes.StructType(::Type{Control}) = StructTypes.UnorderedStruct()

struct NegControl
    name::String
    max_qubits::Union{Nothing, Int}
end
StructTypes.StructType(::Type{NegControl}) = StructTypes.UnorderedStruct()

struct Power
    name::String
    exponent_types::Vector{ExponentType}
end
StructTypes.StructType(::Type{Power}) = StructTypes.UnorderedStruct()

struct Inverse
    name::String
end
StructTypes.StructType(::Type{Inverse}) = StructTypes.UnorderedStruct()

struct FidelityType
    name::String
    description::Union{Nothing, String}
end
StructTypes.StructType(::Type{FidelityType}) = StructTypes.UnorderedStruct()

struct GateFidelity2Q
    direction::Union{Nothing, Dict{QubitDirection, Int}}
    gateName::String
    fidelity::Float64
    standardError::Union{Nothing, Float64}
    fidelityType::FidelityType
end
StructTypes.StructType(::Type{GateFidelity2Q}) = StructTypes.UnorderedStruct()

struct TwoQubitProperties
    twoQubitGateFidelity::Vector{GateFidelity2Q}
end
StructTypes.StructType(::Type{TwoQubitProperties}) = StructTypes.UnorderedStruct()

struct Fidelity1Q
    fidelityType::FidelityType
    fidelity::Float64
    standardError::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{Fidelity1Q}) = StructTypes.UnorderedStruct()

struct CoherenceTime
    value::Float64
    standardError::Union{Nothing, Float64}
    unit::String
end
StructTypes.StructType(::Type{CoherenceTime}) = StructTypes.UnorderedStruct()

struct OneQubitProperties
    T1::CoherenceTime
    T2::CoherenceTime
    oneQubitFidelity::Vector{Fidelity1Q}
end
StructTypes.StructType(::Type{OneQubitProperties}) = StructTypes.UnorderedStruct()

abstract type ErrorMitigationScheme end
StructTypes.StructType(::Type{ErrorMitigationScheme}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{ErrorMitigationScheme}) = (debias=Debias)

struct ErrorMitigationProperties
    minimumShots::Int
end
StructTypes.StructType(::Type{ErrorMitigationProperties}) = StructTypes.UnorderedStruct()

struct Frame
    frameId::String
    portId::String
    frequency::Float64
    centerFrequency::Union{Nothing, Float64}
    phase::Float64
    associatedGate::Union{Nothing, String}
    qubitMappings::Union{Nothing, Vector{Int}}
    qhpSpecificProperties::Union{Nothing, Dict{String, Any}}
end
StructTypes.StructType(::Type{Frame}) = StructTypes.UnorderedStruct()

struct Port
    portId::String
    direction::Direction
    portType::String
    dt::Float64
    qubitMappings::Union{Nothing, Vector{Int}}
    centerFrequencies::Union{Nothing, Set{Float64}}
    qhpSpecificProperties::Union{Nothing, Dict{String, Any}}
end
StructTypes.StructType(::Type{Port}) = StructTypes.UnorderedStruct()

struct PulseFunctionArgument
    name::String
    value::Union{Nothing, Any}
    type::String
    optional::Bool
end
StructTypes.StructType(::Type{PulseFunctionArgument}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PulseFunctionArgument}) = Dict{Symbol, Any}(:optional => false)

struct PulseFunction
    name::String
    arguments::Vector{PulseFunctionArgument}
end
StructTypes.StructType(::Type{PulseFunction}) = StructTypes.UnorderedStruct()
PulseFunction(name::Nothing, arguments::Vector{PulseFunctionArgument}) = PulseFunction("", arguments)

struct PulseInstructionArgument
    name::String
    value::Union{Nothing, Any}
    type::String
    optional::Bool
end
StructTypes.StructType(::Type{PulseInstructionArgument}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PulseInstructionArgument}) = Dict{Symbol, Any}(:optional => false)

struct PulseInstruction
    name::String
    arguments::Union{Nothing, Vector{PulseInstructionArgument}}
end
StructTypes.StructType(::Type{PulseInstruction}) = StructTypes.UnorderedStruct()

struct NativeGate
    name::String
    qubits::Vector{String}
    arguments::Vector{String}
    calibrations::Vector{Union{PulseInstruction, PulseFunction}}
end
StructTypes.StructType(::Type{NativeGate}) = StructTypes.UnorderedStruct()

struct Area
    width::Dec128
    height::Dec128
end
StructTypes.StructType(::Type{Area}) = StructTypes.UnorderedStruct()

struct Geometry
    spacingRadialMin::Dec128
    spacingVerticalMin::Dec128
    positionResolution::Dec128
    numberSitesMax::Int
end
StructTypes.StructType(::Type{Geometry}) = StructTypes.UnorderedStruct()

struct Lattice
    area::Area
    geometry::Geometry
end
StructTypes.StructType(::Type{Lattice}) = StructTypes.UnorderedStruct()

struct RydbergGlobal
    rabiFrequencyRange::Tuple{Dec128, Dec128}
    rabiFrequencyResolution::Dec128
    rabiFrequencySlewRateMax::Dec128
    detuningRange::Tuple{Dec128, Dec128}
    detuningResolution::Dec128
    detuningSlewRateMax::Dec128
    phaseRange::Tuple{Dec128, Dec128}
    phaseResolution::Dec128
    timeResolution::Dec128
    timeDeltaMin::Dec128
    timeMin::Dec128
    timeMax::Dec128
end
StructTypes.StructType(::Type{RydbergGlobal}) = StructTypes.UnorderedStruct()

struct Rydberg
    c6Coefficient::Dec128
    rydbergGlobal::RydbergGlobal
end
StructTypes.StructType(::Type{Rydberg}) = StructTypes.UnorderedStruct()

struct PerformanceLattice
    positionErrorAbs::Dec128
end
StructTypes.StructType(::Type{PerformanceLattice}) = StructTypes.UnorderedStruct()

struct PerformanceRydbergGlobal
    rabiFrequencyErrorRel::Dec128
end
StructTypes.StructType(::Type{PerformanceRydbergGlobal}) = StructTypes.UnorderedStruct()

struct PerformanceRydberg
    rydbergGlobal::PerformanceRydbergGlobal
end
StructTypes.StructType(::Type{PerformanceRydberg}) = StructTypes.UnorderedStruct()

struct Performance
    lattice::PerformanceLattice
    rydberg::PerformanceRydberg
end
StructTypes.StructType(::Type{Performance}) = StructTypes.UnorderedStruct()

struct AdditionalMetadata
    action::AbstractProgram
    dwaveMetadata::Union{Nothing, DwaveMetadata}
    ionqMetadata::Union{Nothing, IonQMetadata}
    rigettiMetadata::Union{Nothing, RigettiMetadata}
    oqcMetadata::Union{Nothing, OqcMetadata}
    xanaduMetadata::Union{Nothing, XanaduMetadata}
    queraMetadata::Union{Nothing, QueraMetadata}
    simulatorMetadata::Union{Nothing, SimulatorMetadata}
end
StructTypes.StructType(::Type{AdditionalMetadata}) = StructTypes.UnorderedStruct()

struct AnalogHamiltonianSimulationShotMetadata
    shotStatus::String
end
StructTypes.StructType(::Type{AnalogHamiltonianSimulationShotMetadata}) = StructTypes.UnorderedStruct()

struct AnalogHamiltonianSimulationShotResult
    preSequence::Union{Nothing, Vector{Int}}
    postSequence::Union{Nothing, Vector{Int}}
end
StructTypes.StructType(::Type{AnalogHamiltonianSimulationShotResult}) = StructTypes.UnorderedStruct()

struct AnalogHamiltonianSimulationShotMeasurement
    shotMetadata::AnalogHamiltonianSimulationShotMetadata
    shotResult::AnalogHamiltonianSimulationShotResult
end
StructTypes.StructType(::Type{AnalogHamiltonianSimulationShotMeasurement}) = StructTypes.UnorderedStruct()

struct ResultTypeValue
    type::AbstractProgramResult
    value::Union{Vector, Float64, Dict}
end
StructTypes.StructType(::Type{ResultTypeValue}) = StructTypes.UnorderedStruct()

struct BlackbirdDeviceActionProperties <: DeviceActionProperties
    version::Vector{String}
    actionType::String
    supportedOperations::Union{Nothing, Vector{String}}
    supportedResultTypes::Vector{ResultType}
end
StructTypes.StructType(::Type{BlackbirdDeviceActionProperties}) = StructTypes.UnorderedStruct()

struct JaqcdDeviceActionProperties <: DeviceActionProperties
    version::Vector{String}
    actionType::String
    supportedOperations::Union{Nothing, Vector{String}}
    supportedResultTypes::Union{Nothing, Vector{ResultType}}
    disabledQubitRewiringSupported::Union{Nothing, Bool}
end
StructTypes.StructType(::Type{JaqcdDeviceActionProperties}) = StructTypes.UnorderedStruct()

struct OpenQASMDeviceActionProperties <: DeviceActionProperties
    version::Vector{String}
    actionType::String
    supportedOperations::Union{Nothing, Vector{String}}
    supportedModifiers::Vector{Union{Control, NegControl, Power, Inverse}}
    supportedPragmas::Vector{String}
    forbiddenPragmas::Vector{String}
    maximumQubitArrays::Union{Nothing, Int}
    maximumClassicalArrays::Union{Nothing, Int}
    forbiddenArrayOperations::Vector{String}
    requiresAllQubitsMeasurement::Bool
    supportPhysicalQubits::Bool
    requiresContiguousQubitIndices::Bool
    supportsPartialVerbatimBox::Bool
    supportsUnassignedMeasurements::Bool
    disabledQubitRewiringSupported::Bool
    supportedResultTypes::Union{Nothing, Vector{ResultType}}
end
StructTypes.StructType(::Type{OpenQASMDeviceActionProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OpenQASMDeviceActionProperties}) = Dict{Symbol, Any}(:supportedModifiers => Any[], :supportsUnassignedMeasurements => true, :requiresAllQubitsMeasurement => false, :supportedPragmas => Any[], :supportPhysicalQubits => false, :supportsPartialVerbatimBox => true, :forbiddenPragmas => Any[], :requiresContiguousQubitIndices => false, :disabledQubitRewiringSupported => false, :forbiddenArrayOperations => Any[])

struct ContinuousVariableQpuParadigmProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    modes::Dict{String, Float64}
    layout::String
    compiler::Vector{String}
    supportedLanguages::Vector{String}
    compilerDefault::String
    nativeGateSet::Vector{String}
    gateParameters::Dict{String, Vector{Vector{Float64}}}
    target::String
end
StructTypes.StructType(::Type{ContinuousVariableQpuParadigmProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{ContinuousVariableQpuParadigmProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.continuous_variable_qpu_paradigm_properties", "1"))

struct DeviceServiceProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    executionWindows::Vector{DeviceExecutionWindow}
    shotsRange::Tuple{Int, Int}
    deviceCost::Union{Nothing, DeviceCost}
    deviceDocumentation::Union{Nothing, DeviceDocumentation}
    deviceLocation::Union{Nothing, String}
    updatedAt::Union{Nothing, String}
    getTaskPollIntervalMillis::Union{Nothing, Int}
end
StructTypes.StructType(::Type{DeviceServiceProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DeviceServiceProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.device_service_properties", "1"))

struct GateModelParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    qubitCount::Int
    disableQubitRewiring::Bool
end
StructTypes.StructType(::Type{GateModelParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.gate_model_parameters", "1"), :disableQubitRewiring => false)

struct GateModelQpuParadigmProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    connectivity::DeviceConnectivity
    qubitCount::Int
    nativeGateSet::Vector{String}
end
StructTypes.StructType(::Type{GateModelQpuParadigmProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelQpuParadigmProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.gate_model_qpu_paradigm_properties", "1"))

struct OpenQasmProgram <: AbstractProgram
    braketSchemaHeader::braketSchemaHeader
    source::String
    inputs::Union{Nothing, Dict{String, Union{String, Float64, Int, Vector{Union{String, Float64, Int}}}}}
end
StructTypes.StructType(::Type{OpenQasmProgram}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OpenQasmProgram}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.ir.openqasm.program", "1"))

struct StandardizedGateModelQpuDeviceProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    oneQubitProperties::Dict{String, OneQubitProperties}
    twoQubitProperties::Dict{String, TwoQubitProperties}
end
StructTypes.StructType(::Type{StandardizedGateModelQpuDeviceProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{StandardizedGateModelQpuDeviceProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.standardized_gate_model_qpu_device_properties", "1"))

struct DwaveProviderLevelParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    annealingOffsets::Union{Nothing, Vector{Float64}}
    annealingSchedule::Union{Nothing, Vector{Vector{Float64}}}
    annealingDuration::Union{Nothing, Int}
    autoScale::Union{Nothing, Bool}
    beta::Union{Nothing, Float64}
    chains::Union{Nothing, Vector{Vector{Int}}}
    compensateFluxDrift::Union{Nothing, Bool}
    fluxBiases::Union{Nothing, Vector{Float64}}
    initialState::Union{Nothing, Vector{Int}}
    maxResults::Union{Nothing, Int}
    postprocessingType::Union{Nothing, Union{PostProcessingType, String, Nothing}}
    programmingThermalizationDuration::Union{Nothing, Int}
    readoutThermalizationDuration::Union{Nothing, Int}
    reduceIntersampleCorrelation::Union{Nothing, Bool}
    reinitializeState::Union{Nothing, Bool}
    resultFormat::Union{Nothing, ResultFormat}
    spinReversalTransformCount::Union{Nothing, Int}
end
StructTypes.StructType(::Type{DwaveProviderLevelParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveProviderLevelParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_provider_level_parameters", "1"))

struct Dwave2000QDeviceLevelParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    annealingOffsets::Union{Nothing, Vector{Float64}}
    annealingSchedule::Union{Nothing, Vector{Vector{Float64}}}
    annealingDuration::Union{Nothing, Float64}
    autoScale::Union{Nothing, Bool}
    beta::Union{Nothing, Float64}
    chains::Union{Nothing, Vector{Vector{Int}}}
    compensateFluxDrift::Union{Nothing, Bool}
    fluxBiases::Union{Nothing, Vector{Float64}}
    initialState::Union{Nothing, Vector{Int}}
    maxResults::Union{Nothing, Int}
    postprocessingType::Union{Nothing, Union{PostProcessingType, String, Nothing}}
    programmingThermalizationDuration::Union{Nothing, Int}
    readoutThermalizationDuration::Union{Nothing, Int}
    reduceIntersampleCorrelation::Union{Nothing, Bool}
    reinitializeState::Union{Nothing, Bool}
    resultFormat::Union{Nothing, ResultFormat}
    spinReversalTransformCount::Union{Nothing, Int}
end
StructTypes.StructType(::Type{Dwave2000QDeviceLevelParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Dwave2000QDeviceLevelParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_2000Q_device_level_parameters", "1"))

struct Dwave2000QDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    deviceLevelParameters::Dwave2000QDeviceLevelParameters
end
StructTypes.StructType(::Type{Dwave2000QDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Dwave2000QDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_2000Q_device_parameters", "1"))

struct DwaveAdvantageDeviceLevelParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    annealingOffsets::Union{Nothing, Vector{Float64}}
    annealingSchedule::Union{Nothing, Vector{Vector{Float64}}}
    annealingDuration::Union{Nothing, Float64}
    autoScale::Union{Nothing, Bool}
    compensateFluxDrift::Union{Nothing, Bool}
    fluxBiases::Union{Nothing, Vector{Float64}}
    initialState::Union{Nothing, Vector{Int}}
    maxResults::Union{Nothing, Int}
    programmingThermalizationDuration::Union{Nothing, Int}
    readoutThermalizationDuration::Union{Nothing, Int}
    reduceIntersampleCorrelation::Union{Nothing, Bool}
    reinitializeState::Union{Nothing, Bool}
    resultFormat::Union{Nothing, ResultFormat}
    spinReversalTransformCount::Union{Nothing, Int}
end
StructTypes.StructType(::Type{DwaveAdvantageDeviceLevelParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveAdvantageDeviceLevelParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_advantage_device_level_parameters", "1"))

struct DwaveAdvantageDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    deviceLevelParameters::DwaveAdvantageDeviceLevelParameters
end
StructTypes.StructType(::Type{DwaveAdvantageDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveAdvantageDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_advantage_device_parameters", "1"))

struct DwaveProviderProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    annealingOffsetStep::Float64
    annealingOffsetStepPhi0::Float64
    annealingOffsetRanges::Vector{Vector{Float64}}
    annealingDurationRange::Vector{Float64}
    couplers::Vector{Vector{Int}}
    defaultAnnealingDuration::Int
    defaultProgrammingThermalizationDuration::Int
    defaultReadoutThermalizationDuration::Int
    extendedJRange::Vector{Float64}
    hGainScheduleRange::Vector{Float64}
    hRange::Vector{Float64}
    jRange::Vector{Float64}
    maximumAnnealingSchedulePoints::Int
    maximumHGainSchedulePoints::Int
    perQubitCouplingRange::Vector{Float64}
    programmingThermalizationDurationRange::Vector{Int}
    qubits::Vector{Int}
    qubitCount::Int
    quotaConversionRate::Float64
    readoutThermalizationDurationRange::Vector{Int}
    taskRunDurationRange::Vector{Int}
    topology::Dict
end
StructTypes.StructType(::Type{DwaveProviderProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveProviderProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_provider_properties", "1"))

struct DwaveDeviceCapabilities <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, DeviceActionProperties}
    deviceParameters::Dict
    provider::DwaveProviderProperties
end
StructTypes.StructType(::Type{DwaveDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_device_capabilities", "1"))

struct DwaveDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    providerLevelParameters::Union{Nothing, DwaveProviderLevelParameters}
    deviceLevelParameters::Union{Nothing, Union{DwaveAdvantageDeviceLevelParameters, Dwave2000QDeviceLevelParameters, Nothing}}
end
StructTypes.StructType(::Type{DwaveDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{DwaveDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.dwave.dwave_device_parameters", "1"))

struct IonqProviderProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    fidelity::Dict{String, Dict{String, Float64}}
    timing::Dict{String, Float64}
    errorMitigation::Union{Nothing, Dict{ErrorMitigationScheme, ErrorMitigationProperties}}
end
StructTypes.StructType(::Type{IonqProviderProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{IonqProviderProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.ionq.ionq_provider_properties", "1"))

struct IonqDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, Union{OpenQASMDeviceActionProperties, JaqcdDeviceActionProperties}}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::GateModelQpuParadigmProperties
    provider::Union{Nothing, IonqProviderProperties}
end
StructTypes.StructType(::Type{IonqDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{IonqDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.ionq.ionq_device_capabilities", "1"))

struct IonqDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    paradigmParameters::GateModelParameters
    errorMitigation::Union{Nothing, Vector{ErrorMitigationScheme}}
end
StructTypes.StructType(::Type{IonqDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{IonqDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.ionq.ionq_device_parameters", "1"))

struct OqcProviderProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    properties::Dict{String, Dict{String, QubitType}}
end
StructTypes.StructType(::Type{OqcProviderProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OqcProviderProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.oqc.oqc_provider_properties", "1"))

struct PulseDeviceActionProperties <: DeviceActionProperties
    braketSchemaHeader::braketSchemaHeader
    supportedQhpTemplateWaveforms::Dict{String, PulseFunction}
    ports::Dict{String, Port}
    supportedFunctions::Dict{String, PulseFunction}
    frames::Union{Nothing, Dict{String, Frame}}
    supportsLocalPulseElements::Bool
    supportsDynamicFrames::Bool
    supportsNonNativeGatesWithPulses::Bool
    validationParameters::Union{Nothing, Dict{String, Float64}}
    nativeGateCalibrationsRef::Union{Nothing, String}
end
StructTypes.StructType(::Type{PulseDeviceActionProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PulseDeviceActionProperties}) = Dict{Symbol, Any}(:supportsNonNativeGatesWithPulses => false, :braketSchemaHeader => braketSchemaHeader("braket.device_schema.pulse.pulse_device_action_properties", "1"), :supportsDynamicFrames => true, :supportsLocalPulseElements => true)

struct OqcDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, Union{OpenQASMDeviceActionProperties, JaqcdDeviceActionProperties}}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::GateModelQpuParadigmProperties
    provider::Union{Nothing, OqcProviderProperties}
    standardized::Union{Nothing, StandardizedGateModelQpuDeviceProperties}
    pulse::Union{Nothing, PulseDeviceActionProperties}
end
StructTypes.StructType(::Type{OqcDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OqcDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.oqc.oqc_device_capabilities", "1"))

struct OqcDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    paradigmParameters::GateModelParameters
end
StructTypes.StructType(::Type{OqcDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{OqcDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.oqc.oqc_device_parameters", "1"))

struct NativeGateCalibrations <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    gates::Dict{String, Dict{String, Vector{NativeGate}}}
    waveforms::Dict{String, Union{TemplateWaveform, ArbitraryWaveform}}
end
StructTypes.StructType(::Type{NativeGateCalibrations}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{NativeGateCalibrations}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.pulse.native_gate_calibrations", "1"))

struct QueraAhsParadigmProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    qubitCount::Int
    lattice::Lattice
    rydberg::Rydberg
    performance::Performance
end
StructTypes.StructType(::Type{QueraAhsParadigmProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{QueraAhsParadigmProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.quera.quera_ahs_paradigm_properties", "1"))

struct QueraDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, DeviceActionProperties}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::QueraAhsParadigmProperties
end
StructTypes.StructType(::Type{QueraDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{QueraDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.quera.quera_device_capabilities", "1"))

struct RigettiProviderProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    specs::Dict{String, Dict{String, Dict{String, Float64}}}
end
StructTypes.StructType(::Type{RigettiProviderProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{RigettiProviderProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.rigetti.rigetti_provider_properties", "1"))

struct RigettiDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, Union{OpenQASMDeviceActionProperties, JaqcdDeviceActionProperties}}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::GateModelQpuParadigmProperties
    provider::Union{Nothing, RigettiProviderProperties}
    standardized::Union{Nothing, StandardizedGateModelQpuDeviceProperties}
    pulse::Union{Nothing, PulseDeviceActionProperties}
end
StructTypes.StructType(::Type{RigettiDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{RigettiDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.rigetti.rigetti_device_capabilities", "1"))

struct RigettiDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    paradigmParameters::GateModelParameters
end
StructTypes.StructType(::Type{RigettiDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{RigettiDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.rigetti.rigetti_device_parameters", "1"))

struct GateModelSimulatorParadigmProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    qubitCount::Int
end
StructTypes.StructType(::Type{GateModelSimulatorParadigmProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelSimulatorParadigmProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_paradigm_properties", "1"))

struct GateModelSimulatorDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, Union{OpenQASMDeviceActionProperties, JaqcdDeviceActionProperties}}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::GateModelSimulatorParadigmProperties
end
StructTypes.StructType(::Type{GateModelSimulatorDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelSimulatorDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_device_capabilities", "1"))

struct GateModelSimulatorDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    paradigmParameters::GateModelParameters
end
StructTypes.StructType(::Type{GateModelSimulatorDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelSimulatorDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_device_parameters", "1"))

struct XanaduProviderProperties <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    loopPhases::Vector{Float64}
    schmidtNumber::Float64
    commonEfficiency::Float64
    squeezingParametersMean::Dict{String, Float64}
    relativeChannelEfficiencies::Vector{Float64}
    loopEfficiencies::Vector{Float64}
end
StructTypes.StructType(::Type{XanaduProviderProperties}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XanaduProviderProperties}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.xanadu.xanadu_provider_properties", "1"))

struct XanaduDeviceCapabilities <: BraketSchemaBase
    service::DeviceServiceProperties
    action::Dict{Union{DeviceActionType, String}, BlackbirdDeviceActionProperties}
    deviceParameters::Dict
    braketSchemaHeader::braketSchemaHeader
    paradigm::ContinuousVariableQpuParadigmProperties
    provider::Union{Nothing, XanaduProviderProperties}
end
StructTypes.StructType(::Type{XanaduDeviceCapabilities}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XanaduDeviceCapabilities}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.xanadu.xanadu_device_capabilities", "1"))

struct XanaduDeviceParameters <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
end
StructTypes.StructType(::Type{XanaduDeviceParameters}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{XanaduDeviceParameters}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.device_schema.xanadu.xanadu_device_parameters", "1"))

struct Problem <: AbstractProgram
    braketSchemaHeader::braketSchemaHeader
    type::Union{ProblemType, String}
    linear::Dict{Int, Float64}
    quadratic::Dict{String, Float64}
end
StructTypes.StructType(::Type{Problem}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Problem}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.ir.annealing.problem", "1"))

struct BlackbirdProgram <: AbstractProgram
    braketSchemaHeader::braketSchemaHeader
    source::String
end
StructTypes.StructType(::Type{BlackbirdProgram}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{BlackbirdProgram}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.ir.blackbird.program", "1"))

struct PersistedJobData <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    dataDictionary::Dict{String, Any}
    dataFormat::Union{PersistedJobDataFormat, String}
end
StructTypes.StructType(::Type{PersistedJobData}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PersistedJobData}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.jobs_data.persisted_job_data", "1"))

struct TaskMetadata <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    id::String
    shots::Int
    deviceId::String
    deviceParameters::Union{Nothing, Union{DwaveDeviceParameters, DwaveAdvantageDeviceParameters, Dwave2000QDeviceParameters, RigettiDeviceParameters, IonqDeviceParameters, OqcDeviceParameters, GateModelSimulatorDeviceParameters, XanaduDeviceParameters, Nothing}}
    createdAt::Union{Nothing, String}
    endedAt::Union{Nothing, String}
    status::Union{Nothing, String}
    failureReason::Union{Nothing, String}
end
StructTypes.StructType(::Type{TaskMetadata}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{TaskMetadata}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.task_metadata", "1"))

struct AnalogHamiltonianSimulationTaskResult <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    taskMetadata::TaskMetadata
    measurements::Union{Nothing, Vector{AnalogHamiltonianSimulationShotMeasurement}}
    additionalMetadata::Union{Nothing, AdditionalMetadata}
end
StructTypes.StructType(::Type{AnalogHamiltonianSimulationTaskResult}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{AnalogHamiltonianSimulationTaskResult}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.analog_hamiltonian_simulation_task_result", "1"))

struct AnnealingTaskResult <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    solutions::Union{Nothing, Vector{Vector{Int}}}
    solutionCounts::Union{Nothing, Vector{Int}}
    values::Union{Nothing, Vector{Float64}}
    variableCount::Union{Nothing, Int}
    taskMetadata::TaskMetadata
    additionalMetadata::AdditionalMetadata
end
StructTypes.StructType(::Type{AnnealingTaskResult}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{AnnealingTaskResult}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.annealing_task_result", "1"))

struct GateModelTaskResult <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    measurements::Union{Nothing, Vector{Vector{Int}}}
    measurementProbabilities::Union{Nothing, Dict{String, Float64}}
    resultTypes::Union{Nothing, Vector{ResultTypeValue}}
    measuredQubits::Union{Nothing, Vector{Int}}
    taskMetadata::TaskMetadata
    additionalMetadata::AdditionalMetadata
end
StructTypes.StructType(::Type{GateModelTaskResult}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{GateModelTaskResult}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.gate_model_task_result", "1"))

struct PhotonicModelTaskResult <: BraketSchemaBase
    braketSchemaHeader::braketSchemaHeader
    measurements::Union{Nothing, Vector{Vector{Vector{Int}}}}
    taskMetadata::TaskMetadata
    additionalMetadata::AdditionalMetadata
end
StructTypes.StructType(::Type{PhotonicModelTaskResult}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{PhotonicModelTaskResult}) = Dict{Symbol, Any}(:braketSchemaHeader => braketSchemaHeader("braket.task_result.photonic_model_task_result", "1"))

struct Debias <: ErrorMitigationScheme
    type::String
end
StructTypes.StructType(::Type{Debias}) = StructTypes.UnorderedStruct()
StructTypes.defaults(::Type{Debias}) = Dict{Symbol, Any}(:type => "braket.device_schema.error_mitigation.debias.Debias")

struct GenericDeviceActionProperties <: DeviceActionProperties
    version::Vector{String}
    actionType::Union{DeviceActionType, String}
end
StructTypes.StructType(::Type{GenericDeviceActionProperties}) = StructTypes.UnorderedStruct()

const type_dict   = Dict{String, DataType}("braket.device_schema.gate_model_qpu_paradigm_properties_v1"=>GateModelQpuParadigmProperties, "braket.device_schema.oqc.oqc_device_capabilities_v1"=>OqcDeviceCapabilities, "braket.device_schema.dwave.dwave_advantage_device_level_parameters_v1"=>DwaveAdvantageDeviceLevelParameters, "braket.device_schema.ionq.ionq_device_capabilities_v1"=>IonqDeviceCapabilities, "braket.device_schema.ionq.ionq_device_parameters_v1"=>IonqDeviceParameters, "braket.device_schema.quera.quera_device_capabilities_v1"=>QueraDeviceCapabilities, "braket.device_schema.standardized_gate_model_qpu_device_properties_v1"=>StandardizedGateModelQpuDeviceProperties, "braket.device_schema.xanadu.xanadu_device_capabilities_v1"=>XanaduDeviceCapabilities, "braket.device_schema.dwave.dwave_device_parameters_v1"=>DwaveDeviceParameters, "braket.task_result.dwave_metadata_v1"=>DwaveMetadata, "braket.device_schema.dwave.dwave_2000Q_device_level_parameters_v1"=>Dwave2000QDeviceLevelParameters, "braket.task_result.quera_metadata_v1"=>QueraMetadata, "braket.device_schema.oqc.oqc_provider_properties_v1"=>OqcProviderProperties, "braket.device_schema.device_service_properties_v1"=>DeviceServiceProperties, "braket.device_schema.xanadu.xanadu_device_parameters_v1"=>XanaduDeviceParameters, "braket.ir.blackbird.program_v1"=>BlackbirdProgram, "braket.device_schema.dwave.dwave_provider_properties_v1"=>DwaveProviderProperties, "braket.device_schema.rigetti.rigetti_device_capabilities_v1"=>RigettiDeviceCapabilities, "braket.task_result.annealing_task_result_v1"=>AnnealingTaskResult, "braket.device_schema.dwave.dwave_provider_level_parameters_v1"=>DwaveProviderLevelParameters, "braket.device_schema.pulse.pulse_device_action_properties_v1"=>PulseDeviceActionProperties, "braket.device_schema.ionq.ionq_provider_properties_v1"=>IonqProviderProperties, "braket.task_result.photonic_model_task_result_v1"=>PhotonicModelTaskResult, "braket.device_schema.continuous_variable_qpu_paradigm_properties_v1"=>ContinuousVariableQpuParadigmProperties, "braket.device_schema.xanadu.xanadu_provider_properties_v1"=>XanaduProviderProperties, "braket.device_schema.pulse.native_gate_calibrations_v1"=>NativeGateCalibrations, "braket.device_schema.dwave.dwave_advantage_device_parameters_v1"=>DwaveAdvantageDeviceParameters, "braket.device_schema.rigetti.rigetti_device_parameters_v1"=>RigettiDeviceParameters, "braket.ir.ahs.program_v1"=>AHSProgram, "braket.ir.jaqcd.program_v1"=>Program, "braket.task_result.task_metadata_v1"=>TaskMetadata, "braket.task_result.analog_hamiltonian_simulation_task_result_v1"=>AnalogHamiltonianSimulationTaskResult, "braket.device_schema.simulators.gate_model_simulator_paradigm_properties_v1"=>GateModelSimulatorParadigmProperties, "braket.task_result.gate_model_task_result_v1"=>GateModelTaskResult, "braket.task_result.ionq_metadata_v1"=>IonQMetadata, "braket.device_schema.rigetti.rigetti_provider_properties_v1"=>RigettiProviderProperties, "braket.device_schema.oqc.oqc_device_parameters_v1"=>OqcDeviceParameters, "braket.device_schema.simulators.gate_model_simulator_device_capabilities_v1"=>GateModelSimulatorDeviceCapabilities, "braket.task_result.xanadu_metadata_v1"=>XanaduMetadata, "braket.device_schema.gate_model_parameters_v1"=>GateModelParameters, "braket.device_schema.simulators.gate_model_simulator_device_parameters_v1"=>GateModelSimulatorDeviceParameters, "braket.task_result.oqc_metadata_v1"=>OqcMetadata, "braket.device_schema.dwave.dwave_device_capabilities_v1"=>DwaveDeviceCapabilities, "braket.device_schema.quera.quera_ahs_paradigm_properties_v1"=>QueraAhsParadigmProperties, "braket.jobs_data.persisted_job_data_v1"=>PersistedJobData, "braket.task_result.rigetti_metadata_v1"=>RigettiMetadata, "braket.task_result.simulator_metadata_v1"=>SimulatorMetadata, "braket.ir.annealing.problem_v1"=>Problem, "braket.device_schema.dwave.dwave_2000Q_device_parameters_v1"=>Dwave2000QDeviceParameters, "braket.ir.openqasm.program_v1"=>OpenQasmProgram)
const header_dict = Dict{DataType, braketSchemaHeader}(GateModelQpuParadigmProperties=>braketSchemaHeader("braket.device_schema.gate_model_qpu_paradigm_properties", "1"), OqcDeviceCapabilities=>braketSchemaHeader("braket.device_schema.oqc.oqc_device_capabilities", "1"), DwaveAdvantageDeviceLevelParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_advantage_device_level_parameters", "1"), IonqDeviceCapabilities=>braketSchemaHeader("braket.device_schema.ionq.ionq_device_capabilities", "1"), IonqDeviceParameters=>braketSchemaHeader("braket.device_schema.ionq.ionq_device_parameters", "1"), QueraDeviceCapabilities=>braketSchemaHeader("braket.device_schema.quera.quera_device_capabilities", "1"), StandardizedGateModelQpuDeviceProperties=>braketSchemaHeader("braket.device_schema.standardized_gate_model_qpu_device_properties", "1"), XanaduDeviceCapabilities=>braketSchemaHeader("braket.device_schema.xanadu.xanadu_device_capabilities", "1"), DwaveDeviceParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_device_parameters", "1"), DwaveMetadata=>braketSchemaHeader("braket.task_result.dwave_metadata", "1"), Dwave2000QDeviceLevelParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_2000Q_device_level_parameters", "1"), QueraMetadata=>braketSchemaHeader("braket.task_result.quera_metadata", "1"), OqcProviderProperties=>braketSchemaHeader("braket.device_schema.oqc.oqc_provider_properties", "1"), DeviceServiceProperties=>braketSchemaHeader("braket.device_schema.device_service_properties", "1"), XanaduDeviceParameters=>braketSchemaHeader("braket.device_schema.xanadu.xanadu_device_parameters", "1"), BlackbirdProgram=>braketSchemaHeader("braket.ir.blackbird.program", "1"), DwaveProviderProperties=>braketSchemaHeader("braket.device_schema.dwave.dwave_provider_properties", "1"), RigettiDeviceCapabilities=>braketSchemaHeader("braket.device_schema.rigetti.rigetti_device_capabilities", "1"), AnnealingTaskResult=>braketSchemaHeader("braket.task_result.annealing_task_result", "1"), DwaveProviderLevelParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_provider_level_parameters", "1"), PulseDeviceActionProperties=>braketSchemaHeader("braket.device_schema.pulse.pulse_device_action_properties", "1"), IonqProviderProperties=>braketSchemaHeader("braket.device_schema.ionq.ionq_provider_properties", "1"), PhotonicModelTaskResult=>braketSchemaHeader("braket.task_result.photonic_model_task_result", "1"), ContinuousVariableQpuParadigmProperties=>braketSchemaHeader("braket.device_schema.continuous_variable_qpu_paradigm_properties", "1"), XanaduProviderProperties=>braketSchemaHeader("braket.device_schema.xanadu.xanadu_provider_properties", "1"), NativeGateCalibrations=>braketSchemaHeader("braket.device_schema.pulse.native_gate_calibrations", "1"), DwaveAdvantageDeviceParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_advantage_device_parameters", "1"), RigettiDeviceParameters=>braketSchemaHeader("braket.device_schema.rigetti.rigetti_device_parameters", "1"), AHSProgram=>braketSchemaHeader("braket.ir.ahs.program", "1"), Program=>braketSchemaHeader("braket.ir.jaqcd.program", "1"), TaskMetadata=>braketSchemaHeader("braket.task_result.task_metadata", "1"), AnalogHamiltonianSimulationTaskResult=>braketSchemaHeader("braket.task_result.analog_hamiltonian_simulation_task_result", "1"), GateModelSimulatorParadigmProperties=>braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_paradigm_properties", "1"), GateModelTaskResult=>braketSchemaHeader("braket.task_result.gate_model_task_result", "1"), IonQMetadata=>braketSchemaHeader("braket.task_result.ionq_metadata", "1"), RigettiProviderProperties=>braketSchemaHeader("braket.device_schema.rigetti.rigetti_provider_properties", "1"), OqcDeviceParameters=>braketSchemaHeader("braket.device_schema.oqc.oqc_device_parameters", "1"), GateModelSimulatorDeviceCapabilities=>braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_device_capabilities", "1"), XanaduMetadata=>braketSchemaHeader("braket.task_result.xanadu_metadata", "1"), GateModelParameters=>braketSchemaHeader("braket.device_schema.gate_model_parameters", "1"), GateModelSimulatorDeviceParameters=>braketSchemaHeader("braket.device_schema.simulators.gate_model_simulator_device_parameters", "1"), OqcMetadata=>braketSchemaHeader("braket.task_result.oqc_metadata", "1"), DwaveDeviceCapabilities=>braketSchemaHeader("braket.device_schema.dwave.dwave_device_capabilities", "1"), QueraAhsParadigmProperties=>braketSchemaHeader("braket.device_schema.quera.quera_ahs_paradigm_properties", "1"), PersistedJobData=>braketSchemaHeader("braket.jobs_data.persisted_job_data", "1"), RigettiMetadata=>braketSchemaHeader("braket.task_result.rigetti_metadata", "1"), SimulatorMetadata=>braketSchemaHeader("braket.task_result.simulator_metadata", "1"), Problem=>braketSchemaHeader("braket.ir.annealing.problem", "1"), Dwave2000QDeviceParameters=>braketSchemaHeader("braket.device_schema.dwave.dwave_2000Q_device_parameters", "1"), OpenQasmProgram=>braketSchemaHeader("braket.ir.openqasm.program", "1"))


lookup_type(header::braketSchemaHeader) = type_dict[header.name * "_v" * header.version]

function parse_raw_schema(x::String)
    obj = copy(JSON3.read(x))
    !haskey(obj, :braketSchemaHeader) && throw(ArgumentError("invalid schema!"))
    bSH = StructTypes.constructfrom(braketSchemaHeader, obj[:braketSchemaHeader])
    typ = lookup_type(bSH)
    return StructTypes.constructfrom(typ, obj)
end

function StructTypes.constructfrom(::Type{DeviceActionProperties}, obj)
    sub_ts = StructTypes.subtypes(DeviceActionProperties)
    T = haskey(obj, :actionType) ? sub_ts[Symbol(obj[:actionType])] : GenericDeviceActionProperties
    return StructTypes.constructfrom(T, obj)
end
function StructTypes.constructfrom(::Type{AbstractProgram}, obj)
    header = obj[:braketSchemaHeader]
    occursin("braket.ir.jaqcd", header[:name]) && return StructTypes.constructfrom(Program, obj)
    occursin("braket.ir.blackbird", header[:name]) && return StructTypes.constructfrom(BlackbirdProgram, obj)
    occursin("braket.ir.ahs", header[:name]) && return StructTypes.constructfrom(AHSProgram, obj)
    occursin("braket.ir.openqasm", header[:name]) && return StructTypes.constructfrom(OpenQasmProgram, obj)
    occursin("braket.ir.annealing", header[:name]) && return StructTypes.constructfrom(Problem, obj)

    throw(ErrorException("invalid program specification!"))
end
Base.:(==)(o1::T, o2::T) where {T<:BraketSchemaBase} = all(Base.getproperty(o1, fn) == Base.getproperty(o2, fn) for fn in fieldnames(T))
for T in (TaskMetadata, AdditionalMetadata)
    Base.:(==)(o1::T, o2::T) = all(Base.getproperty(o1, fn) == Base.getproperty(o2, fn) for fn in fieldnames(T))
end

function StructTypes.constructfrom(::Type{ErrorMitigationScheme}, x::Symbol)
    occursin("debias", string(x)) && return Debias("braket.device_schema.error_mitigation.debias.Debias")
end
