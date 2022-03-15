export Noise, Kraus, BitFlip, PhaseFlip, PauliChannel, AmplitudeDamping, PhaseDamping, Depolarizing, TwoQubitDephasing, TwoQubitDepolarizing, GeneralizedAmplitudeDamping, TwoQubitPauliChannel, MultiQubitPauliChannel
"""
    Noise <: QuantumOperator

Abstract type representing a quantum noise operation.
"""
abstract type Noise <: QuantumOperator end

StructTypes.StructType(::Type{Noise}) = StructTypes.AbstractType()
 
StructTypes.subtypes(::Type{Noise}) = (noise=Noise, kraus=Kraus, bit_flip=BitFlip, phase_flip=PhaseFlip, pauli_channel=PauliChannel, amplitude_damping=AmplitudeDamping, phase_damping=PhaseDamping, depolarizing=Depolarizing, two_qubit_dephasing=TwoQubitDephasing, two_qubit_depolarizing=TwoQubitDepolarizing, generalized_amplitude_damping=GeneralizedAmplitudeDamping, multi_qubit_pauli_channel=MultiQubitPauliChannel)
"""
    Kraus <: Noise

Kraus noise operation.
"""
struct Kraus <: Noise
    matrices::Vector{Matrix{ComplexF64}}
end

Kraus(mats::Vector{Vector{Vector{Vector{Float64}}}}) = Kraus(complex_matrix_from_ir.(mats))
Base.:(==)(k1::Kraus, k2::Kraus) = k1.matrices == k2.matrices
function ir(g::Kraus, target::QubitSet, ::Val{:JAQCD}; kwargs...)
    mats = complex_matrix_to_ir.(g.matrices)
    t_c = collect(target[1:convert(Int, log2(size(g.matrices[1], 1)))])
    return IR.Kraus(t_c, mats, "kraus")
end
function ir(g::Kraus, target::QubitSet, ::Val{:OpenQASM}; serialization_properties::SerializationProperties=OpenQASMSerializationProperties())
    t_c = target[1:convert(Int, log2(size(g.matrices[1], 1)))]
    t   = format_qubits(t_c, serialization_properties)
    ms  = join(format_matrix.(g.matrices), ", ")
    return "#pragma braket noise kraus($ms) $t"
end
qubit_count(g::Kraus) = convert(Int, log2(size(g.matrices[1], 1)))


"""
    BitFlip <: Noise

BitFlip noise operation.
"""
struct BitFlip <: Noise
    probability::Union{Float64, FreeParameter}
end

Parametrizable(g::BitFlip) = Parametrized()
qubit_count(g::BitFlip) = 1


"""
    PhaseFlip <: Noise

PhaseFlip noise operation.
"""
struct PhaseFlip <: Noise
    probability::Union{Float64, FreeParameter}
end

Parametrizable(g::PhaseFlip) = Parametrized()
qubit_count(g::PhaseFlip) = 1


"""
    PauliChannel <: Noise

PauliChannel noise operation.
"""
struct PauliChannel <: Noise
    probX::Union{Float64, FreeParameter}
    probY::Union{Float64, FreeParameter}
    probZ::Union{Float64, FreeParameter}
end

Parametrizable(g::PauliChannel) = Parametrized()
qubit_count(g::PauliChannel) = 1


"""
    AmplitudeDamping <: Noise

AmplitudeDamping noise operation.
"""
struct AmplitudeDamping <: Noise
    gamma::Union{Float64, FreeParameter}
end

Parametrizable(g::AmplitudeDamping) = Parametrized()
qubit_count(g::AmplitudeDamping) = 1


"""
    PhaseDamping <: Noise

PhaseDamping noise operation.
"""
struct PhaseDamping <: Noise
    gamma::Union{Float64, FreeParameter}
end

Parametrizable(g::PhaseDamping) = Parametrized()
qubit_count(g::PhaseDamping) = 1


"""
    Depolarizing <: Noise

Depolarizing noise operation.
"""
struct Depolarizing <: Noise
    probability::Union{Float64, FreeParameter}
end

Parametrizable(g::Depolarizing) = Parametrized()
qubit_count(g::Depolarizing) = 1


"""
    TwoQubitDephasing <: Noise

TwoQubitDephasing noise operation.
"""
struct TwoQubitDephasing <: Noise
    probability::Union{Float64, FreeParameter}
end

Parametrizable(g::TwoQubitDephasing) = Parametrized()
qubit_count(g::TwoQubitDephasing) = 2


"""
    TwoQubitDepolarizing <: Noise

TwoQubitDepolarizing noise operation.
"""
struct TwoQubitDepolarizing <: Noise
    probability::Union{Float64, FreeParameter}
end

Parametrizable(g::TwoQubitDepolarizing) = Parametrized()
qubit_count(g::TwoQubitDepolarizing) = 2


"""
    GeneralizedAmplitudeDamping <: Noise

GeneralizedAmplitudeDamping noise operation.
"""
struct GeneralizedAmplitudeDamping <: Noise
    probability::Union{Float64, FreeParameter}
    gamma::Union{Float64, FreeParameter}
end

Parametrizable(g::GeneralizedAmplitudeDamping) = Parametrized()
qubit_count(g::GeneralizedAmplitudeDamping) = 1


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
function ir(g::MultiQubitPauliChannel{N}, target::QubitSet, ::Val{:JAQCD}; kwargs...) where {N}
    t_c = collect(target[1:N])
    return IR.MultiQubitPauliChannel(g.probabilities, t_c, "multi_qubit_pauli_channel")
end
function MultiQubitPauliChannel(probabilities::Dict{String, <:Union{Float64, FreeParameter}})
    N = length(first(keys(probabilities)))
    return MultiQubitPauliChannel{N}(probabilities)
end
Base.:(==)(c1::MultiQubitPauliChannel{N}, c2::MultiQubitPauliChannel{M}) where {N,M} = N == M && c1.probabilities == c2.probabilities

for (N, IRN, label) in zip((:BitFlip, :PhaseFlip, :PauliChannel, :AmplitudeDamping, :PhaseDamping, :Depolarizing, :TwoQubitDephasing, :TwoQubitDepolarizing, :GeneralizedAmplitudeDamping), (:(IR.BitFlip), :(IR.PhaseFlip), :(IR.PauliChannel), :(IR.AmplitudeDamping), :(IR.PhaseDamping), :(IR.Depolarizing), :(IR.TwoQubitDephasing), :(IR.TwoQubitDepolarizing), :(IR.GeneralizedAmplitudeDamping)), ("bit_flip", "phase_flip", "pauli_channel", "amplitude_damping", "phase_damping", "depolarizing", "two_qubit_dephasing", "two_qubit_depolarizing", "generalized_amplitude_damping"))
    @eval begin
        function ir(n::$N, target::QubitSet, ::Val{:JAQCD}; kwargs...)
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRN)..., target)
            ir_args = (getproperty(n, fn) for fn in fieldnames($N))
            return $IRN(ir_args..., t_c..., $label)
        end
        function ir(n::$N, target::QubitSet, ::Val{:OpenQASM}; serialization_properties=OpenQASMSerializationProperties())
            t_c = IR._generate_control_and_target(IR.ControlAndTarget($IRN)..., target)
            t   = format_qubits(t_c, serialization_properties)
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
