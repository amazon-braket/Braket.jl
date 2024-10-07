push!(LOAD_PATH,"../src/")

using Documenter, Braket, Braket.Dates

makedocs(sitename="Braket.jl")

deploydocs(repo="github.com/amazon-braket/braket.jl.git",)
