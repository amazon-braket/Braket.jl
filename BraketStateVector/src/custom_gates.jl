struct DoubleExcitation <: AngledGate{1}
    angle::NTuple{1, Union{Float64, FreeParameter}}
    DoubleExcitation(angle::T) where {T<:NTuple{1, Union{Float64, FreeParameter}}} = new(angle)
end
Braket.chars(::Type{DoubleExcitation}) = "G2(ang)"
Braket.qubit_count(::Type{DoubleExcitation}) = 4
inverted_gate(g::DoubleExcitation) = DoubleExcitation(-g.angle[1])

struct SingleExcitation <: AngledGate{1}
    angle::NTuple{1, Union{Float64, FreeParameter}}
    SingleExcitation(angle::T) where {T<:NTuple{1, Union{Float64, FreeParameter}}} = new(angle)
end
Braket.chars(::Type{SingleExcitation}) = "G(ang)"
Braket.qubit_count(::Type{SingleExcitation}) = 2
inverted_gate(g::SingleExcitation) = SingleExcitation(-g.angle[1])

function apply_gate!(::Val{V}, g::DoubleExcitation, state_vec::StateVector{T}, t1::Int, t2::Int, t3::Int, t4::Int) where {V, T<:Complex}
    n_amps, endian_ts = get_amps_and_qubits(state_vec, t1, t2, t3, t4)
    ordered_ts = sort(collect(endian_ts))
    cosϕ = cos(g.angle[1]/2.0)
    sinϕ = sin(g.angle[1]/2.0)
    Threads.@threads for ix in 0:div(n_amps, 2^4)-1
        padded_ix = pad_bits(ix, ordered_ts)
        i0011     = flip_bits(padded_ix, (t3, t4)) + 1
        i1100     = flip_bits(padded_ix, (t1, t2)) + 1
        amp0011   = state_vec[i0011]
        amp1100   = state_vec[i1100]
        state_vec[i0011] = cosϕ * amp0011 - sinϕ * amp1100
        state_vec[i1100] = sinϕ * amp0011 + cosϕ * amp1100
    end
    return
end

function apply_gate!(::Val{V}, g::SingleExcitation, state_vec::StateVector{T}, t1::Int, t2::Int) where {V, T<:Complex}
    n_amps, endian_ts = get_amps_and_qubits(state_vec, t1, t2)
    ordered_ts = sort(collect(endian_ts))
    cosϕ = cos(g.angle[1]/2.0)
    sinϕ = sin(g.angle[1]/2.0)
    Threads.@threads for ix in 0:div(n_amps, 4)-1
        padded_ix = pad_bits(ix, ordered_ts)
        i01     = flip_bit(padded_ix, t1) + 1
        i10     = flip_bit(padded_ix, t2) + 1
        amp01   = state_vec[i01]
        amp10   = state_vec[i10]
        state_vec[i01] = cosϕ * amp01 - sinϕ * amp10
        state_vec[i10] = sinϕ * amp01 + cosϕ * amp10
    end
    return
end
