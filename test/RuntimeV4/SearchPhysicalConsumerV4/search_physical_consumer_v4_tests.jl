using Test
using FusionConceptAI

include(joinpath(@__DIR__, "search_physical_consumer_fixture_v4.jl"))

const F4 = SearchPhysicalConsumerV4TestRuntime
const R4 = F4.R
const SPC3 = F4.SPC3

@testset "V4 fixture preserves strong G1 payload and rejects empty-graph control" begin
    fixture = F4.search_physical_fixture_v4()
    graph = fixture.g1_payload.operator_graph
    edges = getfield(graph, :hyperedges)

    @test length(edges) == 2
    @test all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in edges)
    @test fixture.candidate.mechanism_genome_ref.payload === fixture.g1_payload
    @test fixture.compiled.compilation_status === :prefix_consistent
    @test isempty(fixture.compiled.unresolved_nonterminals)

    # Preserve the prior failure as an explicit negative control. The strong
    # payload constructor must continue rejecting a G1 graph with no edges.
    invalid_graph = TypedOperatorHypergraphV1(getfield(graph, :nodes), ();
        registry=F4._fixture_ops)
    @test_throws ArgumentError MechanismGenomePayloadV1(
        fixture.g1_payload.states, (), invalid_graph, (), (), (), ())
end

@testset "V4 fixture prepares exact trusted request without execution" begin
    fixture = F4.search_physical_fixture_v4()
    active = F4.active_queue_v4(fixture)
    context = fixture.contexts[1]
    trusted = F4.trusted_registry_v4(context)

    @test active.queued.status === :queued
    @test active.active.status === :active
    @test active.active.candidate_ref == context.compiled.prefix_hash

    record = SPC3.prepare_search_physical_consumer_v3(
        active.queue, active.active.candidate_ref, context, trusted)
    @test record.state === :ready_for_dispatch
    @test record.inner.request !== nothing
    @test record.inner.request.status === :ready_for_dispatch
    @test record.inner.request.context_hash == context.context_hash
    @test record.inner.request.scenario_hash == context.scenario_hash
    @test record.inner.g1_hash == context.genome_bindings[1].genome_hash
    @test record.inner.g2_hash == context.genome_bindings[2].genome_hash
    @test record.inner.g3_hash == context.genome_bindings[3].genome_hash
    @test record.inner.trusted_receipt === nothing
    @test record.claim_ceiling === none
    @test !record.physical_validation && !record.engineering_validation
    @test record.candidate_discovery_credit == 0 && record.credible_device_count == 0
    @test SPC3.validate_search_physical_consumer_receipt_v3(
        record, active.queue, context, trusted)

    R4.mark_deferred!(active.queue, active.active.candidate_ref)
    @test !SPC3.validate_search_physical_consumer_receipt_v3(
        record, active.queue, context, trusted)
end

@testset "V4 canonical receipt binds semantic view and queue snapshot" begin
    fixture = F4.search_physical_fixture_v4()
    active = F4.active_queue_v4(fixture)
    context = fixture.contexts[1]
    trusted = F4.trusted_registry_v4(context)
    record = SPC3.prepare_search_physical_consumer_v3(
        active.queue, active.active.candidate_ref, context, trusted)

    @test SPC3.canonical_hash(record) == record.record_hash
    canonical = canonical_json(record)
    @test occursin("search-physical-consumer-v3", canonical)
    @test occursin("queue_fingerprint_before", canonical)
    @test occursin(string(record.inner.request_hash), canonical)
    @test SPC3.validate_search_physical_consumer_receipt_v3(
        record, active.queue, context, trusted)
    @test record.queue_stable == (record.queue_fingerprint_before !== nothing &&
        record.queue_fingerprint_before == record.queue_fingerprint_after)
    @test_throws MethodError SPC3.SearchPhysicalConsumerReceiptV3(
        ntuple(i -> getfield(record, i), fieldcount(typeof(record)))...)
    @test record.claim_ceiling === none
    @test record.candidate_discovery_credit == 0
    @test !record.physical_validation && !record.engineering_validation
end

