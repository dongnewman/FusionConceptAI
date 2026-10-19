using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "SearchPhysicalConsumerV4",
    "search_physical_consumer_fixture_v4.jl"))

const F5 = SearchPhysicalConsumerV4TestRuntime
const R5 = F5.R

function _load_v1_compat_with_parent_alias_v5!(parent::Module,
        compat_path::AbstractString)
    isdefined(parent, :PhysicalEdgeObligationV1) &&
        throw(ArgumentError("parent namespace already binds PhysicalEdgeObligationV1"))
    isdefined(parent, :PhysicalEdgeObligationV1Compat) &&
        throw(ArgumentError("parent namespace already loaded PhysicalEdgeObligationV1Compat"))
    Base.include(parent, compat_path)
    compat = getfield(parent, :PhysicalEdgeObligationV1Compat)
    Core.eval(parent, :(const PhysicalEdgeObligationV1 = PhysicalEdgeObligationV1Compat))
    getfield(parent, :PhysicalEdgeObligationV1) === compat ||
        throw(ArgumentError("parent alias does not resolve to the compatibility module"))
    compat
end

const V1_COMPAT_PATH_V5 = joinpath(F5.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV1Compat.jl")
const PEO1_V5 = _load_v1_compat_with_parent_alias_v5!(R5, V1_COMPAT_PATH_V5)
Base.include(R5, joinpath(F5.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV3.jl"))
const PEO3_V5 = R5.PhysicalEdgeObligationV3

function physical_edge_fixture_v5(index::Int=1; foreign_g3=false)
    base = F5.search_physical_fixture_v4(foreign_g3=foreign_g3)
    scenario = base.scenarios[index]
    scenarios = (scenario,)
    scenario_scope = (scenario.name,)
    compiled = R5.compile_candidate(base.candidate, F5.registry;
        mission_payload=base.mission_payload,
        bounds_payload=base.bounds_payload,
        comparison_scope=base.comparison_scope,
        scenario_scope=scenario_scope)
    binding = R5.make_axisymmetric_equilibrium_binding(compiled,
        F5.registry, base.mission_payload, base.bounds_payload,
        base.comparison_scope, scenario_scope, scenario, base.declaration)
    subject = R5.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        base.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, (binding,), scenarios,
        (fixture_scope=:physical_edge_v5_single_scenario_test_only,
         declaration_hash=canonical_hash(base.declaration)),
        R5.derive_capability_obligations(compiled))
    contexts = R5.make_forward_chain_contexts(base.candidate, compiled,
        F5.registry, base.mission_payload, base.bounds_payload,
        base.comparison_scope, scenario_scope, subject, scenarios)
    (; candidate=base.candidate, g1_payload=base.g1_payload, compiled,
       declaration=base.declaration, scenario, scenarios, mission_payload=base.mission_payload,
       bounds_payload=base.bounds_payload, comparison_scope=base.comparison_scope,
       scenario_scope, subject, contexts, context=only(contexts))
end

function fabricated_cached_successes_v5(context, obligations)
    fake_hash(label) = canonical_hash((test_only_fabricated=label,))
    Tuple(begin
        identity = obligation.identity
        capability = R5.CapabilitySignatureV4(
            "test-only:forged-capability", "v1", :test_only,
            string(identity.operator_id, "@", identity.operator_version), ("u",),
            "lumped", "lumped", 0, (), "none", "none", "steady",
            ("value",), none, fake_hash("bounds"))
        requirement = PEO1_V5._peo_requirement(identity, capability)
        provider = PEO1_V5._peo_provider_state(
            provider_state=:completed, receipt_state=:validated,
            provider_backend="caller-forged-provider",
            provider_manifest_hash=fake_hash("manifest"),
            registry_hash=fake_hash("registry"),
            request_hash=fake_hash(("request", identity.identity_hash)),
            receipt_hash=fake_hash(("receipt", identity.identity_hash)),
            input_hash=fake_hash(("input", identity.identity_hash)),
            output_hash=fake_hash(("output", identity.identity_hash)),
            provider_status=:completed, exit_code=0)
        PEO1_V5._peo_make_obligation(identity, obligation.candidate_hash,
            obligation.genome_bundle_hash, obligation.context_hash,
            obligation.scenario_hash; requirement, provider)
    end for obligation in obligations)
end

@testset "V5 preserves strong G1 and source-backed single-scenario binding" begin
    fixture = physical_edge_fixture_v5()
    graph = fixture.g1_payload.operator_graph
    edges = getfield(graph, :hyperedges)
    context = fixture.context

    @test length(edges) == 2
    @test all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in edges)
    @test fixture.candidate.mechanism_genome_ref.payload === fixture.g1_payload
    @test fixture.compiled.compilation_status === :prefix_incomplete
    @test fixture.compiled.unresolved_nonterminals ==
        ("required_physical_capability:IDENTITY@v1",)
    @test length(fixture.subject.bindings) == 1
    @test only(fixture.subject.bindings) isa R5.AxisymmetricEquilibriumBindingV4
    @test only(fixture.subject.bindings).scenario_hash == context.scenario_hash
    @test R5._freegs_context_binding(context).binding_hash ==
        only(fixture.subject.bindings).binding_hash

    invalid_graph = TypedOperatorHypergraphV1(getfield(graph, :nodes), ();
        registry=F5._fixture_ops)
    @test_throws ArgumentError MechanismGenomePayloadV1(
        fixture.g1_payload.states, fixture.g1_payload.invariants, invalid_graph,
        fixture.g1_payload.transitions, fixture.g1_payload.fluxes,
        fixture.g1_payload.observables, fixture.g1_payload.boundary_conditions)

    duplicate_subject = R5.ExecutablePhysicalSubjectV4(
        fixture.compiled.prefix_hash,
        fixture.candidate.canonical_hashes.genome_bundle_hash,
        fixture.compiled.minimality_scope.mission_hash,
        fixture.compiled.minimality_scope.bounds_hash,
        (only(fixture.subject.bindings), only(fixture.subject.bindings)),
        fixture.scenarios, (fixture_scope=:duplicate_binding_negative_test,),
        R5.derive_capability_obligations(fixture.compiled))
    duplicate_context = only(R5.make_forward_chain_contexts(
        fixture.candidate, fixture.compiled, F5.registry,
        fixture.mission_payload, fixture.bounds_payload,
        fixture.comparison_scope, fixture.scenario_scope,
        duplicate_subject, fixture.scenarios))
    @test_throws ArgumentError R5._freegs_context_binding(duplicate_context)
end

@testset "V5 cached caller-forged edge success remains deferred" begin
    fixture = physical_edge_fixture_v5()
    context = fixture.context
    obligations = PEO1_V5.physical_edge_obligations_v1(context)
    fabricated = fabricated_cached_successes_v5(context, obligations)
    registry = F5.trusted_registry_v4(context)

    @test length(Tuple(x for x in obligations
        if x.identity.layer === :g1_mechanism &&
           x.identity.operator_id == "IDENTITY" &&
           x.identity.operator_version == "v1")) == 2
    @test PEO1_V5.assess_candidate_obligations_v1(
        context, fabricated).status === :contract_ready_unwired

    assessment = PEO3_V5.assess_candidate_obligations_v3(
        context, registry, fabricated, ())
    @test assessment.status === :deferred
    @test assessment.reasons == (:live_receipt_revalidation_required,)
    @test !assessment.activated
    @test !assessment.physical_validation && !assessment.engineering_validation
    @test assessment.candidate_discovery_credit == 0
    @test assessment.credible_device_count == 0
    @test !PEO3_V5.live_attempt_manifest_v3().executor_issuance_provenance_available
end

@testset "V5 string-only compiler label cannot resolve typed edges" begin
    fixture = physical_edge_fixture_v5()
    context = fixture.context
    obligations = PEO1_V5.physical_edge_obligations_v1(context)
    registry = F5.trusted_registry_v4(context)
    result = PEO3_V5.assess_candidate_obligations_v3(context, registry,
        obligations, (); unresolved_nonterminals=
            fixture.compiled.unresolved_nonterminals)

    @test result.status === :deferred
    @test result.reasons == (:compiler_gap_has_no_edge_bound_resolution,)
    @test !result.activated
    @test result.candidate_discovery_credit == 0
    @test !result.physical_validation && !result.engineering_validation
end

@testset "V5 registration is scenario and candidate bound" begin
    fixture_a = physical_edge_fixture_v5(1)
    fixture_b = physical_edge_fixture_v5(2)
    context_a = fixture_a.context
    context_b = fixture_b.context
    registry_a = F5.trusted_registry_v4(context_a)
    cap_a = R5.trusted_freegs_axisymmetric_capability(context_a)
    input_a = R5.make_trusted_freegs_axisymmetric_input(context_a, cap_a)
    cap_b = R5.trusted_freegs_axisymmetric_capability(context_b)
    input_b = R5.make_trusted_freegs_axisymmetric_input(context_b, cap_b)
    request_a = R5.build_trusted_provider_dispatch_request(
        registry_a, context_a, cap_a, input_a)
    request_b = R5.build_trusted_provider_dispatch_request(
        registry_a, context_b, cap_b, input_b)

    @test context_a.candidate_hash == context_b.candidate_hash
    @test context_a.scenario_hash != context_b.scenario_hash
    @test request_a.status === :ready_for_dispatch
    @test request_b.status === :recoverable_gap
    @test request_b.recoverable_gaps == ("trusted_provider_registration_missing",)
    @test R5.validate_trusted_provider_dispatch_request(
        request_b, registry_a, context_b, cap_b, input_b)

    foreign = physical_edge_fixture_v5(1; foreign_g3=true)
    cap_foreign = R5.trusted_freegs_axisymmetric_capability(foreign.context)
    input_foreign = R5.make_trusted_freegs_axisymmetric_input(
        foreign.context, cap_foreign)
    request_foreign = R5.build_trusted_provider_dispatch_request(
        registry_a, foreign.context, cap_foreign, input_foreign)
    @test foreign.context.candidate_hash != context_a.candidate_hash
    @test request_foreign.status === :recoverable_gap
    @test request_foreign.recoverable_gaps ==
        ("trusted_provider_registration_missing",)
end

@testset "V5 G2 request and forged receipt are not a G1 edge envelope" begin
    fixture = physical_edge_fixture_v5()
    context = fixture.context
    obligations = PEO1_V5.physical_edge_obligations_v1(context)
    registry = F5.trusted_registry_v4(context)
    capability = R5.trusted_freegs_axisymmetric_capability(context)
    input = R5.make_trusted_freegs_axisymmetric_input(context, capability)
    request = R5.build_trusted_provider_dispatch_request(
        registry, context, capability, input)
    @test request.status === :ready_for_dispatch

    registration = request.registration::R5.TrustedProviderRegistrationV4
    forged_output = (execution_kind=:caller_forged_without_dispatch,
        input_hash=canonical_hash(input))
    forged_output_hash = canonical_hash(forged_output)
    forged_message = "test-only forged result; executor was not invoked"
    forged_body = R5._tpr_receipt_body(request, registration,
        forged_output, forged_output_hash, 0, :physical_model_screen,
        forged_message)
    forged_receipt = R5.TrustedProviderExecutionReceiptV4(R5._TPR_TOKEN,
        request.registry_hash, request.request_hash,
        registration.registration_hash, registration.manifest.manifest_hash,
        request.input_hash, forged_output, forged_output_hash, 0,
        :physical_model_screen, forged_message, canonical_hash(forged_body))
    attempts = Tuple(PEO3_V5.PhysicalEdgeLiveAttemptV3(
        obligation.identity.identity_hash, canonical_hash(obligation),
        capability, request, forged_receipt) for obligation in obligations)
    valid, reason = PEO3_V5._attempt_revalidates(context, registry,
        obligations, first(obligations), first(attempts))

    @test !valid
    @test reason === :live_attempt_missing_edge_bound_input
    @test !R5.validate_trusted_provider_execution_receipt(
        forged_receipt, request, registry, context)
    assessment = PEO3_V5.assess_candidate_obligations_v3(
        context, registry, obligations, attempts;
        unresolved_nonterminals=fixture.compiled.unresolved_nonterminals)
    @test assessment.status === :deferred
    @test assessment.reasons == (:compiler_gap_has_no_edge_bound_resolution,)
    @test assessment.candidate_discovery_credit == 0
    @test !assessment.physical_validation && !assessment.engineering_validation
end

include(joinpath(F5.ROOT, "examples", "runtime_v4_trusted_provider_registry.jl"))
const TPR5 = TrustedProviderRegistryRuntime
const RT5 = TPR5

@testset "V5 self-consistent caller receipt lacks executor issuance authority" begin
    registry = TPR5.trusted_registry
    context = TPR5.trusted_context
    capability = TPR5.trusted_capability
    input = TPR5.trusted_input
    request = RT5.build_trusted_provider_dispatch_request(
        registry, context, capability, input)
    @test request.status === :ready_for_dispatch
    @test RT5.validate_trusted_provider_dispatch_request(
        request, registry, context, capability, input)

    registration = request.registration::RT5.TrustedProviderRegistrationV4
    forged_output = (execution_kind=:caller_forged_without_dispatch,
        input_hash=canonical_hash(input))
    forged_output_hash = canonical_hash(forged_output)
    forged_message = "constructed by caller; no executor invocation"
    forged_body = RT5._tpr_receipt_body(request, registration,
        forged_output, forged_output_hash, 0, :completed, forged_message)
    forged_receipt = RT5.TrustedProviderExecutionReceiptV4(RT5._TPR_TOKEN,
        request.registry_hash, request.request_hash,
        registration.registration_hash, registration.manifest.manifest_hash,
        request.input_hash, forged_output, forged_output_hash, 0, :completed,
        forged_message, canonical_hash(forged_body))

    @test RT5.validate_trusted_provider_execution_receipt(
        forged_receipt, request, registry, context)
    @test forged_receipt.output.execution_kind === :caller_forged_without_dispatch
    @test !hasproperty(forged_receipt, :issuer_proof)
    @test !hasproperty(forged_receipt, :execution_identity)
    @test !PEO3_V5.live_attempt_manifest_v3().receipt_validator_is_issuer_attestation
    @test !PEO3_V5.live_attempt_manifest_v3().executor_issuance_provenance_available
    edge_fixture = physical_edge_fixture_v5()
    edge_context = edge_fixture.context
    edge_registry = F5.trusted_registry_v4(edge_context)
    edge_obligations = PEO1_V5.physical_edge_obligations_v1(edge_context)
    no_attempt = PEO3_V5.assess_candidate_obligations_v3(
        edge_context, edge_registry, edge_obligations, ())
    @test no_attempt.status === :deferred
    @test no_attempt.reasons == (:live_receipt_revalidation_required,)
    @test no_attempt.candidate_discovery_credit == 0
end

module PhysicalEdgeObligationV5ForeignAliasFixture
end
Core.eval(PhysicalEdgeObligationV5ForeignAliasFixture,
    :(const PhysicalEdgeObligationV1 = :foreign_alias))

@testset "V5 compat loader is single-owner and fail-closed" begin
    @test isdefined(R5, :PhysicalEdgeObligationV1Compat)
    @test isdefined(R5, :PhysicalEdgeObligationV1)
    @test getfield(R5, :PhysicalEdgeObligationV1) === PEO1_V5
    @test parentmodule(PEO3_V5) === R5
    @test PEO3_V5.PEO1 === PEO1_V5

    @test_throws ArgumentError _load_v1_compat_with_parent_alias_v5!(
        R5, V1_COMPAT_PATH_V5)
    @test getfield(R5, :PhysicalEdgeObligationV1) === PEO1_V5

    @test_throws ArgumentError _load_v1_compat_with_parent_alias_v5!(
        PhysicalEdgeObligationV5ForeignAliasFixture, V1_COMPAT_PATH_V5)
    @test getfield(PhysicalEdgeObligationV5ForeignAliasFixture,
        :PhysicalEdgeObligationV1) === :foreign_alias
    @test !isdefined(PhysicalEdgeObligationV5ForeignAliasFixture,
        :PhysicalEdgeObligationV1Compat)
end

@testset "V5 frozen V1 name collision is contained in a disposable module" begin
    probe = Module(gensym(:UP5PhysicalEdgeCollisionProbeV5))
    caught = try
        Core.eval(probe, quote
            module PhysicalEdgeObligationV1
                struct PhysicalEdgeObligationV1 end
            end
        end)
        nothing
    catch err
        err
    end
    @test caught !== nothing
    message = sprint(showerror, caught)
    @test occursin("invalid redefinition of constant", message)
    @test occursin("PhysicalEdgeObligationV1.PhysicalEdgeObligationV1", message)
end