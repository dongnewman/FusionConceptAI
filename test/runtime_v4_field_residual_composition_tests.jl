using Test
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_field_residual_composition_fixture.jl"))

function _d41_resign_evidence(evidence::RuntimeEvidenceV4, binding_provenance;
        provider=nothing, metrics=evidence.metrics,
        artifact_refs=evidence.artifact_refs,
        uncertainty_or_null=evidence.uncertainty_or_null)
    RuntimeEvidenceV4(evidence.physical_subject_hash, evidence.scenario_hash,
        evidence.solver_input_hash, evidence.provider_manifest_hash,
        binding_provenance, evidence.status_vector, metrics;
        claim_ceiling=evidence.claim_ceiling,
        provider_manifest=provider, backend_revision=evidence.backend_revision,
        numerical_configuration_hash=evidence.numerical_configuration_hash,
        artifact_refs=artifact_refs,
        uncertainty_or_null=uncertainty_or_null)
end

function _d41_resign_report(report::FieldResidualPipelineReportV4,
        evidence::RuntimeEvidenceV4)
    body = (status=report.status,
        artifact_hash=report.artifact === nothing ? nothing : report.artifact.result_hash,
        receipt=report.receipt, evidence=evidence,
        claim_ceiling=report.claim_ceiling,
        credible_physical_candidate_count=report.credible_physical_candidate_count,
        p5_ready=report.p5_ready, unsupported_emitted=report.unsupported_emitted)
    FieldResidualPipelineReportV4(FusionRuntimeV4._FRP_TOKEN,
        report.status, report.artifact, report.receipt, evidence,
        report.claim_ceiling, report.credible_physical_candidate_count,
        report.p5_ready, report.unsupported_emitted, canonical_hash(body))
end

function _d41_compile_with_g2(c, u_report, f_report)
    compile_field_residual_plan(composition_candidate, composition_compiled,
        tdae_registry, default_operator_registry(), u_report, f_report;
        scenario=d3_g2_scenario, grid=c.grid,
        constraint_edge_hash=canonical_hash(composition_constraint),
        unknown_state_ref=StateGeneRefV1("u"),
        source_state_ref=StateGeneRefV1("f"),
        residual_state_ref=StateGeneRefV1("r"),
        affine_factors=(1, 1, 1), affine_offsets=(0, 0, 0),
        protocol=StructuredGridProtocolV4())
end

function _d41_reordered_g2_report(report::FieldEvaluationReportV4)
    result = FusionRuntimeV4._field_evaluation_result(
        reverse(report.result.coordinates), reverse(report.result.values),
        report.result.output_type)
    provider = field_evaluation_provider(report.plan)
    evidence = _d41_resign_evidence(report.evidence,
        report.evidence.binding_provenance; provider=provider,
        artifact_refs=(result.result_hash,))
    FieldEvaluationReportV4(report.plan, report.status, result, report.subject,
        report.input, evidence, report.provider_manifest_hash,
        report.unresolved_gaps, report.claim_ceiling)
end

function _d41_plan_with_allowed_opcodes(plan::FieldEvaluationPlanV4,
        allowed_opcodes)
    body = FusionRuntimeV4._field_plan_body(plan.candidate_hash,
        plan.prefix_hash, plan.field_geometry_hash, plan.support_ref,
        plan.support_hash, plan.chart_ref, plan.chart_hash,
        plan.coordinate_map_hash, plan.metric_hash, plan.program_site_ref,
        plan.program_hash, plan.root_ref_hash, plan.parameter_hashes,
        plan.program, plan.root, plan.parameters, plan.chart_bounds, plan.grid,
        Tuple(allowed_opcodes), plan.used_manifest_bindings,
        plan.scenario_hash, plan.code_hash, plan.status, plan.unresolved_gaps)
    FieldEvaluationPlanV4(FusionRuntimeV4._FIELD_PLAN_TOKEN,
        body.candidate_hash, body.prefix_hash, body.field_geometry_hash,
        body.support_ref, body.support_hash, body.chart_ref, body.chart_hash,
        body.coordinate_map_hash, body.metric_hash, body.program_site_ref,
        body.program_hash, body.root_ref_hash, body.parameter_hashes,
        body.program, body.root, body.parameters, body.chart_bounds, body.grid,
        body.allowed_opcodes, body.used_manifest_bindings, body.scenario_hash,
        body.code_hash, body.status, body.unresolved_gaps, canonical_hash(body))
end

