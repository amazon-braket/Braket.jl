suite["circuit"] = BenchmarkGroup(["construction", "append", "add_result_type", "basis_rotation_instructions", "ir"])

suite["circuit"]["construction"] = BenchmarkGroup(["depth_10", "depth_50", "depth_1000"])
suite["circuit"]["append"]       = BenchmarkGroup(["depth_10", "depth_50", "depth_1000"])
suite["circuit"]["ir"]           = BenchmarkGroup(["depth_10", "depth_50", "depth_1000"])


suite["circuit"]["add_result_type"] = BenchmarkGroup(["Sum", "Probability", "TensorProduct"])
suite["circuit"]["basis_rotation_instructions"] = BenchmarkGroup(["Z", "Probability", "TensorProduct"])

suite["circuit"]["construction"]["depth_10"]   = @benchmarkable Circuit(g) setup=(g=circ_list_gen(10))
suite["circuit"]["construction"]["depth_50"]   = @benchmarkable Circuit(g) setup=(g=circ_list_gen(50))
suite["circuit"]["construction"]["depth_1000"] = @benchmarkable Circuit(g) setup=(g=circ_list_gen(1000))

suite["circuit"]["append"]["depth_10"]   = @benchmarkable c1(c2) setup=(c1=Circuit(circ_list_gen(10)); c2=Circuit(circ_list_gen(10)))
suite["circuit"]["append"]["depth_50"]   = @benchmarkable c1(c2) setup=(c1=Circuit(circ_list_gen(50)); c2=Circuit(circ_list_gen(10)))
suite["circuit"]["append"]["depth_1000"] = @benchmarkable c1(c2) setup=(c1=Circuit(circ_list_gen(1000)); c2=Circuit(circ_list_gen(10)))

suite["circuit"]["ir"]["depth_10"]   = @benchmarkable ir(c, Val(:OpenQASM)) setup=(c=Circuit(circ_list_gen(10)))
suite["circuit"]["ir"]["depth_50"]   = @benchmarkable ir(c, Val(:OpenQASM)) setup=(c=Circuit(circ_list_gen(50)))
suite["circuit"]["ir"]["depth_1000"] = @benchmarkable ir(c, Val(:OpenQASM)) setup=(c=Circuit(circ_list_gen(1000)))

tp1 = Braket.Observables.X() * Braket.Observables.Y() * Braket.Observables.Z() 
tp2 = Braket.Observables.Z() * Braket.Observables.Y() * Braket.Observables.Z() 
suite["circuit"]["add_result_type"]["Probability"]   = @benchmarkable c(Probability()) setup=(c=Circuit(circ_list_gen(10)))
suite["circuit"]["add_result_type"]["Sum"]           = @benchmarkable c(Expectation, 2.0 * $tp1 - 3.0 * $tp2, [2, 3, 5]) setup=(c=Circuit(circ_list_gen(10)))
suite["circuit"]["add_result_type"]["TensorProduct"] = @benchmarkable c(Expectation, $tp1, [2, 3, 5]) setup=(c=Circuit(circ_list_gen(10)))

suite["circuit"]["basis_rotation_instructions"]["Probability"]   = @benchmarkable Braket.basis_rotation_instructions!(c) setup=(c=Circuit(circ_list_gen(10)); c(Probability,))
suite["circuit"]["basis_rotation_instructions"]["Z"]             = @benchmarkable Braket.basis_rotation_instructions!(c) setup=(c=Circuit(circ_list_gen(10)); c(Expectation, Braket.Observables.Z(), 1))
suite["circuit"]["basis_rotation_instructions"]["TensorProduct"] = @benchmarkable Braket.basis_rotation_instructions!(c) setup=(c=Circuit(circ_list_gen(10)); c(Expectation, $tp1, [2, 3, 5]))
