using Braket, Test, JSON3, StructTypes, Mocking, UUIDs, DecFP

Mocking.activate()

struct MockRydbergLocal
    timeResolution::Dec128
    commonDetuningResolution::Dec128
    localDetuningResolution::Dec128
end

struct MockRydberg
    c6coefficient::Dec128
    rydbergGlobal::Braket.RydbergGlobal
    rydbergLocal::MockRydbergLocal
end

struct MockDiscretizationProperties
    rydberg::MockRydberg
end

@testset "AHS.LocalDetuning" begin

	@testset "LocalDetuning" begin
           times₁ = [0, 0.1, 0.2, 0.3]
           times₂ = [0.3, 0.1, 0.2, 0]
           glob_amplitude₁ = [0.5, 0.8, 0.9, 1.0]
           pattern₁ = [0.3, 0.7, 0.6, -0.5, 0, 1.6]
           s₁ = LocalDetuning(times₁, glob_amplitude₁, pattern₁)
           s₂ = LocalDetuning(times₂, glob_amplitude₁, pattern₁)
           @test s₁.magnitude.pattern.series == [0.3, 0.7, 0.6, -0.5, 0, 1.6]
           @test s₁.magnitude.time_series.sorted == true
           @test s₂.magnitude.time_series.sorted == false
	end
	
	@testset "LocalDetuning Stitch: Mean, Left, Right" begin
           times₁ = [0, 0.1, 0.2, 0.3]
           glob_amplitude₁ = [0.5, 0.8, 0.9, 1.0]
           pattern₁ = [0.3, 0.7, 0.6, -0.5, 0, 1.6]	
           times₂ = [0, 0.1, 0.2, 0.3]
           glob_amplitude₂ = [0.5, 0.8, 0.9, 1.0]
           pattern₂ = pattern₁
           s₂ = LocalDetuning(times₂, glob_amplitude₂, pattern₂)
           s₁ = LocalDetuning(times₁, glob_amplitude₁, pattern₁)
           stitchedₗ = stitch(s₁, s₂, :left)
           @test stitchedₗ.magnitude.pattern == s₁.magnitude.pattern
	end
end
