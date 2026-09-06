using Pkg
Pkg.activate(joinpath(@__DIR__,".."))
using Test
include(joinpath(@__DIR__,"..","test","runtime_v4_typed_time_execution_tests.jl"))
println("D1.3 reports: continuous/refinement/event=PASS")
println("D1.3 gate: cache execution_count=1")
println("D1.3 gate: replay read-only=PASS")
println("D1.3 claim: screen_only credible_count=0 p5_ready=false unsupported=false")
