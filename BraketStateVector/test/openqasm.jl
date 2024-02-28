using Test, Statistics, LinearAlgebra, BraketStateVector.OpenQASM3, BraketStateVector, Braket, Braket.Observables

using Braket: Instruction

get_tol(shots::Int) = return (
    shots > 0 ? Dict("atol" => 0.1, "rtol" => 0.15) : Dict("atol" => 0.01, "rtol" => 0)
)
@testset "OpenQASM" begin
    @testset "For loop and subroutines" begin
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
    end
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
        global_ctx(parsed_qasm)
        @test global_ctx.definitions["arccos_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(acos(1))
        @test global_ctx.definitions["arcsin_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(asin(1))
        @test global_ctx.definitions["arctan_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(atan(1))
        @test global_ctx.definitions["ceiling_result"].value == BraketStateVector.OpenQASM3.IntegerLiteral(4)
        @test global_ctx.definitions["cos_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(cos(1))
        @test global_ctx.definitions["exp_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(exp(2))
        @test global_ctx.definitions["floor_result"].value == BraketStateVector.OpenQASM3.IntegerLiteral(3)
        @test global_ctx.definitions["log_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(1.0)
        @test global_ctx.definitions["mod_int_result"].value == BraketStateVector.OpenQASM3.IntegerLiteral(1)
        @test global_ctx.definitions["mod_float_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(mod(5.2, 2.5))
        @test global_ctx.definitions["popcount_bit_result"].value == BraketStateVector.OpenQASM3.IntegerLiteral(4)
        @test global_ctx.definitions["popcount_int_result"].value == BraketStateVector.OpenQASM3.IntegerLiteral(4)
        @test global_ctx.definitions["sin_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(sin(1))
        @test global_ctx.definitions["sqrt_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(sqrt(2))
        @test global_ctx.definitions["tan_result"].value == BraketStateVector.OpenQASM3.FloatLiteral(tan(1))

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
    @testset "Adjoint Gradient pragma" begin
        qasm = """
        input float theta;
        qubit[4] q;
        rx(theta) q[0];
        #pragma braket result adjoint_gradient expectation(-6 * y(q[0]) @ i(q[1]) + 0.75 * y(q[2]) @ z(q[3])) theta
        """
        parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_prog, extern_lookup=Dict("theta"=>0.1))
        θ           = FreeParameter("theta")
        obs         = -2 * Braket.Observables.Y() * (3 * Braket.Observables.I()) + 0.75 * Braket.Observables.Y() * Braket.Observables.Z()
        @test circuit.result_types[1].observable == obs
        @test circuit.result_types[1].targets == [QubitSet([0, 1]), QubitSet([2, 3])]
        @test circuit.result_types[1].parameters == ["theta"]
    end
    @testset "Assignment operators" begin
        qasm = """
        int[16] x;
        bit[4] xs;

        x = 0;
        xs = "0000";

        x += 1; // 1
        x *= 2; // 2
        x /= 2; // 1
        x -= 5; // -4

        xs[2:] |= "11";
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        global_ctx  = BraketStateVector.QASMGlobalContext{Braket.Operator}()
        global_ctx(parsed_qasm)
        @test global_ctx.definitions["x"].value  == -4
        @test global_ctx.definitions["xs"].value == BitVector([0,0,1,1])
    end
    @testset "Bit operators" begin
        qasm = """
        bit[4] and;
        bit[4] or;
        bit[4] xor;
        bit[4] lshift;
        bit[4] rshift;
        bit[4] flip;
        bit gt;
        bit lt;
        bit ge;
        bit le;
        bit eq;
        bit neq;
        bit not;
        bit not_zero;

        bit[4] x = "0101";
        bit[4] y = "1100";

        and = x & y;
        or = x | y;
        xor = x ^ y;
        lshift = x << 2;
        rshift = y >> 2;
        flip = ~x;
        gt = x > y;
        lt = x < y;
        ge = x >= y;
        le = x <= y;
        eq = x == y;
        neq = x != y;
        not = !x;
        not_zero = !(x << 4);
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        global_ctx = BraketStateVector.QASMGlobalContext{Braket.Operator}()
        global_ctx(parsed_qasm)
        @test global_ctx.definitions["x"].value == BitVector([0,1,0,1])
        @test global_ctx.definitions["y"].value == BitVector([1,1,0,0])
        @test global_ctx.definitions["and"].value == BitVector([0,1,0,0])
        @test global_ctx.definitions["or"].value == BitVector([1,1,0,1])
        @test global_ctx.definitions["xor"].value == BitVector([1,0,0,1])
        @test global_ctx.definitions["lshift"].value == BitVector([0,1,0,0])
        @test global_ctx.definitions["rshift"].value == BitVector([0,0,1,1])
        @test global_ctx.definitions["flip"].value == BitVector([1,0,1,0])
        @test global_ctx.definitions["gt"].value == false
        @test global_ctx.definitions["lt"].value == true
        @test global_ctx.definitions["ge"].value == false
        @test global_ctx.definitions["le"].value == true
        @test global_ctx.definitions["eq"].value == false
        @test global_ctx.definitions["neq"].value == true
        @test global_ctx.definitions["not"].value == false
        @test global_ctx.definitions["not_zero"].value == true
    end
    @testset "If" begin
        qasm = """
        int[8] two = 2;
        bit[3] m = "000";

        if (two + 1) {
            m[0] = 1;
        } else {
            m[1] = 1;
        }

        if (!bool(two - 2)) {
            m[2] = 1;
        }
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        global_ctx = BraketStateVector.QASMGlobalContext{Braket.Operator}()
        global_ctx(parsed_qasm)
        bit_vec = BitVector([1,0,1])
        @test global_ctx.definitions["m"].value == bit_vec
    end
    @testset "Global gate control" begin
        qasm = """
        qubit q1;
        qubit q2;

        h q1;
        h q2;
        ctrl @ s q1, q2;
        """
        parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_prog)
        simulation  = BraketStateVector.StateVectorSimulator(2, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        @test simulation.state_vector ≈ [0.5, 0.5, 0.5, 0.5im]
    end
    @testset "Pow" begin
        qasm = """
        int[8] two = 2;
        gate x a { U(π, 0, π) a; }
        gate cx c, a {
            pow(1) @ ctrl @ x c, a;
        }
        gate cxx_1 c, a {
            pow(two) @ cx c, a;
        }
        gate cxx_2 c, a {
            pow(1/2) @ pow(4) @ cx c, a;
        }
        gate cxxx c, a {
            pow(1) @ pow(two) @ cx c, a;
        }

        qubit q1;
        qubit q2;
        qubit q3;
        qubit q4;
        qubit q5;

        pow(1/2) @ x q1;       // half flip
        pow(1/2) @ x q1;       // half flip
        cx q1, q2;   // flip
        cxx_1 q1, q3;    // don't flip
        cxx_2 q1, q4;    // don't flip
        cnot q1, q5;    // flip
        x q3;       // flip
        x q4;       // flip

        s q1;   // sqrt z
        s q1;   // again
        inv @ z q1; // inv z
        """
        parsed_prog  = BraketStateVector.OpenQASM3.parse(qasm)
        circuit      = BraketStateVector.interpret(parsed_prog)
        simulation  = BraketStateVector.StateVectorSimulator(5, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        sv = zeros(32)
        sv[end] = 1.0
        @test simulation.state_vector ≈ sv 
    end
    @testset "Gate control" begin
        qasm = """
        int[8] two = 2;
        gate x a { U(π, 0, π) a; }
        gate cx c, a {
            ctrl @ x c, a;
        }
        gate ccx_1 c1, c2, a {
            ctrl @ ctrl @ x c1, c2, a;
        }
        gate ccx_2 c1, c2, a {
            ctrl(two) @ x c1, c2, a;
        }
        gate ccx_3 c1, c2, a {
            ctrl @ cx c1, c2, a;
        }

        qubit q1;
        qubit q2;
        qubit q3;
        qubit q4;
        qubit q5;

        // doesn't flip q2
        cx q1, q2;
        // flip q1
        x q1;
        // flip q2
        cx q1, q2;
        // doesn't flip q3, q4, q5
        ccx_1 q1, q4, q3;
        ccx_2 q1, q3, q4;
        ccx_3 q1, q3, q5;
        // flip q3, q4, q5;
        ccx_1 q1, q2, q3;
        ccx_2 q1, q2, q4;
        ccx_2 q1, q2, q5;
        """
        parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_prog)
        simulation  = BraketStateVector.StateVectorSimulator(5, 0)
        sv = zeros(ComplexF64, 32)
        sv[end] = 1.0
        canonical_circuit     = Circuit([(CNot, 0, 1), (X, 0), (CNot, 0, 1), (CCNot, 0, 3, 2), (CCNot, 0, 2, 3), (CCNot, 0, 2, 4), (CCNot, 0, 1, 2), (CCNot, 0, 1, 3), (CCNot, 0, 1, 4)])
        canonical_simulation  = BraketStateVector.StateVectorSimulator(5, 0)
        ii = 1
        @testset for (ix, c_ix) in zip(circuit.instructions, canonical_circuit.instructions)
            BraketStateVector.evolve!(simulation, [ix])
            BraketStateVector.evolve!(canonical_simulation, [c_ix])
            for jj in 1:32
                @test simulation.state_vector[jj] ≈ canonical_simulation.state_vector[jj] atol=1e-10
            end
            @test simulation.state_vector ≈ canonical_simulation.state_vector atol=1e-10
            ii += 1
        end
        @test canonical_simulation.state_vector ≈ sv rtol=1e-10
        @test simulation.state_vector ≈ sv rtol=1e-10
    end
    @testset "Gate inverses" begin
        qasm = """
        gate rand_u_1 a { U(1, 2, 3) a; }
        gate rand_u_2 a { U(2, 3, 4) a; }
        gate rand_u_3 a { inv @ U(3, 4, 5) a; }

        gate both a {
            rand_u_1 a;
            rand_u_2 a;
        }
        gate both_inv a {
            inv @ both a;
        }
        gate all_3 a {
            rand_u_1 a;
            rand_u_2 a;
            rand_u_3 a;
        }
        gate all_3_inv a {
            inv @ inv @ inv @ all_3 a;
        }

        gate apply_phase a {
            gphase(1);
        }

        gate apply_phase_inv a {
            inv @ gphase(1);
        }

        qubit q;

        both q;
        both_inv q;

        all_3 q;
        all_3_inv q;

        apply_phase q;
        apply_phase_inv q;

        U(1, 2, 3) q;
        inv @ U(1, 2, 3) q;

        s q;
        inv @ s q;

        t q;
        inv @ t q;
        """
        parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_prog)
        collapsed   = prod(BraketStateVector.matrix_rep(ix.operator) for ix in circuit.instructions)
        @test collapsed ≈ diagm(ones(ComplexF64, 2^qubit_count(circuit)))
    end
    @testset "GPhase" begin
        qasm = """
        qubit[2] qs;

        int[8] two = 2;

        gate x a { U(π, 0, π) a; }
        gate cx c, a { ctrl @ x c, a; }
        gate phase c, a {
            gphase(π/2);
            ctrl(two) @ gphase(π) c, a;
        }
        gate h a { U(π/2, 0, π) a; }

        h qs[0];
        
        cx qs[0], qs[1];
        phase qs[0], qs[1];
        
        gphase(π);
        inv @ gphase(π / 2);
        negctrl @ ctrl @ gphase(2 * π) qs[0], qs[1];
        """
        parsed_prog = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_prog)
        simulation  = BraketStateVector.StateVectorSimulator(2, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        sv = 1/√2 * [-1; 0; 0; 1]
        @test simulation.state_vector ≈ sv 
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
            global_ctx(parsed_qasm)
            @test global_ctx.definitions["doubled"].value == in_int * 2
            @test global_ctx.definitions["in_bit"].value == in_bit
        end
    end
    @testset "Physical qubits" begin
        qasm = """
        h \$0;
        cnot \$0, \$1;
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        expected_circuit = Circuit([(H, 0), (CNot, 0, 1)])
        @test circuit == expected_circuit
    end
    @testset "Gate on qubit registers" begin 
        qasm = """
        qubit[3] qs;
        qubit q;

        x qs[{0, 2}];
        h q;
        cphaseshift(1) qs, q;
        phaseshift(-2) q;
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        simulation  = BraketStateVector.StateVectorSimulator(4, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        @test simulation.state_vector ≈ [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1/√2, 1/√2, 0, 0, 0, 0]
    end
    @testset "Unitary pragma" begin
        qasm = """
        qubit[3] q;

        x q[0];
        h q[1];

        // unitary pragma for t gate
        #pragma braket unitary([[1.0, 0], [0, 0.70710678 + 0.70710678im]]) q[0]
        ti q[0];

        // unitary pragma for h gate (with phase shift)
        #pragma braket unitary([[0.70710678im, 0.70710678im], [0 - -0.70710678im, -0.0 - 0.70710678im]]) q[1]
        gphase(-π/2) q[1];
        h q[1];

        // unitary pragma for ccnot gate
        #pragma braket unitary([[1.0, 0, 0, 0, 0, 0, 0, 0], [0, 1.0, 0, 0, 0, 0, 0, 0], [0, 0, 1.0, 0, 0, 0, 0, 0], [0, 0, 0, 1.0, 0, 0, 0, 0], [0, 0, 0, 0, 1.0, 0, 0, 0], [0, 0, 0, 0, 0, 1.0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 1.0], [0, 0, 0, 0, 0, 0, 1.0, 0]]) q
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        simulation  = BraketStateVector.StateVectorSimulator(3, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        @test simulation.state_vector ≈ [0, 0, 0, 0, 0.70710678, 0, 0, 0.70710678]
    end
    @testset "Verbatim" begin
        with_verbatim = """
        OPENQASM 3.0;
        bit[2] b;
        qubit[2] q;
        #pragma braket verbatim
        box{
        cnot q[0], q[1];
        cnot q[0], q[1];
        rx(1.57) q[0];
        }
        b[0] = measure q[0];
        b[1] = measure q[1];
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(with_verbatim)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        sim_w_verbatim = BraketStateVector.StateVectorSimulator(2, 0)
        BraketStateVector.evolve!(sim_w_verbatim, circuit.instructions)

        without_verbatim = """
        OPENQASM 3.0;
        bit[2] b;
        qubit[2] q;
        box{
        cnot q[0], q[1];
        cnot q[0], q[1];
        rx(1.57) q[0];
        }
        b[0] = measure q[0];
        b[1] = measure q[1];
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(without_verbatim)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        sim_wo_verbatim = BraketStateVector.StateVectorSimulator(2, 0)
        BraketStateVector.evolve!(sim_wo_verbatim, circuit.instructions)

        @test sim_w_verbatim.state_vector ≈ sim_wo_verbatim.state_vector
    end
    @testset "Void subroutine" begin
        qasm = """
               def flip(qubit q) {
                 x q;
               }
               qubit[2] qs;
               flip(qs[0]);
               """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm)
        circuit     = BraketStateVector.interpret(parsed_qasm)
        simulation  = BraketStateVector.StateVectorSimulator(2, 0)
        BraketStateVector.evolve!(simulation, circuit.instructions)
        @test simulation.state_vector ≈ [0, 0, 1, 0]
    end
    @testset "Array ref subroutine" begin
        qasm = """
        int[16] total_1;
        int[16] total_2;

        def sum(readonly array[int[8], #dim = 1] arr) -> int[16] {
            int[16] size = sizeof(arr);
            int[16] x = 0;
            for int[8] i in [0:size - 1] {
                x += arr[i];
            }
            return x;
        }

        array[int[8], 5] array_1 = {1, 2, 3, 4, 5};
        array[int[8], 10] array_2 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

        total_1 = sum(array_1);
        total_2 = sum(array_2);
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm) 
        global_ctx  = BraketStateVector.QASMGlobalContext{Braket.Operator}()
        global_ctx(parsed_qasm)
        @test global_ctx.definitions["total_1"].value == 15
        @test global_ctx.definitions["total_2"].value == 55
    end
    @testset "Array ref subroutine with mutation" begin
        qasm = """
        def mutate_array(mutable array[int[8], #dim = 1] arr) {
            int[16] size = sizeof(arr);
            for int[8] i in [0:size - 1] {
                arr[i] = 0;
            }
        }

        array[int[8], 5] array_1 = {1, 2, 3, 4, 5};
        array[int[8], 10] array_2 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        array[int[8], 10] array_3 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

        mutate_array(array_1);
        mutate_array(array_2);
        mutate_array(array_3[4:2:-1]);
        """
        parsed_qasm = BraketStateVector.OpenQASM3.parse(qasm) 
        global_ctx = BraketStateVector.QASMGlobalContext{Braket.Operator}(Dict{String,Float64}())
        global_ctx(parsed_qasm)
        @test global_ctx.definitions["array_1"].value == zeros(Int, 5) 
        @test global_ctx.definitions["array_2"].value == zeros(Int, 10) 
        @test global_ctx.definitions["array_3"].value == [1, 2, 3, 4, 0, 6, 0, 8, 0, 10]
    end
end
