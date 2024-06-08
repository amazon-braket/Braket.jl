using Braket, Test

@testset "Free parameters" begin
    α = FreeParameter(:alpha)
    θ = FreeParameter(:theta)
    @test_throws MethodError qubit_count(θ)
    circ = Circuit()
    circ = H(circ, 0)
    circ = Rx(circ, 1, α)
    circ = Ry(circ, 0, θ)
    circ = Probability(circ)
    new_circ = circ(theta=2.0, alpha=1.0)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 2.0)) |> Probability
    @test new_circ == non_para_circ
    new_circ = circ(1.0)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 1.0)) |> Probability
    @test new_circ == non_para_circ
    ϕ = FreeParameter(:phi)
    circ = apply_gate_noise!(circ, BitFlip(ϕ))
    circ = apply_gate_noise!(circ, PhaseFlip(0.1))
    new_circ = circ(theta=2.0, alpha=1.0, phi=0.2)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, 1.0)) |> (ci->Ry(ci, 0, 2.0)) |> Probability |> (ci->apply_gate_noise!(ci, BitFlip(0.2))) |> (ci->apply_gate_noise!(ci, PhaseFlip(0.1)))
    @test new_circ == non_para_circ
    b = FreeParameter("b")
    @test b.name == :b
    @test copy(b) === b
end


@testset "Free parameter Expression" begin
    α = FreeParameter(:alpha)
    θ = FreeParameter(:theta)
    gate = FreeParameterExpression("α + 2*θ")
    gsub = subs(gate, Dict(:α => 2.0, :θ => 2.0))
    circ = Circuit()
    circ = H(circ, 0)
    circ = Rx(circ, 1, gsub)
    circ = Ry(circ, 0, θ)
    circ = Probability(circ)
    new_circ = circ(6.0)
    non_para_circ = Circuit() |> (ci->H(ci, 0)) |> (ci->Rx(ci, 1, gsub)) |> (ci->Ry(ci, 0, 6.0)) |> Probability
    @test new_circ == non_para_circ
end