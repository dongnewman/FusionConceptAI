using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "UP2CandidatePhysicalBindingV1.jl"))
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N05FluxAuthorityProjectionV1.jl"))
include(joinpath(@__DIR__, "n05_flux_authority_tests.jl"))
