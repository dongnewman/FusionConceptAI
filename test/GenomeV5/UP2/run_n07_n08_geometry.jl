using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N07N08GeometryProjectionV1.jl"))
include(joinpath(@__DIR__, "n07_n08_geometry_tests.jl"))
