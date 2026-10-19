module SearchPhysicalConsumerV4TestRuntime

using FusionConceptAI

const ROOT = normpath(abspath(joinpath(@__DIR__, "..", "..", "..")))

# Reuse the repository's already-validated strong G1 fixture. Do not reconstruct
# it from nodes with an empty hyperedge tuple: MechanismGenomePayloadV1 requires
# a non-empty graph made only of AtomicMIMOHyperedgeV1 edges.
include(joinpath(ROOT, "examples", "runtime_v4_declared_fixture.jl"))

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
Base.include(FusionRuntimeV4, joinpath(ROOT, "src", "RuntimeV4",
    "SearchPhysicalConsumerV3.jl"))

const R = FusionRuntimeV4
const SPC3 = R.SearchPhysicalConsumerV3
const TRUSTED_REPOSITORY_ROOT = ROOT

function search_physical_fixture_v4(; foreign_g3=false)
    scenario_a = (name="nominal-static-equilibrium", load_case="test-only")
    scenario_b = (name="alternate-static-equilibrium", load_case="test-only")
    scenarios = (scenario_a, scenario_b)
    scenario_scope = Tuple(x.name for x in scenarios)
    comparison_scope = ("isolated-search-physical-consumer-v4-test",)

    # _fixture_mechanism_payload() builds and validates two atomic MIMO edges,
    # their registry bindings, states, conservation invariant, and observable.
    # Preserve the whole strong payload instead of stripping its graph edges.
    g1_payload = _fixture_mechanism_payload()
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
        foreign_g3 ? "search-physical-consumer-v4-foreign-g3" :
            "search-physical-consumer-v4-test",
        _fixture_mission, g1, g2, g3, registry)
    mission_payload = (mission_id="search-physical-consumer-v4-test-mission",
        contract=candidate.mission_contract_ref)
    bounds_payload = (model="test-only-static-axisymmetric-screen",
        declaration_hash=canonical_hash(declaration))
    compiled = R.compile_candidate(candidate, registry;
        mission_payload=mission_payload, bounds_payload=bounds_payload,
        comparison_scope=comparison_scope, scenario_scope=scenario_scope)
    bindings = Tuple(R.make_axisymmetric_equilibrium_binding(compiled, registry,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        scenario, declaration) for scenario in scenarios)
    subject = R.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, scenarios,
        (fixture_scope=:g2_axisymmetric_consumer_v4_test_only,
         declaration_hash=canonical_hash(declaration)),
        R.derive_capability_obligations(compiled))
    contexts = R.make_forward_chain_contexts(candidate, compiled, registry,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        subject, scenarios)
    (; candidate, g1_payload, compiled, declaration, scenarios, mission_payload,
       bounds_payload, comparison_scope, scenario_scope, contexts)
end

function active_queue_v4(fixture; override_registry_hash=nothing)
    queue = R.CandidateQueueV4()
    kwargs = override_registry_hash === nothing ?
        (; registry_hash=canonical_hash(registry)) :
        (; registry_hash=override_registry_hash)
    queued = R.enqueue_candidate!(queue, fixture.candidate, fixture.compiled;
        kwargs...)
    active = R.next_compilable!(queue)
    (; queue, queued, active)
end

function trusted_registry_v4(context)
    empty_registry = R.bootstrap_trusted_provider_registry(
        Val(:trusted_repository_with_freegs_bootstrap), TRUSTED_REPOSITORY_ROOT)
    capability = R.trusted_freegs_axisymmetric_capability(context)
    manifest = R.make_repository_owned_provider_manifest(empty_registry,
        context, R._TPR_FREEGS_PROVIDER, capability;
        model_class=R._TPR_FREEGS_MODEL_CLASS)
    R.register_trusted_provider(empty_registry, context,
        R._TPR_FREEGS_PROVIDER, capability, manifest)
end

end # module SearchPhysicalConsumerV4TestRuntime
