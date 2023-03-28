suite["noise"] = BenchmarkGroup(["initialization", "model", "gate_noise"])
suite["noise"]["gate_noise"] = BenchmarkGroup(["depth_10", "depth_50", "depth_1000"])
suite["noise"]["model"]      = BenchmarkGroup(["depth_10", "depth_50", "depth_1000"])

suite["noise"]["initialization"] = @benchmarkable Braket.apply_initialization_noise!(c, BitFlip(0.2), [2, 3]) setup=(c=Circuit(circ_list_gen(10)))

suite["noise"]["gate_noise"]["depth_10"]   = @benchmarkable Braket.apply_gate_noise!(c, BitFlip(0.2)) setup=(c=Circuit(circ_list_gen(10)))
suite["noise"]["gate_noise"]["depth_50"]   = @benchmarkable Braket.apply_gate_noise!(c, BitFlip(0.2)) setup=(c=Circuit(circ_list_gen(50)))
suite["noise"]["gate_noise"]["depth_1000"] = @benchmarkable Braket.apply_gate_noise!(c, BitFlip(0.2)) setup=(c=Circuit(circ_list_gen(1000)))

function gen_noise_model()
    nm = Braket.NoiseModel()
    Braket.add_noise!(nm, BitFlip(0.1), Braket.GateCriteria(Rx))
    Braket.add_noise!(nm, PhaseFlip(0.1), Braket.GateCriteria(Ry))
    Braket.add_noise!(nm, AmplitudeDamping(0.1), Braket.GateCriteria(Rz))
    return nm
end

suite["noise"]["model"]["depth_10"]   = @benchmarkable Braket.apply(nm, c) setup=(c=Circuit(circ_list_gen(10)); nm=gen_noise_model())
suite["noise"]["model"]["depth_50"]   = @benchmarkable Braket.apply(nm, c) setup=(c=Circuit(circ_list_gen(50)); nm=gen_noise_model())
suite["noise"]["model"]["depth_1000"] = @benchmarkable Braket.apply(nm, c) setup=(c=Circuit(circ_list_gen(1000)); nm=gen_noise_model())
