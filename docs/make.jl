push!(LOAD_PATH,"../src/")

using Documenter, Braket 

makedocs(sitename="Braket.jl")

deploydocs(repo="github.com/awslabs/Braket.jl.git",)
