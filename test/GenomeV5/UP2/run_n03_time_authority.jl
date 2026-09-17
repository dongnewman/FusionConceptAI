using FusionConceptAI
FusionConceptAI.load_genome_v5_components!()
const _N03_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2")
Base.include(FusionConceptAI, joinpath(_N03_ROOT, "PrecompilerInvocationCounterV1.jl"))
Base.include(FusionConceptAI, joinpath(_N03_ROOT, "N03TimeAuthorityProjectionV1.jl"))
include(joinpath(@__DIR__, "n03_time_authority_tests.jl"))
