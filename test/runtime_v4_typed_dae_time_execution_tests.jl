using Test
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_typed_dae_time_execution_fixture.jl"))

const DAETimePoint = FusionRuntimeV4.TypedDAETimePointV4
const DAETimePlan = FusionRuntimeV4.TypedDAETimePlanV4
const DAETimeResult = FusionRuntimeV4.TypedDAETimeResultV4
const DAETimeReceipt = FusionRuntimeV4.TypedDAETimeReceiptV4
const DAETimeReport = FusionRuntimeV4.TypedDAETimeReportV4
const execute_dae_time_once! = FusionRuntimeV4.execute_once!

function compile_time_case(; protocol=d2_time_protocol,
                           init_plan=d2_init_plan,
                           init_report=d2_init_report)
    compile_typed_dae_time_execution_plan(init_plan, init_report;
        protocol=protocol)
end

@testset "D2.2 sealed prerequisite and plan authority" begin
    @test d2_time_plan.protocol.method === :backward_euler
    @test d2_time_plan.protocol.step_count == 4
    @test d2_time_plan.protocol.max_steps == 4
    @test d2_time_plan.protocol.time_unit ==
        UnitSignature((0, 0, 1, 0, 0, 0, 0))
    @test canonical_hash(d2_time_plan.protocol) ==
        d2_time_plan.protocol.protocol_hash
    @test canonical_hash(d2_time_plan) == d2_time_plan.plan_hash
    @test d2_time_plan.source_hash == FusionRuntimeV4._tdaet_source_hash()
    @test d2_time_plan.provider.executor === nothing
    @test d2_time_plan.provider.code_hash == d2_time_plan.source_hash
    @test d2_time_plan.input.provider_manifest_hash ==
        d2_time_plan.provider.manifest_hash
    @test d2_time_plan.input.payload.initialization_plan_hash ==
        d2_init_plan.plan_hash
    @test d2_time_plan.input.payload.initialization_report_hash ==
        canonical_hash(d2_init_report)
    @test d2_time_plan.input.payload.initialization_artifact_hash ==
        canonical_hash(d2_init_report.artifact)
    @test d2_time_plan.subject.compiled_prefix_hash ==
        d2_init_plan.compiled.prefix_hash
    @test d2_time_plan.subject.genome_bundle_hash ==
        d2_init_plan.compiled.candidate.canonical_hashes.genome_bundle_hash
    @test d2_time_plan.subject.materialized_payload.executed_scope ==
        "g1_lumped_index1_dae_time_screen"
    @test "cross_temporal_coupling" in
        d2_time_plan.subject.materialized_payload.unexecuted_scopes
    @test d2_time_plan.capability.states == ("x", "z1", "z2")
    @test d2_time_plan.capability.evidence_level === screen_only

    @test_throws ArgumentError TypedDAETimeProtocolV4(method=:rk4)
    @test_throws ArgumentError TypedDAETimeProtocolV4(t_stop=0.45, step=0.1)
    @test_throws ArgumentError TypedDAETimeProtocolV4(
        t_stop=0.4, step=0.1, max_steps=3)
    @test_throws ArgumentError TypedDAETimeProtocolV4(time_unit=UnitSignature())
    @test_throws ArgumentError TypedDAETimeProtocolV4(step=0.0)
    @test_throws ArgumentError TypedDAETimeProtocolV4(max_iterations=0)
    @test_throws ArgumentError TypedDAETimeProtocolV4(rank_relative_tol=0.0)

    rejected_init_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(
        tdae_compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
        scenario=dae_scenario,
        protocol=FusionRuntimeV4.ConsistentInitializationProtocolV4(
            max_condition=0.5))
    rejected_init_report = FusionRuntimeV4.execute_once!(
        FusionRuntimeV4.TypedDAEInitializationStoreV4(),
        rejected_init_plan.input, rejected_init_plan.provider,
        rejected_init_plan)
    @test rejected_init_report.numerical_status === :numerical_fail
    @test_throws ArgumentError compile_time_case(
        init_plan=rejected_init_plan, init_report=rejected_init_report)

    alternate_scenario = FusionRuntimeV4.ConsistentInitializationScenarioV4(
        "alternate-t0", dae_scenario.initial_values)
    alternate_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(
        tdae_compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
        scenario=alternate_scenario)
    alternate_report = FusionRuntimeV4.execute_once!(
        FusionRuntimeV4.TypedDAEInitializationStoreV4(),
        alternate_plan.input, alternate_plan.provider, alternate_plan)
    @test_throws ArgumentError compile_time_case(init_report=alternate_report)

    ir = d2_init_report
    tampered_init = FusionRuntimeV4.TypedDAEInitializationReportV4(
        FusionRuntimeV4._TDAE_TOKEN, ir.artifact, ir.evidence, ir.receipt,
        ir.numerical_status, ir.unresolved_gaps, ir.executed_scope,
        ir.unexecuted_scopes, ir.claim_ceiling,
        ir.credible_physical_candidate_count, ir.p5_ready,
        ir.unsupported_emitted, nothing, digest256_text("tampered-init"))
    @test_throws ArgumentError compile_time_case(init_report=tampered_init)
