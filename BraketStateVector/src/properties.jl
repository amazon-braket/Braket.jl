const sv_qubit_count = 28
const sv_max_shots = 1_000_000
const sv_observables = ["x", "y", "z", "h", "i", "hermitian"]
const sv_props_dict = Dict(
    "braketSchemaHeader"=>Dict("name"=>"braket.device_schema.simulators.gate_model_simulator_device_capabilities", "version"=>"1"),
    "service"=>Dict("executionWindows"=>[Dict("executionDay"=>"Everyday", "windowStartHour"=>"00:00", "windowEndHour"=>"23:59:59",)], "shotsRange"=>[0, sv_max_shots],),
    "action"=>Dict("braket.ir.jaqcd.program"=>Dict("actionType"=>"braket.ir.jaqcd.program", "version"=>["1"], "supportedOperations"=>[ "ccnot", "cnot", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "cswap", "cv", "cy", "cz", "ecr", "h", "i", "iswap", "pswap", "phaseshift", "rx", "ry", "rz", "s", "si", "swap", "t", "ti", "unitary", "v", "vi", "x", "xx", "xy", "y", "yy", "z", "zz"],
                        "supportedResultTypes"=>[
                            Dict("name"=>"Sample", "observables"=>sv_observables, "minShots"=>1, "maxShots"=>sv_max_shots),
                            Dict("name"=>"Expectation", "observables"=>sv_observables, "minShots"=>0, "maxShots"=>sv_max_shots),
                            Dict("name"=>"Variance", "observables"=>sv_observables, "minShots"=>0, "maxShots"=>sv_max_shots,),
                            Dict("name"=>"Probability", "minShots"=>0, "maxShots"=>sv_max_shots),
                            Dict("name"=>"StateVector", "minShots"=>0, "maxShots"=>0),
                            Dict("name"=>"DensityMatrix", "minShots"=>0, "maxShots"=>0),
                            Dict("name"=>"Amplitude", "minShots"=>0, "maxShots"=>0),
                        ],
                    ),
                    "braket.ir.openqasm.program"=>Dict("actionType"=>"braket.ir.openqasm.program", "version"=>["1"], "supportedOperations"=>["U", "GPhase", "ccnot", "cnot", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "cswap", "cv", "cy", "cz", "ecr", "gpi", "gpi2", "h", "i", "iswap", "ms", "pswap", "phaseshift", "rx", "ry", "rz", "s", "si", "swap", "t", "ti", "unitary", "v", "vi", "x", "xx", "xy", "y", "yy", "z", "zz"],
                        "supportedModifiers"=>[
                            Dict("name"=>"ctrl"),
                            Dict("name"=>"negctrl"),
                            Dict("name"=>"pow", "exponent_types"=>["int", "float"]),
                            Dict("name"=>"inv"),
                        ],
                        "supportedPragmas"=>["braket_unitary_matrix", "braket_result_type_state_vector", "braket_result_type_density_matrix", "braket_result_type_sample", "braket_result_type_expectation", "braket_result_type_variance", "braket_result_type_probability", "braket_result_type_amplitude"],
                        "forbiddenPragmas"=>["braket_noise_amplitude_damping", "braket_noise_bit_flip", "braket_noise_depolarizing", "braket_noise_kraus", "braket_noise_pauli_channel", "braket_noise_generalized_amplitude_damping", "braket_noise_phase_flip", "braket_noise_phase_damping", "braket_noise_two_qubit_dephasing", "braket_noise_two_qubit_depolarizing", "braket_result_type_adjoint_gradient"],
                        "supportedResultTypes"=>[
                            Dict("name"=>"Sample", "observables"=>sv_observables, "minShots"=>1, "maxShots"=>sv_max_shots),
                            Dict("name"=>"Expectation", "observables"=>sv_observables, "minShots"=>0, "maxShots"=>sv_max_shots),
                            Dict("name"=>"Variance", "observables"=>sv_observables, "minShots"=>0, "maxShots"=>sv_max_shots),
                            Dict("name"=>"Probability", "minShots"=>0, "maxShots"=>sv_max_shots),
                            Dict("name"=>"StateVector", "minShots"=>0, "maxShots"=>0),
                            Dict("name"=>"DensityMatrix", "minShots"=>0, "maxShots"=>0),
                            Dict("name"=>"Amplitude", "minShots"=>0, "maxShots"=>0),
                        ],
                        "supportPhysicalQubits"=>false,
                        "supportsPartialVerbatimBox"=>false,
                        "requiresContiguousQubitIndices"=>true,
                        "requiresAllQubitsMeasurement"=>true,
                        "supportsUnassignedMeasurements"=>true,
                        "disabledQubitRewiringSupported"=>false,
                    ),
                ),
                "paradigm"=>Dict("qubitCount"=>sv_qubit_count),
                "deviceParameters"=>Dict("paradigmParameters"=>Dict("qubitCount"=>sv_qubit_count)),
            )

const sv_props = Braket.parse_raw_schema(JSON3.write(sv_props_dict))

