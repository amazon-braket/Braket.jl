using Braket, Test

@testset "Rigetti device" begin
    @testset "Device capabilities" begin
        props = """{
                    "braketSchemaHeader": {
                        "name": "braket.device_schema.standardized_gate_model_qpu_device_properties",
                        "version": "1"
                    },
                    "oneQubitProperties": {
                        "0": {
                            "T1": {"value": 28.9, "standardError": 0.01, "unit": "us"},
                            "T2": {"value": 44.5, "standardError": 0.02, "unit": "us"},
                            "oneQubitFidelity": [
                                {
                                    "fidelityType": {"name": "readout"},
                                    "fidelity": 0.9993,
                                    "standardError": null
                                },
                                {
                                    "fidelityType": {"name": "randomized_benchmarking"},
                                    "fidelity": 0.903,
                                    "standardError": null
                                }
                            ]
                        }
                    },
                    "twoQubitProperties": {
                        "0-1": {
                            "twoQubitGateFidelity": [
                                {
                                    "direction": {"control": 0, "target": 1},
                                    "gateName": "cnot",
                                    "fidelity": 0.877,
                                    "fidelityType": {"name": "interleaved_randomized_benchmarking"}
                                }
                            ]
                        }
                    }
                }
                """
        jaqcd() = """{
                    "braketSchemaHeader": {
                        "name": "braket.device_schema.rigetti.rigetti_device_capabilities",
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
                        "qubitCount": 32,
                        "nativeGateSet": ["ccnot", "cy"],
                        "connectivity": {"fullyConnected": false, "connectivityGraph": {"1": ["2", "3"]}}
                    },
                    "deviceParameters": {},
                    "standardized": $props 
                }"""
        openqasm() = """{
                        "braketSchemaHeader": {
                            "name": "braket.device_schema.rigetti.rigetti_device_capabilities",
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
                                "requireAllQubitsMeasurement": false,
                                "requireContiguousQubitIndices": false,
                                "supportsPartialVerbatimBox": true,
                                "supportsUnassignedMeasurements": true
                            }
                        },
                        "paradigm": {
                            "braketSchemaHeader": {
                                "name": "braket.device_schema.gate_model_qpu_paradigm_properties",
                                "version": "1"
                            },
                            "qubitCount": 32,
                            "nativeGateSet": ["ccnot", "cy"],
                            "connectivity": {"fullyConnected": false, "connectivityGraph": {"1": ["2", "3"]}}
                        },
                        "deviceParameters": {}
                    }
                    """
        @testset for format in [jaqcd, openqasm]
            @test Braket.parse_raw_schema(format()) isa Braket.RigettiDeviceCapabilities
        end
    end
    @testset "Device parameters" begin
        ir_gen() = """{
                        "braketSchemaHeader": {
                            "name": "braket.device_schema.rigetti.rigetti_device_parameters",
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
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.RigettiDeviceParameters
    end
    @testset "Provider properties" begin
        ir_gen() = """{
                        "braketSchemaHeader": {
                            "name": "braket.device_schema.rigetti.rigetti_provider_properties",
                            "version": "1"
                        },
                        "specs": {
                            "1Q": {
                                "0": {
                                    "T1": 1.69308193540552e-05,
                                    "T2": 1.8719137150144e-05,
                                    "f1QRB": 0.995048041389577,
                                    "f1QRB_std_err": 0.000244061520274907,
                                    "f1Q_simultaneous_RB": 0.989821537688075,
                                    "f1Q_simultaneous_RB_std_err": 0.000699235456806402,
                                    "fActiveReset": 0.978,
                                    "fRO": 0.919
                                }
                            },
                            "2Q": {
                                "0-1": {
                                    "Avg_T1": 2.679913663417025e-05,
                                    "Avg_T2": 2.957247297939755e-05,
                                    "Avg_f1QRB": 0.9973200289413551,
                                    "Avg_f1QRB_std_err": 0.000219048562898114,
                                    "Avg_f1Q_simultaneous_RB": 0.9933270881335465,
                                    "Avg_f1Q_simultaneous_RB_std_err": 0.000400066119480196,
                                    "Avg_fActiveReset": 0.8425,
                                    "Avg_fRO": 0.9165000000000001,
                                    "fCZ": 0.843255182448229,
                                    "fCZ_std_err": 0.00806009046760912
                                }
                            }
                        }
                    }"""
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.RigettiProviderProperties
    end
end
