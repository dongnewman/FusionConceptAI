using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

module RuntimeV4AlgebraicScopedFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"))
end

const F = RuntimeV4AlgebraicScopedFixture

function _scoped_compiled(; bounds=(scope="algebraic-scoped-search",))
    compile_candidate(F.candidate, F.registry;
        mission_payload=F.candidate.mission_contract_ref,
        bounds_payload=bounds, comparison_scope=("algebraic-residual",),
        scenario_scope=("zero-dimensional",))
end

function _scoped_scenario(; x=0.5, y=-0.25, name="zero", max_iterations=64)
    unit = UnitSignature()
    AlgebraicScenarioV4(name,
        (StateValueV4(StateGeneRefV1("x"), x, unit),
         StateValueV4(StateGeneRefV1("y"), y, unit)); max_iterations=max_iterations)
end

function _scoped_entry(compiled)
    queue = CandidateQueueV4()
    entry = enqueue_candidate!(queue, F.candidate, compiled;
        registry_hash=canonical_hash(F.registry))
    queue, entry
end

@testset "algebraic scoped work is candidate-local" begin
    compiled = _scoped_compiled()
    queue, entry = _scoped_entry(compiled)
    scenario = _scoped_scenario()
    work = make_algebraic_scoped_work(entry, F.registry, scenario)
    @test work.candidate_ref == entry.candidate_ref == compiled.prefix_hash
    @test work.prefix_hash == compiled.prefix_hash
    @test work.plan.compiled_prefix_hash == compiled.prefix_hash
    @test work.stage == :g1_zero_dimensional_algebraic_constraint
    @test work.scenario_hash == scenario.scenario_hash
    @test work.capability.kind == :algebraic_constraint_screen
    @test work.work_hash isa Digest256
    @test entry.status == :deferred

    archive = CapabilityArchiveV4()
    deferred = defer_algebraic_scoped!(archive, work)
    @test deferred.stage == work.stage
    @test length(archive.deferred) == 1
    @test queue.entries[entry.candidate_ref].status == :deferred

    provider = algebraic_residual_manifest(work.plan)
    revived_work = requeue_scoped_resolved!(archive, work, (provider,))
    @test revived_work === work
    @test isempty(archive.deferred)
    @test queue.entries[entry.candidate_ref].status == :deferred

    foreign_provider = ProviderManifestV4(provider.schema, provider.revision, provider.kind,
        provider.capability, provider.domain, provider.backend, provider.backend_revision,
        digest256_text("foreign-requeue-provider"), provider.independence_group,
        provider.claim_ceiling; input_schema_hash=provider.input_schema_hash, executor=provider.executor)
    defer_algebraic_scoped!(archive, work; providers=(foreign_provider,))
    @test requeue_scoped_resolved!(archive, work, (foreign_provider,)) === nothing
    @test length(archive.deferred) == 1
    @test only(values(archive.deferred)).match_status == out_of_domain
    @test queue.entries[entry.candidate_ref].status == :deferred
end

@testset "scoped resolution validates identities and keeps screen authority local" begin
    compiled = _scoped_compiled()
    queue, entry = _scoped_entry(compiled)
    scenario = _scoped_scenario()
    work = make_algebraic_scoped_work(entry, F.registry, scenario)
    provider = algebraic_residual_manifest(work.plan)
    report = execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, scenario; provider=provider)
    resolution = make_algebraic_scoped_resolution(work, work.plan, scenario, report)
    @test resolution.classification == :evaluated_screen
    @test resolution.scope == "g1_zero_dimensional_algebraic_constraint"
    @test resolution.candidate_ref == entry.candidate_ref
    @test resolution.prefix_hash == compiled.prefix_hash
    @test resolution.selected_constraint_hashes == work.plan.selected_constraint_hashes
    @test resolution.report === report
    @test resolution.resolution_hash isa Digest256
    @test resolution.remaining_unresolved_nonterminals == entry.compiled.unresolved_nonterminals
    @test resolution.remaining_capability_obligations == entry.compiled.capability_obligations
    @test !isempty(resolution.remaining_unresolved_nonterminals)
    @test !isempty(resolution.remaining_capability_obligations)
    @test report.evidence.status_vector.applicability == required
    @test report.evidence.status_vector.match_status == unique_match
    @test report.evidence.status_vector.resolution == resolved
    @test report.evidence.status_vector.lifecycle == low_fidelity_evaluated
    @test report.evidence.claim_ceiling == screen_only

    deferred_report = execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, scenario; provider=nothing)
    @test_throws ArgumentError make_algebraic_scoped_resolution(work, work.plan, scenario, deferred_report)

    foreign_provider = ProviderManifestV4(provider.schema, provider.revision, provider.kind,
        provider.capability, provider.domain, provider.backend, provider.backend_revision,
        digest256_text("foreign-algebraic-provider"), provider.independence_group,
        provider.claim_ceiling; input_schema_hash=provider.input_schema_hash, executor=provider.executor)
    @test_throws ArgumentError execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, scenario;
        provider=foreign_provider)

    other_compiled = _scoped_compiled(bounds=(scope="foreign-prefix",))
    _, other_entry = _scoped_entry(other_compiled)
    other_work = make_algebraic_scoped_work(other_entry, F.registry, scenario)
    @test other_work.prefix_hash != work.prefix_hash
    @test_throws ArgumentError make_algebraic_scoped_resolution(work, other_work.plan, scenario, report)
    foreign_scenario = _scoped_scenario(name="foreign-scenario")
    @test_throws ArgumentError make_algebraic_scoped_resolution(work, work.plan, foreign_scenario, report)
