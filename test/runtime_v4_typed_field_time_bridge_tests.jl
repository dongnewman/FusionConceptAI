using Test

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_typed_field_time_bridge_fixture.jl"))

function _d3_rebuilt_report(base::FieldTimeBridgeReportV4;
        status=base.status,
        field_time_executable=base.field_time_executable,
        field_time_artifact=base.field_time_artifact,
        merged_metrics=base.merged_metrics,
        component_evidence_ids=base.component_evidence_ids,
        unresolved_gaps=base.unresolved_gaps,
        claim_ceiling=base.claim_ceiling,
        credible_physical_candidate_count=base.credible_physical_candidate_count,
        p5_ready=base.p5_ready,
        unsupported_emitted=base.unsupported_emitted)
    fields = (base.materialization, status, field_time_executable,
        field_time_artifact, merged_metrics, component_evidence_ids,
        unresolved_gaps, claim_ceiling, credible_physical_candidate_count,
        p5_ready, unsupported_emitted)
    draft = FieldTimeBridgeReportV4(FusionRuntimeV4._TFTB_TOKEN,
        fields..., digest256_text("draft"))
    FieldTimeBridgeReportV4(FusionRuntimeV4._TFTB_TOKEN, fields...,
        canonical_hash(FusionRuntimeV4._tftb_report_identity(draft)))
end

function _d3_validate(report=d3_report; candidate=d3_candidate,
        compiled=d3_compiled, d2_plan=d3_time_plan,
        d2_report=d3_time_report, g2_plan=d3_g2_plan,
        g2_report=d3_g2_report, d2_scenario=d3_d2_scenario,
        g2_scenario=d3_g2_scenario, g2_provider=d3_g2_provider)
    validate_typed_field_time_bridge(candidate, compiled, tdae_registry,
        d3_operator_registry, d2_plan, d2_report, g2_plan, g2_report,
        d2_scenario, g2_scenario, report; g2_provider=g2_provider)
end

@testset "D3 combined candidate executes both independent components" begin
    @test d3_time_plan.initialization_plan.compiled.prefix_hash ==
        d3_compiled.prefix_hash
    @test d3_g2_plan.prefix_hash == d3_compiled.prefix_hash
    @test d3_g2_plan.candidate_hash ==
        d3_candidate.canonical_hashes.genome_bundle_hash
    @test d3_init_report.numerical_status === :pass
    @test d3_time_report.numerical_status === :pass
    @test d3_time_report.artifact.accepted_steps == 4
    @test d3_g2_report.status === :evaluated_screen
    @test length(d3_g2_report.result.values) == 27
    @test d3_g2_report.result.min_value == -2.0
    @test d3_g2_report.result.max_value == 4.0
    @test d3_time_report.evidence.evidence_id !=
        d3_g2_report.evidence.evidence_id
    @test _d3_validate()
end

@testset "D3 materialization and promotion firewall" begin
    materialization = d3_report.materialization
    @test canonical_hash(materialization) == materialization.materialization_hash
    @test materialization.candidate_hash == canonical_hash(d3_candidate)
    @test materialization.prefix_hash == d3_compiled.prefix_hash
    @test materialization.mechanism_hash ==
        d3_candidate.canonical_hashes.mechanism_hash
    @test materialization.field_geometry_hash ==
        d3_candidate.canonical_hashes.field_geometry_hash
    @test materialization.realization_control_hash ==
        d3_candidate.canonical_hashes.realization_control_hash
    @test materialization.scenario_relationship === :distinct_unmapped
    @test materialization.d2_scenario_hash != materialization.g2_scenario_hash
    @test materialization.d2_time_evidence_id ==
        d3_time_report.evidence.evidence_id
    @test materialization.g2_evidence_id == d3_g2_report.evidence.evidence_id
    @test materialization.g2_report_hash ==
        canonical_hash(semantic_view(d3_g2_report))
    @test materialization.g2_component_status === :evaluated_screen
    @test materialization.g2_unresolved_gaps == d3_g2_report.unresolved_gaps
    @test d3_report.component_evidence_ids ==
        (d3_time_report.evidence.evidence_id,
         d3_g2_report.evidence.evidence_id)
    @test d3_report.status === :terminal_deferred
    @test !d3_report.field_time_executable
    @test d3_report.field_time_artifact === nothing
    @test d3_report.merged_metrics === nothing
    @test d3_report.claim_ceiling === none
    @test d3_report.credible_physical_candidate_count == 0
    @test !d3_report.p5_ready
    @test !d3_report.unsupported_emitted
    @test canonical_hash(d3_report) == d3_report.report_hash
