using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "SearchPhysicalConsumerV4",
    "search_physical_consumer_fixture_v4.jl"))

const F2 = SearchPhysicalConsumerV4TestRuntime
const R2 = F2.R
Base.include(R2, joinpath(F2.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV1.jl"))
Base.include(R2, joinpath(F2.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV3.jl"))
const PEO1_2 = R2.PhysicalEdgeObligationV1
const PEO3 = R2.PhysicalEdgeObligationV3

function fabricated_cached_successes_v3(context, obligations)
    fake_hash(label) = canonical_hash((test_only_fabricated=label,))
    Tuple(begin
        identity = obligation.identity
        capability = R2.CapabilitySignatureV4(
            "test-only:forged-capability", "v1", :test_only,
            string(identity.operator_id, "@", identity.operator_version), ("u",),
            "lumped", "lumped", 0, (), "none", "none", "steady",
            ("value",), none, fake_hash("bounds"))
        requirement = PEO1_2._peo_requirement(identity, capability)
        provider = PEO1_2._peo_provider_state(
            provider_state=:completed,
            receipt_state=:validated,
            provider_backend="caller-forged-provider",
            provider_manifest_hash=fake_hash("manifest"),
            registry_hash=fake_hash("registry"),
            request_hash=fake_hash(("request", identity.identity_hash)),
            receipt_hash=fake_hash(("receipt", identity.identity_hash)),
            input_hash=fake_hash(("input", identity.identity_hash)),
            output_hash=fake_hash(("output", identity.identity_hash)),
            provider_status=:completed,
            exit_code=0)
        PEO1_2._peo_make_obligation(identity, obligation.candidate_hash,
            obligation.genome_bundle_hash, obligation.context_hash,
            obligation.scenario_hash; requirement, provider)
    end for obligation in obligations)
end

@testset "V3 cached module-qualified success fields do not establish live receipt" begin
    fixture = F2.search_physical_fixture_v4()
    context = fixture.contexts[1]
    obligations = PEO1_2.physical_edge_obligations_v1(context)
    fabricated = fabricated_cached_successes_v3(context, obligations)
    registry = F2.trusted_registry_v4(context)

    # This directly captures the V1 false-positive: caller-accessible module
    # tokens can construct self-consistent cached fields that satisfy V1's
    # readiness label without any live request or receipt.
    old_assessment = PEO1_2.assess_candidate_obligations_v1(context, fabricated)
    @test old_assessment.status === :contract_ready_unwired

    # V3 treats those cached states as untrusted and defers with no live proof.
    fresh_assessment = PEO3.assess_candidate_obligations_v3(
        context, registry, fabricated, ())
    @test fresh_assessment.status === :deferred
    @test fresh_assessment.reasons == (:live_receipt_revalidation_required,)
    @test !fresh_assessment.activated
    @test !fresh_assessment.physical_validation
    @test !fresh_assessment.engineering_validation
    @test fresh_assessment.candidate_discovery_credit == 0
    @test fresh_assessment.credible_device_count == 0
end

@testset "V3 rejects string-only gap resolution and preserves zero credit" begin
    fixture = F2.search_physical_fixture_v4()
    context = fixture.contexts[1]
    obligations = PEO1_2.physical_edge_obligations_v1(context)
    registry = F2.trusted_registry_v4(context)
    result = PEO3.assess_candidate_obligations_v3(context, registry,
        obligations, (); unresolved_nonterminals=(
            "required_physical_capability:IDENTITY@v1",))

    @test result.status === :deferred
    @test result.reasons == (:compiler_gap_has_no_edge_bound_resolution,)
    @test !result.activated
    @test result.candidate_discovery_credit == 0
    @test !result.physical_validation && !result.engineering_validation
end

include(joinpath(F2.ROOT, "examples", "runtime_v4_trusted_provider_registry.jl"))
const TPR3 = TrustedProviderRegistryRuntime
const R3 = TPR3

@testset "self-consistent caller-built receipt passes content validator but is not executor-issued" begin
    registry = TPR3.trusted_registry
    context = TPR3.trusted_context
    capability = TPR3.trusted_capability
    input = TPR3.trusted_input
    # This public builder reconstructs an equivalent ready request without
    # invoking its registered executor.
    request = R3.build_trusted_provider_dispatch_request(
        registry, context, capability, input)
    @test request.status === :ready_for_dispatch
    @test R3.validate_trusted_provider_dispatch_request(
        request, registry, context, capability, input)

    registration = request.registration::R3.TrustedProviderRegistrationV4
    forged_output = (execution_kind=:caller_forged_without_dispatch,
        input_hash=canonical_hash(input))
    forged_output_hash = canonical_hash(forged_output)
    forged_message = "constructed by caller; no executor invocation"
    forged_body = R3._tpr_receipt_body(request, registration,
        forged_output, forged_output_hash, 0, :completed, forged_message)
    forged_receipt = R3.TrustedProviderExecutionReceiptV4(R3._TPR_TOKEN,
        request.registry_hash, request.request_hash,
        registration.registration_hash, registration.manifest.manifest_hash,
        request.input_hash, forged_output, forged_output_hash, 0, :completed,
        forged_message, canonical_hash(forged_body))

    # This passing check is only reconstructed content/hash validation. There
    # is no executor-issued receipt ledger or issuer proof in the current ABI.
    @test R3.validate_trusted_provider_execution_receipt(
        forged_receipt, request, registry, context)
    @test forged_receipt.output.execution_kind === :caller_forged_without_dispatch
    @test !hasproperty(forged_receipt, :issuer_proof)
    @test !hasproperty(forged_receipt, :execution_identity)
    @test !PEO3.live_attempt_manifest_v3().receipt_validator_is_issuer_attestation
    @test !PEO3.live_attempt_manifest_v3().executor_issuance_provenance_available
end
