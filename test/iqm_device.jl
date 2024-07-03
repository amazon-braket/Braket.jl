using Braket, Test

@testset "IQM device schema" begin
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
                }"""
        jaqcd() = """{
                        "braketSchemaHeader": {
                            "name": "braket.device_schema.iqm.iqm_device_capabilities",
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
                            "deviceLocation": "eu-west-2",
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
                        "deviceParameters": {}
                    }
        """
        openqasm() = """{
                        "braketSchemaHeader": {
                            "name": "braket.device_schema.iqm.iqm_device_capabilities",
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
                                "supportsPartialVerbatimBox": false,
                                "supportsUnassignedMeasurements": false
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
                    }
        """
        @testset for format in [jaqcd, openqasm]
            @test Braket.parse_raw_schema(format()) isa Braket.IqmDeviceCapabilities
        end
    end
    @testset "Device parameters" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.iqm.iqm_device_parameters",
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
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.IqmDeviceParameters
    end
    @testset "Provider properties" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.iqm.iqm_provider_properties",
                "version": "1"
            },
            "properties": {
                "one_qubit": {
                    "0": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "1": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "2": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "3": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "4": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "5": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "6": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    },
                    "7": {
                        "T1": 12.2,
                        "T2": 13.5,
                        "fRO": 0.99,
                        "fRB": 0.98,
                        "native_gate_fidelities": [
                            {"native_gate": "rz", "CLf": 0.99},
                            {"native_gate": "sx", "CLf": 0.99},
                            {"native_gate": "x", "CLf": 0.99}
                        ],
                        "EPE": 0.001
                    }
                },
                "two_qubit": {
                    "0-1": {
                        "coupling": {"control_qubit": 0, "target_qubit": 1},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "1-2": {
                        "coupling": {"control_qubit": 1, "target_qubit": 2},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "2-3": {
                        "coupling": {"control_qubit": 2, "target_qubit": 3},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "3-4": {
                        "coupling": {"control_qubit": 3, "target_qubit": 4},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "4-5": {
                        "coupling": {"control_qubit": 4, "target_qubit": 5},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "5-6": {
                        "coupling": {"control_qubit": 5, "target_qubit": 6},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "6-7": {
                        "coupling": {"control_qubit": 6, "target_qubit": 7},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    },
                    "7-0": {
                        "coupling": {"control_qubit": 7, "target_qubit": 0},
                        "CLf": 0.99,
                        "ECR_f": 0.99
                    }
                }
            }
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.IqmProviderProperties
    end
end
