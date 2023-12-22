for G in (:X, :Y, :Z, :H, :I, :Swap, :CNot, :CY, :CZ, :CCNot, :CSwap, :GPi)
    @eval begin
        inverted_gate(g::$G) = g
    end
end
for G in (:Rx, :Ry, :Rz, :PhaseShift, :PSwap, :CPhaseShift, :CPhaseShift00, :CPhaseShift01, :CPhaseShift10, :XX, :YY, :ZZ, :XY)
    @eval begin
        inverted_gate(g::$G) = $G(-g.angle[1])
    end
end
for (G, Gi) in ((:V, :Vi), (:S, :Si), (:T, :Ti))
    @eval begin
        inverted_gate(g::$G) = $Gi()
    end
end

function inverted_gate(g::ISwap)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[1,1] = 1.0
    u_mat[4,4] = 1.0
    u_mat[2,3] = -im
    u_mat[3,2] = -im
    return Unitary(u_mat)
end

function inverted_gate(g::ECR)
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[1,3] = 1/√2
    u_mat[2,4] = 1/√2
    u_mat[3,1] = 1/√2
    u_mat[4,2] = 1/√2
    u_mat[1,4] = im/√2
    u_mat[2,3] = im/√2
    u_mat[3,2] = -im/√2
    u_mat[4,1] = -im/√2
    return Unitary(transpose(u_mat))
end

function inverted_gate(g::GPi2)
    ϕ     = g.angle[1]
    cosϕ  = cos(ϕ)
    sinϕ  = sin(ϕ)
    u_mat = 1/√2[1.0 sinϕ+im*cosϕ; -sinϕ+im*cosϕ 1.0]
    return Unitary(u_mat)
end

function inverted_gate(g::MS)
    ϕ1, ϕ2, ϕ3 = g.angle
    sin_ϕ3 = sin(ϕ3/2)
    cos_ϕ3 = cos(ϕ3/2)
    cos_ϕ1_plus_ϕ2_mul_ϕ3 = cos(ϕ1+ϕ2)*sin_ϕ3
    sin_ϕ1_plus_ϕ2_mul_ϕ3 = sin(ϕ1+ϕ2)*sin_ϕ3
    cos_ϕ1_min_ϕ2_mul_ϕ3  = cos(ϕ1-ϕ2)*sin_ϕ3
    sin_ϕ1_min_ϕ2_mul_ϕ3  = sin(ϕ1-ϕ2)*sin_ϕ3
    u_mat = zeros(ComplexF64, 4, 4)
    u_mat[diagind(u_mat)] .= cos_ϕ3
    u_mat[1, 4] =  sin_ϕ1_plus_ϕ2_mul_ϕ3 + im*cos_ϕ1_plus_ϕ2_mul_ϕ3
    u_mat[2, 3] =  sin_ϕ1_min_ϕ2_mul_ϕ3  + im*cos_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[3, 2] = -sin_ϕ1_min_ϕ2_mul_ϕ3  + im*cos_ϕ1_min_ϕ2_mul_ϕ3
    u_mat[4, 1] = -sin_ϕ1_plus_ϕ2_mul_ϕ3 + im*cos_ϕ1_plus_ϕ2_mul_ϕ3
    return Unitary(u_mat)
end
