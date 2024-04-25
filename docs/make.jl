push!(LOAD_PATH,"../src/")

using Documenter, Braket 

makedocs(sitename="Braket.jl")

deploydocs(repo="github.com/amazon-braket/braket.jl.git",)