end

const d2_time_store = TypedDAETimeStoreV4()
const d2_time_report = execute_dae_time_once!(d2_time_store,
    d2_time_plan.input, d2_time_plan.provider, d2_time_plan)

@testset "D2.2 graph-derived backward Euler trajectory" begin
    result = d2_time_report.artifact
    @test d2_time_report.numerical_status === :pass
    @test result !== nothing && result.status === :pass
    @test result.accepted_steps == d2_time_plan.protocol.step_count
    @test result.attempted_step == d2_time_plan.protocol.step_count
    @test length(result.trajectory) == d2_time_plan.protocol.step_count + 1
    @test result.trajectory[1].states === d2_init_report.artifact.final_values ||
        result.trajectory[1].states == d2_init_report.artifact.final_values
    @test all(isapprox(actual, expected; atol=4eps(Float64), rtol=0.0)
        for (actual, expected) in zip(
            (point.time for point in result.trajectory),
            (0.0, 0.1, 0.2, 0.3, 0.4)))
    @test all(point -> point.time_unit == d2_time_plan.protocol.time_unit,
        result.trajectory)
    @test all(point -> all(value -> value isa StateValueV4, point.states),
        result.trajectory)
    @test all(point -> Tuple(value.state_ref for value in point.states) ==
        Tuple(value.state_ref for value in result.trajectory[1].states),
        result.trajectory)
    @test all(point -> Tuple(value.unit for value in point.states) ==
        Tuple(value.unit for value in result.trajectory[1].states),
        result.trajectory)
    for (index, point) in enumerate(result.trajectory)
        values = Dict(value.state_ref.value => value.value for value in point.states)
        expected_x = (1 + d2_time_plan.protocol.step)^(-(index - 1))
        @test isapprox(values["x"], expected_x; atol=2e-9, rtol=0.0)
        @test isapprox(values["z1"], 2.0; atol=2e-9, rtol=0.0)
        @test isapprox(values["z2"], 1.0; atol=2e-9, rtol=0.0)
        @test maximum(abs, point.scaled_differential_residual) < 2e-9
        @test maximum(abs, point.scaled_algebraic_residual) < 2e-9
        @test index == 1 ? point.scaled_joint_condition === nothing :
            (isfinite(point.scaled_joint_condition) &&
             point.scaled_joint_condition <= d2_time_plan.protocol.max_condition)
        @test isfinite(point.scaled_jzz_condition) &&
            point.scaled_jzz_condition <= d2_time_plan.protocol.max_condition
        @test canonical_hash(point) == point.point_hash
    end
    @test result.max_scaled_differential_residual < 2e-9
    @test result.max_scaled_algebraic_residual < 2e-9
    @test isfinite(result.max_scaled_joint_condition) &&
        result.max_scaled_joint_condition <= d2_time_plan.protocol.max_condition
    @test canonical_hash(result) == result.result_hash
    @test validate_typed_dae_time_report(d2_time_plan, d2_time_report)
    @test replay_typed_dae_time_execution(d2_time_plan, d2_time_report)
    @test canonical_hash(d2_init_report.artifact) ==
        d2_time_plan.input.payload.initialization_artifact_hash
