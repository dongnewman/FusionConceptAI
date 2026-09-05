#!/usr/bin/env julia
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_g2_field_fixture.jl"))

const bounds_payload = (scope="g2",)
const comparison_scope = ("g2",)
const scenario_scope = ("g2-field-scenario",)
compiled = compile_candidate(candidate, registry;
    mission_payload=candidate.mission_contract_ref,
    bounds_payload=bounds_payload,
    comparison_scope=comparison_scope, scenario_scope=scenario_scope)
plan = compile_field_evaluation_plan(candidate, compiled, registry,
    default_operator_registry(); scenario=scenario, grid=grid,
    program_site_ref=_g2_site, root_position=1)
provider = field_evaluation_provider(plan)
report = execute_field_evaluation(Dict{Digest256,Any}(), candidate, compiled,
    registry, default_operator_registry(), plan, scenario; provider=provider)
println("candidate_hash=", plan.candidate_hash)
println("compiled_prefix_hash=", plan.prefix_hash)
println("field_geometry_hash=", plan.field_geometry_hash)
println("plan_hash=", plan.plan_hash)
println("provider_manifest_hash=", provider.manifest_hash)
println("evidence_hash=", report.evidence.evidence_id)
println("status=", report.status, " claim_ceiling=", report.claim_ceiling)
println("grid_points=", length(report.result.values), " min=", report.result.min_value,
    " max=", report.result.max_value, " output_type=", report.result.output_type,
    " checksum=", report.result.checksum)
println("sample_values=", report.result.values[1:3])
println("unresolved_gaps=", report.unresolved_gaps)
println("compiled_unresolved_nonterminals=", compiled.unresolved_nonterminals)
println("credible_physical_count=0 authority=withheld p5_ready=false")
