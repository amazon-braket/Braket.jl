using Braket, Test

@testset "Xanadu device" begin
    @testset "Device capabilities" begin
        ir_gen() = """{
        "braketSchemaHeader": {
            "name": "braket.device_schema.xanadu.xanadu_device_capabilities",
            "version": "1"
        },
        "service": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.device_service_properties",
                "version": "1"
            },
            "executionWindows": [
                {"executionDay": "Everyday", "windowStartHour": "11:00", "windowEndHour": "12:00"}
            ],
            "shotsRange": [1, 10],
            "deviceCost": {"price": 0.25, "unit": "minute"},
            "deviceDocumentation": {
                "imageUrl": "image_url",
                "summary": "Summary on the device",
                "externalDocumentationUrl": "exter doc link"
            },
            "deviceLocation": "us-east-1",
            "updatedAt": "2020-06-16T19:28:02.869136"
        },
        "action": {
            "braket.ir.blackbird.program": {
                "actionType": "braket.ir.blackbird.program",
                "version": ["1"],
                "supportedOperations": ["x", "y"],
                "supportedResultTypes": []
            }
        },
        "paradigm": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.continuous_variable_qpu_paradigm_properties",
                "version": "1"
            },
            "modes": {"spatial": 1, "concurrent": 44, "temporal_max": 331},
            "layout": "Some layout",
            "compiler": ["borealis"],
            "supportedLanguages": ["blackbird:1.0"],
            "compilerDefault": "borealis",
            "nativeGateSet": ["XGate"],
            "gateParameters": {
                "s": [[0.0, 2.0]],
                "r0": [[-1.5707963267948966, 1.5707963267948966]]
            },
            "target": "borealis"
        },
        "deviceParameters": {}
    }
    """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.XanaduDeviceCapabilities
    end
    @testset "Device parameters" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.xanadu.xanadu_device_parameters",
                "version": "1"
            },
            "paradigmParameters": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.photonic_model_parameters",
                    "version": "1"
                }
            }
        }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.XanaduDeviceParameters
    end
    @testset "Provider properties" begin
        ir_gen() = """{
        "braketSchemaHeader": {
            "name": "braket.device_schema.xanadu.xanadu_provider_properties",
            "version": "1"
        },
        "loopPhases": [0.06293596790273215, 0.15291642690139806, -1.5957742826142312],
        "schmidtNumber": 1.1240597475954237,
        "commonEfficiency": 0.42871142768980564,
        "loopEfficiencies": [0.9106461685832691, 0.8904556756334581, 0.8518902619448591],
        "squeezingParametersMean": {
            "low": 0.6130577606615072,
            "high": 1.0635796125448667,
            "medium": 0.893051739389763
        },
        "relativeChannelEfficiencies": [
            0.9305010775397536,
            0.9648681625753431,
            0.9518909571324008,
            0.9486638084844965,
            0.8987246282353925,
            0.9726334999710303,
            0.9489037154275138,
            0.9727238556532112,
            1.0,
            0.973400900408643,
            0.8771940466934924,
            0.9271209514090495,
            0.9595068270114586,
            0.9002874120338067,
            0.911213274548878,
            0.9752842185805198
        ]
    }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.XanaduProviderProperties
    end
end
