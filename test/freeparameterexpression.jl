using Braket, Test

function test_show(f)
    io = IOBuffer()
    show(io, "text/plain", f)
    return String(take!(io))
end

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
    gate = FreeParameterExpression("phi + 2*gamma")
    # creating gates directly
    gsub = subs(gate, Dict(:phi => 4.0, :gamma => 4.0))
    @test subs == 12.0
    gate = FreeParameterExpression("zeta + 2*theta")
    output = test_show(gate)
    @test output == "2theta + zeta"
end
