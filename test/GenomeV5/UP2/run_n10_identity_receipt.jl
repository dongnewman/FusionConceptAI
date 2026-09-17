using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N10IdentityReceiptProjectionV1.jl"))
include(joinpath(@__DIR__, "n10_identity_receipt_tests.jl"))
