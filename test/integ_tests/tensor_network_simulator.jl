using Braket, Test

SHOTS = 1000
TN1_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/tn1"
SIMULATOR_ARNS = [TN1_ARN]
get_tol(shots::Int) = return (shots > 0 ? Dict("atol"=> 0.1, "rtol"=>0.15) : Dict("atol"=>0.01, "rtol"=>0))
s3_destination_folder = Braket.default_task_bucket()

bell_circ() = Circuit([(H, 0), (CNot, 0, 1)])

function _ghz(num_qubits)
    circuit = Circuit([(H, 0)])
    for qubit in 0:num_qubits - 2
        circuit(CNot, qubit, qubit + 1)
    end
    return circuit
end

function _qft(circuit, num_qubits)
    for i in 0:num_qubits-1
        circuit(H, i)
        for j in 1:num_qubits - i-1
            circuit(CPhaseShift, i + j, i, π/(2^j))
        end
    end
    for qubit in 0:div(num_qubits, 2)-1
        circuit(Swap, qubit, num_qubits - qubit - 1)
    end
    return circuit
end


function _inverse_qft(circuit, num_qubits)
    for qubit in 0:div(num_qubits, 2)-1
        circuit(Swap, qubit, num_qubits - qubit - 1)
    end
    for i in reverse(0:num_qubits-1)
        for j in reverse(1:num_qubits - i - 1)
            circuit(CPhaseShift, i + j, i, -π/(2^j))
        end
        circuit(H, i)
    end
    return circuit
end

@testset "Tensor network simulator" begin
    @testset "GHZ" begin 
        num_qubits = 50
        circuit = _ghz(num_qubits)
        expected = Dict(prod("0" for q in 1:num_qubits)=>0.5, prod("1" for q in 1:num_qubits)=>0.5)
        @testset for simulator_arn in SIMULATOR_ARNS
            device = AwsDevice(_arn=simulator_arn)
            shots = SHOTS
            tol = get_tol(shots)
            res = result(device(circuit, shots=shots, s3_destination_folder=s3_destination_folder))
            probabilities = res.measurement_probabilities
            
            for (bitstring, val) in probabilities
                @test isapprox(val, expected[bitstring], rtol=tol["rtol"], atol=tol["atol"])
            end
            @test length(res.measurements) == shots
        end
    end
    @testset "H + QFT + iQFT" begin
        num_qubits = 24
        h_qubit = rand(0:num_qubits - 1)
        circuit = _inverse_qft(_qft(Circuit([(H, h_qubit)]), num_qubits), num_qubits)
        h_qubit_str = falses(num_qubits)
        h_qubit_str[h_qubit+1] = true
        h_qubit_str = join(string.(Int.(h_qubit_str)), "")
        expected = Dict(prod("0" for q in 1:num_qubits)=>0.5, h_qubit_str=>0.5)
        @testset for simulator_arn in SIMULATOR_ARNS
            device = AwsDevice(_arn=simulator_arn)
            shots = SHOTS
            tol = get_tol(shots)
            res = result(device(circuit, shots=shots, s3_destination_folder=s3_destination_folder))
            probabilities = res.measurement_probabilities
            for (bitstring, val) in probabilities
                @test isapprox(val, expected[bitstring], rtol=tol["rtol"], atol=tol["atol"])
            end
            @test length(res.measurements) == shots
        end
    end
    @testset "No result types Bell pair OpenQASM" begin
        expected = Dict("00"=>0.5, "11"=>0.5)
        openqasm_string = """
            OPENQASM 3;
            qubit[2] q;
            bit[2] c;
            h q[0];
            cnot q[0], q[1];
            c[0] = measure q[0];
            c[1] = measure q[1];
            """
        hardcoded_openqasm = OpenQasmProgram(Braket.header_dict[OpenQasmProgram], openqasm_string, nothing)
        circuit = bell_circ()
        generated_openqasm = ir(circuit, Val(:OpenQASM))
        @testset for simulator_arn in SIMULATOR_ARNS, program in (hardcoded_openqasm, generated_openqasm)
            device = AwsDevice(_arn=simulator_arn)
            tol = get_tol(SHOTS)
            res = result(device(program, shots=SHOTS, s3_destination_folder=s3_destination_folder))
            probabilities = res.measurement_probabilities
            for (bitstring, val) in probabilities
                @test isapprox(val, expected[bitstring], rtol=tol["rtol"], atol=tol["atol"])
            end
            @test length(res.measurements) == SHOTS
        end
    end
end