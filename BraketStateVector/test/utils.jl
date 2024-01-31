using Test, BraketStateVector

@testset "utils" begin
	for ix in 0:(2^12-1)
		@test BraketStateVector.index_to_endian_bits(ix, 12) == reverse(digits(ix, base=2, pad=qc))
	end

end
