Base.:(^)(g::Gate, n::Real) = Unitary(Matrix(matrix_rep(g)^n))
Base.:(^)(g::MultiQubitPhaseShift{N}, n::Real) where {N} = MultiQubitPhaseShift{N}((g.angle[1]^n,))
Base.:(^)(g::Control{<:Gate, B}, n::Real) where {B} = Control{Unitary, B}(g.g ^ n, g.bitvals) 
Base.:(^)(g::Control{MultiQubitPhaseShift{N}, B}, n::Real) where {N, B} = Control{MultiQubitPhaseShift{N}, B}(g.g ^ n, g.bitvals)

