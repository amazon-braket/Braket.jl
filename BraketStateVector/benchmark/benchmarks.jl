using BraketStateVector, Braket, PythonCall, BenchmarkTools


suite = BenchmarkGroup()
suite["gates"] = BenchmarkGroup()
suite["noise"] = BenchmarkGroup()
for gate in [
    "H",
    "X",
    "Y",
    "Z",
    "V",
    "Vi",
    "T",
    "Ti",
    "S",
    "Si",
    "Rx",
    "Ry",
    "Rz",
    "PhaseShift",
    "CNot",
    "CY",
    "CZ",
    "CV",
    "XX",
    "XY",
    "YY",
    "ZZ",
    "ECR",
    "Swap",
    "ISwap",
    "PSwap",
    "CCNot",
    "CSwap",
    "CPhaseShift",
    "CPhaseShift00",
    "CPhaseShift01",
    "CPhaseShift10",
]
    suite["gates"][gate] = BenchmarkGroup()
end
for noise in [
    "BitFlip",
    "PhaseFlip",
    "Depolarizing",
    "PauliChannel",
    "AmplitudeDamping",
    "GeneralizedAmplitudeDamping",
    "PhaseDamping",
    "TwoQubitDepolarizing",
    "TwoQubitPauliChannel",
    "TwoQubitDephasing",
    "Kraus",
]
    suite["noise"][noise] = BenchmarkGroup()
end
gate_operations = pyimport("braket.default_simulator.gate_operations")
noise_operations = pyimport("braket.default_simulator.noise_operations")
local_sv = pyimport("braket.default_simulator.state_vector_simulation")
local_dm = pyimport("braket.default_simulator.density_matrix_simulation")
for n_qubits = 4:2:28
    n_amps = 2^n_qubits
    angle = π / 3.5
    for (gate_str, gate, py_gate) in zip(
        ["H", "X", "Y", "Z", "V", "Vi", "T", "Ti", "S", "Si"],
        [H(), X(), Y(), Z(), V(), Vi(), T(), Ti(), S(), Si()],
        [
            [gate_operations.Hadamard([0])],
            [gate_operations.PauliX([0])],
            [gate_operations.PauliY([0])],
            [gate_operations.PauliZ([0])],
            [gate_operations.V([0])],
            [gate_operations.Vi([0])],
            [gate_operations.T([0])],
            [gate_operations.Ti([0])],
            [gate_operations.S([0])],
            [gate_operations.Si([0])],
        ],
    )
        suite["gates"][gate_str][(string(n_qubits), string(0), "Julia")] =
            @benchmarkable BraketStateVector.apply_gate!($gate, sv, 0) setup =
                (sv = zeros(ComplexF64, $n_amps))
        suite["gates"][gate_str][(string(n_qubits), string(0), "Python")] =
            @benchmarkable py_sv.evolve($py_gate) setup =
                (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1))
    end
    for (gate_str, gate, py_gate) in zip(
        ["Rx", "Ry", "Rz", "PhaseShift"],
        [Rx(angle), Ry(angle), Rz(angle), PhaseShift(angle)],
        [
            gate_operations.RotX([0], angle),
            gate_operations.RotY([0], angle),
            gate_operations.RotZ([0], angle),
            gate_operations.PhaseShift([0], angle),
        ],
    )
        suite["gates"][gate_str][(string(n_qubits), string(0), "Julia")] =
            @benchmarkable BraketStateVector.apply_gate!($gate, sv, 0) setup =
                (sv = zeros(ComplexF64, $n_amps))
        suite["gates"][gate_str][(string(n_qubits), string(0), "Python")] =
            @benchmarkable py_sv.evolve([$py_gate]) setup =
                (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1))
    end
    for (gate_str, gate, py_gate) in zip(
        [
            "XX",
            "XY",
            "YY",
            "ZZ",
            "CPhaseShift",
            "CPhaseShift00",
            "CPhaseShift10",
            "CPhaseShift01",
            "PSwap",
        ],
        [
            XX(angle),
            XY(angle),
            YY(angle),
            ZZ(angle),
            CPhaseShift(angle),
            CPhaseShift00(angle),
            CPhaseShift10(angle),
            CPhaseShift01(angle),
            PSwap(angle),
        ],
        [
            gate_operations.XX([0, 1], angle),
            gate_operations.XY([0, 1], angle),
            gate_operations.YY([0, 1], angle),
            gate_operations.ZZ([0, 1], angle),
            gate_operations.CPhaseShift([0, 1], angle),
            gate_operations.CPhaseShift00([0, 1], angle),
            gate_operations.CPhaseShift10([0, 1], angle),
            gate_operations.CPhaseShift01([0, 1], angle),
            gate_operations.PSwap([0, 1], angle),
        ],
    )
        suite["gates"][gate_str][(string(n_qubits), string(0), string(1), "Julia")] =
            @benchmarkable BraketStateVector.apply_gate!($gate, sv, 0, 1) setup =
                (sv = zeros(ComplexF64, $n_amps))
        suite["gates"][gate_str][(string(n_qubits), string(0), string(1), "Python")] =
            @benchmarkable py_sv.evolve([$py_gate]) setup =
                (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1))
    end
    for (gate_str, gate, py_gate) in zip(
        ["CNot", "CY", "CZ", "CV", "Swap", "ISwap", "ECR"],
        [CNot(), CY(), CZ(), CV(), Swap(), ISwap(), ECR()],
        [
            gate_operations.CX([0, 1]),
            gate_operations.CY([0, 1]),
            gate_operations.CZ([0, 1]),
            gate_operations.CV([0, 1]),
            gate_operations.Swap([0, 1]),
            gate_operations.ISwap([0, 1]),
            gate_operations.ECR([0, 1]),
        ],
    )
        suite["gates"][gate_str][(string(n_qubits), string(0), string(1), "Julia")] =
            @benchmarkable BraketStateVector.apply_gate!($gate, sv, 0, 1) setup =
                (sv = zeros(ComplexF64, $n_amps))
        suite["gates"][gate_str][(string(n_qubits), string(0), string(1), "Python")] =
            @benchmarkable py_sv.evolve([$py_gate]) setup =
                (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1))
    end
    for (gate_str, gate, py_gate) in zip(
        ["CCNot", "CSwap"],
        [CCNot(), CSwap()],
        [gate_operations.CCNot([0, 1, 2]), gate_operations.CSwap([0, 1, 2])],
    )
        suite["gates"][gate_str][(
            string(n_qubits),
            string(0),
            string(1),
            string(2),
            "Julia",
        )] = @benchmarkable BraketStateVector.apply_gate!($gate, sv, 0, 1, 2) setup =
            (sv = zeros(ComplexF64, $n_amps))
        suite["gates"][gate_str][(
            string(n_qubits),
            string(0),
            string(1),
            string(2),
            "Python",
        )] = @benchmarkable py_sv.evolve([$py_gate]) setup =
            (py_sv = local_sv.StateVectorSimulation($n_qubits, 0, 1))
    end
