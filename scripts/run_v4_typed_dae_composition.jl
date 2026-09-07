using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "test", "runtime_v4_typed_dae_composition_tests.jl"))
