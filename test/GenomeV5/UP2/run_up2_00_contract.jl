using Test
using JSON3
using FusionConceptAI

const _UP2_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2")
FusionConceptAI.load_genome_v5_components!()
Base.include(FusionConceptAI, joinpath(_UP2_ROOT, "TypedPrecompilerContractV1.jl"))
Base.include(FusionConceptAI, joinpath(_UP2_ROOT, "PrecompilerInvocationCounterV1.jl"))
Base.include(FusionConceptAI, joinpath(_UP2_ROOT, "TypedPrecompilerValidatorV1.jl"))
include(joinpath(@__DIR__, "up2_00_contract_tests.jl"))
