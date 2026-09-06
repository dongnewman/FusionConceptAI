"""D3 candidate-bound materialization and unresolved coupling obligations."""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

function _tftb_same_candidate(candidate::CandidateStatePackageV4,
                              other::CandidateStatePackageV4, label::String)
    candidate.identity_ref == other.identity_ref &&
        candidate.canonical_hashes == other.canonical_hashes &&
        semantic_view(candidate) == semantic_view(other) ||
        throw(ArgumentError("$label candidate identity mismatch"))
    true
end

function _tftb_validate_components(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4,
        operator_registry::OperatorRegistryV1,
        d2_plan::TypedDAETimePlanV4,
        d2_report::TypedDAETimeReportV4,
        g2_plan::FieldEvaluationPlanV4,
        g2_report::FieldEvaluationReportV4,
        d2_scenario, g2_scenario; g2_provider=nothing)
    canonical_hash(compiled)
    _tftb_same_candidate(candidate, compiled.candidate, "compiled prefix")
    _runtime_scenario_hash(d2_scenario) !=
        _runtime_scenario_hash(g2_scenario) ||
        throw(ArgumentError("D2 and G2 scenarios require distinct explicit identities"))
    init_plan = d2_plan.initialization_plan
    init_report = d2_plan.initialization_report
    init_plan.compiled.prefix_hash == compiled.prefix_hash ||
        throw(ArgumentError("D2 plan uses a foreign compiled prefix"))
    _tftb_same_candidate(candidate, init_plan.compiled.candidate, "D2")
    canonical_hash(init_plan.registry) == canonical_hash(registry) ||
        throw(ArgumentError("D2 genome registry mismatch"))
    init_plan.scenario.scenario_hash == _runtime_scenario_hash(d2_scenario) ||
        throw(ArgumentError("D2 explicit scenario identity mismatch"))
    validate_typed_dae_initialization_report(init_plan, init_report)
    validate_typed_dae_time_report(d2_plan, d2_report)
    init_report.numerical_status === :pass && init_report.artifact !== nothing &&
        init_report.artifact.status === :pass ||
        throw(ArgumentError("D2 initialization is not a passing execution"))
    d2_report.numerical_status === :pass && d2_report.artifact !== nothing &&
        d2_report.artifact.status === :pass ||
        throw(ArgumentError("D2 trajectory is not a passing execution"))
    d2_report.claim_ceiling === screen_only &&
        d2_report.credible_physical_candidate_count == 0 &&
        !d2_report.p5_ready && !d2_report.unsupported_emitted ||
        throw(ArgumentError("D2 report exceeds its screen-only authority"))

    g2_plan.candidate_hash == candidate.canonical_hashes.genome_bundle_hash ||
        throw(ArgumentError("G2 candidate bundle mismatch"))
    g2_plan.prefix_hash == compiled.prefix_hash ||
        throw(ArgumentError("G2 plan uses a foreign compiled prefix"))
    _runtime_scenario_hash(g2_scenario) == g2_plan.scenario_hash ||
        throw(ArgumentError("G2 explicit scenario identity mismatch"))
    expected_plan = compile_field_evaluation_plan(candidate, compiled, registry,
        operator_registry; scenario=g2_scenario, grid=g2_plan.grid,
        program_site_ref=g2_plan.program_site_ref,
        root_position=g2_plan.root.root_position)
    semantic_view(expected_plan) == semantic_view(g2_plan) ||
        throw(ArgumentError("G2 plan is not derived from the frozen candidate"))
    expected_report = execute_field_evaluation(Dict{Digest256,Any}(), candidate,
        compiled, registry, operator_registry, expected_plan, g2_scenario;
        provider=g2_provider)
    semantic_view(expected_report) == semantic_view(g2_report) ||
        throw(ArgumentError("G2 report is not a complete deterministic replay"))
    if g2_provider === nothing
        g2_report.status === :deferred && g2_report.result === nothing &&
            g2_report.subject === nothing && g2_report.input === nothing &&
            g2_report.evidence === nothing &&
            g2_report.provider_manifest_hash === nothing &&
            g2_report.claim_ceiling === none ||
            throw(ArgumentError("missing G2 provider must remain deferred"))
    else
        g2_provider isa ProviderManifestV4 ||
            throw(ArgumentError("G2 provider must be typed"))
        g2_report.status === :evaluated_screen && g2_report.result !== nothing &&
            g2_report.subject !== nothing && g2_report.input !== nothing &&
            g2_report.evidence !== nothing ||
            throw(ArgumentError("G2 component is not an evaluated screen"))
        evidence = g2_report.evidence
        evidence.claim_ceiling === screen_only &&
            evidence.status_vector.applicability == required &&
            evidence.status_vector.match_status == unique_match &&
            evidence.status_vector.resolution == resolved &&
            evidence.status_vector.lifecycle == low_fidelity_evaluated &&
            evidence.status_vector.stage_outcome == pass ||
            throw(ArgumentError("G2 evidence is not a passing screen"))
    end
    true
end

