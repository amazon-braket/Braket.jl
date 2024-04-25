using Braket, PyBraket, Test
using Braket: AtomArrangement, AtomArrangementItem, TimeSeries, DrivingField, AwsDevice, AnalogHamiltonianSimulation, discretize, AnalogHamiltonianSimulationQuantumTaskResult

@testset "AHS" begin
    a = 5.5e-6

    register = AtomArrangement()
    push!(register, AtomArrangementItem((0.5, 0.5 + 1/√2) .* a))
    push!(register, AtomArrangementItem((0.5 + 1/√2, 0.5) .* a))
    push!(register, AtomArrangementItem((0.5 + 1/√2, -0.5) .* a))
    push!(register, AtomArrangementItem((0.5, -0.5 - 1/√2) .* a))
    push!(register, AtomArrangementItem((-0.5, -0.5 - 1/√2) .* a))
    push!(register, AtomArrangementItem((-0.5 -1/√2, -0.5) .* a))
    push!(register, AtomArrangementItem((-0.5 -1/√2, 0.5) .* a))
    push!(register, AtomArrangementItem((-0.5, 0.5 + 1/√2) .* a))
    # extracted from device paradigm
    (C6, Ω_min, Ω_max, Ω_slope_max, Δ_min, Δ_max, time_max) = (5.42e-24, 0.0, 6.3e6, 2.5e14, -1.25e8, 1.25e8, 4.0e-6)

    time_max     = Float64(time_max)
    Δ_start      = -5 * Float64(Ω_max)
    Δ_end        = 5 * Float64(Ω_max)
    @test all(Δ_min <= Δ <= Δ_max for Δ in (Δ_start, Δ_end))

    time_ramp = 1e-7  # seconds
    @test Float64(Ω_max) / time_ramp < Ω_slope_max

    Ω                       = TimeSeries()
    Ω[0.0]                  = 0.0
    Ω[time_ramp]            = Ω_max
    Ω[time_max - time_ramp] = Ω_max
    Ω[time_max]             = 0.0 

    Δ                       = TimeSeries()
    Δ[0.0]                  = Δ_start
    Δ[time_ramp]            = Δ_start
    Δ[time_max - time_ramp] = Δ_end
    Δ[time_max]             = Δ_end

    ϕ           = TimeSeries()
    ϕ[0.0]      = 0.0
    ϕ[time_max] = 0.0

    drive                   = DrivingField(Ω, ϕ, Δ)
    ahs_program             = AnalogHamiltonianSimulation(register, drive)

    ahs_local    = PyBraket.LocalSimulator("braket_ahs")
    local_result = result(run(ahs_local, ahs_program, shots=1_000))
    @test length(local_result.measurements) == 1_000

    
    #=if !haskey(ENV, "GITLAB_CI")
        aquila_qpu   = AwsDevice("arn:aws:braket:us-east-1::device/qpu/quera/Aquila")
        drive                   = DrivingField(Ω, ϕ, Δ)
        ahs_program             = AnalogHamiltonianSimulation(register, drive)
        discretized_ahs_program = discretize(ahs_program, aquila_qpu)
        local_result = result(run(ahs_local, discretized_ahs_program, shots=1_000))
        @test length(local_result.measurements) == 1_000
    end=#
end


@testset "AHS_Local_simulator" begin
    a = 5.5e-6

    register = AtomArrangement()
    push!(register, AtomArrangementItem((0, 0) .* a))
    
    Ω_max = 2.5e6
    t_max = 2π/(Ω_max)
    Ω = TimeSeries()
    Ω[0.0] = Ω_max
    Ω[t_max] = Ω_max

    ϕ = TimeSeries()
    ϕ[0.0] = 0.0
    ϕ[t_max] = 0.0

    Δ = TimeSeries()
    Δ[0.0] = 0.0
    Δ[t_max] = 0.0

    drive                   = DrivingField(Ω, ϕ, Δ)
    ahs_program             = AnalogHamiltonianSimulation(register, drive)

    ahs_local    = PyBraket.LocalSimulator("braket_ahs")
    local_result = result(run(ahs_local, ahs_program, shots=1_000))
    
    g_count = 0
    for meas in local_result.measurements
        g_count += meas.post_sequence[1]
    end

    @test g_count == 1_000

end
