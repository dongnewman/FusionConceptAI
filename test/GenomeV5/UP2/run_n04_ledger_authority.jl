using Test
using JSON3
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N04LedgerAuthorityProjectionV1.jl"))
include(joinpath(@__DIR__, "n04_ledger_authority_tests.jl"))
