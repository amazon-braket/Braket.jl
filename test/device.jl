using Braket, Test, Mocking, JSON3, Dates, Graphs

Mocking.activate()


MOCK_GATE_MODEL_QPU_CAPABILITIES_1 = """{
    "braketSchemaHeader": {
        "name": "braket.device_schema.rigetti.rigetti_device_capabilities",
        "version": "1"
    },
    "service": {
        "executionWindows": [
            {
                "executionDay": "Everyday",
                "windowStartHour": "11:00",
                "windowEndHour": "12:00"
            }
        ],
        "shotsRange": [1, 10]
    },
    "action": {
        "braket.ir.jaqcd.program": {
            "actionType": "braket.ir.jaqcd.program",
            "version": ["1"],
            "supportedOperations": ["H"]
        }
    },
    "paradigm": {
        "qubitCount": 30,
        "nativeGateSet": ["ccnot", "cy"],
        "connectivity": {"fullyConnected": false, "connectivityGraph": {"1": ["2", "3"]}}
    },
    "deviceParameters": {}
}"""

MOCK_GATE_MODEL_QPU_1() = """{
    "deviceName": "Aspen-10",
    "deviceType": "QPU",
    "providerName": "provider1",
    "deviceStatus": "OFFLINE",
    "deviceCapabilities": $MOCK_GATE_MODEL_QPU_CAPABILITIES_1
}"""

MOCK_GATE_MODEL_QPU_CAPABILITIES_2 = """{
    "braketSchemaHeader": {
        "name": "braket.device_schema.rigetti.rigetti_device_capabilities",
        "version": "1"
    },
    "service": {
        "executionWindows": [
            {
                "executionDay": "Everyday",
                "windowStartHour": "11:00",
                "windowEndHour": "12:00"
            }
        ],
        "shotsRange": [1, 10]
    },
    "action": {
        "braket.ir.jaqcd.program": {
            "actionType": "braket.ir.jaqcd.program",
            "version": ["1"],
            "supportedOperations": ["H"]
        }
    },
    "paradigm": {
        "qubitCount": 30,
        "nativeGateSet": ["ccnot", "cy"],
        "connectivity": {"fullyConnected": true, "connectivityGraph": {}}
    },
    "deviceParameters": {}
}"""

MOCK_GATE_MODEL_QPU_2() = """{
    "deviceName": "Blah",
    "deviceType": "QPU",
    "providerName": "blahhhh",
    "deviceStatus": "OFFLINE",
    "deviceCapabilities": $MOCK_GATE_MODEL_QPU_CAPABILITIES_2
}"""

MOCK_DWAVE_QPU_CAPABILITIES = """{
    "braketSchemaHeader": {
        "name": "braket.device_schema.dwave.dwave_device_capabilities",
        "version": "1"
    },
    "provider": {
        "annealingOffsetStep": 1.45,
        "annealingOffsetStepPhi0": 1.45,
        "annealingOffsetRanges": [[1.45, 1.45], [1.45, 1.45]],
        "annealingDurationRange": [1, 2, 3],
        "couplers": [[1, 2], [2, 3]],
        "defaultAnnealingDuration": 1,
        "defaultProgrammingThermalizationDuration": 1,
        "defaultReadoutThermalizationDuration": 1,
        "extendedJRange": [1, 2, 3],
        "hGainScheduleRange": [1, 2, 3],
        "hRange": [1, 2, 3],
        "jRange": [1, 2, 3],
        "maximumAnnealingSchedulePoints": 1,
        "maximumHGainSchedulePoints": 1,
        "perQubitCouplingRange": [1, 2, 3],
        "programmingThermalizationDurationRange": [1, 2, 3],
        "qubits": [1, 2, 3],
        "qubitCount": 1,
        "quotaConversionRate": 1,
        "readoutThermalizationDurationRange": [1, 2, 3],
        "taskRunDurationRange": [1, 2, 3],
        "topology": {}
    },
    "service": {
        "executionWindows": [
            {"executionDay": "Everyday", "windowStartHour": "11:00", "windowEndHour": "12:00"}
        ],
        "shotsRange": [1, 10]
    },
    "action": {
        "braket.ir.annealing.problem": {
            "actionType": "braket.ir.annealing.problem",
            "version": ["1"]
        }
    },
    "deviceParameters": {}
}"""

