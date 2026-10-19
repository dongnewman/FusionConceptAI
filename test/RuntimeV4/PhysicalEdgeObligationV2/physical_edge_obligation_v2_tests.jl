using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "SearchPhysicalConsumerV4",
    "search_physical_consumer_fixture_v4.jl"))

const F2 = SearchPhysicalConsumerV4TestRuntime
const R2 = F2.R
Base.include(R2, joinpath(F2.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV1.jl"))
Base.include(R2, joinpath(F2.ROOT, "src", "RuntimeV4",
    "PhysicalEdgeObligationV2.jl"))
const PEO1_2 = R2.PhysicalEdgeObligationV1
const PEO2 = R2.PhysicalEdgeObligationV2

function fabricated_cached_successes_v2(context, obligations)
    fake_hash(label) = canonical_hash((test_only_fabricated=label,))
    Tuple(begin
        identity = obligation.identity
        capability = R2.CapabilitySignatureV4(
            "test-only:forged-capability", "v1", :test_only,
            string(identity.operator_id, "@", identity.operator_version), (),
            "lumped", "lumped", 0, (), "none", "none", "steady",
            ("value",), none, fake_hash("bounds"))
        requirement = PEO1_2._peo_requirement(identity, capability)
        provider = PEO1_2._peo_provider_state(
            provider_state=:completed,
            receipt_state=:validated,
            provider_backend="caller-forged-provider",
            provider_manifest_hash=fake_hash("manifest"),
            registry_hash=fake_hash("registry"),
            request_hash=fake_hash("request:" * identity.identity_hash),
            receipt_hash=fake_hash("receipt:" * identity.identity_hash),
            input_hash=fake_hash("input:" * identity.identity_hash),
            output_hash=fake_hash("output:" * identity.identity_hash),
            provider_status=:completed,
            exit_code=0)
        PEO1_2._peo_make_obligation(identity, obligation.candidate_hash,
            obligation.genome_bundle_hash, obligation.context_hash,
            obligation.scenario_hash; requirement, provider)
    end for obligation in obligations)
end

@testset "V2 requires fresh request and receipt at assessment" begin
    fixture = F2.search_physical_fixture_v4()
    context = fixture.contexts[1]
    obligations = PEO1_2.physical_edge_obligations_v1(context)
    fabricated = fabricated_cached_successes_v2(context, obligations)
    registry = F2.trusted_registry_v4(context)

    # This directly captures the V1 false-positive: caller-accessible module
    # tokens can construct self-consistent cached fields that satisfy V1's
    # readiness label without any live request or receipt.
    old_assessment = PEO1_2.assess_candidate_obligations_v1(context, fabricated)
    @test old_assessment.status === :contract_ready_unwired

    # V2 treats those cached states as untrusted and defers with no live proof.
    fresh_assessment = PEO2.assess_candidate_obligations_v2(
        context, registry, fabricated, ())
    @test fresh_assessment.status === :deferred
    @test fresh_assessment.reasons == (:live_receipt_revalidation_required,)
    @test !fresh_assessment.activated
    @test !fresh_assessment.physical_validation
    @test !fresh_assessment.engineering_validation
    @test fresh_assessment.candidate_discovery_credit == 0
    @test fresh_assessment.credible_device_count == 0
end

@testset "V2 rejects string-only gap resolution and preserves zero credit" begin
    fixture = F2.search_physical_fixture_v4()
    context = fixture.contexts[1]
    obligations = PEO1_2.physical_edge_obligations_v1(context)
    registry = F2.trusted_registry_v4(context)
    result = PEO2.assess_candidate_obligations_v2(context, registry,
        obligations, (); unresolved_nonterminals=(
            "required_physical_capability:IDENTITY@v1",))

    @test result.status === :deferred
    @test result.reasons == (:compiler_gap_has_no_edge_bound_resolution,)
    @test !result.activated
    @test result.candidate_discovery_credit == 0
    @test !result.physical_validation && !result.engineering_validation
end