end

@testset "D2.2 evidence and claim firewall" begin
    @test d2_time_report.claim_ceiling === screen_only
    @test d2_time_report.credible_physical_candidate_count == 0
    @test !d2_time_report.p5_ready
    @test !d2_time_report.unsupported_emitted
    @test d2_time_report.executed_scope ==
        "g1_lumped_index1_dae_time_screen"
    @test "whole_device_vvuq" in d2_time_report.unexecuted_scopes
    @test d2_time_report.evidence.claim_ceiling === screen_only
    @test d2_time_report.evidence.provider_manifest_hash ==
        d2_time_plan.provider.manifest_hash
    @test d2_time_report.evidence.artifact_refs ==
        (canonical_hash(d2_time_report.artifact),)
    @test length(d2_time_report.evidence.metrics) == 5
    @test d2_time_report.evidence.metrics[end].unit ==
        d2_time_plan.protocol.time_unit
    @test all(metric -> metric.unit == UnitSignature(),
        d2_time_report.evidence.metrics[1:4])
    manifest = FusionRuntimeV4.typed_dae_time_execution_manifest()
    @test manifest.method === :backward_euler
    @test manifest.claim_ceiling === screen_only
    @test manifest.credible_physical_candidate_count == 0
    @test !manifest.p5_ready && !manifest.unsupported_emitted
    @test "vvuq" in manifest.excluded
end

@testset "D2.2 execute-once cache and deferred semantics" begin
    key = d2_time_plan.input.solver_input_hash
    @test d2_time_store.execution_counts[key] == 1
    @test execute_dae_time_once!(d2_time_store, d2_time_plan.input,
        d2_time_plan.provider, d2_time_plan) === d2_time_report
    @test cache_typed_dae_time_execution(d2_time_store, d2_time_plan) ===
        d2_time_report
    @test length(d2_time_store.reports) == 1
    @test length(d2_time_store.artifacts) == 1
    @test length(d2_time_store.execution_counts) == 1

    foreign_input = SolverInputV4(d2_time_plan.input.physical_subject_hash,
        digest256_text("foreign-time-scenario"),
        d2_time_plan.input.provider_manifest_hash,
        d2_time_plan.input.input_schema_hash, d2_time_plan.input.payload)
    @test_throws ArgumentError execute_dae_time_once!(TypedDAETimeStoreV4(),
        foreign_input, d2_time_plan.provider, d2_time_plan)
    provider = d2_time_plan.provider
    foreign_provider = ProviderManifestV4(provider.schema, provider.revision,
        provider.kind, provider.capability, provider.domain, provider.backend,
        "foreign-revision", provider.code_hash, provider.independence_group,
        provider.claim_ceiling; input_schema_hash=provider.input_schema_hash,
        executor=nothing)
    @test_throws ArgumentError execute_dae_time_once!(TypedDAETimeStoreV4(),
        d2_time_plan.input, foreign_provider, d2_time_plan)

    count_only = TypedDAETimeStoreV4()
    count_only.execution_counts[key] = 1
    @test_throws ArgumentError execute_dae_time_once!(count_only,
        d2_time_plan.input, d2_time_plan.provider, d2_time_plan)
    artifact_only = TypedDAETimeStoreV4()
    artifact_hash = canonical_hash(d2_time_report.artifact)
    artifact_only.artifacts[(key, artifact_hash)] = d2_time_report.artifact
    @test_throws ArgumentError execute_dae_time_once!(artifact_only,
        d2_time_plan.input, d2_time_plan.provider, d2_time_plan)
    report_without_count = deepcopy(d2_time_store)
    delete!(report_without_count.execution_counts, key)
    @test_throws ArgumentError execute_dae_time_once!(report_without_count,
        d2_time_plan.input, d2_time_plan.provider, d2_time_plan)
    @test_throws ArgumentError cache_typed_dae_time_execution(
        report_without_count, d2_time_plan)

    failing_plan = compile_time_case(protocol=TypedDAETimeProtocolV4(
        t_stop=0.1, step=0.1, max_steps=1, max_condition=0.5))
    failing_report = execute_dae_time_once!(TypedDAETimeStoreV4(),
        failing_plan.input, failing_plan.provider, failing_plan)
    extra = deepcopy(d2_time_store)
    foreign_hash = canonical_hash(failing_report.artifact)
    extra.artifacts[(key, foreign_hash)] = failing_report.artifact
    @test_throws ArgumentError execute_dae_time_once!(extra,
        d2_time_plan.input, d2_time_plan.provider, d2_time_plan)
    @test_throws ArgumentError cache_typed_dae_time_execution(extra,
        d2_time_plan)

    deferred_store = TypedDAETimeStoreV4()
    deferred = execute_dae_time_once!(deferred_store, d2_time_plan.input,
        nothing, d2_time_plan)
    @test deferred.numerical_status === :terminal_deferred
    @test deferred.artifact === nothing
    @test deferred.receipt.execution_count == 0
    @test deferred.evidence.claim_ceiling === none
    @test isempty(deferred_store.reports) && isempty(deferred_store.artifacts) &&
        isempty(deferred_store.execution_counts)
    @test validate_typed_dae_time_report(d2_time_plan, deferred)
    @test replay_typed_dae_time_execution(d2_time_plan, deferred)
    tampered_deferred = FusionRuntimeV4._tdaet_build_report(d2_time_plan,
        nothing, 0; provider=nothing,
        deferred_reason="tampered provider absence")
    @test_throws ArgumentError validate_typed_dae_time_report(
        d2_time_plan, tampered_deferred)
