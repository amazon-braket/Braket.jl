export Noise, Kraus, BitFlip, PhaseFlip, PauliChannel, AmplitudeDamping, PhaseDamping, Depolarizing, TwoQubitDephasing, TwoQubitDepolarizing, GeneralizedAmplitudeDamping, TwoQubitPauliChannel, MultiQubitPauliChannel
"""
    Noise <: QuantumOperator

Abstract type representing a quantum noise operation.
"""
abstract type Noise <: QuantumOperator end
StructTypes.StructType(::Type{Noise}) = StructTypes.AbstractType()
StructTypes.subtypes(::Type{Noise}) = (noise=Noise, kraus=Kraus, bit_flip=BitFlip, phase_flip=PhaseFlip, pauli_channel=PauliChannel, amplitude_damping=AmplitudeDamping, phase_damping=PhaseDamping, depolarizing=Depolarizing, two_qubit_dephasing=TwoQubitDephasing, two_qubit_depolarizing=TwoQubitDepolarizing, generalized_amplitude_damping=GeneralizedAmplitudeDamping, multi_qubit_pauli_channel=MultiQubitPauliChannel)

const ProbabilityType = Union{Float64, FreeParameter}

"""
    Kraus <: Noise

Kraus noise operation.
"""
struct Kraus <: Noise
    matrices::Vector{Matrix{ComplexF64}}
