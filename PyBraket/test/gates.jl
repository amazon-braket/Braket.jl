using Test, PyBraket, Braket, Braket.IR, PythonCall
using PythonCall: Py, pyconvert, pyisTrue

@testset "Gates" begin
    @testset for (gate, ir_gate) in ((H, IR.H),
                                     (Braket.I, IR.I),
                                     (X, IR.X),
                                     (Y, IR.Y),
                                     (Z, IR.Z),
                                     (S, IR.S),
                                     (Si, IR.Si),
                                     (T, IR.T),
                                     (Ti, IR.Ti),
                                     (V, IR.V),
                                     (Vi, IR.Vi)
                                    )
        g = gate()
        ir_g = Braket.ir(g, 0)
        py_g = Py(g)
        @test pyisTrue(py_g.to_ir([0]) == Py(ir_g))
        @test pyconvert(ir_gate, Py(ir_g)) == ir_g
    end
    @testset for (gate, ir_gate) in ((PhaseShift, IR.PhaseShift),
                                     (Rx, IR.Rx),
                                     (Ry, IR.Ry),
                                     (Rz, IR.Rz),
                                    )
        angle = rand()
        g = gate(angle)
        ir_g = Braket.ir(g, 0)
        py_g = Py(g)
        @test pyisTrue(py_g.to_ir([0]) == Py(ir_g))
        @test pyconvert(ir_gate, Py(ir_g)) == ir_g
    end
    @testset for (gate, ir_gate) in ((CNot, IR.CNot),
                                     (Swap, IR.Swap),
                                     (ISwap, IR.ISwap),
                                     (CZ, IR.CZ),
                                     (CY, IR.CY),
                                     (CV, IR.CV),
                                     (ECR, IR.ECR),
                                    )
        g = gate()
        ir_g = Braket.ir(g, [0, 1])
        py_g = Py(g)
        @test pyisTrue(py_g.to_ir([0, 1]) == Py(ir_g))
        @test pyconvert(ir_gate, Py(ir_g)) == ir_g
    end
    @testset for (gate, ir_gate) in ((CPhaseShift, IR.CPhaseShift),
                                     (CPhaseShift00, IR.CPhaseShift00),
                                     (CPhaseShift01, IR.CPhaseShift01),
                                     (CPhaseShift10, IR.CPhaseShift10),
                                     (XX, IR.XX),
                                     (YY, IR.YY),
                                     (ZZ, IR.ZZ),
                                     (PSwap, IR.PSwap)
                                    )
        angle = rand()
        g = gate(angle)
        ir_g = Braket.ir(g, [0, 1])
        py_g = Py(g)
        @test pyisTrue(py_g.to_ir([0, 1]) == Py(ir_g))
        @test pyconvert(ir_gate, Py(ir_g)) == ir_g
    end
    @testset for (gate, ir_gate) in ((CCNot, IR.CCNot), (CSwap, IR.CSwap))
        g = gate()
        ir_g = Braket.ir(g, [0, 1, 2])
        py_g = Py(g)
        @test pyisTrue(py_g.to_ir([0, 1, 2]) == Py(ir_g))
        @test pyconvert(ir_gate, Py(ir_g)) == ir_g
    end
    @testset "(gate, ir_gate) = (Unitary, IR.Unitary)" begin
        mat = complex([0. 1.; 1. 0.])
        n = Unitary(mat)
        ir_n = Braket.ir(n, 0)
        py_n = Py(n)
        @test pyisTrue(py_n.to_ir([0]) == Py(ir_n))
        @test pyconvert(IR.Unitary, Py(ir_n)) == ir_n
    end
end