@testset "D4.1 field residual composition" begin
    @test field_residual_candidate === composition_candidate
    @test field_residual_compiled === composition_compiled
    @test Tuple(c.n for c in field_residual_cases) == (5, 9, 17)
    @test Tuple(length(c.report.artifact.solution) for c in field_residual_cases) ==
        (125, 729, 4913)
    @test all(c -> c.report.status === :pass &&
        c.report.artifact.status === :converged, field_residual_cases)
    @test all(c -> c.plan.mission.evidence_class === :manufactured_control &&
        c.plan.source_scale_bindings[1].scale == -2.0, field_residual_cases)
    @test all(c -> c.plan.u_plan_hash == c.reports[1].plan.plan_hash &&
        c.plan.f_plan_hash == c.reports[2].plan.plan_hash &&
        c.plan.u_result_hash == c.reports[1].result.result_hash &&
        c.plan.f_result_hash == c.reports[2].result.result_hash &&
        c.plan.u_evidence_id == c.reports[1].evidence.evidence_id &&
        c.plan.f_evidence_id == c.reports[2].evidence.evidence_id, field_residual_cases)
    @test all(c -> c.plan.source_content_hash == c.source.content_hash &&
        c.plan.boundary_content_hash == c.boundary.content_hash, field_residual_cases)
    @test all(c -> c.report.claim_ceiling === screen_only &&
        c.report.credible_physical_candidate_count == 0 &&
        !c.report.p5_ready && !c.report.unsupported_emitted,
        field_residual_cases)
    @test validate_manufactured_field_convergence_receipt(field_residual_convergence)
    @test field_residual_convergence.orders isa Tuple
    @test all(o -> 1.8 <= o <= 2.2, field_residual_convergence.orders)
    @test all(c -> validate_field_residual_report(c.plan, c.report), field_residual_cases)
    @test all(c -> replay_field_residual_pipeline(c.plan, c.report), field_residual_cases)
    @test all(c -> c.provider.backend == "native-sparse-lu" &&
        c.plan.protocol.solver === :julia_sparse_lu &&
        c.report.artifact.factorization_status === :success &&
        c.report.evidence.artifact_refs ==
            (c.plan.u_result_hash, c.plan.f_result_hash, c.report.artifact.result_hash),
        field_residual_cases)
    @test field_residual_plans[1].form.unknown_type.units == UnitSignature()
    @test field_residual_plans[1].form.source_types[1].units == UnitSignature()
    @test field_residual_plans[1].form.residual_type.units ==
        UnitSignature((0, -2, 0, 0, 0, 0, 0))
    @test field_parameter_value(composition_zero_offset) == 0.0
    @test all(c -> all(zip(c.reports[1].result.coordinates,
            c.reports[1].result.values, c.reports[2].result.values)) do values
        coordinate, u_value, f_value = values
        rho2 = sum(value * value for value in coordinate)
        u_value == rho2 * rho2 && f_value == 10.0 * rho2
    end, field_residual_cases)
end


@testset "D4.1 re-signed G2 authority tampering fails closed" begin
    c = field_residual_cases[1]
    u_report = c.reports[1]
    u_provider = field_evaluation_provider(u_report.plan)
    forged_binding = merge(u_report.evidence.binding_provenance,
        (code_hash=digest256_text("foreign-g2-code"),))
    forged_evidence = _d41_resign_evidence(u_report.evidence,
        forged_binding; provider=u_provider)
    forged_report = FieldEvaluationReportV4(u_report.plan, u_report.status,
        u_report.result, u_report.subject, u_report.input, forged_evidence,
        u_report.provider_manifest_hash, u_report.unresolved_gaps,
        u_report.claim_ceiling)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(forged_evidence)
    @test_throws ArgumentError _d41_compile_with_g2(c, forged_report, c.reports[2])

    foreign_provider = ProviderManifestV4(u_provider.schema, u_provider.revision,
        u_provider.kind, u_provider.capability, u_provider.domain,
        u_provider.backend, u_provider.backend_revision,
        digest256_text("foreign-g2-provider-code"),
        u_provider.independence_group, u_provider.claim_ceiling;
        input_schema_hash=u_provider.input_schema_hash,
        executor=u_provider.executor)
    capability = FusionRuntimeV4._field_capability(u_report.plan)
    foreign_input = compile_solver_input(u_report.subject, d3_g2_scenario,
        capability, foreign_provider)
    foreign_binding = (physical_subject_hash=foreign_input.physical_subject_hash,
        scenario_hash=foreign_input.scenario_hash,
        solver_input_hash=foreign_input.solver_input_hash,
        provider_manifest_hash=foreign_provider.manifest_hash,
        backend_revision=foreign_provider.backend_revision,
        code_hash=foreign_provider.code_hash)
    foreign_evidence = RuntimeEvidenceV4(foreign_input.physical_subject_hash,
        foreign_input.scenario_hash, foreign_input.solver_input_hash,
        foreign_provider.manifest_hash, foreign_binding,
        u_report.evidence.status_vector, u_report.evidence.metrics;
        claim_ceiling=screen_only, provider_manifest=foreign_provider,
        backend_revision=foreign_provider.backend_revision,
        numerical_configuration_hash=
            canonical_hash(foreign_input.payload.numerical_configuration),
        artifact_refs=(u_report.result.result_hash,),
        uncertainty_or_null=nothing)
    foreign_report = FieldEvaluationReportV4(u_report.plan, u_report.status,
        u_report.result, u_report.subject, foreign_input, foreign_evidence,
        foreign_provider.manifest_hash, u_report.unresolved_gaps,
        u_report.claim_ceiling)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(foreign_evidence)
    @test_throws ArgumentError _d41_compile_with_g2(c, foreign_report, c.reports[2])

    reordered_u = _d41_reordered_g2_report(c.reports[1])
    reordered_f = _d41_reordered_g2_report(c.reports[2])
    @test all(zip(reordered_u.result.coordinates, reordered_u.result.values,
            reordered_f.result.values)) do values
        coordinate, u_value, f_value = values
        rho2 = sum(value * value for value in coordinate)
        u_value == rho2 * rho2 && f_value == 10.0 * rho2
    end
    @test_throws ArgumentError _d41_compile_with_g2(c, reordered_u, reordered_f)

    altered_plan = _d41_plan_with_allowed_opcodes(u_report.plan,
        (u_report.plan.allowed_opcodes..., "FOREIGN_OPCODE"))
    altered_plan_report = FieldEvaluationReportV4(altered_plan,
        u_report.status, u_report.result, u_report.subject, u_report.input,
        u_report.evidence, u_report.provider_manifest_hash,
        u_report.unresolved_gaps, u_report.claim_ceiling)
    altered_plan_error = try
        _d41_compile_with_g2(c, altered_plan_report, c.reports[2])
        nothing
    catch error
        error
    end
    @test altered_plan_error isa ArgumentError
    @test occursin("not derived from the frozen candidate",
        sprint(showerror, altered_plan_error))
