struct DoubleExcitation <: AngledGate{1}
    angle::NTuple{1,Union{Float64,FreeParameter}}
    DoubleExcitation(angle::T) where {T<:NTuple{1,Union{Float64,FreeParameter}}} =
        new(angle)
end
Braket.chars(::Type{DoubleExcitation}) = "G2(ang)"
Braket.qubit_count(::Type{DoubleExcitation}) = 4
inverted_gate(g::DoubleExcitation) = DoubleExcitation(-g.angle[1])
function matrix_rep(g::DoubleExcitation)
    cosϕ = cos(g.angle[1] / 2.0)
    sinϕ = sin(g.angle[1] / 2.0)
    
    mat = diagm(ones(T, 16))
    mat[4, 4] = cosϕ
    mat[13, 13] = cosϕ
    mat[4, 13] = -sinϕ
    mat[13, 4] = sinϕ
    return SMatrix{32, 32, ComplexF64}(mat)
end

struct SingleExcitation <: AngledGate{1}
    angle::NTuple{1,Union{Float64,FreeParameter}}
    SingleExcitation(angle::T) where {T<:NTuple{1,Union{Float64,FreeParameter}}} =
        new(angle)
end
Braket.chars(::Type{SingleExcitation}) = "G(ang)"
Braket.qubit_count(::Type{SingleExcitation}) = 2
inverted_gate(g::SingleExcitation) = SingleExcitation(-g.angle[1])
function matrix_rep(g::SingleExcitation)
    cosϕ = cos(g.angle[1] / 2.0)
    sinϕ = sin(g.angle[1] / 2.0)
    return SMatrix{4, 4, ComplexF64}([1.0 0 0 0; 0 cosϕ -sinϕ 0; 0 sinϕ cosϕ 0; 0 0 0 1.0])
end
struct MultiRZ <: AngledGate{1}
    angle::NTuple{1,Union{Float64,FreeParameter}}
    MultiRZ(angle::T) where {T<:NTuple{1,Union{Float64,FreeParameter}}} = new(angle)
end
Braket.chars(::Type{MultiRZ}) = "G(ang)"
Braket.qubit_count(g::MultiRZ) = 1
inverted_gate(g::MultiRZ) = MultiRZ(-g.angle[1])

for (V, f) in ((true, :conj), (false, :identity))
    @eval begin
        apply_gate!(::Val{$V}, g::MultiRZ, state_vec::StateVector{T}, t::Int) where {T<:Complex} =
            apply_gate!(Val($V), Rz(g.angle), state_vec, t)
        apply_gate!(
            ::Val{$V},
            g::MultiRZ,
            state_vec::StateVector{T},
            t1::Int,
            t2::Int,
        ) where {T<:Complex} = apply_gate!(Val($V), ZZ(g.angle), state_vec, t1, t2)
        function apply_gate!(
            ::Val{$V},
            g::MultiRZ,
            state_vec::StateVector{T},
            ts::Vararg{Int,N},
        ) where {T<:Complex,N}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, ts...)
            ordered_ts = sort(collect(endian_ts))
            flip_list = map(0:2^N-1) do t
                f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:N-1]
                return ordered_ts[f_vals]
            end
            factor = -im * g.angle[1] / 2.0
            r_mat = Braket.PauliEigenvalues(Val(N))
            g_mat = Diagonal($f(SVector{2^N,ComplexF64}(exp(factor * r_mat[i]) for i = 1:2^N)))

            Threads.@threads for ix = 0:div(n_amps, 2^N)-1
                padded_ix = pad_bits(ix, ordered_ts)
                ixs = SVector{2^N,Int}(flip_bits(padded_ix, f) + 1 for f in flip_list)
                # multiRZ = exp(-iθ Z^n / 2)
                # diagonal in Z basis
                # use SVector * Vector kernel
                @views begin
                    @inbounds begin
                        amps = state_vec[ixs]
                        new_amps = g_mat * amps
                        state_vec[ixs] = new_amps
                    end
                end
            end
            return
        end
    end
end

for V in (false, true)
    @eval begin
        function apply_gate!(
            ::Val{$V},
            g::DoubleExcitation,
            state_vec::StateVector{T},
            t1::Int,
            t2::Int,
            t3::Int,
            t4::Int,
        ) where {T<:Complex}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, t1, t2, t3, t4)
            ordered_ts = sort(collect(endian_ts))
            cosϕ = cos(g.angle[1] / 2.0)
            sinϕ = sin(g.angle[1] / 2.0)
            Threads.@threads for ix = 0:div(n_amps, 2^4)-1
                padded_ix = pad_bits(ix, ordered_ts)
                i0011 = flip_bits(padded_ix, (t3, t4)) + 1
                i1100 = flip_bits(padded_ix, (t1, t2)) + 1
                @inbounds begin
                    amp0011 = state_vec[i0011]
                    amp1100 = state_vec[i1100]
                    state_vec[i0011] = cosϕ * amp0011 - sinϕ * amp1100
                    state_vec[i1100] = sinϕ * amp0011 + cosϕ * amp1100
                end
            end
            return
        end

        function apply_gate!(
            ::Val{$V},
            g::SingleExcitation,
            state_vec::StateVector{T},
            t1::Int,
            t2::Int,
        ) where {T<:Complex}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, t1, t2)
            ordered_ts = sort(collect(endian_ts))
            cosϕ = cos(g.angle[1] / 2.0)
            sinϕ = sin(g.angle[1] / 2.0)
            Threads.@threads for ix = 0:div(n_amps, 4)-1
                padded_ix = pad_bits(ix, ordered_ts)
                i01 = flip_bit(padded_ix, t1) + 1
                i10 = flip_bit(padded_ix, t2) + 1
                @inbounds begin
                    amp01 = state_vec[i01]
                    amp10 = state_vec[i10]
                    state_vec[i01] = cosϕ * amp01 - sinϕ * amp10
                    state_vec[i10] = sinϕ * amp01 + cosϕ * amp10
                end
            end
            return
        end
    end
end