end

@testset "D3 exact typed unresolved obligations" begin
    gaps = d3_report.unresolved_gaps
    @test length(gaps) == 4
    @test all(g -> g isa UnresolvedStageDeclarationV4, gaps)
    @test Tuple(g.code for g in gaps) == (
        :missing_lumped_state_to_field_producer,
        :missing_time_dependent_field_state,
        :missing_spatial_residual_to_field_root_binding,
        :coordinate_map_metric_unexecuted)
    @test gaps[1].missing_axes ==
        (:state_gene_ref, :field_parameter_or_source_ref,
         :unit_transform, :sample_time)
    @test gaps[2].missing_axes ==
        (:field_unknown, :initial_payload, :mass_operator, :dt_root)
    @test gaps[3].missing_axes ==
        (:g1_spatial_residual, :g2_program_root)
    @test gaps[4].missing_axes ==
        (:coordinate_map_execution, :metric_execution)
    @test all(g -> g.source_hash == d3_report.materialization.materialization_hash,
        gaps)
end

@testset "D3 missing provider stays deferred, never unsupported" begin
    deferred_g2 = FusionRuntimeV4.execute_field_evaluation(
        Dict{Digest256,Any}(), d3_candidate, d3_compiled, tdae_registry,
        d3_operator_registry, d3_g2_plan, d3_g2_scenario; provider=nothing)
    deferred_bridge = build_typed_field_time_bridge(d3_candidate,
        d3_compiled, tdae_registry, d3_operator_registry, d3_time_plan,
        d3_time_report, d3_g2_plan, deferred_g2, d3_d2_scenario,
        d3_g2_scenario; g2_provider=nothing)
    @test deferred_g2.status === :deferred
    @test deferred_g2.evidence === nothing
    @test deferred_bridge.status === :terminal_deferred
    @test deferred_bridge.materialization.g2_evidence_id === nothing
    @test deferred_bridge.materialization.g2_component_status === :deferred
    @test "missing_provider:g2_typed_field_evaluation" in
        deferred_bridge.materialization.g2_unresolved_gaps
    @test deferred_bridge.materialization.g2_report_hash ==
        canonical_hash(semantic_view(deferred_g2))
    @test deferred_bridge.component_evidence_ids ==
        (d3_time_report.evidence.evidence_id,)
    @test !deferred_bridge.field_time_executable
    @test !deferred_bridge.unsupported_emitted
    @test _d3_validate(deferred_bridge; g2_report=deferred_g2,
        g2_provider=nothing)
end

