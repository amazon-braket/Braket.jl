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
    return SMatrix{32,32,ComplexF64}(mat)
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
    return SMatrix{4,4,ComplexF64}([1.0 0 0 0; 0 cosϕ -sinϕ 0; 0 sinϕ cosϕ 0; 0 0 0 1.0])
end
struct MultiRZ <: AngledGate{1}
    angle::NTuple{1,Union{Float64,FreeParameter}}
    MultiRZ(angle::T) where {T<:NTuple{1,Union{Float64,FreeParameter}}} = new(angle)
end
Braket.chars(::Type{MultiRZ}) = "MultiRZ(ang)"
Braket.qubit_count(g::MultiRZ) = 1
inverted_gate(g::MultiRZ) = MultiRZ(-g.angle[1])

struct MultiQubitPhaseShift{N} <: AngledGate{1}
    angle::NTuple{1,Union{Float64,FreeParameter}}
    MultiQubitPhaseShift{N}(angle::T) where {N,T<:NTuple{1,Union{Float64,FreeParameter}}} = new(angle)
end
Braket.chars(::Type{MultiQubitPhaseShift}) = "GPhase(ang)"
Braket.qubit_count(g::MultiQubitPhaseShift{N}) where {N} = N
inverted_gate(g::MultiQubitPhaseShift) = MultiQubitPhaseShift(-g.angle[1])

for (V, f) in ((true, :conj), (false, :identity))
    @eval begin
        apply_gate!(
            ::Val{$V},
            g::MultiRZ,
            state_vec::StateVector{T},
            t::Int,
        ) where {T<:Complex} = apply_gate!(Val($V), Rz(g.angle), state_vec, t)
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
            g_mat =
                Diagonal($f(SVector{2^N,ComplexF64}(exp(factor * r_mat[i]) for i = 1:2^N)))

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
        function apply_gate!(
            ::Val{$V},
            g::MultiQubitPhaseShift{1},
            state_vec::StateVector{T},
            t::Int,
        ) where {T<:Complex}
            g_mat = $f(Diagonal(SVector{2, ComplexF64}(exp(im*g.angle[1]), exp(im*g.angle[1]))))
            return apply_gate!(g_mat, state_vec, t)
        end
        function apply_gate!(
            ::Val{$V},
            g::MultiQubitPhaseShift{N},
            state_vec::StateVector{T},
            ts::Vararg{Int,N},
        ) where {T<:Complex,N}
            n_amps, endian_ts = get_amps_and_qubits(state_vec, ts...)
            ordered_ts = sort(collect(endian_ts))
            flip_list = map(0:2^N-1) do t
                f_vals = Bool[(((1 << f_ix) & t) >> f_ix) for f_ix = 0:N-1]
                return ordered_ts[f_vals]
            end
            factor = im * g.angle[1]
            r_mat = ones(Float64, 2^N)
            g_mat = Diagonal($f(SVector{2^N,ComplexF64}(exp(factor) * r_mat[i]) for i = 1:2^N))

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
    end
end

struct Control{G<:Gate, B} <: Gate
    g::G
    bitvals::NTuple{B, Int}
    Control{G, B}(g::G, bitvals::NTuple{B, Int}) where {B, G} = new(g, bitvals)
end
Control(g::G, bitvals::NTuple{B, Int}) where {G<:Gate, B} = Control{G, B}(g, bitvals)
Control(g::Control{G, BC}, bitvals::NTuple{B, Int}) where {G<:Gate, BC, B} = Control(g.g, (g.bitvals..., bitvals...))
Braket.qubit_count(c::Control{G, B}) where {G<:Gate, B} = qubit_count(c.g) + B
function matrix_rep(c::Control{G, B}) where {G<:Gate, B}
    inner_mat = matrix_rep(c.g)
    inner_qc  = qubit_count(c.g)
    total_qc  = qubit_count(c.g) + B
    full_mat  = diagm(ones(ComplexF64, 2^total_qc))
    ctrl_ix   = 0
    for (b_ix, b) in enumerate(c.bitvals)
        ctrl_ix += b << (b_ix + inner_qc - 1)
    end
    for inner_ix in 1:2^qubit_count(c.g), inner_jx in 1:2^qubit_count(c.g)
        full_mat[ctrl_ix + inner_ix, ctrl_ix + inner_jx] = inner_mat[inner_ix, inner_jx]
    end
    return full_mat
end

