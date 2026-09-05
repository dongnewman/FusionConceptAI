#!/usr/bin/env julia
"""Run the conservative v4 spine on the declared software fixture."""

using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
const _bounds = (scope="runtime-v4-spine-bounds",)
const _compiled = compile_candidate(candidate, registry;
    mission_payload=candidate.mission_contract_ref, bounds_payload=_bounds,
    comparison_scope=("runtime-v4-spine",), scenario_scope=("p1",))
const _screen = first(filter(o -> o.kind == :structural_screen,
    _compiled.capability_obligations))
const _stages = default_stage_specs(_screen, "p1")
const _report = run_v4_spine(candidate, registry; stage_specs=_stages,
    scenarios=((name="p1",),), providers=(), bounds_payload=_bounds,
    compiled_prefix=_compiled)

println("campaign_hash=", _report.campaign.campaign_hash)
println("compiled_prefix_hash=", _report.compiled.prefix_hash)
println("p1_claim_ceiling=", _report.p1.claim_ceiling)
println("stage_count=", length(_report.campaign.stage_specs))
println("admitted=", _report.admission.admitted)
println("p5_ready=", _report.closure.p5_ready)
println("provider_coverage_complete=", _report.authority.provider_coverage_complete)
println("goal_acceptance=", _report.authority.goal_acceptance)
println("terminal_classification_executed=", _report.authority.terminal_classification_executed)
println("classification=", _report.authority.disposition)
println("derived_gap_count=", length(_report.closure.unresolved_gaps))
for gap in _report.closure.unresolved_gaps
    println("gap=", gap)
end
