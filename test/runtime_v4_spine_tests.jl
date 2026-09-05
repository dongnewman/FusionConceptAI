using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))

const BOUNDS = (scope="runtime-v4-spine-bounds",)
const R_BOUNDS = digest256_text("runtime-v4-screen-bounds")
const COMPILED = compile_candidate(candidate, registry;
    mission_payload=candidate.mission_contract_ref, bounds_payload=BOUNDS,
    comparison_scope=("runtime-v4-spine",), scenario_scope=("p1",))
const SCREEN = first(filter(o -> o.kind == :structural_screen,
    COMPILED.capability_obligations))

test_subject(scenarios=((name="p1",),)) = ExecutablePhysicalSubjectV4(
    digest256_text("test-prefix"), digest256_text("test-bundle"),
    digest256_text("test-mission"), digest256_text("test-bounds"),
    (candidate="fixture",), Tuple(scenarios),
    (materialized_payload=(marker="typed",),), (SCREEN,))

@testset "frozen StageSpec derives Cartesian gaps" begin
    spec = StageSpecV4(:p1, (SCREEN,), (:compile,), ("a", "b"), screen_only)
    @test spec.spec_hash isa Digest256
    gaps = derive_stage_gaps(spec, ((name="a",), (name="b",)))
    @test length(gaps) == 2
    @test all(g -> g.reason == "missing_exact_match_or_evidence", gaps)
    @test_throws ArgumentError StageSpecV4(:p1, (), (), ("p1",), screen_only)
    @test_throws ArgumentError StageSpecV4(:p1, (SCREEN,), (), (), screen_only)
    @test_throws ArgumentError freeze_campaign((), ((name="a",),))
    @test_throws ArgumentError freeze_campaign((spec, spec), ((name="a",), (name="b",)))
    ladder = default_stage_specs(SCREEN, "a")
    @test length(ladder) == 11
    @test ladder[1].stage == :s0_compiled_materialized
    @test ladder[end].stage == :s10_validation_vvuq
    @test ladder[end].prerequisites == (:s9_independent_cross_code,)
end

@testset "admission and closure are separate" begin
    spec = StageSpecV4(:p1, (SCREEN,), (), ("p1",), screen_only)
    admitted = admit_whole_device((spec,), nothing; providers=(), scenarios=((name="p1",),),
        hard_gates=(), protocol_ready=false, resources_ready=false)
    @test !admitted.admitted
    @test !admitted.p5_ready
    @test !admitted.provider_coverage_complete
    @test !admitted.goal_acceptance
    closure = audit_whole_device(admitted, (spec,), ((name="p1",),); providers=())
    authority = classify_authority(closure)
    @test authority.disposition == :withheld
    @test !authority.terminal_classification_executed
    @test !authority.goal_acceptance
    @test any(g -> hasproperty(g, :reason), closure.unresolved_gaps)

    # Exact provider coverage is tracked independently of evidence closure.
    exact_provider = deterministic_screen_manifest(SCREEN)
    covered = admit_whole_device((spec,), test_subject();
        providers=(exact_provider,), scenarios=((name="p1",),),
        hard_gates=(true,), protocol_ready=true, resources_ready=true)
    @test covered.provider_coverage_complete
    @test covered.admitted
    @test !covered.p5_ready
end

@testset "spine reports unresolved provider coverage" begin
    spec = StageSpecV4(:p1, (SCREEN,), (), ("p1",), screen_only)
    report = run_v4_spine(candidate, registry; stage_specs=(spec,),
        scenarios=((name="p1",),), providers=(), bounds_payload=BOUNDS)
    @test report.authority.disposition == :withheld
    @test report.authority.terminal_classification_executed == false
    @test report.authority.provider_coverage_complete == false
    @test report.authority.goal_acceptance == false
    @test !isempty(report.closure.unresolved_gaps)
    @test_throws ArgumentError run_v4_spine(candidate, registry; stage_specs=(spec,),
        scenarios=((name="p1",),), providers=(), bounds_payload=(scope="wrong",),
        compiled_prefix=report.compiled)
