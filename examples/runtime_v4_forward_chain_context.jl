"""Runnable two-scenario fixture for the isolated ForwardChainContextV4.

The fixture is a structural, materialized software subject.  It produces no
runtime evidence and confers no physical, engineering, or terminal authority.
"""

using FusionConceptAI

module ForwardChainContextRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
end

include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))

const forward_mission_payload = (
    mission_id="forward-context-fixture",
    contract=candidate.mission_contract_ref)
const forward_bounds_payload = (
    scope="forward-context-fixture",
    lower=-1.0,
    upper=1.0)
const forward_comparison_scope = ("typed-forward-identity",)
const forward_scenarios = (
    (name="startup", load_case="nominal"),
    (name="hold", load_case="nominal"))
const forward_scenario_scope = Tuple(s.name for s in forward_scenarios)

const forward_compiled = ForwardChainContextRuntime.compile_candidate(candidate, registry;
    mission_payload=forward_mission_payload,
    bounds_payload=forward_bounds_payload,
    comparison_scope=forward_comparison_scope,
    scenario_scope=forward_scenario_scope)

const forward_subject = ForwardChainContextRuntime.ExecutablePhysicalSubjectV4(
    forward_compiled.prefix_hash,
    candidate.canonical_hashes.genome_bundle_hash,
    forward_compiled.minimality_scope.mission_hash,
    forward_compiled.minimality_scope.bounds_hash,
    ((binding_kind="typed_fixture_materialization", candidate_ref=candidate.identity_ref),),
    forward_scenarios,
    (materialization="immutable-software-fixture", revision="v1"),
    ForwardChainContextRuntime.derive_capability_obligations(forward_compiled))

const forward_contexts = ForwardChainContextRuntime.make_forward_chain_contexts(
    candidate, forward_compiled, registry, forward_mission_payload,
    forward_bounds_payload, forward_comparison_scope, forward_scenario_scope,
    forward_subject, forward_scenarios)

const forward_context = first(forward_contexts)

if abspath(PROGRAM_FILE) == @__FILE__
    println("contexts=", length(forward_contexts))
    println("context_hash=", ForwardChainContextRuntime.canonical_hash(forward_context))
    println("compilation_status=", forward_compiled.compilation_status)
    println("unresolved_nonterminals=", length(forward_compiled.unresolved_nonterminals))
    println("emits_evidence=", ForwardChainContextRuntime.forward_chain_context_manifest().emits_evidence)
    println("terminal_authority=", ForwardChainContextRuntime.forward_chain_context_manifest().terminal_authority)
end
