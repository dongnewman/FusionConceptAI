using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_up2_components!()
const _H0A_SOURCE = normpath(joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "N06DimensionedLedgerLawV1.jl"))
Base.include(G, _H0A_SOURCE)
include(joinpath(@__DIR__, "n06_dimensioned_law_tests.jl"))