end

@testset "typed evidence binding closes exact Cartesian scope" begin
    scenario_a = (name="a",)
    scenario_b = (name="b",)
    spec = StageSpecV4(:screen, (SCREEN,), (), ("a", "b"), screen_only)
    @test_throws ArgumentError derive_stage_gaps(spec, (scenario_a,))

    provider = deterministic_screen_manifest(SCREEN)
    subject = ExecutablePhysicalSubjectV4(
        digest256_text("prefix"), digest256_text("bundle"), digest256_text("mission"),
        R_BOUNDS, (candidate="fixture",), (scenario_a, scenario_b),
        (materialized_payload=(marker="typed",),), (SCREEN,))
    match = match_provider(SCREEN, (provider,))
    input_a = compile_solver_input(subject, scenario_a, SCREEN, provider)
    status = StatusVectorV4(required, unique_match, resolved, low_fidelity_evaluated, pass)
    evidence_a = RuntimeEvidenceV4(input_a.physical_subject_hash, input_a.scenario_hash,
        input_a.solver_input_hash, provider.manifest_hash,
        (subject_hash=subject.physical_subject_hash, scenario_hash=input_a.scenario_hash),
        status; claim_ceiling=screen_only, provider_manifest=provider)
    binding_a = StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        subject, input_a, evidence_a, match)
    input_b = compile_solver_input(subject, scenario_b, SCREEN, provider)
    evidence_b = RuntimeEvidenceV4(input_b.physical_subject_hash, input_b.scenario_hash,
        input_b.solver_input_hash, provider.manifest_hash,
        (subject_hash=subject.physical_subject_hash, scenario_hash=input_b.scenario_hash),
        status; claim_ceiling=screen_only, provider_manifest=provider)
    binding_b = StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_b,
        subject, input_b, evidence_b, match)
    @test binding_a.spec_hash == spec.spec_hash
    @test length(derive_stage_gaps(spec, (scenario_a, scenario_b); evidence=(binding_a,))) == 1
    @test derive_stage_gaps(spec, (scenario_a, scenario_b); evidence=(binding_a, binding_a))[1].reason == "ambiguous_duplicate_evidence"
    stage_admission = admit_whole_device((spec,), subject; providers=(provider,),
        scenarios=(scenario_a, scenario_b), hard_gates=(true,), protocol_ready=true,
        resources_ready=true)
    stage_closed = audit_whole_device(stage_admission, (spec,), (scenario_a, scenario_b);
        providers=(provider,), evidence_refs=(binding_a, binding_b))
    @test stage_closed.stage_decisions[1].closure_complete
    @test stage_closed.stage_decisions[1].outcome == :evidence_closed
    @test !stage_closed.p5_ready
    dependent_spec = StageSpecV4(:dependent, (SCREEN,), (:screen,), ("a", "b"), screen_only)
    dependent_admission = admit_whole_device((spec, dependent_spec), subject;
        providers=(provider,), scenarios=(scenario_a, scenario_b), hard_gates=(true,),
        protocol_ready=true, resources_ready=true,
        prior_stage_decisions=stage_closed.stage_decisions)
    @test dependent_admission.admitted
    @test_throws ArgumentError admit_frontier(dependent_spec; subject=subject,
        providers=(provider,), scenarios=(scenario_a, scenario_b), hard_gates=(true,),
        protocol_ready=true, resources_ready=true,
        prerequisite_decisions=stage_closed.stage_decisions)
    provider_b = ProviderManifestV4(SCREEN.schema, SCREEN.revision, SCREEN.kind, SCREEN,
        (bounds_hash=SCREEN.applicability_bounds, provider="other"), "other-screen",
        "v4-screen-other", digest256_text("other-code"), "other-group", screen_only;
        input_schema_hash=SCREEN.input_schema_hash)
    @test_throws ArgumentError close_frontier(spec, stage_admission.stage_decisions[1],
        (scenario_a, scenario_b); providers=(provider_b,),
        evidence_refs=(binding_a, binding_b))

    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec,
        screen_capability(digest256_text("wrong")), scenario_a, subject, input_a, evidence_a,
        match_provider(screen_capability(digest256_text("wrong")), (provider,)))
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, StageSpecV4(:other, (SCREEN,), (), ("a",), screen_only),
        SCREEN, scenario_a, subject, input_a, evidence_a, match)
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_b,
        subject, input_a, evidence_a, match)
    bad_input = SolverInputV4(input_a.physical_subject_hash, digest256_text("wrong-scenario"),
        input_a.provider_manifest_hash, input_a.input_schema_hash, input_a.payload)
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        subject, bad_input, evidence_a, match)
    bad_schema = SolverInputV4(input_a.physical_subject_hash, input_a.scenario_hash,
        input_a.provider_manifest_hash, digest256_text("wrong-schema"), input_a.payload)
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        subject, bad_schema, evidence_a, match)
    bad_evidence = RuntimeEvidenceV4(input_a.physical_subject_hash, digest256_text("wrong-evidence"),
        input_a.solver_input_hash, provider.manifest_hash,
        (subject_hash=subject.physical_subject_hash,), status;
        claim_ceiling=screen_only, provider_manifest=provider)
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        subject, input_a, bad_evidence, match)
    wrong_subject = ExecutablePhysicalSubjectV4(
        digest256_text("other-prefix"), digest256_text("test-bundle"), digest256_text("test-mission"),
        digest256_text("test-bounds"), (candidate="fixture",), (scenario_a, scenario_b),
        (materialized_payload=(marker="typed",),), (SCREEN,))
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        wrong_subject, input_a, evidence_a, match)
    wrong_provider = deterministic_screen_manifest(screen_capability(digest256_text("other-domain")))
    forged_match = ProviderMatchResultV4(unique_match, wrong_provider, SCREEN, "forged")
    @test_throws ArgumentError StageEvidenceBindingV4(:screen, spec, SCREEN, scenario_a,
        subject, input_a, evidence_a, forged_match)
    high_spec = StageSpecV4(:high, (SCREEN,), (), ("a", "b"), candidate_bound)
    @test_throws ArgumentError StageEvidenceBindingV4(:high, high_spec, SCREEN, scenario_a,
        subject, input_a, evidence_a, match)
    @test_throws ArgumentError audit_whole_device(stage_admission,
        (StageSpecV4(:replacement, (SCREEN,), (), ("a", "b"), screen_only),),
        (scenario_a, scenario_b); providers=(provider,), evidence_refs=(binding_a, binding_b))
    @test_throws ArgumentError admit_whole_device((spec,), :fake_subject;
        providers=(provider,), scenarios=(scenario_a, scenario_b), hard_gates=(true,),
        protocol_ready=true, resources_ready=true)
end

@testset "prerequisite closure is typed and P5 stays withheld" begin
    first_spec = StageSpecV4(:first, (SCREEN,), (), ("p1",), screen_only)
    second_spec = StageSpecV4(:second, (SCREEN,), (:first,), ("p1",), screen_only)
    provider = deterministic_screen_manifest(SCREEN)
    admission = admit_whole_device((first_spec, second_spec), test_subject();
        providers=(provider,), scenarios=((name="p1",),), hard_gates=(true,),
        protocol_ready=true, resources_ready=true)
    @test !admission.admitted
    @test any(d -> d.stage == :second && any(g -> getproperty(g, :reason) == "prerequisite_not_ready", d.unresolved_gaps), admission.stage_decisions)
    audited = audit_whole_device(admission, (first_spec, second_spec), ((name="p1",),);
        providers=(provider,))
    @test !audited.p5_ready
    @test !audited.goal_acceptance
    @test !audited.terminal_classification_executed

end
