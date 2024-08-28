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
    
    @testset "LocalDetuning: Discretize" begin
        times₅ = [0, 0.1, 0.2]
        values₅ = [0.2, 0.5, 0.7]
        pattern₅ = [0.1, 0.3, 0.5]
        ld = LocalDetuning(times₅, values₅, pattern₅)
        properties = Braket.DiscretizationProperties(
            Braket.Lattice(
               Braket.Area(Dec128("1e-3"), Dec128("1e-3")),
               Braket.Geometry(Dec128("1e-7"), Dec128("1e-7"), Dec128("1e-7"), 200)
            ),
            MockRydberg(
                Dec128("1e-6"), 
                Braket.RydbergGlobal(
                    (Dec128("1.0"), Dec128("1e6")),
                    Dec128("400.0"),
                    Dec128("0.2"),
                    (Dec128("1.0"), Dec128("1e6")),
                    Dec128("0.2"),
                    Dec128("0.2"),
                    (Dec128("1.0"), Dec128("1e6")),
                    Dec128("5e-7"),
                    Dec128("1e-9"),
                    Dec128("1e-5"),
                    Dec128("0.0"),
                    Dec128("100.0")
                ),
                MockRydbergLocal(Dec128("1e-9"), Dec128("2000.0"), Dec128("0.01"))
            )
        )
        discretized_ld = discretize(ld, properties)
        @test discretized_ld isa LocalDetuning
    end

end
