using Braket, Test

@testset "Free parameter expressions" begin
    α = FreeParameter(:alpha)
    θ = FreeParameter(:theta)
    gate = FreeParameterExpression("α + 2*θ")
    @test copy(gate) === gate
    gsub = subs(gate, Dict(:α => 2.0, :θ => 2.0))
    circ = Circuit()
    circ = H(circ, 0)
    circ = Rx(circ, 1, gsub)
    circ = Ry(circ, 0, θ)
    circ = Probability(circ)
    new_circ = circ(6.0)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, gsub)) |> (ci->Ry(ci, 0, 6.0)) |> Probability
    @test new_circ == non_para_circ
    ϕ = FreeParameter(:phi)
    circ = apply_gate_noise!(circ, BitFlip(ϕ))
    circ = apply_gate_noise!(circ, PhaseFlip(0.1))
    new_circ = circ(theta=2.0, alpha=1.0, phi=0.2)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, gsub)) |> (ci->Ry(ci, 0, 2.0)) |> Probability |> (ci->apply_gate_noise!(ci, BitFlip(0.2))) |> (ci->apply_gate_noise!(ci, PhaseFlip(0.1)))
    @test new_circ == non_para_circ

    # creating gates directly 
    gate = FreeParameterExpression("phi + 2*gamma")
    gsub₁ = subs(gate, Dict(:phi => 4.0, :gamma => 4.0))
    @test gsub₁ == 12.0
    circ = Circuit()
    circ = H(circ, 0)
    circ = Rx(circ, 1, gsub₁)
    circ = Ry(circ, 0, θ)
    circ = Probability(circ)
    new_circ = circ(6.0)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, gsub₁)) |> (ci->Ry(ci, 0, 6.0)) |> Probability
    @test new_circ == non_para_circ

    # + operator 
    fpe1 = FreeParameterExpression("α + θ")
    fpe2 = FreeParameterExpression("2 * θ")
    result = fpe1 + fpe2
    result  == FreeParameterExpression("2 * θ + α + θ")
    gsub = subs(result, Dict(:α => 1.0, :θ => 1.0))
    @test gsub == 4.0 # α + 3θ == 4.0 
    fpe3 = FreeParameterExpression("2 * θ")
    # == operator
    @test fpe3 == fpe2 
    # != operator
    @test fpe1 != fpe2 
    show(fpe3)
    # - operator
    result = fpe1 - fpe2
    result  == FreeParameterExpression("α - θ")
    gsub = subs(result, Dict(:α => 1.0, :θ => 1.0))
    @test gsub == 0.0 # α - θ == 0.0 
    # * operator
    result = fpe1 * fpe2
    result  == FreeParameterExpression("2(α + θ)*θ")
    gsub = subs(result, Dict(:α => 1.0, :θ => 1.0))
    @test gsub == 4.0 # 2(α + θ)*θ == 4.0
    # / operator
    result = fpe1 / fpe2
    result  == FreeParameterExpression("(α + θ) / (2θ)")
    gsub = subs(result, Dict(:α => 1.0, :θ => 1.0))
    @test gsub == 1.0 # (α + θ) / (2θ) == 1.0
    # ^ operator
    result = fpe1 ^ fpe2
    result  == FreeParameterExpression("(α + θ)^(2θ)")
    gsub = subs(result, Dict(:α => 1.0, :θ => 1.0))
    @test gsub == 4.0 # (α + θ)^(2θ) == 4.0
end