end

@testset "D2.2 bounded numerical failures retain partial trajectory" begin
    strict_condition_plan = compile_time_case(protocol=TypedDAETimeProtocolV4(
        t_stop=0.1, step=0.1, max_steps=1, max_condition=0.5))
    strict_condition_report = execute_dae_time_once!(TypedDAETimeStoreV4(),
        strict_condition_plan.input, strict_condition_plan.provider,
        strict_condition_plan)
    @test strict_condition_report.numerical_status === :numerical_fail
    @test strict_condition_report.artifact.status === :numerical_fail
    @test strict_condition_report.artifact.failure_code in
        (:ill_conditioned_algebraic_jacobian,
         :ill_conditioned_step_jacobian)
    @test strict_condition_report.artifact.accepted_steps == 0
    @test validate_typed_dae_time_report(strict_condition_plan,
        strict_condition_report)
    @test replay_typed_dae_time_execution(strict_condition_plan,
        strict_condition_report)

    zero_residual_singular_case = let
        rhs_program = let
            x = ASTInputV1(1, tdae_diff)
            rate = ASTConstantV1(:inverse_step, 10.0, tdae_rate)
            product = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"),
                (1, 2); registry=tdae_ops,
                input_types=(tdae_diff, tdae_rate))
            TypedASTProgramV1((x, rate, product), (3,), (1,), tdae_ops)
        end
        rhs_edge = AtomicMIMOHyperedgeV1("rhs-x-singular-step",
            (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 5),),
            rhs_program, additive; registry=tdae_ops)
        graph = TypedOperatorHypergraphV1(tdae_graph.nodes,
            (tdae_gx, rhs_edge, tdae_gz1, tdae_gz2, tdae_c1, tdae_c2);
            registry=tdae_ops)
        payload = MechanismGenomePayloadV1(tdae_payload.states,
            tdae_payload.invariants, graph, tdae_payload.parameters,
            tdae_payload.symmetries, tdae_payload.observables,
            tdae_payload.operator_holes)
        mechanism = MechanismGenomeV4(1, tdae_mech_ref, payload)
        candidate = CandidateStatePackageV4("tdae-singular-step-fixture",
            tdae_mission, mechanism, tdae_field, tdae_real, tdae_registry)
        compiled = compile_candidate(candidate, tdae_registry;
            mission_payload=tdae_mission, bounds_payload=tdae_bounds,
            comparison_scope=("typed-dae",), scenario_scope=("mixed-state",))
        rows = (FusionRuntimeV4.TimeResidualRowBindingV4(tdae_drefs[1],
                canonical_hash(tdae_gx), 1, canonical_hash(rhs_edge), 1),
            tdae_rows[2], tdae_rows[3])
        scenario = FusionRuntimeV4.ConsistentInitializationScenarioV4(
            "singular-step-t0", (
                StateValueV4(tdae_drefs[1], 0.0, tdae_unit),
                StateValueV4(tdae_arefs[1], 0.0, tdae_unit),
                StateValueV4(tdae_arefs[2], 0.0, tdae_unit)))
        init_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(
            compiled, tdae_registry; differential_refs=tdae_drefs,
            algebraic_refs=tdae_arefs, row_bindings=rows,
            scenario=scenario)
        init_report = FusionRuntimeV4.execute_once!(
            FusionRuntimeV4.TypedDAEInitializationStoreV4(),
            init_plan.input, init_plan.provider, init_plan)
        time_plan = compile_typed_dae_time_execution_plan(init_plan,
            init_report; protocol=TypedDAETimeProtocolV4(
                t_stop=0.1, step=0.1, max_steps=1))
        (plan=time_plan, init_report=init_report)
    end
    @test zero_residual_singular_case.init_report.numerical_status === :pass
    singular_step_report = execute_dae_time_once!(TypedDAETimeStoreV4(),
        zero_residual_singular_case.plan.input,
        zero_residual_singular_case.plan.provider,
        zero_residual_singular_case.plan)
    @test singular_step_report.numerical_status === :numerical_fail
    @test singular_step_report.artifact.failure_code ===
        :singular_step_jacobian
    @test singular_step_report.artifact.accepted_steps == 0
    @test length(singular_step_report.artifact.trajectory) == 1

    stagnation_plan = compile_time_case(protocol=TypedDAETimeProtocolV4(
        t_stop=0.2, step=0.1, max_steps=2, correction_abs_tol=0.5))
    stagnation_report = execute_dae_time_once!(TypedDAETimeStoreV4(),
        stagnation_plan.input, stagnation_plan.provider, stagnation_plan)
    @test stagnation_report.numerical_status === :numerical_fail
    @test stagnation_report.artifact.failure_code === :newton_stagnation
    @test length(stagnation_report.artifact.trajectory) == 1
    @test stagnation_report.artifact.trajectory[1].states ==
        d2_init_report.artifact.final_values

    one_iteration_plan = compile_time_case(protocol=TypedDAETimeProtocolV4(
        t_stop=0.1, step=0.1, max_steps=1, max_iterations=1))
    one_iteration_report = execute_dae_time_once!(TypedDAETimeStoreV4(),
        one_iteration_plan.input, one_iteration_plan.provider,
        one_iteration_plan)
    @test one_iteration_report.numerical_status === :pass

    impossible_tolerance_plan = compile_time_case(
        protocol=TypedDAETimeProtocolV4(t_stop=0.1, step=0.1, max_steps=1,
            max_iterations=1, residual_abs_tol=1e-16,
            residual_rel_tol=1e-16, correction_abs_tol=1e-18))
    impossible_tolerance_report = execute_dae_time_once!(
        TypedDAETimeStoreV4(), impossible_tolerance_plan.input,
        impossible_tolerance_plan.provider, impossible_tolerance_plan)
    @test impossible_tolerance_report.numerical_status === :numerical_fail
    @test impossible_tolerance_report.artifact.failure_code in
        (:newton_nonconvergence, :inconsistent_initial_algebraic_residual)