@testset "V4 dispatch lease rejects competing owners, drift, and callback injection" begin
    fixture = F4.search_physical_fixture_v4()
    active = F4.active_queue_v4(fixture)
    ref = active.active.candidate_ref
    fingerprint = SPC3._spc3_queue_fingerprint(active.queue, ref)
    calls = Ref(0)
    fake_provider(args...; kwargs...) = (calls[] += 1; :must_not_run)

    first_claim = SPC3._spc3_claim_dispatch!(active.queue, ref, fingerprint)
    @test first_claim.failure_code === nothing
    lease = first_claim.lease
    second_claim = fetch(@async SPC3._spc3_claim_dispatch!(
        active.queue, ref, fingerprint))
    @test second_claim.lease === nothing
    @test second_claim.failure_code === :queue_owner_busy
    other_task_gate = fetch(@async SPC3._spc3_dispatch_gate(
        active.queue, ref, lease))
    @test !other_task_gate.allowed
    @test other_task_gate.failure_code === :queue_owner_task_mismatch

    old_entry = active.queue.entries[ref]
    active.queue.entries[ref] = R4.CandidateQueueEntryV4(
        old_entry.candidate, old_entry.compiled, old_entry.registry_hash,
        old_entry.parent_refs, old_entry.proposal_refs,
        old_entry.priority + 1, :active)
    gate = SPC3._spc3_dispatch_gate(active.queue, ref, lease)
    @test !gate.allowed
    @test gate.failure_code === :queue_changed_before_dispatch
    @test !SPC3._spc3_mark_dispatched!(active.queue, ref, lease)
    @test calls[] == 0
    @test SPC3._spc3_release_dispatch!(active.queue, lease)
    @test calls[] == 0

    context = fixture.contexts[1]
    @test_throws MethodError SPC3.execute_search_physical_consumer_v3!(
        active.queue, ref, context, F4.trusted_registry_v4(context);
        executor=fake_provider)
    @test calls[] == 0
end

@testset "V4 dispatch token is exact and cannot be replayed" begin
    fixture = F4.search_physical_fixture_v4()
    active = F4.active_queue_v4(fixture)
    ref = active.active.candidate_ref
    fingerprint = SPC3._spc3_queue_fingerprint(active.queue, ref)
    claim = SPC3._spc3_claim_dispatch!(active.queue, ref, fingerprint)
    lease = claim.lease

    @test SPC3._spc3_dispatch_gate(active.queue, ref, lease).allowed
    @test SPC3._spc3_mark_dispatched!(active.queue, ref, lease)
    @test SPC3._spc3_dispatch_token_matches(active.queue, ref, lease.token)
    @test !SPC3._spc3_dispatch_token_matches(active.queue, ref,
        lease.token + UInt64(1))
    @test SPC3._spc3_release_dispatch!(active.queue, lease)

    replay = SPC3._spc3_claim_dispatch!(active.queue, ref, fingerprint)
    @test replay.lease === nothing
    @test replay.failure_code === :already_dispatched
end

@testset "V4 preflight exception and receipt tamper never call a fake provider" begin
    fixture = F4.search_physical_fixture_v4()
    active = F4.active_queue_v4(fixture)
    context = fixture.contexts[1]
    trusted = F4.trusted_registry_v4(context)
    calls = Ref(0)
    fake_provider(args...; kwargs...) = (calls[] += 1; :must_not_run)

    malformed_registry = R4.TrustedProviderRegistryV4(R4._TPR_TOKEN,
        "not-normalized-root", trusted.repository_identity_hash,
        trusted.descriptors, trusted.registrations, trusted.registry_hash)
    @test_throws MethodError SPC3.execute_search_physical_consumer_v3!(
        active.queue, active.active.candidate_ref, context, malformed_registry;
        executor=fake_provider)
    @test calls[] == 0
    exception_record = SPC3.execute_search_physical_consumer_v3!(
        active.queue, active.active.candidate_ref, context, malformed_registry)
    @test exception_record.state === :program_exception
    @test exception_record.failure_code === :preflight_exception
    @test exception_record.inner.request === nothing
    @test calls[] == 0

    good = SPC3.prepare_search_physical_consumer_v3(
        active.queue, active.active.candidate_ref, context, trusted)
    request = good.inner.request
    registration = request.registration
    tampered = R4.TrustedProviderExecutionReceiptV4(R4._TPR_TOKEN,
        request.registry_hash, request.request_hash,
        registration.registration_hash, registration.manifest.manifest_hash,
        request.input_hash, nothing, canonical_hash(nothing), 1,
        :executor_error, "synthetic tamper negative control",
        digest256_text("intentionally-wrong-receipt-hash"))
    @test !R4.validate_trusted_provider_execution_receipt(
        tampered, request, trusted, context)
    @test !SPC3._spc3_execution_receipt_valid(tampered, good.inner,
        trusted, context)
    @test_throws MethodError SPC3.execute_search_physical_consumer_v3!(
        active.queue, active.active.candidate_ref, context, trusted;
        executor=fake_provider)
    @test calls[] == 0
end