end

@testset "D4.1 re-signed provenance tampering fails closed" begin
    c = field_residual_cases[1]
    forged_binding = merge(c.report.evidence.binding_provenance,
        (candidate_hash=digest256_text("foreign-candidate"),))
    forged_evidence = _d41_resign_evidence(c.report.evidence,
        forged_binding; provider=c.provider)
    forged_report = _d41_resign_report(c.report, forged_evidence)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(forged_evidence)
    @test forged_report.report_hash == canonical_hash(semantic_view(forged_report))
    @test !validate_field_residual_report(c.plan, forged_report)
    @test !replay_field_residual_pipeline(c.plan, forged_report)

    metric_evidence = _d41_resign_evidence(c.report.evidence,
        c.report.evidence.binding_provenance; provider=c.provider,
        metrics=(MetricWithUnit(:forged_metric, 1.0),))
    metric_report = _d41_resign_report(c.report, metric_evidence)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(metric_evidence)
    @test !validate_field_residual_report(c.plan, metric_report)

    deferred = execute_once!(FieldResidualPipelineStoreV4(), c.input, nothing, c.plan)
    forged_deferred_binding = merge(deferred.evidence.binding_provenance,
        (reason="forged_missing_provider",))
    forged_deferred_evidence = _d41_resign_evidence(deferred.evidence,
        forged_deferred_binding)
    forged_deferred = _d41_resign_report(deferred, forged_deferred_evidence)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(forged_deferred_evidence)
    @test forged_deferred.report_hash == canonical_hash(semantic_view(forged_deferred))
    @test !validate_field_residual_report(c.plan, forged_deferred)

    artifact_deferred_evidence = _d41_resign_evidence(deferred.evidence,
        deferred.evidence.binding_provenance;
        artifact_refs=(digest256_text("forged-deferred-artifact"),))
    artifact_deferred = _d41_resign_report(deferred, artifact_deferred_evidence)
    @test FusionRuntimeV4._frp_runtime_evidence_integrity(artifact_deferred_evidence)
    @test !validate_field_residual_report(c.plan, artifact_deferred)
end

@testset "D4.1 execute-once and deferred authority" begin
    c = field_residual_cases[2]
    count0 = c.store.execution_counts[c.input.solver_input_hash]
    @test execute_once!(c.store, c.input, c.provider, c.plan) === c.report
    @test c.store.execution_counts[c.input.solver_input_hash] == count0
    deferred_store = FieldResidualPipelineStoreV4()
    deferred = execute_once!(deferred_store, c.input, nothing, c.plan)
    @test deferred.status === :terminal_deferred
    @test deferred.artifact === nothing
    @test validate_field_residual_report(c.plan, deferred)
    @test isempty(deferred_store.reports) && isempty(deferred_store.artifacts) &&
        isempty(deferred_store.execution_counts)
