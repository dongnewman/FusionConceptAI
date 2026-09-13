# julia --startup-file=no --project=. scripts/run_v4_algebraic_generation_slice.jl NEW_RUN_DIR
# Three 0D screens (seed plus two actual G1 descendants), not a fusion device search.
using FusionConceptAI, SHA, Serialization
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

module GenerationRunFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"))
end
const F = GenerationRunFixture

length(ARGS) == 1 || error("exactly one new run directory is required")
run_dir = abspath(ARGS[1])
ispath(run_dir) && !isempty(readdir(run_dir)) && error("refusing nonempty run directory")
mkpath(run_dir)

function screen(candidate, compiled, queue, archive)
    lineage = candidate.proposal_lineage
    entry = enqueue_candidate!(queue, candidate, compiled;
        registry_hash=canonical_hash(F.registry),
        parent_refs=isempty(lineage) ? () : last(lineage).parent_refs,
        proposal_refs=isempty(lineage) ? () : (last(lineage).proposal_id,))
    scenario = AlgebraicScenarioV4("generation-screen",
        (StateValueV4(StateGeneRefV1("x"), 0.5, UnitSignature()),
         StateValueV4(StateGeneRefV1("y"), -0.25, UnitSignature()));
        max_iterations=64)
    work = make_algebraic_scoped_work(entry, F.registry, scenario)
    provider = algebraic_residual_manifest(work.plan)
    report = execute_algebraic_once!(Dict{Digest256,Any}(), work.plan, scenario; provider=provider)
    resolution = make_algebraic_scoped_resolution(work, work.plan, scenario, report)
    for obligation in entry.compiled.capability_obligations
        defer!(archive, entry.candidate_ref, :remaining_runtime_capability,
            obligation, no_match, "not covered by the 0D algebraic screen",
            digest256_text("algebraic-generation-no-other-providers"))
    end
    (entry=entry, resolution=resolution, provider=provider, scenario=scenario)
end

function state_hash(queue, archive)
    entries = Tuple((ref=string(k), entry=semantic_view(queue.entries[k]),
        candidate=semantic_view(queue.entries[k].candidate))
        for k in sort(collect(keys(queue.entries)), by=string))
    proposals = Tuple(semantic_view(queue.proposals[k])
        for k in sort(collect(keys(queue.proposals))))
    deferred = Tuple(semantic_view(archive.deferred[k])
        for k in sort(collect(keys(archive.deferred)), by=string))
    canonical_hash((entries=entries, proposals=proposals, deferred=deferred))
end

compiled = compile_candidate(F.candidate, F.registry;
    mission_payload=F.candidate.mission_contract_ref,
    bounds_payload=(scope="generation-screen",),
    comparison_scope=("algebraic-residual",),
    scenario_scope=("generation-screen",))
queue = CandidateQueueV4()
archive = CapabilityArchiveV4()
rows = NamedTuple[]
providers = Digest256[]
feedback_files = NamedTuple[]
candidate = F.candidate
for generation in 0:2
    if generation > 0
        previous = last(rows)
        prior = previous.screen
        child = next_algebraic_generation_edit(candidate, prior.entry,
            prior.resolution, F.registry;
            proposal_id="algebraic-generation-$generation",
            expected_scenario_hash=prior.scenario.scenario_hash)
        child === nothing && error("typed edit coverage exhausted before generation $generation")
        submit_proposal!(queue, child.proposal)
        global candidate = child.candidate
        global compiled = child.compiled
    end
    result = screen(candidate, compiled, queue, archive)
    result.resolution.report.result.status == :converged ||
        error("fixture screen did not converge at generation $generation")
    push!(rows, (generation=generation, screen=result))
    push!(providers, result.provider.manifest_hash)
    feedback_path = joinpath(run_dir, "feedback_generation_$generation.jls")
    open(feedback_path, "w") do io
        serialize(io, result.resolution)
    end
    restored_feedback = open(deserialize, feedback_path)
    restored_feedback isa AlgebraicScopedResolutionV4 &&
        restored_feedback.resolution_hash == result.resolution.resolution_hash &&
        restored_feedback.candidate_ref == result.entry.candidate_ref &&
        restored_feedback.report.evidence.evidence_id == result.resolution.report.evidence.evidence_id &&
        restored_feedback.report.result.result_hash == result.resolution.report.result.result_hash ||
        error("typed feedback archive did not reimport exactly")
    push!(feedback_files, (generation=generation,
        file=basename(feedback_path), sha256=bytes2hex(SHA.sha256(read(feedback_path))),
        resolution_hash=string(result.resolution.resolution_hash)))
    println("GENERATION_SCREEN=", generation, " candidate=", result.entry.candidate_ref,
        " result=", result.resolution.result_hash, " status=", result.resolution.classification)
    flush(stdout)
