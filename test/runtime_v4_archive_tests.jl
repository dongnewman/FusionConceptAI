using Test
using FusionConceptAI

module RuntimeV4ArchiveTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Execution.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Search.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Archives.jl"))
end

const R = RuntimeV4ArchiveTestModule
const H = digest256_text("runtime-v4-archive-test")

module RuntimeV4ArchivePublishedFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
end

function _archive_candidate_fixture()
    candidate = RuntimeV4ArchivePublishedFixture.candidate
    registry = RuntimeV4ArchivePublishedFixture.registry
    candidate, registry, candidate.mechanism_genome_ref.payload.operator_graph
end

function _archive_compiled(candidate, graph; grammar_hash=H, bounds_hash=H, mission_hash=H)
    sig = _archive_signature(bounds_hash)
    scope = R.MinimalityScopeV4(grammar_hash, bounds_hash, mission_hash, screen_only,
        ("archive-comparison",), ("archive-scenario",))
    R.CompiledCandidatePrefixV4(candidate, (mission=:archive,), (bounds=:archive,), scope,
        graph, graph, graph, graph, (), (), (), (), (sig,), :prefix_consistent)
end

function _archive_signature(bounds=H)
    R.CapabilitySignatureV4("fusionconceptai:runtime-v4-screen", "v1", :structural_screen,
        "typed_structure_audit", ("typed_graph",), "typed_graph", "typed_graph", 1, ("lumped",),
        "none_declared", "none_declared", "static_time", ("typed_structure_audit",),
        screen_only, bounds; input_schema_hash=digest256_text("screen-input"), coordinate_system="lumped")
end

@testset "RuntimeV4 deferred gaps aggregate by exact signature" begin
    archive = R.CapabilityArchiveV4()
    sig = _archive_signature()
    c1 = digest256_text("candidate-1")
    c2 = digest256_text("candidate-2")
    retry = digest256_text("provider-registry-old")
    R.defer!(archive, c1, :capability, sig, no_match, "no provider", retry)
    R.defer!(archive, c2, :capability, sig, ambiguous, "two providers", retry)
    report = R.gap_report(archive)
    @test length(report) == 1
    @test report[1].signature_hash == canonical_hash(sig)
    @test report[1].count == 2
    @test report[1].candidate_refs == Tuple(sort([string(c1), string(c2)]))
    R.defer!(archive, c1, :field, sig, no_match, "field provider missing", retry)
    @test length(R.gap_report(archive)) == 2
    @test_throws ArgumentError R.defer!(archive, c1, :capability, sig, unique_match, "invalid", retry)
end

@testset "RuntimeV4 requeue waits for all candidate gaps" begin
    archive = R.CapabilityArchiveV4()
    candidate_ref = digest256_text("candidate-multi-gap")
    retry = digest256_text("provider-old-multi-gap")
    sig1 = _archive_signature()
    sig2 = R.CapabilitySignatureV4("fusionconceptai:runtime-v4-screen", "v1", :structural_screen,
        "typed_structure_audit_2", ("typed_graph",), "typed_graph", "typed_graph", 1, ("lumped",),
        "none_declared", "none_declared", "static_time", ("typed_structure_audit",),
        screen_only, H; input_schema_hash=digest256_text("screen-input-2"), coordinate_system="lumped")
    R.defer!(archive, candidate_ref, :field, sig1, no_match, "first gap", retry)
    R.defer!(archive, candidate_ref, :whole_device, sig2, no_match, "second gap", retry)
    p1 = R.ProviderManifestV4(sig1.schema, sig1.revision, sig1.kind, sig1,
        (bounds_hash=H,), "screen", "v1", H, "independent-1", screen_only;
        input_schema_hash=sig1.input_schema_hash)
    p2 = R.ProviderManifestV4(sig2.schema, sig2.revision, sig2.kind, sig2,
        (bounds_hash=H,), "screen", "v2", H, "independent-2", screen_only;
        input_schema_hash=sig2.input_schema_hash)
    @test isempty(R.requeue_resolved!(archive, (p1,)))
    @test length(archive.deferred) == 1
    @test R.requeue_resolved!(archive, (p1, p2)) == (string(candidate_ref),)
    @test isempty(archive.deferred)
end

@testset "RuntimeV4 proposals stay outside candidate evidence" begin
    queue = R.CandidateQueueV4()
    proposal = ProposalEnvelopeV4("proposal-1", "candidate-ref", (), :screen,
        ((edit=:typed_addition,),), "cell-1", (predicted_metric=999.0,), (sigma=1.0,),
        1.0, H, :compile)
    @test R.submit_proposal!(queue, proposal) == "proposal-1"
    @test queue.proposals["proposal-1"].predicted_outcomes.predicted_metric == 999.0
    @test length(queue.entries) == 0
end

