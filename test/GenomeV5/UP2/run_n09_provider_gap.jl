using FusionConceptAI

FusionConceptAI.load_genome_v5_components!()
const _N09_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2")
Base.include(FusionConceptAI, joinpath(_N09_ROOT, "PrecompilerInvocationCounterV1.jl"))
Base.include(FusionConceptAI, joinpath(_N09_ROOT, "N09ProviderGapProjectionV1.jl"))
include(joinpath(@__DIR__, "n09_provider_gap_tests.jl"))
