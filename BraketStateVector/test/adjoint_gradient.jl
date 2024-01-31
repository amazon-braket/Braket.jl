using BraketStateVector, Braket, Test

@testset "Adjoint Gradient" begin
    @testset "with nested targets" begin
        θ      = FreeParameter(:theta)
        inputs = Dict("theta"=>0.2)
        obs    = (-2*Braket.Observables.Y()) * (3*Braket.Observables.I()) + 0.75 * Braket.Observables.Y() * Braket.Observables.Z()
        circ   = Circuit([(Rx, 0, θ), (AdjointGradient, obs, [[0, 1], [2, 3]], ["theta"])])

        expected_openqasm = """
        OPENQASM 3.0;
        input float theta;
        qubit[4] q;
        rx(theta) q[0];
        #pragma braket result adjoint_gradient expectation(-6.0 * y(q[0]) @ i(q[1]) + 0.75 * y(q[2]) @ z(q[3])) theta"""
        dev = LocalSimulator("default") 
        res = result(dev(circ, inputs=inputs))
        #@test res.additional_metadata.action.source == expected_openqasm
        @test res.values == [Dict(:expectation=>1.1920159847703675, :gradient=>Dict(:theta=>5.880399467047451))]
        #@test first(res.result_types).type.observable == "-6.0 * y @ i + 0.75 * y @ z"
        #@test res.additional_metadata.action.inputs == inputs
    end
    @testset "with standard observable terms" begin
        θ      = FreeParameter(:theta)
        inputs = Dict("theta"=>0.2)
        obs    = 2*Braket.Observables.X() + 3*Braket.Observables.Y() - Braket.Observables.Z()
        circ   = Circuit([(Rx, 0, θ), (AdjointGradient, obs, [[0], [1], [2]], ["theta"])])

        expected_openqasm = """
        OPENQASM 3.0;
        input float theta;
        qubit[3] q;
        rx(theta) q[0];
        #pragma braket result adjoint_gradient expectation(2.0 * x(q[0]) + 3.0 * y(q[1]) - 1.0 * z(q[2])) theta"""

        dev = LocalSimulator("default") 
        res = result(dev(circ, inputs=inputs))
        #@test res.additional_metadata.action.source == expected_openqasm
        @test res.values == [Dict(:expectation=>-1, :gradient=>Dict(:theta=>0))]
        #@test first(res.result_types).type.observable == "2.0 * x + 3.0 * y - 1.0 * z"
        #@test res.additional_metadata.action.inputs == inputs
    end
    @testset "with batch" begin
        θ      = FreeParameter(:theta)
        inputs = Dict("theta"=>0.2)
        obs1   = 2*Braket.Observables.Y() * 3 * Braket.Observables.I()
        obs2   = -2*Braket.Observables.Y() * 3 * Braket.Observables.I() + 0.75 * Braket.Observables.Y() * Braket.Observables.Z()
        circ1  = Circuit([(Rx, 0, θ), (AdjointGradient, obs1, [0, 1], ["theta"])])
        circ2  = Circuit([(Rx, 0, θ), (AdjointGradient, obs2, [[0, 1], [0, 1]], ["theta"])])
        expected_openqasm = [
            """OPENQASM 3.0;
            input float theta;
            qubit[2] q;
            rx(theta) q[0];
            #pragma braket result adjoint_gradient expectation(6.0 * y(q[0]) @ i(q[1])) theta""",
            """OPENQASM 3.0;
            input float theta;
            qubit[2] q;
            rx(theta) q[0];
            #pragma braket result adjoint_gradient expectation(-6.0 * y(q[0]) @ i(q[1]) + 0.75 * y(q[0]) @ z(q[1])) theta"""
            ,
        ]
        expected_result_values = [
          [Dict(:expectation=>-1.1920159847703675, :gradient=>Dict(:theta=>-5.880399467047451))],
          [Dict(:expectation=>1.0430139866740715, :gradient=>Dict(:theta=>5.145349533666519))],
        ]
        expected_observables = ["6.0 * y @ i", "-6.0 * y @ i + 0.75 * y @ z"]
    
        dev = LocalSimulator("default") 
        gradient_batch_tasks = dev([circ1, circ2], shots=0, inputs=inputs)
        for (i, res) in enumerate(results(gradient_batch_tasks))
            #@test res.additional_metadata.action.source == expected_openqasm[i]
            @test res.values == expected_result_values[i]
            #@test first(res.result_types).type.observable == expected_observables[i]
            #@test res.additional_metadata.action.inputs == inputs
        end
    end
end