end
Kraus(mats::Vector{Vector{Vector{Vector{Float64}}}}) = Kraus(complex_matrix_from_ir.(mats))
Base.:(==)(k1::Kraus, k2::Kraus) = k1.matrices == k2.matrices
ir(g::Kraus, target::QubitSet, ::Val{:JAQCD}; kwargs...) = IR.Kraus(collect(target), [complex_matrix_to_ir(mat) for mat in g.matrices], "kraus")
function ir(g::Kraus, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    t   = format_qubits(collect(target), serialization_properties)
    ms  = join(format_matrix.(g.matrices), ", ")
    return "#pragma braket noise kraus($ms) $t"
end
qubit_count(g::Kraus) = convert(Int, log2(size(g.matrices[1], 1)))
chars(n::Kraus) = ntuple(i->"KR", qubit_count(n))

"""
    BitFlip <: Noise

BitFlip noise operation.
"""
struct BitFlip <: Noise
    probability::ProbabilityType
end
Parametrizable(g::BitFlip) = Parametrized()
n_targets(g::BitFlip) = Val(1)
n_targets(::Type{BitFlip}) = Val(1)
qubit_count(g::BitFlip) = 1
chars(n::BitFlip) = map(char->replace(string(char), "prob"=>string(n.probability)), ("BF(prob)",))
n_probabilities(::BitFlip)       = Val(1)
n_probabilities(::Type{BitFlip}) = Val(1)

"""
    PhaseFlip <: Noise

PhaseFlip noise operation.
"""
struct PhaseFlip <: Noise
    probability::ProbabilityType
end
Parametrizable(g::PhaseFlip) = Parametrized()
qubit_count(g::PhaseFlip) = 1
chars(n::PhaseFlip) = map(char->replace(string(char), "prob"=>string(n.probability)), ("PF(prob)",))
n_targets(g::PhaseFlip) = Val(1)
n_targets(::Type{PhaseFlip}) = Val(1)
n_probabilities(::PhaseFlip)       = Val(1)
n_probabilities(::Type{PhaseFlip}) = Val(1)

"""
    PauliChannel <: Noise

PauliChannel noise operation.
"""
struct PauliChannel <: Noise
    probX::ProbabilityType
    probY::ProbabilityType
    probZ::ProbabilityType
    PauliChannel(probX::TX, probY::TY, probZ::TZ) where {TX<:ProbabilityType, TY<:ProbabilityType, TZ<:ProbabilityType} = new(probX, probY, probZ)
end
n_targets(g::PauliChannel) = Val(1)
n_targets(::Type{PauliChannel}) = Val(1)
n_probabilities(::PauliChannel)       = Val(3)
n_probabilities(::Type{PauliChannel}) = Val(3)
Parametrizable(g::PauliChannel) = Parametrized()
qubit_count(g::PauliChannel) = 1
chars(n::PauliChannel) = map(char->replace(string(char), "prob"=>join([string(n.probX), string(n.probY), string(n.probX)], ", ")), ("PC(prob)",))

"""
    AmplitudeDamping <: Noise

AmplitudeDamping noise operation.
"""
struct AmplitudeDamping <: Noise
    gamma::ProbabilityType
end
n_targets(g::AmplitudeDamping) = Val(1)
n_targets(::Type{AmplitudeDamping}) = Val(1)
n_probabilities(::AmplitudeDamping)       = Val(1)
n_probabilities(::Type{AmplitudeDamping}) = Val(1)
Parametrizable(g::AmplitudeDamping) = Parametrized()
qubit_count(g::AmplitudeDamping) = 1
chars(n::AmplitudeDamping) = map(char->replace(string(char), "prob"=>string(n.gamma)), ("AD(prob)",))

"""
    PhaseDamping <: Noise

PhaseDamping noise operation.
"""
struct PhaseDamping <: Noise
    gamma::ProbabilityType
end
n_targets(g::PhaseDamping) = Val(1)
n_targets(::Type{PhaseDamping}) = Val(1)
n_probabilities(::PhaseDamping)       = Val(1)
n_probabilities(::Type{PhaseDamping}) = Val(1)
Parametrizable(g::PhaseDamping) = Parametrized()
qubit_count(g::PhaseDamping) = 1
chars(n::PhaseDamping) = map(char->replace(string(char), "prob"=>string(n.gamma)), ("PD(prob)",))

"""
    Depolarizing <: Noise

Depolarizing noise operation.
"""
struct Depolarizing <: Noise
    probability::ProbabilityType
end
n_targets(g::Depolarizing) = Val(1)
n_targets(::Type{Depolarizing}) = Val(1)
n_probabilities(::Depolarizing)       = Val(1)
n_probabilities(::Type{Depolarizing}) = Val(1)
Parametrizable(g::Depolarizing) = Parametrized()
qubit_count(g::Depolarizing) = 1
chars(n::Depolarizing) = map(char->replace(string(char), "prob"=>string(n.probability)), ("DEPO(prob)",))

"""
    TwoQubitDephasing <: Noise

TwoQubitDephasing noise operation.
"""
struct TwoQubitDephasing <: Noise
    probability::ProbabilityType
end
n_targets(g::TwoQubitDephasing) = Val(2)
n_targets(::Type{TwoQubitDephasing}) = Val(2)
n_probabilities(::TwoQubitDephasing)       = Val(1)
n_probabilities(::Type{TwoQubitDephasing}) = Val(1)
Parametrizable(g::TwoQubitDephasing) = Parametrized()
qubit_count(g::TwoQubitDephasing) = 2
chars(n::TwoQubitDephasing) = map(char->replace(string(char), "prob"=>string(n.probability)), ("DEPH(prob)", "DEPH(prob)"))

"""
    TwoQubitDepolarizing <: Noise

TwoQubitDepolarizing noise operation.
"""
struct TwoQubitDepolarizing <: Noise
    probability::ProbabilityType
end
n_targets(g::TwoQubitDepolarizing) = Val(2)
n_targets(::Type{TwoQubitDepolarizing}) = Val(2)
n_probabilities(::TwoQubitDepolarizing)       = Val(1)
n_probabilities(::Type{TwoQubitDepolarizing}) = Val(1)
Parametrizable(g::TwoQubitDepolarizing) = Parametrized()
qubit_count(g::TwoQubitDepolarizing) = 2
chars(n::TwoQubitDepolarizing) = map(char->replace(string(char), "prob"=>string(n.probability)), ("DEPO(prob)", "DEPO(prob)"))

"""
    GeneralizedAmplitudeDamping <: Noise

GeneralizedAmplitudeDamping noise operation.
"""
struct GeneralizedAmplitudeDamping <: Noise
    probability::ProbabilityType
    gamma::ProbabilityType
    GeneralizedAmplitudeDamping(probability::TP, gamma::TG) where {TP<:ProbabilityType, TG<:ProbabilityType} = new(probability, gamma) 
end
n_targets(g::GeneralizedAmplitudeDamping) = Val(1)
n_targets(::Type{GeneralizedAmplitudeDamping}) = Val(1)
n_probabilities(::GeneralizedAmplitudeDamping)       = Val(2)
n_probabilities(::Type{GeneralizedAmplitudeDamping}) = Val(2)
Parametrizable(g::GeneralizedAmplitudeDamping) = Parametrized()
qubit_count(g::GeneralizedAmplitudeDamping) = 1
chars(n::GeneralizedAmplitudeDamping) = map(char->replace(string(char), "prob"=>join([string(n.gamma), string(n.probability)], ", ")), ("GAD(prob)",))

"""
    MultiQubitPauliChannel{N} <: Noise

Pauli channel noise operation on `N` qubits.
"""
struct MultiQubitPauliChannel{N} <: Noise
    probabilities::Dict{String, Union{Float64, FreeParameter}}
end
"""
    TwoQubitPauliChannel <: Noise

Pauli channel noise operation on two qubits.
"""
TwoQubitPauliChannel = MultiQubitPauliChannel{2} 
qubit_count(g::MultiQubitPauliChannel{N}) where {N} = N
Parametrizable(g::MultiQubitPauliChannel) = Parametrized()
ir(g::MultiQubitPauliChannel{N}, target::QubitSet, ::Val{:JAQCD}; kwargs...) where {N} = IR.MultiQubitPauliChannel(g.probabilities, collect(target), "multi_qubit_pauli_channel")
function MultiQubitPauliChannel(probabilities::Dict{String, <:Union{Float64, FreeParameter}})
    N = length(first(keys(probabilities)))
    return MultiQubitPauliChannel{N}(probabilities)
end
Base.:(==)(c1::MultiQubitPauliChannel{N}, c2::MultiQubitPauliChannel{M}) where {N,M} = N == M && c1.probabilities == c2.probabilities
chars(n::TwoQubitPauliChannel) = ("PC2", "PC2")
n_controls(n::Noise) = Val(0)
targets_and_controls(n::N, target::QubitSet) where {N<:Noise} = targets_and_controls(n_controls(n), n_targets(n), target)
for (N, IRN, label) in zip((:BitFlip, :PhaseFlip, :PauliChannel, :AmplitudeDamping, :PhaseDamping, :Depolarizing, :TwoQubitDephasing, :TwoQubitDepolarizing, :GeneralizedAmplitudeDamping), (:(IR.BitFlip), :(IR.PhaseFlip), :(IR.PauliChannel), :(IR.AmplitudeDamping), :(IR.PhaseDamping), :(IR.Depolarizing), :(IR.TwoQubitDephasing), :(IR.TwoQubitDepolarizing), :(IR.GeneralizedAmplitudeDamping)), ("bit_flip", "phase_flip", "pauli_channel", "amplitude_damping", "phase_damping", "depolarizing", "two_qubit_dephasing", "two_qubit_depolarizing", "generalized_amplitude_damping"))
    @eval begin
        function ir(n::$N, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = targets_and_controls(n, target)
            ir_args = (getproperty(n, fn) for fn in fieldnames($N))
            return $IRN(ir_args..., t_c[2], $label)
        end
        function ir(n::$N, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t   = format_qubits(target, serialization_properties)
            ir_args = join([repr(getproperty(n, fn)) for fn in fieldnames($N)], ", ")
            return "#pragma braket noise " * $label * "($ir_args) $t"
        end
    end
end
Parametrizable(g::Noise) = NonParametrized()
parameters(g::Noise) = parameters(Parametrizable(g), g)
parameters(::Parametrized, g::N) where {N<:Noise} = filter(x->x isa FreeParameter, [getproperty(g, fn) for fn in fieldnames(N)])
parameters(::NonParametrized, g::Noise) = FreeParameter[]
bind_value!(n::N, params::Dict{Symbol, <:Number}) where {N<:Noise} = bind_value!(Parametrizable(n), n, params)
bind_value!(::NonParametrized, n::N, params::Dict{Symbol, <:Number}) where {N<:Noise} = n
ir(g::Noise, target::Int, args...) = ir(g, QubitSet(target), args...)

function bind_value!(::Parametrized, g::N, params::Dict{Symbol, Number}) where {N<:Noise}
    new_args = OrderedDict(zip(fieldnames(N), (getproperty(g, fn) for fn in fieldnames(N)))) 
    for fp in findall(v->v isa FreeParameter, new_args)
        new_args[fp] = get(params, getproperty(g, fp).name, new_args[fp])
    end
    return N(values(new_args)...)
end
function Base.Dict(n::N) where {N<:Noise}
    type_dict = convert(Dict, StructTypes.subtypes(Noise))
    rev_type_dict = Dict(zip(values(type_dict), string.(keys(type_dict))))
    field_dict = Dict(string(fn)=>getproperty(n, fn) for fn in fieldnames(N))
    return merge(Dict("type"=>rev_type_dict[N]), field_dict)
end
function Noise(d::Dict{String})
    noise_t = StructTypes.subtypes(Noise)[Symbol(d["type"])]
    return noise_t([d[string(fn)] for fn in fieldnames(noise_t)]...)
end
