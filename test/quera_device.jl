using Braket, Test

@testset "Quera device" begin
    @testset "Ahs paradigm properties" begin
        ir_gen() = """{
        "braketSchemaHeader": {
            "name": "braket.device_schema.quera.quera_ahs_paradigm_properties",
            "version": "1"
        },
        "qubitCount": 256,
        "lattice": {
            "area": {
                "width": 100.0e-6,
                "height": 100.0e-6
            },
            "geometry": {
                "spacingRadialMin": 4.0e-6,
                "spacingVerticalMin": 2.5e-6,
                "positionResolution": 1e-7,
                "numberSitesMax": 256
            }
        },
        "rydberg": {
            "c6Coefficient": $(2 * pi * 862690),
            "rydbergGlobal": {
                "rabiFrequencyRange": [0, $(2 * pi * 4.0e6)],
                "rabiFrequencyResolution": 400,
                "rabiFrequencySlewRateMax": $(2 * pi * 4e6 / 100e-9),
                "detuningRange": [$(-2 * pi * 20.0e6), $(2 * pi * 20.0e6)],
                "detuningResolution": 0.2,
                "detuningSlewRateMax": $(2 * pi * 40.0e6 / 100e-9),
                "phaseRange": [-99, 99],
                "phaseResolution": 5e-7,
                "phaseSlewRateMax": $(2 * pi / 100e-9),
                "timeResolution": 1e-9,
                "timeDeltaMin": 1e-8,
                "timeMax": 4.0e-6,
                "timeMin": 0
            },
            "rydbergLocal": {
                "detuningRange": [0, $(2 * pi * 50.0e6)],
                "commonDetuningResolution": 2000,
                "localDetuningResolution": 0.01,
                "detuningSlewRateMax": $(1 / 100e-9),
                "numberLocalDetuningSites": 256,
                "spacingRadialMin": 5e-6,
                "timeResolution": 1e-9,
                "timeDeltaMin": 1e-8
            }
        },
        "performance": {
            "lattice": {
                "positionErrorAbs": 0.025e-6
            },
            "rydberg": {
                "rydbergGlobal": {
                    "rabiFrequencyErrorRel": 0.01,
                    "rabiFrequencyHomogeneityRel": 0.05,
                    "rabiFrequencyHomogeneityAbs": 60e3,
                    "detuningErrorAbs": $(2 * pi * 10.0e3),
                    "phaseErrorAbs": $(2 * pi / 1000),
                    "omegaTau": 10,
                    "singleQubitFidelity": 0.95,
                    "twoQubitFidelity": 0.95,
                    "timeMax": 4.0e-6,
                    "timeMin": 0
                },
                "rydbergLocal": {
                    "detuningDynamicRange": 10,
                    "detuningErrorRel": 0.01,
                    "detuningHomogeneity": 0.02,
                    "detuningScaleErrorRel": 0.01,
                    "darkErrorRete": 1e3,
                    "brightErrorRate": 3e6
                }
            },
            "detection": {
                "atomDetectionFidelity": 0.99,
                "vacancyDetectionFidelity": 0.999,
                "groundStateDetectionFidelity": 0.99,
                "rydbergStateDetectionFidelity": 0.99
            },
            "sorting": {
                "moveFidelity": 0.98,
                "patternFidelitySquare": 1e-4
            }
        }
    }
    """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.QueraAhsParadigmProperties
    end
    @testset "Device capabilities" begin
        ir_gen() = """{
        "braketSchemaHeader": {
            "name": "braket.device_schema.quera.quera_device_capabilities",
            "version": "1"
        },
        "service": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.device_service_properties",
                "version": "1"
            },
            "executionWindows": [
                {
                    "executionDay": "Everyday",
                    "windowStartHour": "09:00",
                    "windowEndHour": "10:00"
                }
            ],
            "shotsRange": [1, 10000],
            "deviceCost": {"price": 0.25, "unit": "minute"},
            "deviceDocumentation": {
                "imageUrl": "image_url",
                "summary": "Summary on the device",
                "externalDocumentationUrl": "external doc link"
            },
            "deviceLocation": "us-east-1",
            "updatedAt": "2022-04-16T19:28:02.869136"
        },
        "action": {
            "braket.ir.ahs.program": {
                "actionType": "braket.ir.ahs.program",
                "version": ["1"]
            }
        },
        "deviceParameters": {},
        "paradigm": {
            "braketSchemaHeader": {
                "name": "braket.device_schema.quera.quera_ahs_paradigm_properties",
                "version": "1"
            },
            "qubitCount": 256,
            "lattice": {
                "area": {
                    "width": 100.0e-6,
                    "height": 100.0e-6
                },
                "geometry": {
                    "spacingRadialMin": 4.0e-6,
                    "spacingVerticalMin": 2.5e-6,
                    "positionResolution": 1e-7,
                    "numberSitesMax": 256
                }
            },
            "rydberg": {
                "c6Coefficient": $(2 * pi * 862690),
                "timeMax": 4.0e-6,
                "rydbergGlobal": {
                    "rabiFrequencyRange": [0, $(2 * pi * 4.0e6)],
                    "rabiFrequencyResolution": 400,
                    "rabiFrequencySlewRateMax": $(2 * pi * 4e6 / 100e-9),
                    "detuningRange": [$(-2 * pi * 20.0e6), $(2 * pi * 20.0e6)],
                    "detuningResolution": 0.2,
                    "detuningSlewRateMax": $(2 * pi * 40.0e6 / 100e-9),
                    "phaseRange": [-99, 99],
                    "phaseResolution": 5e-7,
                    "phaseSlewRateMax": $(2 * pi / 100e-9),
                    "timeResolution": 1e-9,
                    "timeDeltaMin": 1e-8,
                    "timeMax": 4.0e-6,
                    "timeMin": 0
                },
                "rydbergLocal": {
                    "detuningRange": [0, $(2 * pi * 50.0e6)],
                    "commonDetuningResolution": 2000,
                    "localDetuningResolution": 0.01,
                    "detuningSlewRateMax": $(1 / 100e-9),
                    "numberLocalDetuningSites": 256,
                    "spacingRadialMin": 5e-6,
                    "timeResolution": 1e-9,
                    "timeDeltaMin": 1e-8
                }
            },
            "performance": {
                "lattice": {
                    "positionErrorAbs": 0.025e-6
                },
                "rydberg": {
                    "rydbergGlobal": {
                        "rabiFrequencyErrorRel": 0.01,
                        "rabiFrequencyHomogeneityRel": 0.05,
                        "rabiFrequencyHomogeneityAbs": 60e3,
                        "detuningErrorAbs": $(2 * pi * 10.0e3),
                        "phaseErrorAbs": $(2 * pi / 1000),
                        "omegaTau": 10,
                        "singleQubitFidelity": 0.95,
                        "twoQubitFidelity": 0.95,
                        "timeMax": 4.0e-6,
                        "timeMin": 0
                    },
                    "rydbergLocal": {
                        "detuningDynamicRange": 10,
                        "detuningErrorRel": 0.01,
                        "detuningHomogeneity": 0.02,
                        "detuningScaleErrorRel": 0.01,
                        "darkErrorRete": 1e3,
                        "brightErrorRate": 3e6
                    }
                },
                "detection": {
                    "atomDetectionFidelity": 0.99,
                    "vacancyDetectionFidelity": 0.999,
                    "groundStateDetectionFidelity": 0.99,
                    "rydbergStateDetectionFidelity": 0.99
                },
                "sorting": {
                    "moveFidelity": 0.98,
                    "patternFidelitySquare": 1e-4
                }
            }
        }
    }
    """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.QueraDeviceCapabilities
    end
end
