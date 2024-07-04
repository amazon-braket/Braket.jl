using Braket, Test, Mocking, JSON3, Dates, Graphs
using Braket: status
Mocking.activate()

# Constants
RESERVATION_ARN = "arn:aws:braket:us-east-1:123456789:reservation/uuid"
DEVICE_ARN = "arn:aws:braket:us-east-1:123456789:device/qpu/ionq/Forte-1"

@testset "DirectReservation Tests" begin
    # Creating a DirectReservation
    @testset "Creating DirectReservation" begin
        reservation = Braket.DirectReservation(DEVICE_ARN, RESERVATION_ARN)
        @test reservation.device_arn == DEVICE_ARN
        @test reservation.reservation_arn == RESERVATION_ARN
        @test reservation.is_active == false
    end

    # Starting and stopping a reservation
    @testset "Starting and Stopping Reservation" begin
        reservation = Braket.DirectReservation(DEVICE_ARN, RESERVATION_ARN)

        # Start reservation
        Braket.start_reservation!(reservation)
        @test reservation.is_active == true
        @test ENV["AMZN_BRAKET_RESERVATION_DEVICE_ARN"] == DEVICE_ARN
        @test ENV["AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN"] == RESERVATION_ARN

        # Stop reservation
        Braket.stop_reservation!(reservation)
        @test reservation.is_active == false
        @test !haskey(ENV, "AMZN_BRAKET_RESERVATION_DEVICE_ARN")
        @test !haskey(ENV, "AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN")

    end

    function test_func()
        println("Executing within reservation context")
        return 5 
        # Add actions as needed
        @test ENV["AMZN_BRAKET_RESERVATION_DEVICE_ARN"] == DEVICE_ARN
        @test ENV["AMZN_BRAKET_RESERVATION_TIME_WINDOW_ARN"] == RESERVATION_ARN 
    end

    @testset "Direct Reservation Function" begin
	   reservation = Braket.DirectReservation(DEVICE_ARN, RESERVATION_ARN)
	   @test Braket.direct_reservation(reservation, test_func) == 5
    end

    @testset "Invalid Device Type" begin
        invalid_device = 12345  # Not a valid device type
        @test_throws UndefVarError DirectReservation(invalid_device, RESERVATION_ARN)
    end

end
