using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "..", "..", "examples",
    "runtime_v4_declared_fixture.jl"))

module SearchPhysicalConsumerTestRuntime
using FusionConceptAI
const ROOT = normpath(abspath(joinpath(@__DIR__, "..", "..", "..")))
include(joinpath(ROOT, "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "ForwardChainContext.jl"))
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "FreeGSAxisymmetricExecution.jl"))
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "TrustedProviderRegistryV4.jl"))
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "TrustedFreeGSAxisymmetricProviderV4.jl"))
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "SearchPhysicalConsumerV1.jl"))
end

const R = SearchPhysicalConsumerTestRuntime.FusionRuntimeV4
const SPC = R.SearchPhysicalConsumerV1
const TRUSTED_REPOSITORY_ROOT = normpath(abspath(joinpath(@__DIR__, "..", "..", "..")))

function _search_physical_fixture(; foreign_g3=false)
    scenario_a = (name="nominal-static-equilibrium", load_case="test-only")
    scenario_b = (name="alternate-static-equilibrium", load_case="test-only")
    scenarios = (scenario_a, scenario_b)
    scenario_scope = Tuple(x.name for x in scenarios)
    comparison_scope = ("isolated-search-physical-consumer-test",)
    base_payload = _fixture_mechanism_payload()
    g1_graph = TypedOperatorHypergraphV1(base_payload.operator_graph.nodes, ();
        registry=_fixture_ops)
    g1_payload = MechanismGenomePayloadV1(base_payload.states, (), g1_graph,
        (), (), (), ())
    g1 = MechanismGenomeV4(17, _fixture_refs[1], g1_payload)

    declaration = R.AxisymmetricEquilibriumDeclarationV4(
        "search-physical-consumer-axisymmetric-test",
        R.AxisymmetricDomainV4(0.1, 2.0, -1.0, 1.0, 65, 65),
        (R.AxisymmetricFilamentCoilV4("pf-lower-inner", 1.0, -1.1),
         R.AxisymmetricFilamentCoilV4("pf-upper-inner", 1.0, 1.1),
         R.AxisymmetricFilamentCoilV4("pf-lower-outer", 1.75, -0.6),
         R.AxisymmetricFilamentCoilV4("pf-upper-outer", 1.75, 0.6)),
        R.AxisymmetricConstrainPaxisIpProfileV4(10_000.0, 1_000_000.0,
            1.0, 1.0, 2.0, 1.0),
        R.AxisymmetricShapeConstraintsV4(((1.1, -0.6), (1.1, 0.8)),
            ((1.1, -0.6, 1.1, 0.6),), 1.0e-12),
        R.AxisymmetricSolverControlsV4(1.0e-4, 1.0e-10, 100))

    g2 = FieldGeometryGenomeV4(18, _fixture_refs[2], _fixture_graph();
        fields=(declaration,))
    g3_graph = if foreign_g3
        TypedOperatorHypergraphV1(
            (node(:region, _fixture_type; id="foreign-runtime-region"),
             node(:boundary, _fixture_type; id="foreign-runtime-boundary")), ();
            registry=_fixture_ops)
    else
        _fixture_graph()
    end
    g3 = RealizationControlGenomeV4(19, 20, _fixture_refs[3], g3_graph, g3_graph)
    candidate = CandidateStatePackageV4(
        foreign_g3 ? "search-physical-consumer-foreign-g3" :
            "search-physical-consumer-test",
        _fixture_mission, g1, g2, g3, registry)
    mission_payload = (mission_id="search-physical-consumer-test-mission",
        contract=candidate.mission_contract_ref)
    bounds_payload = (model="test-only-static-axisymmetric-screen",
        declaration_hash=canonical_hash(declaration))
    compiled = R.compile_candidate(candidate, registry;
        mission_payload=mission_payload, bounds_payload=bounds_payload,
        comparison_scope=comparison_scope, scenario_scope=scenario_scope)
    @test compiled.compilation_status === :prefix_consistent
    @test isempty(compiled.unresolved_nonterminals)
    bindings = Tuple(R.make_axisymmetric_equilibrium_binding(compiled, registry,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        scenario, declaration) for scenario in scenarios)
    subject = R.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, scenarios,
        (fixture_scope=:g2_axisymmetric_consumer_test_only,
         declaration_hash=canonical_hash(declaration)),
        R.derive_capability_obligations(compiled))
    contexts = R.make_forward_chain_contexts(candidate, compiled, registry,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        subject, scenarios)
    (; candidate, compiled, declaration, scenarios, mission_payload,
       bounds_payload, comparison_scope, scenario_scope, contexts)