end

@testset "D2.2 sealed artifact chain rejects substitutions" begin
    @test_throws Exception DAETimePoint(Val(:bad))
    @test_throws Exception DAETimePlan(Val(:bad))
    @test_throws Exception DAETimeResult(Val(:bad))
    @test_throws Exception DAETimeReceipt(Val(:bad))
    @test_throws Exception DAETimeReport(Val(:bad))

    point = d2_time_report.artifact.trajectory[end]
    bad_point = DAETimePoint(FusionRuntimeV4._TDAET_TOKEN,
        point.time, point.time_unit, point.states,
        point.scaled_differential_residual,
        point.scaled_algebraic_residual, point.scaled_joint_condition,
        point.scaled_jzz_condition,
        digest256_text("bad-point"))
    @test_throws ArgumentError canonical_hash(bad_point)

    result = d2_time_report.artifact
    changed_states = collect(point.states)
    changed_states[1] = StateValueV4(changed_states[1].state_ref,
        changed_states[1].value + 0.01, changed_states[1].unit)
    point_fields = (point.time, point.time_unit, Tuple(changed_states),
        point.scaled_differential_residual,
        point.scaled_algebraic_residual, point.scaled_joint_condition,
        point.scaled_jzz_condition)
    point_draft = DAETimePoint(FusionRuntimeV4._TDAET_TOKEN,
        point_fields..., digest256_text("draft"))
    changed_point = DAETimePoint(FusionRuntimeV4._TDAET_TOKEN,
        point_fields...,
        canonical_hash(FusionRuntimeV4._tdaet_point_identity(point_draft)))
    changed_trajectory = (result.trajectory[1:end-1]..., changed_point)
    result_fields = (result.status, result.failure_code,
        result.failure_reason, changed_trajectory, result.accepted_steps,
        result.attempted_step, result.max_scaled_differential_residual,
        result.max_scaled_algebraic_residual,
        result.max_scaled_joint_condition)
    result_draft = DAETimeResult(FusionRuntimeV4._TDAET_TOKEN,
        result_fields..., digest256_text("draft"))
    changed_result = DAETimeResult(FusionRuntimeV4._TDAET_TOKEN,
        result_fields...,
        canonical_hash(FusionRuntimeV4._tdaet_result_identity(result_draft)))
    changed_report = FusionRuntimeV4._tdaet_build_report(d2_time_plan,
        changed_result, 1)
    @test_throws ArgumentError validate_typed_dae_time_report(
        d2_time_plan, changed_report)

    receipt = d2_time_report.receipt
    receipt_fields = (receipt.invocation_hash, receipt.solver_input_hash,
        receipt.provider_manifest_hash, receipt.plan_hash,
        receipt.initialization_plan_hash, receipt.initialization_report_hash,
        receipt.initialization_artifact_hash, receipt.status,
        receipt.failure_code, receipt.failure_reason, receipt.artifact_hash,
        receipt.evidence_id, 2)
    receipt_draft = DAETimeReceipt(FusionRuntimeV4._TDAET_TOKEN,
        receipt_fields..., digest256_text("draft"))
    bad_receipt = DAETimeReceipt(FusionRuntimeV4._TDAET_TOKEN,
        receipt_fields...,
        canonical_hash(FusionRuntimeV4._tdaet_receipt_identity(receipt_draft)))
    report_fields = (d2_time_report.artifact, d2_time_report.evidence,
        bad_receipt, d2_time_report.numerical_status,
        d2_time_report.unresolved_gaps, d2_time_report.executed_scope,
        d2_time_report.unexecuted_scopes, screen_only, 0, false, false)
    report_draft = DAETimeReport(FusionRuntimeV4._TDAET_TOKEN,
        report_fields..., digest256_text("draft"))
    bad_count_report = DAETimeReport(FusionRuntimeV4._TDAET_TOKEN,
        report_fields...,
        canonical_hash(FusionRuntimeV4._tdaet_report_identity(report_draft)))
    @test_throws ArgumentError validate_typed_dae_time_report(
        d2_time_plan, bad_count_report)
end
