using Test
using FusionConceptAI

# V5 is a deferred-only regression fixture. It reuses the V4 owner fixture to
# preserve the strong G1 payload, but deliberately does not call the dispatch
# or solver entrypoint. The existing compiler gap must remain visible.
include(joinpath(@__DIR__, "..", "SearchPhysicalConsumerV4",
    "search_physical_consumer_fixture_v4.jl"))

const F5 = SearchPhysicalConsumerV4TestRuntime
const R5 = F5.R
const SPC5 = F5.SPC3

function deferred_queue_v5(fixture)
    queue = R5.CandidateQueueV4()
    queued = R5.enqueue_candidate!(queue, fixture.candidate, fixture.compiled;
        registry_hash=canonical_hash(F5.registry))
    queue, queued
end

@testset "V5 preserves strong G1 and exact unresolved compiler gap" begin
    fixture = F5.search_physical_fixture_v4()
    graph = fixture.g1_payload.operator_graph
    edges = getfield(graph, :hyperedges)

    @test length(edges) == 2
    @test all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in edges)
    @test fixture.candidate.mechanism_genome_ref.payload === fixture.g1_payload
    @test fixture.compiled.compilation_status === :prefix_incomplete
    @test fixture.compiled.unresolved_nonterminals ==
        ("required_physical_capability:IDENTITY@v1",)

    invalid_graph = TypedOperatorHypergraphV1(getfield(graph, :nodes), ();
        registry=F5._fixture_ops)
    @test_throws ArgumentError MechanismGenomePayloadV1(
        fixture.g1_payload.states, (), invalid_graph, (), (), (), ())
end

@testset "V5 unresolved prefix stays deferred and never becomes active" begin
    fixture = F5.search_physical_fixture_v4()
    queue, queued = deferred_queue_v5(fixture)

    @test queued.status === :deferred
    @test queued.compiled.compilation_status === :prefix_incomplete
    @test queued.compiled.unresolved_nonterminals ==
        ("required_physical_capability:IDENTITY@v1",)
    @test R5.next_compilable!(queue) === nothing
    @test queue.entries[queued.candidate_ref].status === :deferred
end

@testset "V5 consumer preflight returns typed deferred with no dispatch data" begin
    fixture = F5.search_physical_fixture_v4()
    queue, queued = deferred_queue_v5(fixture)
    context = fixture.contexts[1]
    trusted = F5.trusted_registry_v4(context)

    record = SPC5.prepare_search_physical_consumer_v3(
        queue, queued.candidate_ref, context, trusted)

    @test record.state === :deferred
    @test record.failure_code === :search_entry_not_active
    @test record.inner.state === :deferred
    @test record.inner.queue_status === :deferred
    @test record.inner.gaps == ("search_entry_not_active",)
    @test record.inner.capability === nothing
    @test record.inner.input === nothing
    @test record.inner.request === nothing
    @test record.inner.trusted_receipt === nothing
    @test record.request_hash === nothing
    @test record.provider_status === nothing
    @test record.trusted_receipt_hash === nothing
    @test record.output_hash === nothing
    @test record.queue_owner_token === nothing
    @test record.queue_stable
    @test record.claim_ceiling === none
    @test !record.physical_validation && !record.engineering_validation
    @test record.candidate_discovery_credit == 0
    @test record.credible_device_count == 0
    @test SPC5.validate_search_physical_consumer_receipt_v3(
        record, queue, context, trusted)
    @test queue.entries[queued.candidate_ref].status === :deferred
end
