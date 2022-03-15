using Test, Braket

@testset "Ionq Device Schema" begin
    @testset "Device capabilities" begin
        jaqcd() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.ionq.ionq_device_capabilities",
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
                }
            },
            "paradigm": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.gate_model_qpu_paradigm_properties",
                    "version": "1"
                },
                "qubitCount": 11,
                "nativeGateSet": ["ccnot", "cy"],
                "connectivity": {"fullyConnected": false, "connectivityGraph": {"1": ["2", "3"]}}
            },
            "deviceParameters": {}
        }"""

        openqasm() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.ionq.ionq_device_capabilities",
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
                    "supportedPragmas": ["braket_noise_bit_flip"],
                    "forbiddenPragmas": ["braket_unitary_matrix"],
                    "forbiddenArrayOperations": ["concatenation", "range", "slicing"],
                    "requiresAllQubitsMeasurement": false,
                    "requiresContiguousQubitIndices": false,
                    "supportsPartialVerbatimBox": false,
                    "supportsUnassignedMeasurements": false
                }
            },
            "paradigm": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.gate_model_qpu_paradigm_properties",
                    "version": "1"
                },
                "qubitCount": 11,
                "nativeGateSet": ["ccnot", "cy"],
                "connectivity": {"fullyConnected": false, "connectivityGraph": {"1": ["2", "3"]}}
            },
            "deviceParameters": {}
        }
        """
        @testset for format in [openqasm, jaqcd]
            @test Braket.parse_raw_schema(format()) isa Braket.IonqDeviceCapabilities
        end
    end
    @testset "Device parameters" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.ionq.ionq_device_parameters",
                "version": "1"
            },
            "paradigmParameters": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.gate_model_parameters",
                    "version": "1"
                },
                "qubitCount": 1
            }
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.IonqDeviceParameters 
    end
    @testset "Provider properties" begin
        ir_gen() = """
        {
            "braketSchemaHeader": {
                "name": "braket.device_schema.ionq.ionq_provider_properties",
                "version": "1"
            },
            "fidelity": {"1Q": {"mean": 0.99717}, "2Q": {"mean": 0.9696}, "spam": {"mean": 0.9961}},
            "timing": {
                "T1": 10000000000,
                "T2": 500000,
                "1Q": 1.1e-05,
                "2Q": 0.00021,
                "readout": 0.000175,
                "reset": 3.5e-05
            }
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.IonqProviderProperties
    end
end
