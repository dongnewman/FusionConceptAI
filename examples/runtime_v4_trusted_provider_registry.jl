"""Runnable repository-trust and operational-receipt fixture."""

module TrustedProviderRegistryRuntime

using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "TrustedProviderRegistryV4.jl"))

include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))

const trusted_mission = (mission_id="trusted-provider-fixture",
    contract=candidate.mission_contract_ref)
const trusted_bounds = (scope="trusted-provider-fixture", lower=-1.0, upper=1.0)
const trusted_comparison_scope = ("trusted-repository-dispatch",)
const trusted_scenarios = ((name="trusted-startup", load_case="nominal"),)
const trusted_scenario_scope = ("trusted-startup",)

const trusted_compiled = compile_candidate(candidate, registry;
    mission_payload=trusted_mission, bounds_payload=trusted_bounds,
    comparison_scope=trusted_comparison_scope,
    scenario_scope=trusted_scenario_scope)
const trusted_subject = ExecutablePhysicalSubjectV4(trusted_compiled.prefix_hash,
    candidate.canonical_hashes.genome_bundle_hash,
    trusted_compiled.minimality_scope.mission_hash,
    trusted_compiled.minimality_scope.bounds_hash,
    ((binding_kind="trusted-provider-software-fixture",
      candidate_ref=candidate.identity_ref),), trusted_scenarios,
    (materialization="immutable-software-fixture", revision="v1"),
    derive_capability_obligations(trusted_compiled))
const trusted_context = make_forward_chain_context(candidate, trusted_compiled,
    registry, trusted_mission, trusted_bounds, trusted_comparison_scope,
    trusted_scenario_scope, trusted_subject, first(trusted_scenarios))

const trusted_repository_root = _tpr_normalize_root(joinpath(@__DIR__, ".."))
const empty_trusted_registry = bootstrap_trusted_provider_registry(
    Val(:trusted_repository_bootstrap), trusted_repository_root)
const trusted_capability = first(trusted_context.obligations)
const repository_provider_manifest = make_repository_owned_provider_manifest(
    empty_trusted_registry, trusted_context, _TPR_BUILTIN_PROVIDER,
    trusted_capability; model_class="test_only")
const trusted_registry = register_trusted_provider(empty_trusted_registry,
    trusted_context, _TPR_BUILTIN_PROVIDER, trusted_capability,
    repository_provider_manifest)
const trusted_input = (request_kind=:structural_fixture,
    context_hash=trusted_context.context_hash, values=(1.0, 2.0, 3.0))
const trusted_request = build_trusted_provider_dispatch_request(trusted_registry,
    trusted_context, trusted_capability, trusted_input)
const trusted_receipt = execute_trusted_provider(trusted_registry,
    trusted_context, trusted_request)

end


const TPR = TrustedProviderRegistryRuntime
const empty_trusted_registry = TPR.empty_trusted_registry
const trusted_registry = TPR.trusted_registry
const trusted_context = TPR.trusted_context
const trusted_capability = TPR.trusted_capability
const repository_provider_manifest = TPR.repository_provider_manifest
const trusted_input = TPR.trusted_input
const trusted_request = TPR.trusted_request
const trusted_receipt = TPR.trusted_receipt

if abspath(PROGRAM_FILE) == @__FILE__
    println("registrations=", length(trusted_registry.registrations))
    println("request_status=", trusted_request.status)
    println("receipt_status=", trusted_receipt.status)
    println("exit_code=", trusted_receipt.exit_code)
    println("request_hash=", trusted_request.request_hash)
    println("receipt_hash=", trusted_receipt.receipt_hash)
    manifest = TPR.trusted_provider_registry_manifest()
    println("emits_evidence=", manifest.emits_evidence)
    println("physical_validation_credit=", manifest.physical_validation_credit)
    println("p5_ready=", manifest.p5_ready)
end
