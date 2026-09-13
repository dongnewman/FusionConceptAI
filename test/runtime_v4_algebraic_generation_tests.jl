using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

module GenerationFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"))
end
const GF = GenerationFixture

function generation_screen(candidate, compiled, queue, archive)
    lineage = candidate.proposal_lineage
    entry = enqueue_candidate!(queue, candidate, compiled;
        registry_hash=canonical_hash(GF.registry),
        parent_refs=isempty(lineage) ? () : last(lineage).parent_refs,
        proposal_refs=isempty(lineage) ? () : (last(lineage).proposal_id,))
    scenario = AlgebraicScenarioV4("generation-screen",
        (StateValueV4(StateGeneRefV1("x"), 0.5, UnitSignature()),
         StateValueV4(StateGeneRefV1("y"), -0.25, UnitSignature()));
        max_iterations=64)
    work = make_algebraic_scoped_work(entry, GF.registry, scenario)
    provider = algebraic_residual_manifest(work.plan)
    report = execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, scenario; provider=provider)
    resolution = make_algebraic_scoped_resolution(work, work.plan, scenario, report)
    for obligation in entry.compiled.capability_obligations
        defer!(archive, entry.candidate_ref, :remaining_runtime_capability,
            obligation, no_match, "not covered by the 0D algebraic screen",
            digest256_text("algebraic-generation-no-other-providers"))
    end
    (entry=entry, resolution=resolution, scenario=scenario)
end

function generation_state_hash(queue, archive)
    entries = Tuple((ref=string(k), entry=semantic_view(queue.entries[k]),
        candidate=semantic_view(queue.entries[k].candidate))
        for k in sort(collect(keys(queue.entries)), by=string))
    proposals = Tuple(semantic_view(queue.proposals[k])
        for k in sort(collect(keys(queue.proposals))) )
    deferred = Tuple(semantic_view(archive.deferred[k])
        for k in sort(collect(keys(archive.deferred)), by=string))
    canonical_hash((entries=entries, proposals=proposals, deferred=deferred))
end

@testset "typed G1 generate screen archive feedback two-generation slice" begin
    compiled0 = compile_candidate(GF.candidate, GF.registry;
        mission_payload=GF.candidate.mission_contract_ref,
        bounds_payload=(scope="generation-screen",),
        comparison_scope=("algebraic-residual",),
        scenario_scope=("generation-screen",))
    queue = CandidateQueueV4()
    archive = CapabilityArchiveV4()
    seed = generation_screen(GF.candidate, compiled0, queue, archive)
    @test seed.resolution.classification == :evaluated_screen
    @test seed.resolution.report.evidence.claim_ceiling == screen_only
    @test seed.entry.status == :deferred
    first_child = next_algebraic_generation_edit(GF.candidate, seed.entry,
        seed.resolution, GF.registry; proposal_id="algebraic-generation-1",
        expected_scenario_hash=seed.scenario.scenario_hash)
    @test first_child !== nothing
    @test only(first_child.proposal.typed_edit_trace).edge_id == "constraint-difference"
    @test first_child.proposal.candidate_or_prefix_ref == string(first_child.compiled.prefix_hash)
    @test first_child.candidate.canonical_hashes.mechanism_hash != GF.candidate.canonical_hashes.mechanism_hash
    @test first_child.candidate.canonical_hashes.field_geometry_hash == GF.candidate.canonical_hashes.field_geometry_hash
    submit_proposal!(queue, first_child.proposal)
    gen1 = generation_screen(first_child.candidate, first_child.compiled, queue, archive)
    @test gen1.entry.candidate_ref != seed.entry.candidate_ref
    @test gen1.resolution.report.result.status == :converged
    @test gen1.resolution.report.result.result_hash != seed.resolution.report.result.result_hash
    second_child = next_algebraic_generation_edit(first_child.candidate, gen1.entry,
        gen1.resolution, GF.registry; proposal_id="algebraic-generation-2",
        expected_scenario_hash=gen1.scenario.scenario_hash)
    @test second_child !== nothing
    @test only(second_child.proposal.typed_edit_trace).edge_id == "constraint-sum"
    @test second_child.proposal.candidate_or_prefix_ref == string(second_child.compiled.prefix_hash)
    @test only(second_child.proposal.typed_edit_trace).feedback_resolution_hash == gen1.resolution.resolution_hash
    submit_proposal!(queue, second_child.proposal)
    gen2 = generation_screen(second_child.candidate, second_child.compiled, queue, archive)
    @test length(queue) == 3
    @test length(queue.proposals) == 2
    @test length(gap_report(archive)) > 0
    @test gen2.entry.parent_refs == (string(gen1.entry.candidate_ref),)
    @test gen2.resolution.report.result.status == :converged
    @test next_algebraic_generation_edit(second_child.candidate, gen2.entry,
        gen2.resolution, GF.registry; proposal_id="generation-exhausted",
        expected_scenario_hash=gen2.scenario.scenario_hash) === nothing
    @test_throws ArgumentError algebraic_generation_edit(GF.candidate, gen1.entry,
        seed.resolution, GF.registry, "constraint-sum", 4, "foreign-parent",
        seed.scenario.scenario_hash)
    @test_throws ArgumentError algebraic_generation_edit(GF.candidate, seed.entry,
        seed.resolution, GF.registry, "constraint-sum", 3, "identity-edit",
        seed.scenario.scenario_hash)
    @test_throws ArgumentError algebraic_generation_edit(GF.candidate, seed.entry,
        seed.resolution, GF.registry, "constraint-sum", 11, "out-of-bounds",
        seed.scenario.scenario_hash)
    @test_throws ArgumentError next_algebraic_generation_edit(GF.candidate, seed.entry,
        seed.resolution, GF.registry; proposal_id="cross-scenario",
        expected_scenario_hash=digest256_text("wrong-scenario"))
    constraint_edge = only(e for e in GF.candidate.mechanism_genome_ref.payload.operator_graph.hyperedges
        if e.edge_id == "constraint-sum")
    dead = ASTConstantV1(:dead, 9, constraint_edge.program.nodes[3].output_type)
    @test_throws ArgumentError TypedASTProgramV1(
        (constraint_edge.program.nodes..., dead), constraint_edge.program.roots,
        constraint_edge.program.input_ports; registry=constraint_edge.registry)
    path = tempname()
    campaign = digest256_text("algebraic-generation-campaign-v1")
    providers = digest256_text("algebraic-generation-provider-registry-v1")
    checkpoint_runtime(path, queue, archive;
        campaign_hash=campaign, provider_registry_hash=providers)
    restored = resume_runtime(path;
        campaign_hash=campaign, provider_registry_hash=providers)
    @test length(restored.queue) == 3
    @test length(restored.queue.proposals) == 2
    @test length(gap_report(restored.archive)) == length(gap_report(archive))
    @test generation_state_hash(restored.queue, restored.archive) ==
        generation_state_hash(queue, archive)
    rm(path; force=true)
end
