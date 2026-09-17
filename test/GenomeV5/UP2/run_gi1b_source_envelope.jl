using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_up2_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "GI1AuthorityContextV1.jl"))
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "GI1BSourceMutationEnvelopeV1.jl"))
include(joinpath(@__DIR__, "gi1b_source_envelope_tests.jl"))
