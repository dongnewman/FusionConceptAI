using Test
using FusionConceptAI

const V2_TEST_ROOT = normpath(abspath(joinpath(@__DIR__, "..", "..", "..")))
include(joinpath(V2_TEST_ROOT, "test", "RuntimeV4", "SearchPhysicalConsumerV1",
    "search_physical_consumer_v1_tests.jl"))
Base.include(SearchPhysicalConsumerTestRuntime.FusionRuntimeV4,
    joinpath(V2_TEST_ROOT, "src", "RuntimeV4", "SearchPhysicalConsumerV2.jl"))

const R2 = SearchPhysicalConsumerTestRuntime.FusionRuntimeV4
const SPC2 = R2.SearchPhysicalConsumerV2

@testset "V2 canonical receipt uses FusionConceptAI semantic_view" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    trusted = _trusted_registry(fixture.contexts[1])
    record = SPC2.prepare_search_physical_consumer_v2(active.queue,
        active.active.candidate_ref, fixture.contexts[1], trusted)

    @test record.state === :ready_for_dispatch
    @test SPC2.canonical_hash(record) == record.record_hash
    canonical = canonical_json(record)
    @test occursin("search-physical-consumer-v2", canonical)
    @test occursin("queue_fingerprint_before", canonical)
    @test occursin(string(record.inner.request_hash), canonical)
    @test SPC2.validate_search_physical_consumer_receipt_v2(record,
        active.queue, fixture.contexts[1], trusted)
    @test record.claim_ceiling === none
    @test record.candidate_discovery_credit == 0
    @test !record.physical_validation && !record.engineering_validation
end

@testset "V2 dispatch lease serializes owners and fails closed on queue drift" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    ref = active.active.candidate_ref
    fingerprint = SPC2._spc2_queue_fingerprint(active.queue, ref)
    calls = Ref(0)
    fake_provider(args...; kwargs...) = (calls[] += 1; :must_not_run)

    first_claim = SPC2._spc2_claim_dispatch!(active.queue, ref, fingerprint)
    @test first_claim.failure_code === nothing
    lease = first_claim.lease
    second_claim = fetch(@async SPC2._spc2_claim_dispatch!(
        active.queue, ref, fingerprint))
    @test second_claim.lease === nothing
    @test second_claim.failure_code === :queue_owner_busy
    other_task_gate = fetch(@async SPC2._spc2_dispatch_gate(
        active.queue, ref, lease))
    @test !other_task_gate.allowed
    @test other_task_gate.failure_code === :queue_owner_task_mismatch

    old_entry = active.queue.entries[ref]
    active.queue.entries[ref] = R2.CandidateQueueEntryV4(
        old_entry.candidate, old_entry.compiled, old_entry.registry_hash,
        old_entry.parent_refs, old_entry.proposal_refs,
        old_entry.priority + 1, :active)
    gate = SPC2._spc2_dispatch_gate(active.queue, ref, lease)
    @test !gate.allowed
    @test gate.failure_code === :queue_changed_before_dispatch
    @test !SPC2._spc2_mark_dispatched!(active.queue, ref, lease)
    @test calls[] == 0
    @test SPC2._spc2_release_dispatch!(active.queue, lease)
    @test calls[] == 0

    @test_throws MethodError SPC2.execute_search_physical_consumer_v2!(
        active.queue, ref, fixture.contexts[1], _trusted_registry(fixture.contexts[1]);
        executor=fake_provider)
    @test calls[] == 0
end

@testset "V2 dispatch claim cannot be replayed for the same active entry" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    ref = active.active.candidate_ref
    fingerprint = SPC2._spc2_queue_fingerprint(active.queue, ref)
    claim = SPC2._spc2_claim_dispatch!(active.queue, ref, fingerprint)
    lease = claim.lease
    @test SPC2._spc2_dispatch_gate(active.queue, ref, lease).allowed
    @test SPC2._spc2_mark_dispatched!(active.queue, ref, lease)
    @test SPC2._spc2_release_dispatch!(active.queue, lease)

    replay = SPC2._spc2_claim_dispatch!(active.queue, ref, fingerprint)
    @test replay.lease === nothing
    @test replay.failure_code === :already_dispatched
end

@testset "V2 preflight exception and receipt tamper reject before any fake provider" begin
    fixture = _search_physical_fixture()
    active = _active_queue(fixture)
    context = fixture.contexts[1]
    trusted = _trusted_registry(context)
    calls = Ref(0)
    fake_provider(args...; kwargs...) = (calls[] += 1; :must_not_run)

    malformed_registry = R2.TrustedProviderRegistryV4(R2._TPR_TOKEN,
        "not-normalized-root", trusted.repository_identity_hash,
        trusted.descriptors, trusted.registrations, trusted.registry_hash)
    @test_throws MethodError SPC2.execute_search_physical_consumer_v2!(
        active.queue, active.active.candidate_ref, context, malformed_registry;
        executor=fake_provider)
    @test calls[] == 0
    exception_record = SPC2.execute_search_physical_consumer_v2!(
        active.queue, active.active.candidate_ref, context, malformed_registry)
    @test exception_record.state === :program_exception
    @test exception_record.failure_code === :preflight_exception
    @test exception_record.inner.request === nothing
    @test calls[] == 0

    good = SPC2.prepare_search_physical_consumer_v2(active.queue,
        active.active.candidate_ref, context, trusted)
    request = good.inner.request
    registration = request.registration
    tampered = R2.TrustedProviderExecutionReceiptV4(R2._TPR_TOKEN,
        request.registry_hash, request.request_hash,
        registration.registration_hash, registration.manifest.manifest_hash,
        request.input_hash, nothing, canonical_hash(nothing), 1,
        :executor_error, "synthetic tamper negative control",
        digest256_text("intentionally-wrong-receipt-hash"))
    @test !R2.validate_trusted_provider_execution_receipt(tampered,
        request, trusted, context)
    @test !SPC2._spc2_execution_receipt_valid(tampered, good.inner,
        trusted, context)
    @test_throws MethodError SPC2.execute_search_physical_consumer_v2!(
        active.queue, active.active.candidate_ref, context, trusted;
        executor=fake_provider)
    @test calls[] == 0
end
