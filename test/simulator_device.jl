using Braket, Test

@testset "Gate model simulator device" begin
    @testset "Device capabilities" begin
        ir_gen() = """{
        "braketSchemaHeader": {
            "name": "braket.device_schema.simulators.gate_model_simulator_device_capabilities",
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
            "braket.ir.jaqcd.program": {
                "actionType": "braket.ir.jaqcd.program",
                "version": ["1"],
                "supportedOperations": ["x", "y"],
                "supportedResultTypes": [
                    {
                        "name": "resultType1",
                        "observables": ["observable1"],
                        "minShots": 2,
                        "maxShots": 4
                    }
                ]
            },
            "braket.ir.openqasm.program": {
                "actionType": "braket.ir.openqasm.program",
                "version": ["1"],
                "supportedOperations": ["x", "y"],
                "supportedResultTypes": [
                    {
                        "name": "resultType1",
                        "observables": ["observable1"],
                        "minShots": 2,
                        "maxShots": 4
                    }
                ],
                "supportPhysicalQubits": false,
                "supportedPragmas": ["braket_noise_bit_flip", "braket_unitary_matrix"],
                "forbiddenPragmas": [],
                "forbiddenArrayOperations": ["concatenation", "range", "slicing"],
                "requireAllQubitsMeasurement": true,
                "requireContiguousQubitIndices": false,
                "supportsPartialVerbatimBox": true,
                "supportsUnassignedMeasurements": true
            }
        },
        "paradigm": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.simulators.gate_model_simulator_paradigm_properties",
                "version": "1"
            },
            "qubitCount": 32
        },
        "deviceParameters": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.simulators.gate_model_simulator_device_parameters",
                "version": "1"
            },
            "paradigmParameters": {}
        }
    }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.GateModelSimulatorDeviceCapabilities
    end
    @testset "Device parameters" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.simulators.gate_model_simulator_device_parameters",
                "version": "1"
            },
            "paradigmParameters": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.gate_model_parameters",
                    "version": "1"
                },
                "qubitCount": 1
            }
        }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.GateModelSimulatorDeviceParameters
    end
    @testset "Paradigm properties" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.simulators.gate_model_simulator_paradigm_properties",
                "version": "1"
            },
            "qubitCount": 32
        }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.GateModelSimulatorParadigmProperties
    end
end
