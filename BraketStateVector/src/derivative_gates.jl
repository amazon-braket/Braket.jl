for (g1, g2, tag) in ((:Rx, :X, :deriv_rx), (:Ry, :Y, :deriv_ry), (:Rz, :Z, :deriv_rz))
    @eval begin
        function derivative_gate(::Val{1}, g::$g1, target::Int)
            gate_fn = function $tag(sv::StateVector{<:Complex})
                apply_gate!(g, sv, target)
                apply_gate!($g2(), sv, target)
                return sv
            end
            return -0.5im, gate_fn
        end
    end
end

function derivative_gate(::Val{1}, g::PhaseShift, target::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ)
    sinϕ = sin(ϕ)
    u_mat = zeros(ComplexF64, 2, 2)
    u_mat[2,2] = -sinϕ + im*cosϕ
    gate_fn = function deriv_ps(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, target)
        return sv
    end
    return 1.0, gate_fn
end

for (G, ind, tag) in ((:CPhaseShift, 4, :deriv_cps),
                      (:CPhaseShift00, 1, :deriv_cps00),
                      (:CPhaseShift10, 3, :deriv_cps10),
                      (:CPhaseShift01, 2, :deriv_cps01),
                     )
    @eval begin
        function derivative_gate(::Val{1}, g::$G, control::Int, target::Int)
            ϕ = g.angle[1]
            cosϕ = cos(ϕ)
            sinϕ = sin(ϕ)
            u_mat = zeros(ComplexF64, 4, 4)
            u_mat[$ind,$ind] = -sinϕ + im*cosϕ
            gate_fn = function $tag(sv::StateVector{<:Complex})
                apply_gate!(Unitary(u_mat), sv, target, control)
                return sv
            end
            return 1.0, gate_fn
        end
    end
end

function derivative_gate(::Val{1}, g::PSwap, t1::Int, t2::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ)
    sinϕ = sin(ϕ)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[2,3] = -sinϕ + im*cosϕ
    u_mat[3,2] = -sinϕ + im*cosϕ
    gate_fn = function deriv_pswap(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, t2, t1)
        return sv
    end
    return 1.0, gate_fn
end

function derivative_gate(::Val{1}, g::XX, t1::Int, t2::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ/2.0)
    sinϕ = sin(ϕ/2.0)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[diagind(u_mat)] = -sinϕ/2.0
    u_mat[1, 4] = -im*cosϕ/2.0
    u_mat[2, 3] = -im*cosϕ/2.0
    u_mat[3, 2] = -im*cosϕ/2.0
    u_mat[4, 1] = -im*cosϕ/2.0
    gate_fn = function deriv_xx(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, t2, t1)
        return sv
    end
    return 1.0, gate_fn
end

function derivative_gate(::Val{1}, g::YY, t1::Int, t2::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ/2.0)
    sinϕ = sin(ϕ/2.0)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[diagind(u_mat)] .= -sinϕ/2.0
    u_mat[1, 4] = im*cosϕ/2.0
    u_mat[2, 3] = -im*cosϕ/2.0
    u_mat[3, 2] = -im*cosϕ/2.0
    u_mat[4, 1] = im*cosϕ/2.0
    gate_fn = function deriv_yy(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, t2, t1)
        return sv
    end
    return 1.0, gate_fn
end

function derivative_gate(::Val{1}, g::ZZ, t1::Int, t2::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ/2.0)
    sinϕ = sin(ϕ/2.0)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[diagind(u_mat)] .= -sinϕ/2.0 .+ (im*cosϕ/2.0)*[-1,1,1,-1]
    gate_fn = function deriv_zz(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, t2, t1)
        return sv
    end
    return 1.0, gate_fn
end

function derivative_gate(::Val{1}, g::XY, t1::Int, t2::Int)
    ϕ = g.angle[1]
    cosϕ = cos(ϕ/2.0)
    sinϕ = sin(ϕ/2.0)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[2, 2] = -sinϕ/2.0
    u_mat[3, 3] = -sinϕ/2.0
    u_mat[2, 3] = im*cosϕ/2.0
    u_mat[3, 2] = im*cosϕ/2.0
    gate_fn = function deriv_xy(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, t2, t1)
        return sv
    end
    return 1.0, gate_fn
end

# IonQ native gates
function derivative_gate(::Val{1}, g::GPi, target::Int)
    ϕ    = g.angle[1]
    cosϕ = cos(ϕ)
    sinϕ = sin(ϕ)
    u_mat = zeros(ComplexF64, 2, 2)
    u_mat[1,2] = -sinϕ - im * cosϕ
    u_mat[2,1] = -sinϕ + im * cosϕ
    gate_fn = function deriv_gpi(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, target)
        return sv
    end
    return 1.0, gate_fn
end

function derivative_gate(::Val{1}, g::GPi2, target::Int)
    ϕ    = g.angle[1]
    cosϕ = cos(ϕ)
    sinϕ = sin(ϕ)
    u_mat = zeros(ComplexF64, 2, 2)
    u_mat[1,2] = -cosϕ + im * sinϕ
    u_mat[2,1] = cosϕ + im * sinϕ
    gate_fn = function deriv_gpi2(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, target)
        return sv
    end
    return 1.0, gate_fn
