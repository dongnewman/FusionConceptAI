using Test
using JSON3
using FusionConceptAI

const _UP2E0_SOURCE = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2",
    "UP2CandidatePhysicalBindingV1.jl")
FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, _UP2E0_SOURCE)
include(joinpath(@__DIR__, "up2_candidate_physical_binding_tests.jl"))
