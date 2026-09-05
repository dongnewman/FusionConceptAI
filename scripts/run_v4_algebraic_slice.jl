#!/usr/bin/env julia
"""Run the bounded 0D algebraic constraint screen from the declared fixture."""

using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

fixture = isempty(ARGS) ? joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl") : abspath(ARGS[1])
isfile(fixture) || error("fixture file does not exist: $fixture")
include(fixture)
@assert @isdefined(candidate) "fixture must define candidate"
@assert @isdefined(registry) "fixture must define registry"

mission_payload = candidate.mission_contract_ref
bounds_payload = (scope="algebraic-residual-cli",)
comparison_scope = ("algebraic-residual",)
scenario_scope = ("zero-dimensional",)
compiled = compile_candidate(candidate, registry;
    mission_payload=mission_payload, bounds_payload=bounds_payload,
    comparison_scope=comparison_scope, scenario_scope=scenario_scope)
compilation = compile_algebraic_residual_plan(compiled, registry)
compilation.status == :ready || error("algebraic plan deferred: $(compilation.unresolved_gaps)")
plan = compilation.plan
plan === nothing && error("ready algebraic compilation did not produce a plan")

unit = UnitSignature()
scenario = AlgebraicScenarioV4("zero",
    (StateValueV4(StateGeneRefV1("x"), 0.5, unit),
     StateValueV4(StateGeneRefV1("y"), -0.25, unit)))
store = Dict{Digest256,Any}()
provider = algebraic_residual_manifest(plan)
report = execute_algebraic_once!(store, plan, scenario; provider=provider)
report.result === nothing && error("algebraic execution was deferred")
result = report.result

non_slice_capability_gaps = Tuple((hash=canonical_hash(obligation), kind=obligation.kind,
    operator=obligation.operator) for obligation in compiled.capability_obligations)

println("fixture=", fixture)
println("compiled_prefix_hash=", compiled.prefix_hash)
println("plan_hash=", plan.plan_hash)
println("result_hash=", result.result_hash)
println("provider_manifest_hash=", provider.manifest_hash)
println("evidence_hash=", report.evidence.evidence_id)
println("solver_input_hash=", report.input.solver_input_hash)
println("status=", result.status)
println("final_x=", result.state_values[1])
println("final_y=", result.state_values[2])
println("residuals=", result.residuals)
println("normalized_residual_norm=", result.residual_norm)
println("claim_ceiling=", report.evidence.claim_ceiling)
println("constraint_subgraph_scope=", report.evidence.binding_provenance.constraint_subgraph_scope)
println("ignored_edge_count=", length(plan.ignored_edge_hashes))
println("compiled_unresolved_nonterminals=", compiled.unresolved_nonterminals)
println("non_slice_capability_gaps=", non_slice_capability_gaps)
println("credible_physical_count=0")
println("authority=withheld")
println("whole_device_ready=false")
println("vvuq_ready=false")
println("p5_ready=false")