MOCK_DWAVE_QPU() = """{
    "deviceName": "Advantage_system1.1",
    "deviceType": "QPU",
    "providerName": "provider1",
    "deviceStatus": "ONLINE",
    "deviceCapabilities": $MOCK_DWAVE_QPU_CAPABILITIES
}"""

@testset "Devices" begin
    dev = Braket.AwsDevice(_arn="fake:arn")
    dev._default_shots=10
    @test convert(String, dev) == "fake:arn"
    c = CNot(Circuit(), 0, 1)
    resp_dict = Dict("quantumTaskArn"=>"arn/fake", "status"=>"COMPLETED")
    req_patch  = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
    apply(req_patch) do
        t = dev(c, s3_destination_folder=("fake_bucket", "fake_prefix"))
        @test arn(t) == "arn/fake"
        t = dev([c, c], s3_destination_folder=("fake_bucket", "fake_prefix"))
        @test arn.(Braket.tasks(t)) == ["arn/fake", "arn/fake"]
    end
    resp_dict = Dict("deviceName"=>"fake_name", "deviceStatus"=>"fake_status", "deviceType"=>"fake_type", "providerName"=>"fake_provider", "deviceCapabilities"=>nothing)
    req_patch = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
    apply(req_patch) do
        Braket.refresh_metadata!(dev)
        @test dev._name == "fake_name"
        @test dev._status == "fake_status"
        @test dev._type == "fake_type"
        @test dev._provider_name == "fake_provider"
        @test isnothing(dev._properties)
    end
    execution_window = Braket.DeviceExecutionWindow("everyday",Dates.Time("00:00:00"),Dates.Time("23:59:59"))
    dsp = Braket.DeviceServiceProperties(Braket.header_dict[Braket.DeviceServiceProperties], [execution_window], (0, 1000), nothing, nothing, nothing, nothing)
    paradigm = Braket.GateModelSimulatorParadigmProperties(Braket.header_dict[Braket.GateModelSimulatorParadigmProperties], 100)
    dev_capa = Braket.GateModelSimulatorDeviceCapabilities(dsp, Dict(), Dict(), Braket.header_dict[Braket.GateModelSimulatorDeviceCapabilities], paradigm)
    resp_dict = Dict{String, Any}("devices"=>[Dict{String, Any}(
        "deviceName"=>"fakeName",
        "deviceType"=>"fakeType",
        "deviceStatus"=>"fakeStatus",
        "providerName"=>"fakeProvider",
        "deviceCapabilities"=>JSON3.write(dev_capa),
    )])
    req_patch = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(JSON3.write(resp_dict)))
    apply(req_patch) do
        r = Braket.search_devices(arns=["fakeName"])
        resp_dict["devices"][1]["deviceCapabilities"] = Braket.parse_raw_schema(resp_dict["devices"][1]["deviceCapabilities"])
        @test r == resp_dict["devices"]
    end
    @testset "isavailable" begin
        dev._properties = dev_capa
        dev._status = "ONLINE"
        @test isavailable(dev)
        dev._status = "OFFLINE"
        @test !isavailable(dev)
    end
    @testset "topology graphs" begin
        graphs = [SimpleDiGraph(Edge.([(1, 2), (1, 3)])), complete_digraph(30), SimpleDiGraph(Edge.([(1, 2), (2, 3)]))]
        @testset for (qpu, graph) in zip([MOCK_GATE_MODEL_QPU_1, MOCK_GATE_MODEL_QPU_2, MOCK_DWAVE_QPU], graphs)
            req_patch = @patch Braket.AWS._http_request(a...; b...) = Braket.AWS.Response(Braket.HTTP.Response(200, ["Content-Type"=>"application/json"]), IOBuffer(qpu()))
            apply(req_patch) do
                dev = Braket.AwsDevice(_arn="fake_arn")
                Braket.refresh_metadata!(dev)
                qpu_dict = JSON3.read(qpu())
                @test dev._name == qpu_dict["deviceName"]
                @test dev._status == qpu_dict["deviceStatus"]
                @test dev._type == qpu_dict["deviceType"]
                @test dev._provider_name == qpu_dict["providerName"]
                @test dev._topology_graph == graph
            end
        end
    end
end