end

@testset "D4.1 artifact identity and cache rejection" begin
    c = field_residual_cases[1]
    source_values = collect(c.source.values)
    source_values[div(length(source_values), 2)] += 0.25
    forged_source = FieldResidualPayloadV4(StateGeneRefV1("f"), c.grid,
        Tuple(source_values), composition_static3d)
    forged_snapshot = (state_ref=forged_source.state_ref,
        values=forged_source.values, physical_type=forged_source.physical_type,
        content_hash=forged_source.content_hash)
    forged_input = SolverInputV4(c.plan.subject_hash, c.plan.mission.scenario_hash,
        c.provider.manifest_hash, c.provider.input_schema_hash,
        (materialized_payload=(plan=c.plan, plan_hash=c.plan.plan_hash,
            sources=(forged_snapshot,), boundary=c.input.payload.materialized_payload.boundary),
         numerical_configuration=(protocol_hash=c.plan.protocol.protocol_hash,)))
    @test_throws ArgumentError execute_once!(FieldResidualPipelineStoreV4(),
        forged_input, c.provider, c.plan)

    poisoned = FieldResidualPipelineStoreV4()
    poisoned.reports[c.input.solver_input_hash] = field_residual_cases[2].report
    poisoned.execution_counts[c.input.solver_input_hash] = 1
    @test_throws ArgumentError execute_once!(poisoned, c.input, c.provider, c.plan)
    @test_throws ArgumentError FieldResidualPipelineReportV4()
end

@testset "D4.1 exact contracts and failure taxonomy" begin
    c = field_residual_cases[1]
    wrong_root_report = c.reports[1]
    @test_throws ArgumentError FusionRuntimeV4._frp_validate_manufactured_g2(
        c.reports[1], wrong_root_report,
        FusionRuntimeV4._field_collect(composition_candidate.field_geometry_genome_ref.fields))
    @test FusionRuntimeV4._frp_classify_status(:numerical_fail, :success) ==
        (:numerical_fail, numerical_fail)
    @test FusionRuntimeV4._frp_classify_status(:numerical_fail, :failed) ==
        (:unknown, unknown)
    shifted = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time),
        UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    shifted_laplace = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time),
        UnitSignature((1, -2, 0, 0, 0, 0, 0)))
    shifted_nodes = (
        ASTInputV1(1, shifted), ASTInputV1(2, shifted),
        ASTApplyV1(OperatorRefV1("LAPLACE", "v1"), (1,);
            registry=tdae_ops, input_types=(shifted,)),
        ASTConstantV1(:kappa_m2, 2.0, composition_laplace3d),
        ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (4, 2);
            registry=tdae_ops, input_types=(composition_laplace3d, shifted)),
        ASTApplyV1(OperatorRefV1("SUB", "v1"), (3, 5);
            registry=tdae_ops, input_types=(shifted_laplace, shifted_laplace)))
    shifted_program = TypedASTProgramV1(shifted_nodes, (6,), (1, 2); registry=tdae_ops)
    shifted_edge = AtomicMIMOHyperedgeV1("static-field-residual",
        composition_constraint.input_bindings, composition_constraint.output_bindings,
        shifted_program, constraint; registry=tdae_ops)
    @test_throws ArgumentError FusionRuntimeV4._frp_exact_static_field_constraint(
        shifted_edge, StateGeneRefV1("u"), StateGeneRefV1("f"),
        StateGeneRefV1("r"), composition_candidate)
end

@testset "D4.1 cross-authority rejection" begin
    c = field_residual_cases[1]
    p = c.provider
    foreign_provider = ProviderManifestV4(p.schema, p.revision, p.kind,
        p.capability, p.domain, p.backend, p.backend_revision,
        digest256_text("foreign-d4-code"), p.independence_group,
        p.claim_ceiling; input_schema_hash=p.input_schema_hash,
        executor=p.executor)
    @test_throws ArgumentError execute_once!(FieldResidualPipelineStoreV4(),
        c.input, foreign_provider, c.plan)
    @test_throws ArgumentError compile_field_residual_plan(
        composition_candidate, composition_compiled, tdae_registry,
        default_operator_registry(), c.reports[1], c.reports[2];
        scenario=d3_g2_scenario,
        grid=FieldGridSpecV4(((0.0, 1.0), (0.0, 1.0), (0.0, 1.0))),
        constraint_edge_hash=canonical_hash(composition_constraint),
        unknown_state_ref=StateGeneRefV1("u"),
        source_state_ref=StateGeneRefV1("f"),
        residual_state_ref=StateGeneRefV1("r"),
        affine_factors=(1,1,1), affine_offsets=(0,0,0),
        protocol=StructuredGridProtocolV4())
end
