using Test, Braket, BraketStateVector, LinearAlgebra
import Braket: Instruction

const NUM_SAMPLES = 1000

observables_testdata = [(Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.H()]), (1, 2)),
                        (Braket.Observables.TensorProduct([Braket.Observables.I(), Braket.Observables.Y()]), (0, 2))]

all_qubit_observables_testdata = [
    Braket.Observables.X(),
    Braket.Observables.Y(),
    Braket.Observables.Z(),
    Braket.Observables.H(),
    Braket.Observables.I(),
    #TODO SUPPORT THIS
    Braket.Observables.HermitianObservable([0.0 1.0; 1.0 0.0]),
]

@testset "Result types" begin
    state_vector() = (sqrt.(0:15 ./ 120)) .* vcat(ones(8), im.*ones(8))
    density_matrix(state_vector) = kron(state_vector, conj(state_vector))
    observable() = (Braket.Observables.TensorProduct([Braket.Observables.X(), Braket.Observables.H()]), (1, 2))
    function simulation(obs_func=observable)
        sim = BraketStateVector.StateVectorSimulator(4, NUM_SAMPLES)
        sim.state_vector = state_vector()
        sim = BraketStateVector.apply_observables!(sim, [obs_func()])
        return sim
    end
    function _expectation_from_diagonalization(sim, qubits, eigenvalues)
        qc = Int(log2(length(sim)))
        marginal = BraketStateVector.marginal_probability(sim, qc, qubits)
        evs = (length(eigenvalues) == 2 && length(qubits) > 1) ? repeat(eigenvalues, 2^(length(qubits)-1)) : eigenvalues
        return real(dot(marginal, evs))
    end
    function _variance_from_diagonalization(sim, qubits, eigenvalues)
        qc = Int(log2(length(sim)))
        marginal = BraketStateVector.marginal_probability(sim, qc, qubits) 
        evs = (length(eigenvalues) == 2 && length(qubits) > 1) ? repeat(eigenvalues, 2^(length(qubits)-1)) : eigenvalues
        return real(dot(marginal, (real.(evs).^2) .- real(dot(marginal, evs)^2)))
    end
    @testset "Amplitude" begin
        result_type = Braket.Amplitude(["0010", "0101", "1110"])
        amplitudes = BraketStateVector.calculate(result_type, simulation())
        sv = state_vector()
        @test amplitudes["0010"] ≈ sv[3]
        @test amplitudes["0101"] ≈ sv[6]
        @test amplitudes["1110"] ≈ sv[15]
    end
    @testset "Expectation obs $obs" for obs in observables_testdata
        sim = simulation(()->obs)
        result_type = Expectation(obs...)
        @test result_type.observable == obs[1]
        @test result_type.targets == QubitSet(obs[2])

        calculated           = BraketStateVector.calculate(result_type, sim)
        from_diagonalization = _expectation_from_diagonalization(BraketStateVector.state_with_observables(simulation()), obs[2], eigvals(obs[1]))
        @test calculated     ≈ from_diagonalization
    end
    targs = collect(0:3)
    @testset "Expectation no targets $obs" for obs in all_qubit_observables_testdata
        sim = simulation(()->(obs, targs))
        result_type = Expectation(obs, targs)
        @test result_type.observable == obs

        calculated           = BraketStateVector.calculate(result_type, sim)
        from_diagonalization = _expectation_from_diagonalization(BraketStateVector.state_with_observables(simulation()), targs, eigvals(obs))
        @test calculated     ≈ from_diagonalization
    end
    @testset "Variance obs $obs" for obs in observables_testdata
        sim = simulation(()->obs)
        result_type = Variance(obs...)
        @test result_type.observable == obs[1]
        @test result_type.targets == QubitSet(obs[2])
        calculated           = BraketStateVector.calculate(result_type, sim)
        from_diagonalization = _variance_from_diagonalization(BraketStateVector.state_with_observables(simulation()), obs[2], eigvals(obs[1]))
        @test calculated     ≈ from_diagonalization
    end
    @testset "Variance no targets $obs" for obs in all_qubit_observables_testdata 
        sim = simulation(()->(obs, targs))
        result_type = Variance(obs, targs)
        @test result_type.observable == obs

        calculated           = BraketStateVector.calculate(result_type, sim)
        from_diagonalization = _variance_from_diagonalization(BraketStateVector.state_with_observables(simulation()), targs, eigvals(obs))
        @test calculated     ≈ from_diagonalization
    end
end