@testset "D3 rejects foreign and nonpassing component authority" begin
    foreign_candidate = CandidateStatePackageV4("foreign-d3-display-id",
        d3_candidate.mission_contract_ref,
        d3_candidate.mechanism_genome_ref,
        d3_candidate.field_geometry_genome_ref,
        d3_candidate.realization_control_genome_ref, tdae_registry)
    @test_throws ArgumentError _d3_validate(; candidate=foreign_candidate)

    foreign_compiled = compile_candidate(d3_candidate, tdae_registry;
        mission_payload=tdae_mission, bounds_payload=tdae_bounds,
        comparison_scope=("foreign-scope",),
        scenario_scope=("mixed-state", "g2-field-scenario"))
    @test_throws ArgumentError _d3_validate(; compiled=foreign_compiled)

    deferred_d2 = FusionRuntimeV4.execute_once!(
        FusionRuntimeV4.TypedDAETimeStoreV4(), d3_time_plan.input,
        nothing, d3_time_plan)
    @test deferred_d2.numerical_status === :terminal_deferred
    @test_throws ArgumentError _d3_validate(; d2_report=deferred_d2)

    forged_g2 = FieldEvaluationReportV4(d3_g2_plan, :deferred,
        nothing, nothing, nothing, nothing, nothing,
        d3_g2_plan.unresolved_gaps, none)
    @test_throws ArgumentError _d3_validate(; g2_report=forged_g2)

    altered_deferred = FieldEvaluationReportV4(d3_g2_plan, :deferred,
        nothing, nothing, nothing, nothing, nothing,
        (d3_g2_plan.unresolved_gaps..., "altered_missing_provider_reason"),
        none)
    @test_throws ArgumentError _d3_validate(;
        g2_report=altered_deferred, g2_provider=nothing)

    @test_throws ArgumentError _d3_validate(;
        g2_scenario=d3_d2_scenario)
end

@testset "D3 G2 replay rejects root, grid, scenario, and provider mismatch" begin
    root2_plan = FusionRuntimeV4.compile_field_evaluation_plan(
        d3_candidate, d3_compiled, tdae_registry, d3_operator_registry;
        scenario=d3_g2_scenario, grid=d3_g2_grid,
        program_site_ref=d3_g2_site, root_position=2)
    @test_throws ArgumentError _d3_validate(; g2_plan=root2_plan)

    other_grid = ((-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0))
    grid_plan = FusionRuntimeV4.compile_field_evaluation_plan(
        d3_candidate, d3_compiled, tdae_registry, d3_operator_registry;
        scenario=d3_g2_scenario, grid=other_grid,
        program_site_ref=d3_g2_site, root_position=1)
    @test_throws ArgumentError _d3_validate(; g2_plan=grid_plan)

    @test_throws ArgumentError _d3_validate(;
        g2_scenario=(name="mixed-state",))

    provider = d3_g2_provider
    foreign_provider = ProviderManifestV4(provider.schema, provider.revision,
        provider.kind, provider.capability, provider.domain, provider.backend,
        provider.backend_revision, digest256_text("foreign-d3-code"),
        provider.independence_group, provider.claim_ceiling;
        input_schema_hash=provider.input_schema_hash,
        executor=provider.executor)
    @test_throws ArgumentError _d3_validate(; g2_provider=foreign_provider)
end

@testset "D3 report tampering fails closed" begin
    fewer_gaps = _d3_rebuilt_report(d3_report;
        unresolved_gaps=d3_report.unresolved_gaps[1:3])
    @test_throws ArgumentError _d3_validate(fewer_gaps)

    merged_evidence = _d3_rebuilt_report(d3_report;
        component_evidence_ids=(d3_init_report.evidence.evidence_id,
            d3_time_report.evidence.evidence_id,
            d3_g2_report.evidence.evidence_id))
    @test_throws ArgumentError _d3_validate(merged_evidence)

    executable = _d3_rebuilt_report(d3_report;
        field_time_executable=true)
    @test_throws ArgumentError canonical_hash(executable)

    promoted = _d3_rebuilt_report(d3_report;
        claim_ceiling=screen_only, credible_physical_candidate_count=1,
        p5_ready=true)
    @test_throws ArgumentError canonical_hash(promoted)

    unsupported = _d3_rebuilt_report(d3_report;
        unsupported_emitted=true)
    @test_throws ArgumentError canonical_hash(unsupported)

    @test_throws ArgumentError FieldTimeBridgeReportV4(Val(:public),
        d3_report.materialization, :terminal_deferred, false, nothing,
        nothing, (), (), none, 0, false, false,
        digest256_text("forged"))
end
