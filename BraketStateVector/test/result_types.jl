using Test, Braket, BraketStateVector, LinearAlgebra
import Braket: Instruction

const NUM_SAMPLES = 1000

observables_testdata = [(Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.H()]), (1, 2)),
                        (Braket.Observables.TensorProduct([Braket.Observables.I(), Braket.Observables.Y()]), (0, 2)),
                        (Braket.Observables.Y(), (2,))]

all_qubit_observables_testdata = [
    Braket.Observables.X(),
    Braket.Observables.Y(),
    Braket.Observables.Z(),
    Braket.Observables.H(),
    Braket.Observables.I(),
    Braket.Observables.HermitianObservable([0.0 1.0; 1.0 0.0]),
]

@testset "Result types" begin
    state_vector() = (sqrt.(collect(0:15) ./ 120.0)) .* vcat(ones(8), im.*ones(8))
    function marginal_12()
        all_probs = abs2.(state_vector())
        return [sum(all_probs[[1, 2, 9, 10]]), sum(all_probs[[3, 4, 11, 12]]), sum(all_probs[[5, 6, 13, 14]]), sum(all_probs[[7, 8, 15, 16]])]
    end
    density_matrix(sv) = kron(adjoint(sv), sv)
    observable() = (Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.H()]), (1, 2))
    dm_dict = Dict(3=>[0.46666667 0.49464257; 0.49464257 0.53333333],
                   [0,1,2,3]=>density_matrix(state_vector()),
                   [0,2,1]=>[0.00833333 0.0186339 0.01443376 0.02204793 -0.025im -0.03004626im -0.02763854im -0.03227486im; 0.0186339 0.075 0.05584509 0.09012549 -0.10304215im -0.12492051im -0.11450628im -0.13452974im; 0.01443376 0.05584509 0.04166667 0.06705564 -0.0766346im -0.09286648im -0.08513916im -0.09999755im; 0.02204793 0.09012549 0.06705564 0.10833333 -0.12387881im -0.15020561im -0.13767443im -0.16176752im; 0.025im 0.10304215im 0.0766346im 0.12387881im 0.14166667 0.17178844 0.15745122 0.18501629; 0.03004626im 0.12492051im 0.09286648im 0.15020561im 0.17178844 0.20833333 0.19093927 0.22438101; 0.02763854im 0.11450628im 0.08513916im 0.13767443im 0.15745122 0.19093927 0.175 0.20564493; 0.03227486im 0.13452974im 0.09999755im 0.16176752im 0.18501629 0.22438101 0.20564493 0.24166667],
                  )

    function simulation(obs_func, ::Val{:sv})
        sim = BraketStateVector.StateVectorSimulator(4, NUM_SAMPLES)
        sim.state_vector = state_vector()
        @test sum(abs2.(sim.state_vector)) ≈ 1.0
        if !isnothing(obs_func)
            sim = BraketStateVector.apply_observables!(sim, [obs_func()])
        end
        return sim
    end
    function simulation(obs_func, ::Val{:dm})
        sim = BraketStateVector.DensityMatrixSimulator(4, NUM_SAMPLES)
        sim.density_matrix = density_matrix(state_vector())
        @test sum(diag(sim.density_matrix)) ≈ 1.0
        if !isnothing(obs_func)
            sim = BraketStateVector.apply_observables!(sim, [obs_func()])
        end
        return sim
    end
    function _expectation_from_diagonalization(sim::AbstractVector, qubits, eigenvalues)
        qc       = Int(log2(length(sim)))
        marginal = BraketStateVector.marginal_probability(abs2.(sim), qc, qubits)
        return real(dot(marginal, eigenvalues))
    end
    function _expectation_from_diagonalization(sim::AbstractMatrix, qubits, eigenvalues)
        qc       = Int(log2(size(sim, 1)))
        marginal = BraketStateVector.marginal_probability(real.(diag(sim)), qc, qubits)
        return real(dot(marginal, eigenvalues))
    end
    function _variance_from_diagonalization(sim::AbstractVector, qubits, eigenvalues)
        qc       = Int(log2(length(sim)))
        marginal = BraketStateVector.marginal_probability(abs2.(sim), qc, qubits)
        evs      = eigenvalues
        return real(dot(marginal, (real.(evs).^2) .- real(dot(marginal, evs)^2)))
    end
    function _variance_from_diagonalization(sim::AbstractMatrix, qubits, eigenvalues)
        qc       = Int(log2(size(sim, 1)))
        marginal = BraketStateVector.marginal_probability(real.(diag(sim)), qc, qubits)
        evs      = eigenvalues
        return real(dot(marginal, (real.(evs).^2) .- real(dot(marginal, evs)^2)))
    end
    targs = collect(0:3)
    @testset "Simulation type $sim_type" for sim_type in (Val(:sv), Val(:dm))
        if sim_type isa Val{:sv}
            @testset "Amplitude" begin
                result_type = Braket.Amplitude(["0010", "0101", "1110"])
                amplitudes  = BraketStateVector.calculate(result_type, simulation(observable, sim_type))
                sv = state_vector()
                @test amplitudes["0010"] ≈ sv[3]
                @test amplitudes["0101"] ≈ sv[6]
                @test amplitudes["1110"] ≈ sv[15]
            end
        end
        @testset "Probability" begin
            probability_12 = BraketStateVector.calculate(Braket.Probability([1, 2]), simulation(nothing, sim_type)) 
            @test probability_12 ≈ marginal_12()

            state_vector_probabilities = abs2.(state_vector())
            probability_all_qubits = BraketStateVector.calculate(Braket.Probability([0, 1, 2, 3]), simulation(nothing, sim_type))
            @test probability_all_qubits ≈ state_vector_probabilities
        end
        @testset "Expectation obs $obs" for obs in observables_testdata
            result_type = Expectation(obs...)
            @test result_type.observable == obs[1]
            @test result_type.targets == QubitSet(obs[2])

            sim                  = simulation(()->obs, sim_type)
            calculated           = BraketStateVector.calculate(result_type, sim)
            from_diagonalization = _expectation_from_diagonalization(BraketStateVector.state_with_observables(simulation(()->obs, sim_type)), obs[2], eigvals(obs[1]))
            @test calculated     ≈ from_diagonalization
        end
        @testset "Expectation no targets $obs" for obs in all_qubit_observables_testdata
            result_types = [Expectation(obs, t) for t in targs]
            @test all(result_type.observable == obs for result_type in result_types)

            calculated           = [BraketStateVector.calculate(result_type, simulation(()->(obs, targs), sim_type)) for result_type in result_types]
            from_diagonalization = [_expectation_from_diagonalization(BraketStateVector.state_with_observables(simulation(()->(obs, t), sim_type)), t, eigvals(obs)) for t in targs]
            @test calculated     ≈ from_diagonalization
        end
        @testset "Variance obs $obs" for obs in observables_testdata
            sim = simulation(()->obs, sim_type)
            result_type = Variance(obs...)
            @test result_type.observable == obs[1]
            @test result_type.targets == QubitSet(obs[2])
            calculated           = BraketStateVector.calculate(result_type, sim)
            from_diagonalization = _variance_from_diagonalization(BraketStateVector.state_with_observables(simulation(()->obs, sim_type)), obs[2], eigvals(obs[1]))
            @test calculated     ≈ from_diagonalization atol=1e-12
        end
        @testset "Variance no targets $obs" for obs in all_qubit_observables_testdata 
            result_types = [Variance(obs, t) for t in targs]
            @test all(result_type.observable == obs for result_type in result_types)

            calculated           = [BraketStateVector.calculate(result_type, simulation(()->(obs, targs), sim_type)) for result_type in result_types]
            from_diagonalization = [_variance_from_diagonalization(BraketStateVector.state_with_observables(simulation(()->(obs, t), sim_type)), t, eigvals(obs)) for t in targs]
            @test calculated     ≈ from_diagonalization atol=1e-12
        end
        @testset "Density matrix $qubit" for (qubit, mat) in dm_dict
            dm = DensityMatrix(qubit)
            sim = simulation(nothing, sim_type)
            calculated = BraketStateVector.calculate(dm, sim)
            @test calculated ≈ mat rtol=1e-6
        end
    end
end