const dm_qubit_count = 14
const dm_max_shots = 1_000_000
const dm_observables = ["x", "y", "z", "h", "i", "hermitian"]
const dm_props_dict = Dict(
    "braketSchemaHeader"=>Dict("name"=>"braket.device_schema.simulators.gate_model_simulator_device_capabilities", "version"=>"1"),
    "service"=>Dict("executionWindows"=>[Dict("executionDay"=>"Everyday", "windowStartHour"=>"00:00", "windowEndHour"=>"23:59:59")], "shotsRange"=>[0,dm_max_shots]),
    "action"=>Dict("braket.ir.openqasm.program"=>Dict("actionType"=>"braket.ir.openqasm.program", "version"=>["1"],
            "supportedOperations"=>["U", "GPhase", "ccnot", "cnot", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "cswap", "cv", "cy", "cz", "ecr", "gpi", "gpi2", "h", "i", "iswap", "ms", "pswap", "phaseshift", "rx", "ry", "rz", "s", "si", "swap", "t", "ti", "unitary", "v", "vi", "x", "xx", "xy", "y", "yy", "z", "zz", "bit_flip", "phase_flip", "pauli_channel", "depolarizing", "two_qubit_depolarizing", "two_qubit_dephasing", "amplitude_damping", "generalized_amplitude_damping", "phase_damping", "kraus"],
            "supportedModifiers"=>[
                Dict("name"=>"ctrl"),
                Dict("name"=>"negctrl"),
                Dict("name"=>"pow", "exponent_types"=>["int", "float"]),
                Dict("name"=>"inv")
            ],
            "supportedPragmas"=>[
                "braket_unitary_matrix",
                "braket_result_type_state_vector",
                "braket_result_type_density_matrix",
                "braket_result_type_sample",
                "braket_result_type_expectation",
                "braket_result_type_variance",
                "braket_result_type_probability",
                "braket_result_type_amplitude",
                "braket_noise_amplitude_damping",
                "braket_noise_bit_flip",
                "braket_noise_depolarizing",
                "braket_noise_kraus",
                "braket_noise_pauli_channel",
                "braket_noise_generalized_amplitude_damping",
                "braket_noise_phase_flip",
                "braket_noise_phase_damping",
                "braket_noise_two_qubit_dephasing",
                "braket_noise_two_qubit_depolarizing"
            ],
            "forbiddenPragmas"=>[
                "braket_result_type_adjoint_gradient"
            ],
            "supportedResultTypes"=>[
                Dict(
                    "name"=>"Sample",
                    "observables"=>dm_observables,
                    "minShots"=>1,
                    "maxShots"=>dm_max_shots
                ),
                Dict(
                    "name"=>"Expectation",
                    "observables"=>dm_observables,
                    "minShots"=>0,
                    "maxShots"=>dm_max_shots
                ),
                Dict(
                    "name"=>"Variance",
                    "observables"=>dm_observables,
                    "minShots"=>0,
                    "maxShots"=>dm_max_shots
                ),
                Dict("name"=>"Probability", "minShots"=>0, "maxShots"=>dm_max_shots),
                Dict("name"=>"DensityMatrix", "minShots"=>0, "maxShots"=>0)
            ],
            "supportPhysicalQubits"=>false,
            "supportsPartialVerbatimBox"=>false,
            "requiresContiguousQubitIndices"=>true,
            "requiresAllQubitsMeasurement"=>true,
            "supportsUnassignedMeasurements"=>true,
            "disabledQubitRewiringSupported"=>false
        ),
        "braket.ir.jaqcd.program"=>Dict("actionType"=>"braket.ir.jaqcd.program", "version"=>["1"],
                                        "supportedOperations"=>["amplitude_damping", "bit_flip", "ccnot", "cnot", "cphaseshift", "cphaseshift00", "cphaseshift01", "cphaseshift10", "cswap", "cv", "cy", "cz", "depolarizing", "ecr", "generalized_amplitude_damping", "h", "i", "iswap", "kraus", "pauli_channel", "two_qubit_pauli_channel", "phase_flip", "phase_damping", "phaseshift", "pswap", "rx", "ry", "rz", "s", "si", "swap", "t", "ti", "two_qubit_dephasing", "two_qubit_depolarizing", "unitary", "v", "vi", "x", "xx", "xy", "y", "yy", "z", "zz"],
                                        "supportedResultTypes"=>[Dict("name"=>"Sample", "observables"=>dm_observables, "minShots"=>1, "maxShots"=>dm_max_shots),
                                                                 Dict("name"=>"Expectation", "observables"=>dm_observables, "minShots"=>0, "maxShots"=>dm_max_shots),
                                                                 Dict("name"=>"Variance", "observables"=>dm_observables, "minShots"=>0, "maxShots"=>dm_max_shots),
                                                                 Dict("name"=>"Probability", "minShots"=>0, "maxShots"=>dm_max_shots),
                                                                 Dict("name"=>"DensityMatrix", "minShots"=>0, "maxShots"=>0)
                                                                ]
                                        )
    ),
    "paradigm"=>Dict("qubitCount"=>dm_qubit_count),
    "deviceParameters"=>Dict("paradigmParameters"=>Dict("qubitCount"=>dm_qubit_count)),
    )
const dm_props = Braket.parse_raw_schema(JSON3.write(dm_props_dict))