@testset "RuntimeV4 checkpoint envelope rejects mismatch and corruption" begin
    archive = R.CapabilityArchiveV4()
    sig = _archive_signature()
    R.defer!(archive, digest256_text("candidate-checkpoint"), :capability, sig,
        no_match, "deferred", digest256_text("provider-old"))
    queue = R.CandidateQueueV4()
    path = tempname()
    campaign = digest256_text("campaign")
    providers = digest256_text("providers")
    try
        checksum = R.checkpoint_runtime(path, queue, archive;
            campaign_hash=campaign, provider_registry_hash=providers)
        @test checksum isa Digest256
        restored = R.resume_runtime(path; campaign_hash=campaign, provider_registry_hash=providers)
        @test length(restored.archive.deferred) == 1
        @test_throws ArgumentError R.resume_runtime(path; campaign_hash=digest256_text("other"), provider_registry_hash=providers)
        bytes = read(path)
        open(path, "w") do io
            write(io, bytes[1:end-1])
        end
        @test_throws ArgumentError R.resume_runtime(path; campaign_hash=campaign, provider_registry_hash=providers)
    finally
        isfile(path) && rm(path)
    end
    @test_throws ArgumentError R.checkpoint_runtime(tempname(), R.CandidateQueueV4(), R.CapabilityArchiveV4();
        campaign_hash=campaign, provider_registry_hash=providers)
end

@testset "RuntimeV4 non-empty queue merge, requeue, and deterministic selection" begin
    candidate, registry, graph = _archive_candidate_fixture()
    compiled = _archive_compiled(candidate, graph)
    queue = R.CandidateQueueV4()
    first_entry = R.enqueue_candidate!(queue, candidate, compiled;
        registry_hash=H, parent_refs=("parent-b",), proposal_refs=("proposal-b",), priority=2)
    second_entry = R.enqueue_candidate!(queue, candidate, compiled;
        registry_hash=H, parent_refs=("parent-a",), proposal_refs=("proposal-a",), priority=7)
    @test length(queue.entries) == 1
    @test second_entry.candidate_ref == first_entry.candidate_ref
    @test second_entry.parent_refs == ("parent-a", "parent-b")
    @test second_entry.proposal_refs == ("proposal-a", "proposal-b")
    @test second_entry.priority == 7
    @test second_entry.compiled.prefix_hash == compiled.prefix_hash
    @test second_entry.candidate_ref == compiled.prefix_hash

    sig1 = _archive_signature(H)
    sig2 = R.CapabilitySignatureV4("fusionconceptai:runtime-v4-screen", "v1", :structural_screen,
        "archive_queue_audit_2", ("typed_graph",), "typed_graph", "typed_graph", 1, ("lumped",),
        "none_declared", "none_declared", "static_time", ("typed_structure_audit",), screen_only, H;
        input_schema_hash=digest256_text("archive-queue-screen-input-2"), coordinate_system="lumped")
    archive = R.CapabilityArchiveV4()
    R.mark_deferred!(queue, first_entry.candidate_ref)
    old_retry = digest256_text("archive-queue-old-registry")
    R.defer!(archive, first_entry.candidate_ref, :field, sig1, no_match, "first queue gap", old_retry)
    R.defer!(archive, first_entry.candidate_ref, :whole_device, sig2, no_match, "second queue gap", old_retry)
    p1 = R.ProviderManifestV4(sig1.schema, sig1.revision, sig1.kind, sig1,
        (bounds_hash=H,), "archive-screen", "backend-a", H, "archive-independent-a", screen_only;
        input_schema_hash=sig1.input_schema_hash)
    p2 = R.ProviderManifestV4(sig2.schema, sig2.revision, sig2.kind, sig2,
        (bounds_hash=H,), "archive-screen", "backend-b", H, "archive-independent-b", screen_only;
        input_schema_hash=sig2.input_schema_hash)
    @test isempty(R.requeue_resolved!(archive, queue, (p1,)))
    @test haskey(queue.entries, first_entry.candidate_ref)
    @test queue.entries[first_entry.candidate_ref].status == :deferred
    @test length(archive.deferred) == 1
    @test R.requeue_resolved!(archive, queue, (p1, p2)) == (string(first_entry.candidate_ref),)
    @test isempty(archive.deferred)
    @test queue.entries[first_entry.candidate_ref].status == :revived

    # Two distinct compiled prefixes make the scheduling order observable.
    compiled_low = _archive_compiled(candidate, graph; grammar_hash=digest256_text("grammar-low"))
    compiled_high = _archive_compiled(candidate, graph; grammar_hash=digest256_text("grammar-high"))
    scheduled = R.CandidateQueueV4()
    low = R.enqueue_candidate!(scheduled, candidate, compiled_low; registry_hash=H, priority=1)
    high = R.enqueue_candidate!(scheduled, candidate, compiled_high; registry_hash=H, priority=9)
    chosen = R.next_compilable!(scheduled)
    @test chosen.candidate_ref == high.candidate_ref
    @test chosen.status == :active
    @test scheduled.entries[low.candidate_ref].status == :queued
end
