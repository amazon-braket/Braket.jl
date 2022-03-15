using Braket, Test, Braket.IR

@testset "Dwave Device Schema" begin
    @testset "Provider level parameters" begin
        ir_gen(annealing_duration, max_results) = """
            {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.dwave.dwave_provider_level_parameters",
                    "version": "1"
                },
                "annealingOffsets": [3.67, 6.123],
                "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
                "annealingDuration": $annealing_duration,
                "autoScale": null,
                "beta": 123.456,
                "chains": [[0, 1, 5], [6]],
                "compensateFluxDrift": false,
                "fluxBiases": [1.1, 2.2, 3.3, 4.4],
                "initialState": [1, 3, 0, 1],
                "maxResults": $max_results,
                "postprocessingType": "sampling",
                "programmingThermalizationDuration": 625,
                "readoutThermalizationDuration": 256,
                "reduceIntersampleCorrelation": false,
                "reinitializeState": true,
                "resultFormat": "raw",
                "spinReversalTransformCount": 100
            }
            """
        @testset for annealing_duration in [1, 500], max_results in [1, 20]
            @test Braket.parse_raw_schema(ir_gen(annealing_duration, max_results)) isa Braket.DwaveProviderLevelParameters
        end
        # enable these when we have input verification
        #=
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(0, 1))
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(1, 0))
        =#
    end
    @testset "Provider properties" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.dwave.dwave_provider_properties",
                "version": "1"
            },
            "annealingOffsetStep": 1.45,
            "annealingOffsetStepPhi0": 1.45,
            "annealingOffsetRanges": [[1.45, 1.45], [1.45, 1.45]],
            "annealingDurationRange": [1.45, 2.45, 3],
            "couplers": [[1, 2, 3], [1, 2, 3]],
            "defaultAnnealingDuration": 1,
            "defaultProgrammingThermalizationDuration": 1,
            "defaultReadoutThermalizationDuration": 1,
            "extendedJRange": [1.1, 2.45, 3.45],
            "hGainScheduleRange": [1.11, 2.56, 3.67],
            "hRange": [1.4, 2.6, 3.66],
            "jRange": [1.67, 2.666, 3.666],
            "maximumAnnealingSchedulePoints": 1,
            "maximumHGainSchedulePoints": 1,
            "perQubitCouplingRange": [1.777, 2.567, 3.1201],
            "programmingThermalizationDurationRange": [1, 2, 3],
            "qubits": [1, 2, 3],
            "qubitCount": 1,
            "quotaConversionRate": 1.341234,
            "readoutThermalizationDurationRange": [1, 2, 3],
            "taskRunDurationRange": [1, 2, 3],
            "topology": {}
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.DwaveProviderProperties
    end
    @testset "Device parameters" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.dwave.dwave_device_parameters",
                "version": "1"
            },
            "providerLevelParameters": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.dwave.dwave_provider_level_parameters",
                    "version": "1"
                }
            }
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.DwaveDeviceParameters
    end
    @testset "Device capabilities" begin
        ir_gen() = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.dwave.dwave_device_capabilities",
                "version": "1"
            },
            "provider": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.dwave.dwave_provider_properties",
                    "version": "1"
                },
                "annealingOffsetStep": 1.45,
                "annealingOffsetStepPhi0": 1.45,
                "annealingOffsetRanges": [[1.45, 1.45], [1.45, 1.45]],
                "annealingDurationRange": [1.45, 2.45, 3],
                "couplers": [[1, 2, 3], [1, 2, 3]],
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
                "braket.ir.annealing.problem": {
                    "actionType": "braket.ir.annealing.problem",
                    "version": ["1"]
                }
            },
            "paradigm": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.device_paradigm_properties",
                    "version": "1"
                }
            },
            "deviceParameters": {
                "braketSchemaHeader": {
                    "name": "braket.device_schema.dwave.dwave_device_parameters",
                    "version": "1"
                },
                "providerLevelParameters": {
                    "braketSchemaHeader": {
                        "name": "braket.device_schema.dwave.dwave_provider_level_parameters",
                        "version": "1"
                    }
                }
            }
        }
        """
        @test Braket.parse_raw_schema(ir_gen()) isa Braket.DwaveDeviceCapabilities
    end
    @testset "2000Q Device level parameters" begin
        ir_gen(annealing_duration, max_results) = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.dwave.dwave_2000Q_device_level_parameters",
                "version": "1"
            },
            "annealingOffsets": [3.67, 6.123],
            "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
            "annealingDuration": $annealing_duration,
            "autoScale": null,
            "compensateFluxDrift": false,
            "fluxBiases": [1.1, 2.2, 3.3, 4.4],
            "initialState": [1, 3, 0, 1],
            "maxResults": $max_results,
            "programmingThermalizationDuration": 625,
            "readoutThermalizationDuration": 256,
            "reduceIntersampleCorrelation": false,
            "reinitializeState": true,
            "resultFormat": "raw",
            "spinReversalTransformCount": 100
        }
        """
        @testset for annealing_duration in [1, 500], max_results in [1, 20]
            @test Braket.parse_raw_schema(ir_gen(annealing_duration, max_results)) isa Braket.Dwave2000QDeviceLevelParameters
        end
        # enable these when we have input verification
        #=
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(0, 1))
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(1, 0))
        =#
    end
    @testset "Advantage Device level parameters" begin
        ir_gen(annealing_duration, max_results) = """{
            "braketSchemaHeader": {
                "name": "braket.device_schema.dwave.dwave_advantage_device_level_parameters",
                "version": "1"
            },
            "annealingOffsets": [3.67, 6.123],
            "annealingSchedule": [[13.37, 10.08], [3.14, 1.618]],
            "annealingDuration": $annealing_duration,
            "autoScale": null,
            "compensateFluxDrift": false,
            "fluxBiases": [1.1, 2.2, 3.3, 4.4],
            "initialState": [1, 3, 0, 1],
            "maxResults": $max_results,
            "programmingThermalizationDuration": 625,
            "readoutThermalizationDuration": 256,
            "reduceIntersampleCorrelation": false,
            "reinitializeState": true,
            "resultFormat": "raw",
            "spinReversalTransformCount": 100
        }
        """
        @testset for annealing_duration in [1, 500], max_results in [1, 20]
            @test Braket.parse_raw_schema(ir_gen(annealing_duration, max_results)) isa Braket.DwaveAdvantageDeviceLevelParameters
        end
        # enable these when we have input verification
        #=
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(0, 1))
        @test_throws ArgumentError Braket.parse_raw_schema(ir_gen(1, 0))
        =#
    end
end