end

@testset "failed scoped attempt remains a typed attempt and archive gap" begin
    compiled = _scoped_compiled()
    queue, entry = _scoped_entry(compiled)
    bad_scenario = _scoped_scenario(x=11.0, y=0.0)
    work = make_algebraic_scoped_work(entry, F.registry, bad_scenario)
    archive = CapabilityArchiveV4()
    defer_algebraic_scoped!(archive, work)
    provider = algebraic_residual_manifest(work.plan)
    @test requeue_scoped_resolved!(archive, work, (provider,)) === work
    @test isempty(archive.deferred)
    report = execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, bad_scenario; provider=provider)
    @test report.result.status == :numerical_fail
    attempt = make_algebraic_scoped_attempt(work, work.plan, bad_scenario, report)
    @test attempt.classification == :attempt_failed
    @test attempt.remaining_unresolved_nonterminals == entry.compiled.unresolved_nonterminals
    @test_throws ArgumentError make_algebraic_scoped_resolution(work, work.plan, bad_scenario, report)
    @test isempty(archive.deferred)
    @test queue.entries[entry.candidate_ref].status == :deferred
end

@testset "next scoped work is deterministic and does not revive candidates" begin
    high_compiled = _scoped_compiled(bounds=(scope="scoped-high",))
    low_compiled = _scoped_compiled(bounds=(scope="scoped-low",))
    queue = CandidateQueueV4()
    low_entry = enqueue_candidate!(queue, F.candidate, low_compiled;
        registry_hash=canonical_hash(F.registry), priority=1)
    high_entry = enqueue_candidate!(queue, F.candidate, high_compiled;
        registry_hash=canonical_hash(F.registry), priority=9)
    scenario = _scoped_scenario()
    selected = next_algebraic_scoped_work(queue, F.registry, scenario)
    @test selected !== nothing
    @test selected.candidate_ref == high_entry.candidate_ref
    @test queue.entries[low_entry.candidate_ref].status == :deferred
    @test queue.entries[high_entry.candidate_ref].status == :deferred
    @test next_algebraic_scoped_work(queue, F.registry, scenario).candidate_ref == high_entry.candidate_ref

    bad_queue = CandidateQueueV4()
    bad_entry = enqueue_candidate!(bad_queue, F.candidate, high_compiled;
        registry_hash=digest256_text("wrong-registry"), priority=100)
    @test_throws ArgumentError next_algebraic_scoped_work(bad_queue, F.registry, scenario)
    @test bad_queue.entries[bad_entry.candidate_ref].status == :deferred
end

@testset "scoped archive checkpoint roundtrip preserves candidate stage and signature" begin
    compiled = _scoped_compiled()
    queue, entry = _scoped_entry(compiled)
    work = make_algebraic_scoped_work(entry, F.registry, _scoped_scenario())
    archive = CapabilityArchiveV4()
    defer_algebraic_scoped!(archive, work)
    path = tempname()
    campaign = digest256_text("algebraic-scoped-campaign")
    providers = digest256_text("algebraic-scoped-providers")
    checkpoint_runtime(path, queue, archive; campaign_hash=campaign, provider_registry_hash=providers)
    restored = resume_runtime(path; campaign_hash=campaign, provider_registry_hash=providers)
    restored_entry = restored.queue.entries[entry.candidate_ref]
    restored_record = only(values(restored.archive.deferred))
    @test restored_entry.candidate_ref == entry.candidate_ref
    @test restored_entry.status == :deferred
    @test restored_record.candidate_ref == string(entry.candidate_ref)
    @test restored_record.stage == work.stage
    @test canonical_hash(restored_record.signature) == canonical_hash(work.capability)
    rm(path; force=true)
end
