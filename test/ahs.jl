using Braket, Test, JSON3, StructTypes, UUIDs, DecFP

struct MockRydbergLocal
    timeResolution::Dec128
    commonDetuningResolution::Dec128
    localDetuningResolution::Dec128
end

struct MockRydberg
    c6coefficient::Dec128
    rydbergGlobal::Braket.RydbergGlobal
    rydbergLocal::MockRydbergLocal
end

struct MockAhsParadigmProperties
    lattice::Braket.Lattice
    rydberg::MockRydberg
end

struct MockAhsDeviceCapabilities
    action::Dict{Union{Braket.DeviceActionType, String}, Braket.DeviceActionProperties}
    paradigm::MockAhsParadigmProperties
end

@testset "AHS" begin
    @testset "AHS program translation" begin
        json_str = """{"braketSchemaHeader": {"name": "braket.ir.ahs.program", "version": "1"},
        "setup": {"ahs_register": {"sites": [[0, 0],
            [0, 4e-06],
            [5e-06, 0],
            [5e-06, 4e-06]],
        "filling": [1, 0, 1, 0]}},
        "hamiltonian": {"drivingFields": [{"amplitude": {"pattern": "uniform",
            "time_series": {"times": [0, 1e-07, 3.9e-06, 4e-06],
            "values": [0, 12566400.0, 12566400.0, 0]}},
            "phase": {"pattern": "uniform",
            "time_series": {"times": [0, 1e-07, 3.9e-06, 4e-06],
            "values": [0, 0, -16.0832, -16.0832]}},
            "detuning": {"pattern": "uniform",
            "time_series": {"times": [0, 1e-07, 3.9e-06, 4e-06],
            "values": [-125000000, -125000000, 125000000, 125000000]}}}],
        "shiftingFields": [{"magnitude": {"time_series": {"times": [0, 4e-06],
            "values": [0, 125000000]},
            "pattern": [0.0, 1.0, 0.5, 0.0]}}]}
        }"""
        parsed = Braket.parse_raw_schema(json_str)
        arrange = [Dec128.(["0.0", "0.0"]), Dec128.(["0.0", "4e-6"]), Dec128.(["5e-6", "0.0"]), Dec128.(["5e-6", "4e-6"])]
        @test parsed.setup.ahs_register == Braket.IR.AtomArrangement(arrange, [1, 0, 1, 0])
        @test StructTypes.constructfrom(Braket.AbstractProgram, JSON3.read(json_str)) == parsed
    end

    @testset "AHS result translation" begin
        fi = read(joinpath(@__DIR__, "analog_task_result.json"), String)
        # dict-like
        raw = JSON3.read(fi)
        for m in raw[:measurements]
            mtd = StructTypes.constructfrom(Braket.AnalogHamiltonianSimulationShotMetadata, m[:shotMetadata])

            s = StructTypes.constructfrom(Braket.AnalogHamiltonianSimulationShotMeasurement, m)
            @test s isa Braket.AnalogHamiltonianSimulationShotMeasurement
        end
        AHS_r = Braket.parse_raw_schema(fi)
        @test AHS_r isa Braket.AnalogHamiltonianSimulationTaskResult
        qtr = Braket.format_result(AHS_r)
        @test qtr isa Braket.AnalogHamiltonianSimulationQuantumTaskResult
        @test sprint(show, qtr) == "AnalogHamiltonianSimulationQuantumTaskResult\n"
        @testset for inst in instances(Braket.AnalogHamiltonianSimulationShotStatus)
            @test string(inst) == inst
            @test inst == string(inst)
        end
        @testset "Reading AnalogHamiltonianSimulationQuantumTaskResult" begin
            @test JSON3.read("""{"status": "partial_success"}""", Braket.ShotResult) == Braket.ShotResult(Braket.partial_success, nothing, nothing)
            task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 100, "arn1", nothing, nothing, nothing, nothing, nothing)
            @test JSON3.read("""{"task_metadata": $(JSON3.write(task_metadata))}""", Braket.AnalogHamiltonianSimulationQuantumTaskResult) == Braket.AnalogHamiltonianSimulationQuantumTaskResult(task_metadata, nothing)
        end
    end
    @testset "TimeSeries" begin
        t1 = TimeSeries()
        for (t, v) in [(3.0e-7, 2.51327e7), (3.0e-6, 0.0), (2.7e-6, 2.51327e7), (0.0, 0.0)]
            t1[t] = v
        end
        @test !issorted(t1)
        sort!(t1)
        @test issorted(t1)
        t2 = JSON3.read("{}", Braket.TimeSeries)
        @test issorted(t2)
        @test t2.largest_time == -1
        @test isempty(t2.series)
    end
    @testset "Field" begin
        f = JSON3.read("""{"time_series": {}}""", Braket.Field)
        @test isnothing(f.pattern)
    end
    @testset "AHS task creation" begin
        aa = map(AtomArrangementItem, [(0.0, 0.0), (0.0, 3.0e-6), (0.0, 6.0e-6), (3.0e-6, 0.0), (3.0e-6, 3.0e-6)])
        register = AtomArrangement(aa)
        push!(register, (3.0e-6, 3.0e-6), vacant)
        push!(register, (3.0e-6, 6.0e-6), vacant)

        t1 = TimeSeries()
        t2 = TimeSeries()
        t3 = TimeSeries()
        for (t, v) in [(0.0, 0.0), (3.0e-7, 2.51327e7), (2.7e-6, 2.51327e7), (3.0e-6, 0.0)]
            t1[t] = v
        end
        for (t, v) in [(0.0, 0), (3.0e-6, 0)]
            t2[t] = v
        end
        for (t, v) in [(0.0, -1.25664e8), (3.0e-7, -1.25664e8), (2.7e-6, 1.25664e8), (3.0e-6, 1.25664e8)]
            t3[t] = v
        end
        df = DrivingField(t1, t2, t3)
        ts = TimeSeries()
        for (t, v) in [(0.0, -1.25664e8), (3.0e-6, 1.25664e8)]
            ts[t] = v
        end
        pt = Pattern([0.5, 1.0, 0.5, 0.5, 0.5, 0.5])
        sf = ShiftingField(Field(ts, pt))
        H = AnalogHamiltonianSimulation(register, [df, sf])
        prog = ir(H)
        @test JSON3.read(JSON3.write(prog), Braket.AHSProgram) == prog

        @test vacant == "vacant"
        @test "filled" == filled

        shots = 100
        device_params = Dict("fake_param_1"=>2, "fake_param_2"=>"hello")
        s3_folder = ("fake_bucket", "fake_folder")
        arn = "arn:fake:quera"
        task_args = Braket.prepare_task_input(H, arn, s3_folder, shots, device_params)
        @test task_args[:action] == JSON3.write(ir(H))
        @test task_args[:device_arn] == arn
        @test UUID(task_args[:client_token]) isa UUID
        @test task_args[:shots] == shots
        @test task_args[:outputS3Bucket] == s3_folder[1]
        @test task_args[:outputS3KeyPrefix] == s3_folder[2]
        @test task_args[:extra_opts] == Dict{String, Any}("deviceParameters"=>"{}", "tags"=>Dict{String, String}())
    end
    @testset "discretize" begin
        aa = map(AtomArrangementItem, [(0.0, 0.0), (0.0, 3.0e-6), (0.0, 6.0e-6), (3.0e-6, 0.0), (3.0e-6, 3.0e-6)])
        register = AtomArrangement(aa)
        push!(register, (Dec128("3.0e-6"), Dec128("3.0e-6")), vacant)
        push!(register, (Dec128("3.0e-6"), Dec128("6.0e-6")), vacant)

        t1 = TimeSeries()
        t2 = TimeSeries()
        t3 = TimeSeries()
        for (t, v) in [(0.0, 0.0), (Dec128("3.0e-7"), Dec128("2.51327e7")), (Dec128("2.7e-6"), Dec128("2.51327e7")), (Dec128("3.0e-6"), 0.0)]
            t1[t] = v
        end
        for (t, v) in [(0.0, 0), (Dec128("3.0e-6"), 0)]
            t2[t] = v
        end
        for (t, v) in [(0.0, Dec128("-1.25664e8")), (Dec128("3.0e-7"), Dec128("-1.25664e8")), (Dec128("2.7e-6"), Dec128("1.25664e8")), (Dec128("3.0e-6"), Dec128("1.25664e8"))]
            t3[t] = v
        end
        df = DrivingField(t1, t2, t3)
        ts = TimeSeries()
        for (t, v) in [(0.0, Dec128("-1.25664e8")), (Dec128("3.0e-6"), Dec128("1.25664e8"))]
            ts[t] = v
        end
        pt = Pattern(Dec128.(["0.5", "1.0", "0.5", "0.5", "0.5", "0.5"]))
        sf = ShiftingField(Field(ts, pt))
        ahs = AnalogHamiltonianSimulation(register, [df, sf])
        rl = MockRydbergLocal(Dec128("1e-9"), Dec128("2000.0"), Dec128("0.01"))
        rg = Braket.RydbergGlobal((Dec128("1.0"), Dec128("1e6")), Dec128("400.0"), Dec128("0.2"), (Dec128("1.0"), Dec128("1e6")), Dec128("0.2"), Dec128("0.2"), (Dec128("1.0"), Dec128("1e6")), Dec128("5e-7"), Dec128("1e-9"), Dec128("1e-5"), Dec128("0.0"), Dec128("100.0"))
        dev = Braket.AwsDevice(_arn="arn:fake_device")
        para_props = MockAhsParadigmProperties(
            Braket.Lattice(Braket.Area(Dec128("1e-3"), Dec128("1e-3")), Braket.Geometry(Dec128("1e-7"), Dec128("1e-7"), Dec128("1e-7"), 200)),
            MockRydberg(Dec128("1e-6"), rg, rl),
        )
        dev._properties = MockAhsDeviceCapabilities(Dict("braket.ir.ahs.program"=>Braket.GenericDeviceActionProperties(["1"], "braket.ir.ahs.program")), para_props)
        disc_ahs = Braket.discretize(ahs, dev)

        disc_ir  = ir(disc_ahs)
        read_in  = JSON3.read(JSON3.write(disc_ir), Dict)
        @test read_in["setup"]["ahs_register"]["filling"] == [1, 1, 1, 1, 1, 0, 0]
        for (site, expected) in zip(read_in["setup"]["ahs_register"]["sites"], [[0.0, 0.0], [0.0, 3e-06], [0.0, 6e-06], [3e-06, 0.0], [3e-06, 3e-06], [3e-06, 3e-06], [3e-06, 6e-06]])
            @test Dec128.(site) == Dec128.(string.(expected))
        end

        @test read_in["hamiltonian"]["drivingFields"][1]["amplitude"]["pattern"] == "uniform"
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["amplitude"]["time_series"]["times"])  ≈ [0.0, 3e-07, 2.7e-06, 3e-06] atol=eps(Float64)
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["amplitude"]["time_series"]["values"]) ≈ [0, 25132800, 25132800, 0] atol=eps(Float64)

        @test read_in["hamiltonian"]["drivingFields"][1]["phase"]["pattern"] == "uniform"
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["phase"]["time_series"]["times"])  ≈ [0.0, 3e-06] atol=eps(Float64)
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["phase"]["time_series"]["values"]) ≈ [0.0, 0.0] atol=eps(Float64)

        @test read_in["hamiltonian"]["drivingFields"][1]["detuning"]["pattern"] == "uniform"
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["detuning"]["time_series"]["times"])  ≈ [0.0, 3e-07, 2.7e-06, 3e-06] atol=eps(Float64)
        @test Dec128.(read_in["hamiltonian"]["drivingFields"][1]["detuning"]["time_series"]["values"]) ≈ [-125664000.0, -125664000.0, 125664000.0, 125664000.0] atol=eps(Float64)
        
        @test Dec128.(read_in["hamiltonian"]["shiftingFields"][1]["magnitude"]["pattern"]) == [0.5, 1.0, 0.5, 0.5, 0.5, 0.5]
        @test Dec128.(read_in["hamiltonian"]["shiftingFields"][1]["magnitude"]["time_series"]["times"])  ≈ [0.0, 3e-06] atol=eps(Float64)
        @test Dec128.(read_in["hamiltonian"]["shiftingFields"][1]["magnitude"]["time_series"]["values"]) ≈ [-125664000.0, 125664000.0] atol=eps(Float64)

        dev._properties = MockAhsDeviceCapabilities(Dict("bad_program"=>Braket.GenericDeviceActionProperties(["1"], "braket.ir.ahs.program")), para_props)
        @test_throws ErrorException Braket.discretize(ahs, dev)
    end
end
