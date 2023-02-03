using Braket, Braket.Observables, Test, JSON3

using Braket: NoiseModel, add_noise!, insert_noise!, remove_noise!, from_filter, GateCriteria, QubitInitializationCriteria, UnitaryGateCriteria, ObservableCriteria
import Braket: I as I

h_unitary() = (1/√2).*[1.0 1.0; 1.0 -1.0]

function default_noise_model()
    noise_list = []
    criteria_list = []
    noise_model = NoiseModel()
    for i in 0:2
        noise = BitFlip(0.1)
        criteria = GateCriteria(X, 1)
        add_noise!(noise_model, noise, criteria)
        push!(noise_list, noise)
        push!(criteria_list, criteria)
    end
    return noise_model, noise_list, criteria_list
end

@testset "Noise models" begin
    @testset "Simple noise model" begin
        noise_model = NoiseModel()
        @test length(noise_model.instructions) == 0
        n = BitFlip(0.1)
        c = GateCriteria(X, 1)
        add_noise!(noise_model, n, c)
        noise_list = noise_model.instructions
        @test length(noise_list) == 1
        @test n == noise_list[1].noise
        @test c == noise_list[1].criteria
    end
    @testset "criteria equality" begin
        @test GateCriteria(H) != GateCriteria(H, [0, 2])
        @test GateCriteria(H) != UnitaryGateCriteria(Unitary(h_unitary()), nothing)
        @test QubitInitializationCriteria([0,1]) != QubitInitializationCriteria([0])
    end
    @testset "insert noise" begin
        noise_model, noise_list, criteria_list = default_noise_model()
        listed_noise = noise_model.instructions
        @test length(listed_noise) == 3

        n = PhaseFlip(0.1)
        c = GateCriteria(Y, 1)

        insert_noise!(noise_model, 2, n, c)

        listed_noise = noise_model.instructions
        @test length(listed_noise) == 4
        @test listed_noise[1].noise == noise_list[1]
        @test listed_noise[1].criteria == criteria_list[1]
        @test listed_noise[2].noise == n
        @test listed_noise[2].criteria == c
        @test listed_noise[3].noise == noise_list[2]
        @test listed_noise[3].criteria == criteria_list[2]
        @test listed_noise[4].noise == noise_list[3]
        @test listed_noise[4].criteria == criteria_list[3]
    end
    @testset "remove noise" begin
        noise_model, noise_list, _ = default_noise_model()
        listed_noise = noise_model.instructions
        @test length(listed_noise) == 3

        remove_noise!(noise_model, 2)

        listed_noise = noise_model.instructions
        @test length(listed_noise) == 2
        @test listed_noise[1].noise == noise_list[1]
        @test listed_noise[2].noise == noise_list[3]
    end
    @testset "from filter" begin
        noise_model = NoiseModel()
        add_noise!(noise_model, PauliChannel(0.01, 0.02, 0.03), GateCriteria(Braket.I, [0, 1]))
        add_noise!(noise_model, Depolarizing(0.04), GateCriteria(H))
        add_noise!(noise_model, Depolarizing(0.05), GateCriteria(CNot, [0, 1]))
        add_noise!(noise_model, PauliChannel(0.06, 0.07, 0.08), GateCriteria(H, [0, 1]))
        add_noise!(noise_model, Depolarizing(0.09), GateCriteria(nothing, 0))
        add_noise!(noise_model, Depolarizing(0.10), QubitInitializationCriteria([0, 1]))
        @testset for filter ∈ [
            (nothing, nothing, nothing, nothing, 6),
            (nothing, nothing, PauliChannel, nothing, 2),
            (H, nothing, nothing, nothing, 3),
            (CNot, nothing, nothing, nothing, 2),
            (nothing, 0, nothing, nothing, 5),
            # (nothing, (0, 1), nothing, nothing, 1), # TODO: I'm not sure of the best way to fix this.
            (CNot, [0, 1], nothing, nothing, 1),
            (CNot, [1, 0], nothing, nothing, 0),
            (H, 2, nothing, nothing, 1),
            (H, nothing, Depolarizing, nothing, 2),
        ]
            gate, qubit, noise, noise_type, expected_length = filter
            result_model = from_filter(noise_model, qubit=qubit, gate=gate, noise=noise)
            @test length(result_model.instructions) == expected_length
        end
    end
    @testset "serialization" begin
        noise_model = NoiseModel()
        add_noise!(noise_model, PauliChannel(0.01, 0.02, 0.03), GateCriteria(I, [0, 1]))
        add_noise!(noise_model, Depolarizing(0.04), GateCriteria(H))
        add_noise!(noise_model, Depolarizing(0.05), GateCriteria(CNot, [0, 1]))
        add_noise!(noise_model, PauliChannel(0.06, 0.07, 0.08), GateCriteria(H, [0, 1]))
        add_noise!(noise_model, BitFlip(0.01), UnitaryGateCriteria(Unitary(h_unitary()), 0))
        add_noise!(noise_model, PhaseFlip(0.02), ObservableCriteria(Observables.Y, 1))
        serialized_model = Dict(noise_model)

        deserialized_model = NoiseModel(serialized_model)
        @test length(deserialized_model.instructions) == length(noise_model.instructions)
        for (idx, deserialized_item) in enumerate(deserialized_model.instructions)
            @test noise_model.instructions[idx].noise == deserialized_item.noise
            @test noise_model.instructions[idx].criteria == deserialized_item.criteria
        end
        @test !isnothing(deserialized_model)
    end
    @testset "apply" begin
        noise_model = NoiseModel()
        add_noise!(noise_model, PauliChannel(0.01, 0.02, 0.03), GateCriteria(I, [0, 1]))
        add_noise!(noise_model, Depolarizing(0.04), GateCriteria(H))
        add_noise!(noise_model, TwoQubitDepolarizing(0.05), GateCriteria(CNot, [0, 1]))
        add_noise!(noise_model, PauliChannel(0.06, 0.07, 0.08), GateCriteria(H, [0, 1]))
        add_noise!(noise_model, Depolarizing(0.10), UnitaryGateCriteria(Unitary(h_unitary()), 0))
        add_noise!(noise_model, Depolarizing(0.06), ObservableCriteria(Observables.Z, 0))
        add_noise!(noise_model, Depolarizing(0.09), QubitInitializationCriteria(0))
        layer1 = Sample(CNot(H(Circuit(), 0), 0, 1), Observables.Z(), 0)
        layer2 = Unitary(Circuit(), 0, h_unitary())
        circuit = append!(layer1, layer2)
        noisy_circuit_from_circuit = circuit(noise_model)
        expected_circuit = CNot(PauliChannel(Depolarizing(H(Depolarizing(Circuit(), 0, 0.09), 0), 0, 0.04), 0, 0.06, 0.07, 0.08), 0, 1)
        expected_circuit = Depolarizing(Unitary(TwoQubitDepolarizing(expected_circuit, 0, 1, 0.05), 0, h_unitary()), 0, 0.10)
        Braket.apply_readout_noise!(expected_circuit, Depolarizing(0.06), [0])
        expected_circuit = Sample(expected_circuit, Observables.Z(), 0)
        @test noisy_circuit_from_circuit.instructions == expected_circuit.instructions
        @test noisy_circuit_from_circuit.result_types == expected_circuit.result_types
    end
    @testset for problem_set in [
        (
            # model with noise on all gates
            add_noise!(NoiseModel(), Depolarizing(0.01), GateCriteria()),
            # input circuit
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has noise on all gates
            Depolarizing(Depolarizing(CNot(Depolarizing(H(Circuit(), 0), 0, 0.01), 0, 1), 0, 0.01), 1, 0.01)
        ),
        (
            # model with noise on H(0)
            add_noise!(NoiseModel(), Depolarizing(0.01), GateCriteria(H, 0)),
            # input circuit has an H gate on qubit 0
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has noise on qubit 0
            CNot(Depolarizing(H(Circuit(), 0), 0, 0.01), 0, 1)
        ),
        (
            # model with noise on H(0)
            add_noise!(NoiseModel(), Depolarizing(0.01), GateCriteria(H, 0)),
            # input circuit has two H gates on qubit 0
            CNot(H(H(Circuit(), 0), 0), 0, 1),
            # expected circuit has noise on qubit 0
            CNot(Depolarizing(H(Depolarizing(H(Circuit(), 0), 0, 0.01), 0), 0, 0.01), 0, 1)
        ),
        (
            # model with noise on all gates, on qubits 0, 1
            add_noise!(NoiseModel(), Depolarizing(0.01), GateCriteria(nothing, [0, 1])),
            # input circuit
            CNot(H(H(Circuit(), 0), 1), 0, 1),
            # expected circuit has noise on qubit 0
            CNot(Depolarizing(H(Depolarizing(H(Circuit(), 0), 0, 0.01), 1), 1, 0.01), 0, 1)
        ),
        (
            # model with noise on all gates, on qubits [0, 1]
            add_noise!(NoiseModel(), Depolarizing(0.01), GateCriteria(nothing, [[0, 1]])),
            # input circuit
            CNot(H(H(Circuit(), 0), 1), 0, 1),
            # expected circuit has noise on the CNot gate
            Depolarizing(Depolarizing(CNot(H(H(Circuit(), 0), 1), 0, 1), 0, 0.01), 1, 0.01)
        ),
        (
            # model with noise on all gates, on qubits [0, 1]
            add_noise!(NoiseModel(), TwoQubitDepolarizing(0.01), GateCriteria(nothing, [[0, 1]])),
            # input circuit
            CNot(H(H(Circuit(), 0), 1), 0, 1),
            # expected circuit has noise on the CNot gate
            TwoQubitDepolarizing(CNot(H(H(Circuit(), 0), 1), 0, 1), 0, 1, 0.01)
        ),
        (
            # model with noise on a unitary H(0)
            add_noise!(NoiseModel(), Depolarizing(0.01), UnitaryGateCriteria(Unitary(h_unitary()), 0)),
            # input circuit has a unitary H gate on qubit 0
            CNot(Unitary(Circuit(), 0, h_unitary()), 0, 1),
            # expected circuit has noise on qubit 0
            CNot(Depolarizing(Unitary(Circuit(), 0, h_unitary()), 0, 0.01), 0, 1),
        ),
        (
            # model
            add_noise!(NoiseModel(), Depolarizing(0.01), QubitInitializationCriteria(0)),
            # input circuit has no explicit observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no noise applied
            CNot(H(Depolarizing(Circuit(), 0, 0.01), 0), 0, 1),
        ),
        (
            # model
            add_noise!(NoiseModel(), Depolarizing(0.01), QubitInitializationCriteria([0, 1])),
            # input circuit has no explicit observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no noise applied
            CNot(H(Depolarizing(Depolarizing(Circuit(), 0, 0.01), 1, 0.01), 0), 0, 1),
        ),
        (
            # model
            NoiseModel(),
            # input circuit has no explicit observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no noise applied
            CNot(H(Circuit(), 0), 0, 1),
        ),
        (
            # model has observable criteria only on one qubit
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.Z, 0)),
            # input circuit has no explicit observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no noise applied
            CNot(H(Circuit(), 0), 0, 1),
        ),
        (
            # model
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.Z, nothing)),
            # input circuit has explicit explicit observables
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.Z(), 0),
            # expected circuit has noise applied
            Sample(Depolarizing(CNot(H(Circuit(), 0), 0, 1), 0, 0.01), Observables.Z(), 0),
        ),
        (
            # model
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.X, 0)),
            # input circuit doesn't contain observable X
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no change.
            CNot(H(Circuit(), 0), 0, 1),
        ),
        (
            # model
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.X, 0)),
            # input circuit contains observable X
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
            # expected circuit noise applied.
            Sample(Depolarizing(CNot(H(Circuit(), 0), 0, 1), 0, 0.01), Observables.X(), 0),
        ),
        (
            # model only has an observable on Z
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.Z, 0)),
            # input circuit contains observable X
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
            # expected circuit has no change
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
        ),
        (
            # model has observables on both X and Z
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria([Observables.X, Observables.Z], 0)),
            # input circuit contains observable X
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
            # expected circuit has noise applied
            Sample(Depolarizing(CNot(H(Circuit(), 0), 0, 1), 0, 0.01), Observables.X(), 0),
        ),
        (
            # model uses qubit criteria
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(nothing, nothing)),
            # input circuit doesn't contain observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no noise applied
            CNot(H(Circuit(), 0), 0, 1),
        ),
        (
            # model uses qubit criteria on non-related qubits
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(nothing, [2, 3])),
            # input circuit doesn't contain observables
            CNot(H(Circuit(), 0), 0, 1),
            # expected circuit has no change
            CNot(H(Circuit(), 0), 0, 1),
        ),
        (
            # model uses qubit criteria
            add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(nothing, [0, 1])),
            # input circuit contains observable X
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
            # expected circuit noise applied.
            Sample(Depolarizing(CNot(H(Circuit(), 0), 0, 1), 0, 0.01), Observables.X(), 0),
        ),
        (
            # model uses observable and qubit criteria
            add_noise!(add_noise!(NoiseModel(), Depolarizing(0.01), ObservableCriteria(Observables.X, 0)), Depolarizing(0.02), ObservableCriteria(nothing, [0, 1])),
            # input circuit contains observable X
            Sample(CNot(H(Circuit(), 0), 0, 1), Observables.X(), 0),
            # expected circuit noise applied.
            Sample(Depolarizing(Depolarizing(CNot(H(Circuit(), 0), 0, 1), 0, 0.01), 0, 0.02), Observables.X(), 0),
        ),
        (
            # model uses observable criteria with any observable/qubit.
            add_noise!(NoiseModel(), BitFlip(0.01), ObservableCriteria(nothing, nothing)),
            # input circuit contains many different types of result types for qubit 0
            Variance(Sample(Expectation(Probability(Probability(CNot(H(Circuit(), 0), 0, 1), [0, 1]), [0]), Observables.Z(), 0), Observables.X(), 0), Observables.Z(), 0),
            # expected circuit only applies BitFlip once to qubit 0
            Braket.apply_readout_noise!(Variance(Sample(Expectation(Probability(Probability(CNot(H(Circuit(), 0), 0, 1), [0, 1]), [0]), Observables.Z(), 0), Observables.X(), 0), Observables.Z(), 0), BitFlip(0.01), [0])
        ),
        (
            # model uses observable criteria with any observable/qubit.
            add_noise!(NoiseModel(), BitFlip(0.01), ObservableCriteria(nothing, nothing)),
            # input circuit only has a probability result type
            Probability(Probability(CNot(H(Circuit(), 0), 0, 1), [0, 1]), [0]),
            # expected circuit has no noise applied
            Probability(Probability(CNot(H(Circuit(), 0), 0, 1), [0, 1]), [0])
        ),

    ]
        noise_model, input_circuit, expected_circuit = problem_set
        result_circuit = Braket.apply(noise_model, input_circuit)
        @test result_circuit.instructions == expected_circuit.instructions
        @test result_circuit == expected_circuit
    end
end