end
next_algebraic_generation_edit(candidate, last(rows).screen.entry,
    last(rows).screen.resolution, F.registry; proposal_id="exhausted",
    expected_scenario_hash=last(rows).screen.scenario.scenario_hash) === nothing ||
    error("edit coverage should be exhausted after two descendants")

campaign_hash = canonical_hash((rule="algebraic-generation-coverage-v1", generations=3,
    scenario="generation-screen"))
provider_registry_hash = canonical_hash(Tuple(providers))
checkpoint = joinpath(run_dir, "queue_archive.checkpoint.jls")
checkpoint_hash = checkpoint_runtime(checkpoint, queue, archive;
    campaign_hash=campaign_hash, provider_registry_hash=provider_registry_hash)
restored = resume_runtime(checkpoint;
    campaign_hash=campaign_hash, provider_registry_hash=provider_registry_hash)
queue_archive_state_hash = state_hash(queue, archive)
length(restored.queue) == 3 && length(restored.queue.proposals) == 2 &&
    length(restored.archive.deferred) == length(archive.deferred) &&
    state_hash(restored.queue, restored.archive) == queue_archive_state_hash ||
    error("queue/archive checkpoint did not resume exactly")

source_paths = (joinpath(@__DIR__, "..", "Project.toml"),
    joinpath(@__DIR__, "..", "Manifest.toml"),
    (joinpath(@__DIR__, "..", "src", "RuntimeV4", file) for file in
        ("FusionRuntimeV4.jl", "Contracts.jl", "Compiler.jl", "Search.jl",
         "Archives.jl", "AlgebraicResidual.jl", "AlgebraicScopedSearch.jl",
         "AlgebraicGenerationV4.jl"))...,
    joinpath(@__DIR__, "..", "examples", "runtime_v4_algebraic_constraint_fixture.jl"),
    abspath(@__FILE__))
source_hashes = Tuple((path=replace(relpath(path, joinpath(@__DIR__, "..")), '\\' => '/'),
    sha256=bytes2hex(SHA.sha256(read(path))))
    for path in source_paths)
summaries = Tuple((generation=row.generation,
    candidate_ref=string(row.screen.entry.candidate_ref),
    mechanism_hash=string(row.screen.entry.candidate.canonical_hashes.mechanism_hash),
    parent_refs=row.screen.entry.parent_refs,
    proposal_refs=row.screen.entry.proposal_refs,
    screen_result_hash=string(row.screen.resolution.result_hash),
    screen_resolution_hash=string(row.screen.resolution.resolution_hash),
    solver_input_hash=string(row.screen.resolution.solver_input_hash),
    provider_manifest_hash=string(row.screen.provider.manifest_hash),
    solver_status=String(row.screen.resolution.report.result.status),
    claim_ceiling="screen_only") for row in rows)
receipt = (schema_version="runtime-v4-algebraic-generation-slice-v1",
    classification="typed_G1_screen_search_mechanics_only", source_hashes=source_hashes,
    julia_version=string(VERSION), julia_executable_sha256=bytes2hex(SHA.sha256(read(joinpath(Sys.BINDIR, Base.julia_exename())))),
    thread_count=Threads.nthreads(), candidate_count=3, descendant_count=2,
    generations=summaries, gap_count=length(gap_report(archive)),
    deferred_obligation_count=length(archive.deferred),
    typed_feedback_archive=Tuple(feedback_files),
    typed_feedback_recovery_boundary="separate_local_serialization_files; SHA256 and typed identity verified; not in queue checkpoint",
    campaign_hash=string(campaign_hash), provider_registry_hash=string(provider_registry_hash),
    queue_archive_state_hash=string(queue_archive_state_hash),
    checkpoint_payload_sha256=string(checkpoint_hash),
    checkpoint_file_sha256=bytes2hex(SHA.sha256(read(checkpoint))),
    checkpoint_resume_verified=true,
    process_exit_code=0, physical_validation="unsupported", net_electricity="unknown",
    originality="unsupported", credible_device_count=0,
    R08_accepted=false, R01_to_R10_accepted=false)
write(joinpath(run_dir, "result.json"), canonical_json(receipt) * "\n")
write(joinpath(run_dir, "runner.exit"), "0\n")
println("ALGEBRAIC_GENERATION_RUNNER_EXIT_CODE=0")
