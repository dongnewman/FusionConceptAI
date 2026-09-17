using Test
using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "UP2CandidatePhysicalBindingV1.jl"))
Base.include(FusionConceptAI, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N06SourceFieldLedgerMappingV1.jl"))
include(joinpath(@__DIR__, "n06_source_field_ledger_mapping_tests.jl"))
