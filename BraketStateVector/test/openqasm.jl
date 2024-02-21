using Test, Statistics, LinearAlgebra, BraketStateVector.OpenQASM3, BraketStateVector, Braket, Braket.Observables

using Braket: Instruction

get_tol(shots::Int) = return (
    shots > 0 ? Dict("atol" => 0.1, "rtol" => 0.15) : Dict("atol" => 0.01, "rtol" => 0)
)
@testset "OpenQASM" begin
    qasm_str = """
    OPENQASM 3.0;
    def bell(qubit q0, qubit q1) {
        h q0;
        cnot q0, q1;
    }
    def n_bells(int[32] n, qubit q0, qubit q1) {
        for int i in [0:n - 1] {
            h q0;
            cnot q0, q1;
        }
    }
    qubit[4] __qubits__;
    bell(__qubits__[0], __qubits__[1]);
    n_bells(5, __qubits__[2], __qubits__[3]);
    bit[4] __bit_0__ = "0000";
    __bit_0__[0] = measure __qubits__[0];
    __bit_0__[1] = measure __qubits__[1];
    __bit_0__[2] = measure __qubits__[2];
    __bit_0__[3] = measure __qubits__[3];
    """
    braket_circ = Circuit([(H, 0), (CNot, 0, 1), (H, 2), (CNot, 2, 3),  (H, 2), (CNot, 2, 3),  (H, 2), (CNot, 2, 3),  (H, 2), (CNot, 2, 3),  (H, 2), (CNot, 2, 3)])
    parsed_circ = BraketStateVector.interpret(BraketStateVector.OpenQASM3.parse(qasm_str), extern_lookup=Dict("theta"=>0.2))
    @test ir(parsed_circ, Val(:JAQCD)) == Braket.Program(braket_circ)
    @testset "Parsing Hermitian observables" begin
        three_qubit_circuit(
            θ::Float64,
            ϕ::Float64,
            φ::Float64,
            obs::Braket.Observables.Observable,
            obs_targets::Vector{Int},
        ) = Circuit([
            (Rx, 0, θ),
            (Rx, 1, ϕ),
            (Rx, 2, φ),
            (CNot, 0, 1),
            (CNot, 1, 2),
            (Variance, obs, obs_targets),
            (Expectation, obs, obs_targets),
            (Sample, obs, obs_targets),
        ])
        θ = 0.432
        ϕ = 0.123
        φ = -0.543
        obs_targets = [0, 1, 2]
        ho_mat = [
            -6 2+im -3 -5+2im
            2-im 0 2-im -5+4im
            -3 2+im 0 -4+3im
            -5-2im -5-4im -4-3im -6
        ]
        ho_mat2 = [1 2; 2 4]
        ho_mat3 = [-6 2+im; 2-im 0]
        ho_mat4 = kron([1 0; 0 1], [-6 2+im; 2-im 0])
        ho  = Braket.Observables.HermitianObservable(ComplexF64.(ho_mat))
        ho2 = Braket.Observables.HermitianObservable(ComplexF64.(ho_mat2))
        ho3 = Braket.Observables.HermitianObservable(ComplexF64.(ho_mat3))
        ho4 = Braket.Observables.HermitianObservable(ComplexF64.(ho_mat4))
        meani = -5.7267957792059345
        meany = 1.4499810303182408
        meanz =
            0.5 * (
                -6 * cos(θ) * (cos(φ) + 1) -
                2 * sin(φ) * (cos(θ) + sin(ϕ) - 2 * cos(ϕ)) +
                3 * cos(φ) * sin(ϕ) +
                sin(ϕ)
            )
        meanh = -4.30215023196904
        meanii = -5.78059066879935

        vari = 43.33800156673375
        vary = 74.03174647518193
        varz =
            (
                1057 - cos(2ϕ) + 12 * (27 + cos(2ϕ)) * cos(φ) -
                2 * cos(2φ) * sin(ϕ) * (16 * cos(ϕ) + 21 * sin(ϕ)) + 16 * sin(2ϕ) -
                8 * (-17 + cos(2ϕ) + 2 * sin(2ϕ)) * sin(φ) -
                8 * cos(2θ) * (3 + 3 * cos(φ) + sin(φ))^2 -
                24 * cos(ϕ) * (cos(ϕ) + 2 * sin(ϕ)) * sin(2φ) -
                8 *
                cos(θ) *
                (
                    4 *
                    cos(ϕ) *
                    (4 + 8 * cos(φ) + cos(2φ) - (1 + 6 * cos(φ)) * sin(φ)) +
                    sin(ϕ) *
                    (15 + 8 * cos(φ) - 11 * cos(2φ) + 42 * sin(φ) + 3 * sin(2φ))
                )
            ) / 16
        varh = 370.71292282796804
        varii = 6.268315532585994

        i_array = [1 0; 0 1]
        y_array = [0 -im; im 0]
        z_array = diagm([1, -1])
        eigsi   = eigvals(kron(i_array, ho_mat))
        eigsy   = eigvals(kron(y_array, ho_mat))
        eigsz   = eigvals(kron(z_array, ho_mat))
        eigsh   = [-70.90875406, -31.04969387, 0, 3.26468993, 38.693758]
        eigsii  = eigvals(kron(i_array, kron(i_array, ho_mat3)))
        d       = LocalSimulator("braket_sv")
        @testset "Obs $obs" for (obs, expected_mean, expected_var, expected_eigs) in
                                [
            (Observables.I() * ho, meani, vari, eigsi),
            (Observables.Y() * ho, meany, vary, eigsy),
            (Observables.Z() * ho, meanz, varz, eigsz),
            (ho2 * ho, meanh, varh, eigsh),
            (
                Observables.HermitianObservable(kron(ho_mat2, ho_mat)),
                meanh,
                varh,
                eigsh,
            ),
            (Observables.I() * Observables.I() * ho3, meanii, varii, eigsii),
            (Observables.I() * ho4, meanii, varii, eigsii),
        ]
            circuit    = three_qubit_circuit(θ, ϕ, φ, obs, obs_targets)
            Braket.basis_rotation_instructions!(circuit)
            oq3_circ   = ir(circuit, Val(:OpenQASM))
            jaqcd_circ = ir(circuit, Val(:JAQCD))
            @testset "Simulator $sim" for sim in (StateVectorSimulator,) 
                shots = 8000
                tol   = get_tol(shots)
                j_simulation = sim(qubit_count(circuit), shots)
                p_simulation = sim(qubit_count(circuit), shots)
                parsed_circ = BraketStateVector.parse_program(p_simulation, oq3_circ)
                @test length(parsed_circ.instructions) == length(jaqcd_circ.instructions) 
                for (p_ix, j_ix) in zip(parsed_circ.instructions, jaqcd_circ.instructions)
                    @test p_ix == j_ix
                end
                @test length(parsed_circ.basis_rotation_instructions) == length(jaqcd_circ.basis_rotation_instructions) 
                for (p_ix, j_ix) in zip(parsed_circ.basis_rotation_instructions, jaqcd_circ.basis_rotation_instructions)
                    @test p_ix == j_ix
                end
                @test length(parsed_circ.results) == length(jaqcd_circ.results) 
                for (p_rt, j_rt) in zip(parsed_circ.results, jaqcd_circ.results)
                    @test p_rt == j_rt
                end
                for (p_ix, j_ix) in zip(parsed_circ.instructions, jaqcd_circ.instructions)
                    j_simulation = evolve!(j_simulation, [j_ix])
                    p_simulation = evolve!(p_simulation, [p_ix])
                    @test j_simulation.state_vector ≈ p_simulation.state_vector
                end
                formatted_measurements = [rand(0:1, 3) for s in 1:shots]
                measured_qubits        = [0, 1, 2]
                j_bundled       = BraketStateVector._bundle_results(Braket.ResultTypeValue[], jaqcd_circ, j_simulation)
                p_rtv           = [Braket.ResultTypeValue(rt, 0.0) for rt in jaqcd_circ.results]
                p_bundled       = BraketStateVector._bundle_results(p_rtv, oq3_circ, p_simulation)
                @test j_bundled.measuredQubits == measured_qubits
                @test p_bundled.measuredQubits == measured_qubits
                # test with pre-computed measurements
                new_j_bundled = Braket.GateModelTaskResult(j_bundled.braketSchemaHeader, formatted_measurements, nothing, j_bundled.resultTypes, j_bundled.measuredQubits, j_bundled.taskMetadata, j_bundled.additionalMetadata)
                new_p_bundled = Braket.GateModelTaskResult(p_bundled.braketSchemaHeader, formatted_measurements, nothing, p_bundled.resultTypes, p_bundled.measuredQubits, p_bundled.taskMetadata, p_bundled.additionalMetadata)

                j_formatted = Braket.computational_basis_sampling(Braket.GateModelQuantumTaskResult, new_j_bundled)
                p_formatted = Braket.computational_basis_sampling(Braket.GateModelQuantumTaskResult, new_p_bundled)
                for (j_v, p_v) in zip(j_formatted.values, p_formatted.values)
                    @test j_v == p_v
                end
            end
        end
        @testset "Builtin functions" begin
            qasm = """
                const float[64] arccos_result = arccos(1);
                const float[64] arcsin_result = arcsin(1);
                const float[64] arctan_result = arctan(1);
                const int[64] ceiling_result = ceiling(π);
                const float[64] cos_result = cos(1);
                const float[64] exp_result = exp(2);
                const int[64] floor_result = floor(π);
                const float[64] log_result = log(ℇ);
                const int[64] mod_int_result = mod(4, 3);
                const float[64] mod_float_result = mod(5.2, 2.5);
                const int[64] popcount_bit_result = popcount("1001110");
                const int[64] popcount_int_result = popcount(78);
                // parser gets confused by pow
                // const int[64] pow_int_result = pow(3, 3);
                // const float[64] pow_float_result = pow(2.5, 2.5);
                // add rotl, rotr
                const float[64] sin_result = sin(1);
                const float[64] sqrt_result = sqrt(2);
                const float[64] tan_result = tan(1);
                """
            parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm) 
            global_ctx = BraketStateVector.QASMGlobalContext{Braket.Operator}(Dict{String,Float64}())
            wo = BraketStateVector.WalkerOutput()
            BraketStateVector.interpret!(wo, parsed_qasm, global_ctx)
            @test global_ctx.definitions["arccos_result"].value == acos(1)
            @test global_ctx.definitions["arcsin_result"].value == asin(1)
            @test global_ctx.definitions["arctan_result"].value == atan(1)
            @test global_ctx.definitions["ceiling_result"].value == 4
            @test global_ctx.definitions["cos_result"].value == cos(1)
            @test global_ctx.definitions["exp_result"].value == exp(2)
            @test global_ctx.definitions["floor_result"].value == 3
            @test global_ctx.definitions["log_result"].value == 1
            @test global_ctx.definitions["mod_int_result"].value == 1
            @test global_ctx.definitions["mod_float_result"].value == mod(5.2, 2.5)
            @test global_ctx.definitions["popcount_bit_result"].value == 4
            @test global_ctx.definitions["popcount_int_result"].value == 4
            @test global_ctx.definitions["sin_result"].value == sin(1)
            @test global_ctx.definitions["sqrt_result"].value == sqrt(2)
            @test global_ctx.definitions["tan_result"].value == tan(1)

            @testset "Symbolic" begin
                qasm = """
                    input float x;
                    input float y;
                    rx(x) \$0;
                    rx(arccos(x)) \$0;
                    rx(arcsin(x)) \$0;
                    rx(arctan(x)) \$0; 
                    rx(ceiling(x)) \$0;
                    rx(cos(x)) \$0;
                    rx(exp(x)) \$0;
                    rx(floor(x)) \$0;
                    rx(log(x)) \$0;
                    rx(mod(x, y)) \$0;
                    rx(sin(x)) \$0;
                    rx(sqrt(x)) \$0;
                    rx(tan(x)) \$0;
                    """
                parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
                x = 1.0
                y = 2.0
                inputs      = Dict("x"=>x, "y"=>y)
                circuit     = BraketStateVector.interpret(parsed_qasm, extern_lookup=inputs)
                ixs = [Braket.Instruction(Rx(x), 0),  
                       Braket.Instruction(Rx(acos(x)), 0),  
                       Braket.Instruction(Rx(asin(x)), 0),  
                       Braket.Instruction(Rx(atan(x)), 0),  
                       Braket.Instruction(Rx(ceil(x)), 0),  
                       Braket.Instruction(Rx(cos(x)), 0),  
                       Braket.Instruction(Rx(exp(x)), 0),  
                       Braket.Instruction(Rx(floor(x)), 0),  
                       Braket.Instruction(Rx(log(x)), 0),  
                       Braket.Instruction(Rx(mod(x, y)), 0),  
                       Braket.Instruction(Rx(sin(x)), 0),  
                       Braket.Instruction(Rx(sqrt(x)), 0),  
                       Braket.Instruction(Rx(tan(x)), 0)]
                c = Circuit()
                for ix in ixs
                    Braket.add_instruction!(c, ix)
                end
                @test circuit == c
            end
        end
        @testset "Noise" begin
            qasm = """
            qubit[2] qs;

            #pragma braket noise bit_flip(.5) qs[1]
            #pragma braket noise phase_flip(.5) qs[0]
            #pragma braket noise pauli_channel(.1, .2, .3) qs[0]
            #pragma braket noise depolarizing(.5) qs[0]
            #pragma braket noise two_qubit_depolarizing(.9) qs
            #pragma braket noise two_qubit_depolarizing(.7) qs[1], qs[0]
            #pragma braket noise two_qubit_dephasing(.6) qs
            #pragma braket noise amplitude_damping(.2) qs[0]
            #pragma braket noise generalized_amplitude_damping(.2, .3)  qs[1]
            #pragma braket noise phase_damping(.4) qs[0]
            #pragma braket noise kraus([[0.9486833im, 0], [0, 0.9486833im]], [[0, 0.31622777], [0.31622777, 0]]) qs[0]
            #pragma braket noise kraus([[0.9486832980505138, 0, 0, 0], [0, 0.9486832980505138, 0, 0], [0, 0, 0.9486832980505138, 0], [0, 0, 0, 0.9486832980505138]], [[0, 0.31622776601683794, 0, 0], [0.31622776601683794, 0, 0, 0], [0, 0, 0, 0.31622776601683794], [0, 0, 0.31622776601683794, 0]]) qs[{1, 0}]
            """
            parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
            circuit     = BraketStateVector.interpret(parsed_prog)
            inst_list   = [Instruction(BitFlip(0.5), [1]),
                           Instruction(PhaseFlip(0.5), [0]),
                           Instruction(PauliChannel(0.1, 0.2, 0.3), [0]),
                           Instruction(Depolarizing(0.5), [0]),
                           Instruction(TwoQubitDepolarizing(0.9), [0, 1]),
                           Instruction(TwoQubitDepolarizing(0.7), [1, 0]),
                           Instruction(TwoQubitDephasing(0.6), [0, 1]),
                           Instruction(AmplitudeDamping(0.2), [0]),
                           Instruction(GeneralizedAmplitudeDamping(0.2, 0.3), [1]),
                           Instruction(PhaseDamping(0.4), [0]),
                           Instruction(Kraus([[0.9486833im 0; 0 0.9486833im], [0 0.31622777; 0.31622777 0]]), [0]),
                           Instruction(Kraus([diagm(fill(√0.9, 4)), √0.1*kron([1.0 0.0; 0.0 1.0], [0.0 1.0; 1.0 0.0])]), [1, 0]),
                          ]
            @testset "Operator $(typeof(ix.operator)), target $(ix.target)" for (cix, ix) in zip(circuit.instructions, inst_list)
                @test cix.operator == ix.operator
                @test cix.target == ix.target
            end
        end
        @testset "Basis rotations" begin
            @testset "StandardObservables" begin
                qasm = """
                qubit[3] q;
                i q;
                
                #pragma braket result expectation z(q[2]) @ x(q[0])
                #pragma braket result variance x(q[0]) @ y(q[1])
                #pragma braket result sample x(q[0])
                """
                parsed_prog  = BraketStateVector.OpenQASM3.parse(qasm)
                circuit      = BraketStateVector.interpret(parsed_prog)
                Braket.basis_rotation_instructions!(circuit)
                c_bris = [circuit.basis_rotation_instructions[1], Instruction(Unitary(Matrix(mapreduce(ix->BraketStateVector.matrix_rep(ix.operator), *, circuit.basis_rotation_instructions[2:end]))), [1])]
                bris   = vcat(Instruction(H(), [0]), BraketStateVector.diagonalizing_gates(Braket.Observables.Y(), [1]))
                for (ix, bix) in zip(c_bris, bris)
                    @test BraketStateVector.matrix_rep(ix.operator) ≈ transpose(BraketStateVector.matrix_rep(bix.operator))
                    @test ix.target == bix.target
                end
            end
            @testset "Identity" begin
                qasm = """
                qubit[3] q;
                i q;
                
                #pragma braket result expectation z(q[2]) @ x(q[0])
                #pragma braket result variance x(q[0]) @ y(q[1])
                #pragma braket result sample i(q[0])
                """
                parsed_prog  = BraketStateVector.OpenQASM3.parse(qasm)
                circuit      = BraketStateVector.interpret(parsed_prog)
                Braket.basis_rotation_instructions!(circuit)
                c_bris = [circuit.basis_rotation_instructions[1], Instruction(Unitary(Matrix(mapreduce(ix->BraketStateVector.matrix_rep(ix.operator), *, circuit.basis_rotation_instructions[2:end]))), [1])]
                bris   = vcat(Instruction(H(), [0]), BraketStateVector.diagonalizing_gates(Braket.Observables.Y(), [1]))
                for (ix, bix) in zip(c_bris, bris)
                    @test BraketStateVector.matrix_rep(ix.operator) ≈ transpose(BraketStateVector.matrix_rep(bix.operator))
                    @test ix.target == bix.target
                end
            end
            @testset "Hermitian" begin
                qasm = """
                qubit[3] q;
                i q;
                #pragma braket result expectation x(q[2])
                // # noqa: E501
                #pragma braket result expectation hermitian([[-6+0im, 2+1im, -3+0im, -5+2im], [2-1im, 0im, 2-1im, -5+4im], [-3+0im, 2+1im, 0im, -4+3im], [-5-2im, -5-4im, -4-3im, -6+0im]]) q[0:1]
                // # noqa: E501
                #pragma braket result expectation x(q[2]) @ hermitian([[-6+0im, 2+1im, -3+0im, -5+2im], [2-1im, 0im, 2-1im, -5+4im], [-3+0im, 2+1im, 0im, -4+3im], [-5-2im, -5-4im, -4-3im, -6+0im]]) q[0:1]
                """
                parsed_prog  = BraketStateVector.OpenQASM3.parse(qasm)
                circuit      = BraketStateVector.interpret(parsed_prog)
                Braket.basis_rotation_instructions!(circuit)
                arr = [-6 2+1im -3 -5+2im;
                        2-1im 0 2-1im -5+4im;
                       -3 2+1im 0 -4+3im;
                       -5-2im -5-4im -4-3im -6]
                h = Braket.Observables.HermitianObservable(arr)
                bris = vcat(BraketStateVector.diagonalizing_gates(h, [0, 1]), Instruction(H(), [2]))
                for (ix, bix) in zip(circuit.basis_rotation_instructions, bris)
                    @test BraketStateVector.matrix_rep(ix.operator) ≈ adjoint(BraketStateVector.matrix_rep(bix.operator))
                    @test ix.target == bix.target
                end
            end
        end
        @testset "Output" begin
            qasm = """
                   output int[8] out_int;
                   """
            parsed_prog  = BraketStateVector.OpenQASM3.parse(qasm)
            @test_throws ErrorException("Output not supported.") BraketStateVector.interpret(parsed_prog)
        end
        @testset "Input" begin
            qasm = """
            input int[8] in_int;
            input bit[8] in_bit;
            int[8] doubled;

            doubled = in_int * 2;
            """
            in_bit = 0b10110010
            parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
            @testset for in_int in (0, 1, -2, 5)
                inputs     = Dict("in_int"=>in_int, "in_bit"=>in_bit)
                global_ctx = BraketStateVector.QASMGlobalContext{Braket.Operator}(inputs)
                wo = BraketStateVector.WalkerOutput()
                BraketStateVector.interpret!(wo, parsed_qasm, global_ctx)
                @test global_ctx.definitions["doubled"].value == in_int * 2
                @test global_ctx.definitions["in_bit"].value == in_bit
            end
        end
        @testset "Physical qubits" begin
            qasm = """
            h $0;
            cnot $0, $1;
            """
            parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
            circuit     = BraketStateVector.interpret(parsed_qasm)
            expected_circuit = Circuit([(H, 0), (CNot, 0, 1)])
            @test circuit == expected_circuit
        end
    end
end