end

for n_qubits = 2:2:14
    n_amps = 2^n_qubits
    prob = 0.1
    gamma = 0.2
    for (noise_str, noise, py_noise) in zip(
        ["BitFlip", "PhaseFlip", "Depolarizing", "AmplitudeDamping", "PhaseDamping"],
        [
            BitFlip(prob),
            PhaseFlip(prob),
            Depolarizing(prob),
            AmplitudeDamping(prob),
            PhaseDamping(prob),
        ],
        [
            noise_operations.BitFlip([0], prob),
            noise_operations.PhaseFlip([0], prob),
            noise_operations.Depolarizing([0], prob),
            noise_operations.AmplitudeDamping([0], prob),
            noise_operations.PhaseDamping([0], prob),
        ],
    )
        suite["noise"][noise_str][(string(n_qubits), string(0), "Julia")] =
            @benchmarkable BraketStateVector.apply_noise!($noise, dm, 0) setup =
                (dm = zeros(ComplexF64, $n_amps, $n_amps))
        suite["noise"][noise_str][(string(n_qubits), string(0), "Python")] =
            @benchmarkable py_sv.evolve([$py_noise]) setup =
                (py_sv = local_dm.DensityMatrixSimulation($n_qubits, 0))
    end
    for (noise_str, noise, py_noise) in zip(
        ["TwoQubitDepolarizing", "TwoQubitDephasing"],
        [TwoQubitDepolarizing(prob), TwoQubitDephasing(prob)],
        [
            noise_operations.TwoQubitDepolarizing([0, 1], prob),
            noise_operations.TwoQubitDephasing([0, 1], prob),
        ],
    )
        suite["noise"][noise_str][(string(n_qubits), string(0), string(1), "Julia")] =
            @benchmarkable BraketStateVector.apply_noise!($noise, dm, 0, 1) setup =
                (dm = zeros(ComplexF64, $n_amps, $n_amps))
        suite["noise"][noise_str][(string(n_qubits), string(0), string(1), "Python")] =
            @benchmarkable py_sv.evolve([$py_noise]) setup =
                (py_sv = local_dm.DensityMatrixSimulation($n_qubits, 0))
    end
    suite["noise"]["GeneralizedAmplitudeDamping"][(string(n_qubits), string(0), "Julia")] =
        @benchmarkable BraketStateVector.apply_noise!(
            GeneralizedAmplitudeDamping($prob, $gamma),
            dm,
            0,
        ) setup = (dm = zeros(ComplexF64, $n_amps, $n_amps))
    suite["noise"]["GeneralizedAmplitudeDamping"][(string(n_qubits), string(0), "Python")] =
        @benchmarkable py_sv.evolve([
            noise_operations.GeneralizedAmplitudeDamping([0], $prob, $gamma),
        ]) setup = (py_sv = local_dm.DensityMatrixSimulation($n_qubits, 0))
    suite["noise"]["PauliChannel"][(string(n_qubits), string(0), "Julia")] =
        @benchmarkable BraketStateVector.apply_noise!(
            PauliChannel($prob, $gamma, 0.0),
            dm,
            0,
        ) setup = (dm = zeros(ComplexF64, $n_amps, $n_amps))
    suite["noise"]["PauliChannel"][(string(n_qubits), string(0), "Python")] =
        @benchmarkable py_sv.evolve([
            noise_operations.PauliChannel(
                targets = [0],
                probX = $prob,
                probY = $gamma,
                probZ = 0.0,
            ),
        ]) setup = (py_sv = local_dm.DensityMatrixSimulation($n_qubits, 0))
end
#tune!(suite)
#BenchmarkTools.save("params.json", params(suite));
loadparams!(suite, BenchmarkTools.load("params.json")[1], :evals, :samples);
results = run(suite, verbose = true)
BenchmarkTools.save("results.json", results)
