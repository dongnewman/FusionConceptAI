# B3 fixture: reuse the public B1 fixture and add only evidence binding.
include(joinpath(@__DIR__, "runtime_v4_gridap_field_fixture.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "GridapFieldEvidence.jl"))
const gridap_b3_store = Dict{Digest256,Any}()
const gridap_b3_scenario = d3_g2_scenario
const gridap_b3_bundle = FusionRuntimeV4.execute_gridap_field_evidence!(gridap_b3_store, gridap_b1_compilation; candidate=composition_candidate, compiled=composition_compiled, genome_registry=tdae_registry, scenario=gridap_b3_scenario)