function _tftb_materialization(candidate, compiled, d2_plan, d2_report,
                               g2_plan, g2_report, d2_scenario, g2_scenario)
    init_plan = d2_plan.initialization_plan
    init_report = d2_plan.initialization_report
    g2_result_hash = g2_report.result === nothing ? nothing :
        canonical_hash(g2_report.result)
    g2_subject_hash = g2_report.subject === nothing ? nothing :
        g2_report.subject.physical_subject_hash
    g2_input_hash = g2_report.input === nothing ? nothing :
        g2_report.input.solver_input_hash
    g2_evidence_id = g2_report.evidence === nothing ? nothing :
        g2_report.evidence.evidence_id
    fields = (candidate, compiled, candidate.mechanism_genome_ref,
        candidate.field_geometry_genome_ref,
        candidate.realization_control_genome_ref,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope, canonical_hash(candidate),
        compiled.prefix_hash, candidate.canonical_hashes.genome_bundle_hash,
        candidate.canonical_hashes.mechanism_hash,
        candidate.canonical_hashes.field_geometry_hash,
        candidate.canonical_hashes.realization_control_hash,
        canonical_hash(compiled.mission_payload),
        canonical_hash(compiled.bounds_payload),
        canonical_hash(compiled.minimality_scope),
        _runtime_scenario_hash(d2_scenario),
        _runtime_scenario_hash(g2_scenario), :distinct_unmapped,
        init_plan.plan_hash, init_report.report_hash,
        canonical_hash(init_report.artifact),
        init_report.evidence.evidence_id, d2_plan.plan_hash,
        d2_report.report_hash, canonical_hash(d2_report.artifact),
        d2_report.evidence.evidence_id, g2_plan.plan_hash,
        canonical_hash(semantic_view(g2_report)), g2_report.status,
        g2_report.unresolved_gaps, g2_result_hash, g2_subject_hash,
        g2_input_hash, g2_evidence_id,
        g2_report.provider_manifest_hash, g2_plan.support_hash,
        g2_plan.chart_hash, g2_plan.coordinate_map_hash,
        g2_plan.metric_hash, g2_plan.program_hash, g2_plan.root_ref_hash,
        g2_plan.grid.grid_hash, g2_plan.parameter_hashes,
        g2_plan.used_manifest_bindings)
    draft = FieldTimeMaterializationV4(_TFTB_TOKEN, fields...,
        digest256_text("draft"))
    FieldTimeMaterializationV4(_TFTB_TOKEN, fields...,
        canonical_hash(_tftb_materialization_identity(draft)))
end

function _tftb_required_gaps(materialization::FieldTimeMaterializationV4)
    source = materialization.materialization_hash
    (
        UnresolvedStageDeclarationV4(
            :missing_lumped_state_to_field_producer,
            (:state_gene_ref, :field_parameter_or_source_ref,
             :unit_transform, :sample_time), source, screen_only),
        UnresolvedStageDeclarationV4(
            :missing_time_dependent_field_state,
            (:field_unknown, :initial_payload, :mass_operator, :dt_root),
            source, screen_only),
        UnresolvedStageDeclarationV4(
            :missing_spatial_residual_to_field_root_binding,
            (:g1_spatial_residual, :g2_program_root), source, screen_only),
        UnresolvedStageDeclarationV4(
            :coordinate_map_metric_unexecuted,
            (:coordinate_map_execution, :metric_execution), source, screen_only),
    )
end

function _tftb_report(materialization::FieldTimeMaterializationV4)
    evidence_ids = materialization.g2_evidence_id === nothing ?
        (materialization.d2_time_evidence_id,) :
        (materialization.d2_time_evidence_id,
         materialization.g2_evidence_id)
    fields = (materialization, :terminal_deferred, false, nothing, nothing,
        evidence_ids, _tftb_required_gaps(materialization), none, 0,
        false, false)
    draft = FieldTimeBridgeReportV4(_TFTB_TOKEN, fields...,
        digest256_text("draft"))
    FieldTimeBridgeReportV4(_TFTB_TOKEN, fields...,
        canonical_hash(_tftb_report_identity(draft)))
end

function build_typed_field_time_bridge(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4,
        operator_registry::OperatorRegistryV1,
        d2_plan::TypedDAETimePlanV4,
        d2_report::TypedDAETimeReportV4,
        g2_plan::FieldEvaluationPlanV4,
        g2_report::FieldEvaluationReportV4,
        d2_scenario, g2_scenario; g2_provider=nothing)
    _tftb_validate_components(candidate, compiled, registry,
        operator_registry, d2_plan, d2_report, g2_plan, g2_report,
        d2_scenario, g2_scenario; g2_provider=g2_provider)
    materialization = _tftb_materialization(candidate, compiled, d2_plan,
        d2_report, g2_plan, g2_report, d2_scenario, g2_scenario)
    report = _tftb_report(materialization)
    validate_typed_field_time_bridge(candidate, compiled, registry,
        operator_registry, d2_plan, d2_report, g2_plan, g2_report,
        d2_scenario, g2_scenario, report; g2_provider=g2_provider)
    report
end

function validate_typed_field_time_bridge(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4,
        operator_registry::OperatorRegistryV1,
        d2_plan::TypedDAETimePlanV4,
        d2_report::TypedDAETimeReportV4,
        g2_plan::FieldEvaluationPlanV4,
        g2_report::FieldEvaluationReportV4,
        d2_scenario, g2_scenario,
        report::FieldTimeBridgeReportV4; g2_provider=nothing)
    _tftb_validate_components(candidate, compiled, registry,
        operator_registry, d2_plan, d2_report, g2_plan, g2_report,
        d2_scenario, g2_scenario; g2_provider=g2_provider)
    canonical_hash(report)
    expected_materialization = _tftb_materialization(candidate, compiled,
        d2_plan, d2_report, g2_plan, g2_report, d2_scenario, g2_scenario)
    semantic_view(expected_materialization) ==
        semantic_view(report.materialization) ||
        throw(ArgumentError("D3 materialization is not derived from components"))
    expected = _tftb_report(expected_materialization)
    semantic_view(expected) == semantic_view(report) ||
        throw(ArgumentError("D3 report or unresolved obligations were altered"))
    true
end