end

function _ms_u_mat(::Val{1}, ϕ1, ϕ2, ϕ3)
    cosϕ3 = cos(ϕ3/2)
    sinϕ3 = sin(ϕ3/2)
    cos_ϕ1_plus_ϕ2_mul_ϕ3 = cos(ϕ1+ϕ2)*sinϕ3
    sin_ϕ1_plus_ϕ2_mul_ϕ3 = sin(ϕ1+ϕ2)*sinϕ3
    cos_ϕ1_min_ϕ2_mul_ϕ3  = cos(ϕ1-ϕ2)*sinϕ3
    sin_ϕ1_min_ϕ2_mul_ϕ3  = sin(ϕ1-ϕ2)*sinϕ3
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[1, 4] = -cos_ϕ1_plus_ϕ2_mul_ϕ3 + im*sin_ϕ1_plus_ϕ2_mul_ϕ3
    u_mat[2, 3] = -cos_ϕ1_min_ϕ2_mul_ϕ3  + im*sin_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[3, 2] =  cos_ϕ1_min_ϕ2_mul_ϕ3  + im*sin_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[4, 1] =  cos_ϕ1_plus_ϕ2_mul_ϕ3 + im*sin_ϕ1_plus_ϕ2_mul_ϕ3
    return u_mat
end

function _ms_u_mat(::Val{2}, ϕ1, ϕ2, ϕ3)
    cosϕ3 = cos(ϕ3/2)
    sinϕ3 = sin(ϕ3/2)
    cos_ϕ1_plus_ϕ2_mul_ϕ3 = cos(ϕ1+ϕ2)*sinϕ3
    sin_ϕ1_plus_ϕ2_mul_ϕ3 = sin(ϕ1+ϕ2)*sinϕ3
    cos_ϕ1_min_ϕ2_mul_ϕ3  = cos(ϕ1-ϕ2)*sinϕ3
    sin_ϕ1_min_ϕ2_mul_ϕ3  = sin(ϕ1-ϕ2)*sinϕ3
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[1, 4] = -cos_ϕ1_plus_ϕ2_mul_ϕ3 + im*sin_ϕ1_plus_ϕ2_mul_ϕ3
    u_mat[2, 3] =  cos_ϕ1_min_ϕ2_mul_ϕ3  - im*sin_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[3, 2] = -cos_ϕ1_min_ϕ2_mul_ϕ3  - im*sin_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[4, 1] =  cos_ϕ1_plus_ϕ2_mul_ϕ3 + im*sin_ϕ1_plus_ϕ2_mul_ϕ3
    return u_mat
end

function _ms_u_mat(::Val{3}, ϕ1, ϕ2, ϕ3)
    cosϕ3 = cos(ϕ3/2)
    sinϕ3 = sin(ϕ3/2)
    cos_ϕ1_plus_ϕ2_mul_cos_ϕ3 = cos(ϕ1+ϕ2)*cosϕ3
    sin_ϕ1_plus_ϕ2_mul_cos_ϕ3 = sin(ϕ1+ϕ2)*cosϕ3
    cos_ϕ1_min_ϕ2_mul_cos_ϕ3  = cos(ϕ1-ϕ2)*cosϕ3
    sin_ϕ1_min_ϕ2_mul_cos_ϕ3  = sin(ϕ1-ϕ2)*cosϕ3
    u_mat = zeros(ComplexF64, 4, 4)
    anti_diag_inds = [[1, 4], [2, 3], [3, 2], [4, 1]]
    u_mat[diagind(u_mat)] .= ComplexF64[-sinϕ3/2.0, -sinϕ3/2.0, -sinϕ3/2.0, -sinϕ3/2.0]
    u_mat[anti_diag_inds] .= [-sin_ϕ1_plus_ϕ2_mul_cos_ϕ3/2.0 - im*cos_ϕ1_plus_ϕ2_mul_cos_ϕ3/2.0,
                              -sin_ϕ1_min_ϕ2_mul_cos_ϕ3/2.0  - im*cos_ϕ1_min_ϕ2_mul_cos_ϕ3/2.0,
                               sin_ϕ1_min_ϕ2_mul_cos_ϕ3/2.0  - im*cos_ϕ1_min_ϕ2_mul_cos_ϕ3/2.0,
                               sin_ϕ1_plus_ϕ2_mul_cos_ϕ3/2.0 - im*cos_ϕ1_plus_ϕ2_mul_cos_ϕ3/2.0]
    return u_mat
end

function derivative_gate(::Val{V}, g::MS, t1::Int, t2::Int) where {V}
    ϕ1, ϕ2, ϕ3 = g.angle
    u_mat = _ms_u_mat(Val(V), g.angle...)
    gate_fn = function deriv_ms(sv::StateVector{<:Complex})
        apply_gate!(Unitary(u_mat), sv, target)
        return sv
    end
    return 1.0, gate_fn
end