end

function _active_queue(fixture; override_registry_hash=nothing)
    queue = R.CandidateQueueV4()
    kwargs = override_registry_hash === nothing ?
        (; registry_hash=canonical_hash(registry)) :
        (; registry_hash=override_registry_hash)
    queued = R.enqueue_candidate!(queue, fixture.candidate, fixture.compiled;
        kwargs...)
    active = R.next_compilable!(queue)
    (; queue, queued, active)
end

function _trusted_registry(context)
    empty_registry = R.bootstrap_trusted_provider_registry(
        Val(:trusted_repository_with_freegs_bootstrap), TRUSTED_REPOSITORY_ROOT)
    capability = R.trusted_freegs_axisymmetric_capability(context)
    manifest = R.make_repository_owned_provider_manifest(empty_registry,
        context, R._TPR_FREEGS_PROVIDER, capability;
        model_class=R._TPR_FREEGS_MODEL_CLASS)
    R.register_trusted_provider(empty_registry, context,
        R._TPR_FREEGS_PROVIDER, capability, manifest)
end

@testset "Search physical consumer prepares exact trusted request without execution" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    @test active.queued.status === :queued
    @test active.active.status === :active
    @test active.active.candidate_ref == fixture.contexts[1].compiled.prefix_hash
    trusted = _trusted_registry(fixture.contexts[1])

    record = SPC.prepare_search_physical_consumer(active.queue,
        active.active.candidate_ref, fixture.contexts[1], trusted)
    @test record.state === :ready_for_dispatch
    @test record.request !== nothing
    @test record.request.status === :ready_for_dispatch
    @test record.request.context_hash == fixture.contexts[1].context_hash
    @test record.request.scenario_hash == fixture.contexts[1].scenario_hash
    @test record.g1_hash == fixture.contexts[1].genome_bindings[1].genome_hash
    @test record.g2_hash == fixture.contexts[1].genome_bindings[2].genome_hash
    @test record.g3_hash == fixture.contexts[1].genome_bindings[3].genome_hash
    @test record.trusted_receipt === nothing
    @test record.claim_ceiling === none
    @test !record.physical_validation && !record.engineering_validation
    @test record.candidate_discovery_credit == 0 && record.credible_device_count == 0
    @test SPC.validate_search_physical_consumer_receipt(record, active.queue,
        fixture.contexts[1], trusted)

    R.mark_deferred!(active.queue, active.active.candidate_ref)
    @test !SPC.validate_search_physical_consumer_receipt(record, active.queue,
        fixture.contexts[1], trusted)
end

@testset "scenario and G3 identity drift cannot reuse the request" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    trusted = _trusted_registry(fixture.contexts[1])
    other_scenario = SPC.prepare_search_physical_consumer(active.queue,
        active.active.candidate_ref, fixture.contexts[2], trusted)
    @test other_scenario.state === :deferred
    @test other_scenario.request !== nothing
    @test other_scenario.request.status === :recoverable_gap
    @test other_scenario.scenario_hash != fixture.contexts[1].scenario_hash
    @test SPC.validate_search_physical_consumer_receipt(other_scenario,
        active.queue, fixture.contexts[2], trusted)

    foreign = _search_physical_fixture(foreign_g3=true)
    foreign_active = _active_queue(foreign)
    @test foreign_active.active.status === :active
    mismatch = SPC.prepare_search_physical_consumer(active.queue,
        active.active.candidate_ref, foreign.contexts[1], trusted)
    @test mismatch.state === :not_executed
    @test mismatch.failure_code === :search_context_candidate_or_prefix_mismatch
    @test mismatch.request === nothing
end

@testset "deferred or foreign Search registry never dispatches" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    trusted = _trusted_registry(fixture.contexts[1])
    R.mark_deferred!(active.queue, active.active.candidate_ref)
    deferred = SPC.prepare_search_physical_consumer(active.queue,
        active.active.candidate_ref, fixture.contexts[1], trusted)
    @test deferred.state === :deferred
    @test deferred.failure_code === :search_entry_not_active
    @test deferred.request === nothing

    bad = _active_queue(fixture;
        override_registry_hash=digest256_text("foreign-search-registry"))
    @test bad.active.status === :active
    foreign_registry = SPC.prepare_search_physical_consumer(bad.queue,
        bad.active.candidate_ref, fixture.contexts[1], trusted)
    @test foreign_registry.state === :not_executed
    @test foreign_registry.failure_code === :search_registry_identity_mismatch
    @test foreign_registry.request === nothing
end
