using Test
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedDAEInitializationContracts.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedDAEInitialization.jl"))
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_typed_dae_initialization_fixture.jl"))

const compile_typed_dae_initialization_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan
const TypedDAEInitializationStoreV4 = FusionRuntimeV4.TypedDAEInitializationStoreV4
const TypedDAEInitializationPlanV4 = FusionRuntimeV4.TypedDAEInitializationPlanV4
const TypedDAEInitializationResultV4 = FusionRuntimeV4.TypedDAEInitializationResultV4
const TypedDAEInitializationReceiptV4 = FusionRuntimeV4.TypedDAEInitializationReceiptV4
const TypedDAEInitializationReportV4 = FusionRuntimeV4.TypedDAEInitializationReportV4
const ConsistentInitializationProtocolV4 = FusionRuntimeV4.ConsistentInitializationProtocolV4
const execute_once! = FusionRuntimeV4.execute_once!
const cache_typed_dae_initialization = FusionRuntimeV4.cache_typed_dae_initialization
const replay_typed_dae_initialization = FusionRuntimeV4.replay_typed_dae_initialization
const validate_typed_dae_initialization_report = FusionRuntimeV4.validate_typed_dae_initialization_report
const typed_dae_initialization_manifest = FusionRuntimeV4.typed_dae_initialization_manifest

const dae_plan = compile_typed_dae_initialization_plan(tdae_compiled, tdae_registry;
    differential_refs=tdae_drefs, algebraic_refs=tdae_arefs,
    row_bindings=tdae_rows, scenario=dae_scenario)
const dae_store = TypedDAEInitializationStoreV4()
const dae_report = execute_once!(dae_store, dae_plan.input, dae_plan.provider, dae_plan)

function compile_tdae_case(; d=tdae_drefs, a=tdae_arefs, rows=tdae_rows,
                           scenario=dae_scenario,
                           protocol=ConsistentInitializationProtocolV4())
    compile_typed_dae_initialization_plan(tdae_compiled, tdae_registry;
        differential_refs=d, algebraic_refs=a, row_bindings=rows,
        scenario=scenario, protocol=protocol)
end

@testset "D2.1 real mixed graph authority" begin
    states = tdae_compiled.candidate.mechanism_genome_ref.payload.states
    @test length(states) == 3
    @test count(s -> s.physical_type.temporal_type.kind === differential_time, states) == 1
    @test count(s -> s.physical_type.temporal_type.kind === algebraic_time, states) == 2
    @test length(tdae_compiled.mechanism_graph.hyperedges) == 6
    @test Tuple(s.state_ref for s in sort(collect(states), by=s -> s.state_ref.value)) ==
        (tdae_drefs[1], tdae_arefs[1], tdae_arefs[2])
    @test Tuple(r.state_ref for r in dae_plan.row_bindings if r isa DAEAlgebraicRowBindingV4) == tdae_arefs
    @test count(r -> r isa TimeResidualRowBindingV4, dae_plan.row_bindings) == 1
    @test all(r -> r.operator_manifest_bindings ==
        FusionRuntimeV4._tdae_edge(tdae_compiled.mechanism_graph,
            r.residual_edge_hash).program.used_manifest_bindings,
        (r for r in dae_plan.row_bindings if r isa DAEAlgebraicRowBindingV4))
    @test canonical_hash(dae_plan) == dae_plan.plan_hash
    @test dae_plan.source_hash == FusionRuntimeV4._tdae_source_hash()
    @test dae_plan.subject.materialized_payload.executed_scope ==
        "g1_lumped_mixed_state_initialization"
    @test dae_plan.subject.materialized_payload.unexecuted_scopes ==
        ("g2_field_geometry", "g3_realization_control", "dae_time_trajectory")
end

@testset "D2.1 capability and positive initialization" begin
    @test dae_plan.capability.kind === :typed_dae_consistent_initialization_screen
    @test dae_plan.capability.operator == "mixed_constant_mass_dae_consistent_initialization"
    @test dae_plan.capability.source_space == "mixed_lumped_state_guess_0d"
    @test dae_plan.capability.target_space == "consistent_state_and_initial_derivative_0d"
    @test dae_plan.capability.coordinate_system == "lumped_0d"
    @test dae_plan.capability.required_output ==
        ("consistent_state", "initial_derivative", "algebraic_residual",
         "differential_mass_residual", "local_algebraic_jacobian_audit")
    @test dae_plan.provider.executor === nothing
    @test dae_plan.provider.code_hash == dae_plan.source_hash
    @test dae_plan.provider.manifest_hash == dae_plan.input.provider_manifest_hash
    @test dae_plan.input.physical_subject_hash == dae_plan.subject.physical_subject_hash
    @test dae_plan.input.scenario_hash == dae_scenario.scenario_hash
    @test dae_report.artifact.status === :pass
    @test Tuple(v.state_ref for v in dae_report.artifact.initial_values) ==
        Tuple(v.state_ref for v in dae_report.artifact.final_values)
    @test all(isapprox(actual, expected; atol=1e-9) for (actual, expected) in
        zip((v.value for v in dae_report.artifact.final_values), (1.0, 2.0, 1.0)))
    @test dae_report.artifact.initial_derivative == (-1.0,)
    @test dae_report.artifact.mass_matrix == ((1.0,),)
    @test maximum(abs, dae_report.artifact.final_algebraic_residual) < 1e-10
    @test maximum(abs, dae_report.artifact.differential_mass_residual) < 1e-10
    @test dae_report.artifact.correction_norm > 0
    @test dae_report.artifact.differential_unchanged === true
    @test dae_report.artifact.mass_condition <= dae_plan.protocol.max_condition
    @test dae_report.artifact.jacobian_condition <= dae_plan.protocol.max_condition
    @test length(dae_report.evidence.metrics) == 5
    @test all(metric -> metric.unit == UnitSignature(), dae_report.evidence.metrics)
    @test dae_plan.subject.materialized_payload.row_authority.scaling.basis ===
        :typed_state_bounds_in_declared_base_units
    @test validate_typed_dae_initialization_report(dae_plan, dae_report)
end

@testset "D2.1 claim and execute-once firewall" begin
    @test dae_report.numerical_status === :pass
    @test dae_report.claim_ceiling === screen_only
    @test dae_report.credible_physical_candidate_count == 0
    @test !dae_report.p5_ready
    @test !dae_report.unsupported_emitted
    @test dae_report.trajectory === nothing
    @test dae_report.executed_scope == "g1_lumped_mixed_state_initialization"
    @test dae_report.unexecuted_scopes ==
        ("g2_field_geometry", "g3_realization_control", "dae_time_trajectory")
    @test dae_store.execution_counts[dae_plan.input.solver_input_hash] == 1
    @test execute_once!(dae_store, dae_plan.input, dae_plan.provider, dae_plan) === dae_report
    @test cache_typed_dae_initialization(dae_store, dae_plan) === dae_report
    before = (length(dae_store.reports), length(dae_store.artifacts),
        length(dae_store.execution_counts), dae_store.execution_counts[dae_plan.input.solver_input_hash])
    @test replay_typed_dae_initialization(dae_plan, dae_report)
    @test before == (length(dae_store.reports), length(dae_store.artifacts),
        length(dae_store.execution_counts), dae_store.execution_counts[dae_plan.input.solver_input_hash])

    missing_store = TypedDAEInitializationStoreV4()
    missing = execute_once!(missing_store, dae_plan.input, nothing, dae_plan)
    @test missing.numerical_status === :terminal_deferred
    @test missing.artifact === nothing && missing.receipt.execution_count == 0
    @test missing.evidence.claim_ceiling === none
    @test isempty(missing_store.reports) && isempty(missing_store.artifacts) &&
        isempty(missing_store.execution_counts)
    @test validate_typed_dae_initialization_report(dae_plan, missing)
    @test replay_typed_dae_initialization(dae_plan, missing)
    tampered_deferred = FusionRuntimeV4._tdae_build_report(dae_plan,
        nothing, 0; provider=nothing, forced_reason="tampered deferred reason")
    @test_throws ArgumentError validate_typed_dae_initialization_report(
        dae_plan, tampered_deferred)
end

@testset "D2.1 compiler and scenario negatives" begin
    @test_throws ArgumentError compile_tdae_case(d=(tdae_arefs[1],), a=(tdae_drefs[1], tdae_arefs[2]))
    @test_throws ArgumentError compile_tdae_case(d=tdae_drefs, a=(tdae_arefs[1], tdae_arefs[1]))
    @test_throws ArgumentError compile_tdae_case(rows=tdae_rows[2:3])
    @test_throws ArgumentError compile_tdae_case(rows=(tdae_rows[1], tdae_rows[2], tdae_rows[2]))
    fake_edge = DAEAlgebraicRowBindingV4(tdae_arefs[1],
        tdae_rows[2].governing_edge_hash, digest256_text("foreign-edge"), 1,
        tdae_rows[2].operator_manifest_bindings)
    @test_throws ArgumentError compile_tdae_case(rows=(tdae_rows[1], fake_edge, tdae_rows[3]))
    bad_root = DAEAlgebraicRowBindingV4(tdae_arefs[1],
        tdae_rows[2].governing_edge_hash, tdae_rows[2].residual_edge_hash, 2,
        tdae_rows[2].operator_manifest_bindings)
    @test_throws ArgumentError compile_tdae_case(rows=(tdae_rows[1], bad_root, tdae_rows[3]))
    bad_manifest = DAEAlgebraicRowBindingV4(tdae_arefs[1],
        tdae_rows[2].governing_edge_hash, tdae_rows[2].residual_edge_hash, 1, ())
    @test_throws ArgumentError compile_tdae_case(rows=(tdae_rows[1], bad_manifest, tdae_rows[3]))
    @test_throws ArgumentError FusionRuntimeV4._tdae_require_partition_ports(
        Dict(1 => tdae_arefs[1]), tdae_drefs, "RHS")
    @test_throws ArgumentError FusionRuntimeV4._tdae_require_partition_ports(
        Dict(1 => tdae_drefs[1]), tdae_arefs, "constraint")

    @test_throws ArgumentError ConsistentInitializationScenarioV4("duplicate", (
        StateValueV4(tdae_drefs[1], 1.0, tdae_unit),
        StateValueV4(tdae_drefs[1], 2.0, tdae_unit)))
    reordered = ConsistentInitializationScenarioV4("mixed-state-t0",
        reverse(dae_scenario.initial_values))
    @test reordered.scenario_hash == dae_scenario.scenario_hash
    missing = ConsistentInitializationScenarioV4("missing", dae_scenario.initial_values[1:2])
    @test_throws ArgumentError compile_tdae_case(scenario=missing)
    function resealed_with_scenario(scenario)
        TypedDAEInitializationPlanV4(FusionRuntimeV4._TDAE_TOKEN,
            dae_plan.compiled, dae_plan.registry, dae_plan.differential_refs,
            dae_plan.algebraic_refs, dae_plan.row_bindings, scenario,
            dae_plan.protocol, dae_plan.capability, dae_plan.subject,
            dae_plan.input, dae_plan.provider, dae_plan.source_hash,
            dae_plan.authority_hash, dae_plan.plan_hash)
    end
    @test_throws ArgumentError canonical_hash(resealed_with_scenario(missing))
    wrong_unit = UnitSignature((1, 0, 0, 0, 0, 0, 0))
    wrong = ConsistentInitializationScenarioV4("wrong-unit", (
        StateValueV4(tdae_drefs[1], 1.0, wrong_unit),
        StateValueV4(tdae_arefs[1], 0.0, tdae_unit),
        StateValueV4(tdae_arefs[2], 0.0, tdae_unit)))
    @test_throws ArgumentError compile_tdae_case(scenario=wrong)
    @test_throws ArgumentError canonical_hash(resealed_with_scenario(wrong))
    outside = ConsistentInitializationScenarioV4("outside", (
        StateValueV4(tdae_drefs[1], 20.0, tdae_unit),
        StateValueV4(tdae_arefs[1], 0.0, tdae_unit),
        StateValueV4(tdae_arefs[2], 0.0, tdae_unit)))
    @test_throws ArgumentError compile_tdae_case(scenario=outside)
    @test_throws ArgumentError canonical_hash(resealed_with_scenario(outside))
    @test_throws ArgumentError StateValueV4(tdae_drefs[1], NaN, tdae_unit)
    @test_throws ArgumentError ConsistentInitializationScenarioV4("nonfinite", (
        StateValueV4(tdae_drefs[1], NaN, tdae_unit),
        StateValueV4(tdae_arefs[1], 0.0, tdae_unit),
        StateValueV4(tdae_arefs[2], 0.0, tdae_unit)))
    @test_throws ArgumentError ConsistentInitializationProtocolV4(
        time_unit=UnitSignature())
end

@testset "D2.1 numerical and authority negatives" begin
    low_condition_plan = compile_typed_dae_initialization_plan(
        tdae_compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
        scenario=dae_scenario,
        protocol=ConsistentInitializationProtocolV4(max_condition=0.5))
    low_condition_report = execute_once!(TypedDAEInitializationStoreV4(),
        low_condition_plan.input, low_condition_plan.provider, low_condition_plan)
    @test low_condition_report.numerical_status === :numerical_fail
    @test low_condition_report.artifact.status === :numerical_fail
    @test low_condition_report.artifact.failure_code in
        (:ill_conditioned_algebraic_jacobian, :ill_conditioned_mass_matrix)
    @test all(v -> v isa StateValueV4,
        low_condition_report.artifact.initial_values)
    @test Tuple(v.state_ref for v in low_condition_report.artifact.initial_values) ==
        Tuple(v.state_ref for v in dae_scenario.initial_values)
    @test Tuple(v.unit for v in low_condition_report.artifact.initial_values) ==
        Tuple(v.unit for v in dae_scenario.initial_values)
    @test validate_typed_dae_initialization_report(low_condition_plan,
        low_condition_report)
    @test replay_typed_dae_initialization(low_condition_plan,
        low_condition_report)
    unknown_artifact = FusionRuntimeV4._tdae_failure_result(dae_plan,
        :unknown, :test_backend_exception, "test-only unknown")
    @test all(v -> v isa StateValueV4, unknown_artifact.initial_values)
    @test unknown_artifact.initial_values == dae_scenario.initial_values

    short_plan = compile_typed_dae_initialization_plan(tdae_compiled,
        tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
        scenario=dae_scenario,
        protocol=ConsistentInitializationProtocolV4(max_iterations=1))
    short_report = execute_once!(TypedDAEInitializationStoreV4(),
        short_plan.input, short_plan.provider, short_plan)
    @test short_report.numerical_status === :pass
    @test maximum(abs, short_report.artifact.final_algebraic_residual) < 1e-10

    nonlinear_case = let
        program = let
            z1 = ASTInputV1(1, tdae_alg)
            z2 = ASTInputV1(2, tdae_alg)
            three = ASTConstantV1(:three, 3.0, tdae_alg)
            square = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (1, 1);
                registry=tdae_ops, input_types=(tdae_alg, tdae_alg))
            sum = ASTApplyV1(OperatorRefV1("ADD", "v1"), (4, 2);
                registry=tdae_ops, input_types=(square.output_type, tdae_alg))
            residual = ASTApplyV1(OperatorRefV1("SUB", "v1"), (5, 3);
                registry=tdae_ops, input_types=(sum.output_type, tdae_alg))
            TypedASTProgramV1((z1, z2, three, square, sum, residual), (6,),
                (1, 2), tdae_ops)
        end
        edge = AtomicMIMOHyperedgeV1("c-z1",
            (MIMOInputBindingV1(1, 2), MIMOInputBindingV1(2, 3)),
            (MIMOOutputBindingV1(1, 2),), program, constraint;
            registry=tdae_ops)
        graph = TypedOperatorHypergraphV1(tdae_graph.nodes,
            (tdae_gx, tdae_rx, tdae_gz1, tdae_gz2, edge, tdae_c2);
            registry=tdae_ops)
        payload = MechanismGenomePayloadV1(tdae_payload.states,
            tdae_payload.invariants, graph, tdae_payload.parameters,
            tdae_payload.symmetries, tdae_payload.observables,
            tdae_payload.operator_holes)
        mechanism = MechanismGenomeV4(1, tdae_mech_ref, payload)
        candidate = CandidateStatePackageV4("tdae-nonlinear-fixture",
            tdae_mission, mechanism, tdae_field, tdae_real, tdae_registry)
        compiled = compile_candidate(candidate, tdae_registry;
            mission_payload=tdae_mission, bounds_payload=tdae_bounds,
            comparison_scope=("typed-dae",), scenario_scope=("mixed-state",))
        rows = (tdae_rows[1],
            DAEAlgebraicRowBindingV4(tdae_arefs[1],
                tdae_rows[2].governing_edge_hash, canonical_hash(edge), 1,
                edge.program.used_manifest_bindings), tdae_rows[3])
        scenario = ConsistentInitializationScenarioV4("nonlinear-t0", (
            StateValueV4(tdae_drefs[1], 1.0, tdae_unit),
            StateValueV4(tdae_arefs[1], 1.0, tdae_unit),
            StateValueV4(tdae_arefs[2], 0.0, tdae_unit)))
        (compiled=compiled, rows=rows, scenario=scenario)
    end
    nonlinear_plan = compile_typed_dae_initialization_plan(
        nonlinear_case.compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=nonlinear_case.rows,
        scenario=nonlinear_case.scenario,
        protocol=ConsistentInitializationProtocolV4(max_iterations=1))
    nonlinear_report = execute_once!(TypedDAEInitializationStoreV4(),
        nonlinear_plan.input, nonlinear_plan.provider, nonlinear_plan)
    @test nonlinear_report.numerical_status === :numerical_fail
    @test nonlinear_report.artifact.failure_code === :newton_nonconvergence

    stagnation_plan = compile_tdae_case(protocol=
        ConsistentInitializationProtocolV4(correction_abs_tol=0.5))
    stagnation_report = execute_once!(TypedDAEInitializationStoreV4(),
        stagnation_plan.input, stagnation_plan.provider, stagnation_plan)
    @test stagnation_report.numerical_status === :numerical_fail
    @test stagnation_report.artifact.failure_code === :newton_stagnation

    boundary_bounds = Dict(tdae_arefs[1].value => (0.0, 1.0),
        tdae_arefs[2].value => (0.0, 1.0))
    boundary_jacobian = FusionRuntimeV4._tdae_jacobian(
        z -> [z[1] + z[2], z[1] - z[2]], [0.0, 0.0], 1e-7,
        boundary_bounds, tdae_arefs, (1.0, 1.0), (1.0, 1.0))
    @test boundary_jacobian.normalized ≈ [1.0 1.0; 1.0 -1.0]
    fixed_bounds = Dict(tdae_arefs[1].value => (0.0, 0.0),
        tdae_arefs[2].value => (0.0, 1.0))
    @test_throws Exception FusionRuntimeV4._tdae_jacobian(
        z -> [z[1] + z[2], z[1] - z[2]], [0.0, 0.0], 1e-7,
        fixed_bounds, tdae_arefs, (1.0, 1.0), (1.0, 1.0))
    @test_throws Exception FusionRuntimeV4._tdae_matrix_condition(
        [1.0 0.0; 0.0 1e-12],
        ConsistentInitializationProtocolV4(rank_relative_tol=1e-10),
        :singular_algebraic_jacobian, :ill_conditioned_algebraic_jacobian,
        "near-singular test Jacobian")

    foreign_input = SolverInputV4(dae_plan.input.physical_subject_hash,
        digest256_text("foreign-scenario"), dae_plan.input.provider_manifest_hash,
        dae_plan.input.input_schema_hash, dae_plan.input.payload)
    @test_throws ArgumentError execute_once!(TypedDAEInitializationStoreV4(),
        foreign_input, dae_plan.provider, dae_plan)
    p = dae_plan.provider
    foreign_provider = ProviderManifestV4(p.schema, p.revision, p.kind,
        p.capability, p.domain, p.backend, "foreign", p.code_hash,
        p.independence_group, p.claim_ceiling;
        input_schema_hash=p.input_schema_hash, executor=nothing)
    @test_throws ArgumentError execute_once!(TypedDAEInitializationStoreV4(),
        dae_plan.input, foreign_provider, dae_plan)

    key = dae_plan.input.solver_input_hash
    artifact_key = (key, canonical_hash(dae_report.artifact))
    count_only = TypedDAEInitializationStoreV4()
    count_only.execution_counts[key] = 1
    @test_throws ArgumentError execute_once!(count_only, dae_plan.input,
        dae_plan.provider, dae_plan)
    artifact_only = TypedDAEInitializationStoreV4()
    artifact_only.artifacts[artifact_key] = dae_report.artifact
    @test_throws ArgumentError execute_once!(artifact_only, dae_plan.input,
        dae_plan.provider, dae_plan)
    report_without_count = deepcopy(dae_store)
    delete!(report_without_count.execution_counts, key)
    @test_throws ArgumentError execute_once!(report_without_count,
        dae_plan.input, dae_plan.provider, dae_plan)
    @test_throws ArgumentError cache_typed_dae_initialization(
        report_without_count, dae_plan)
    polluted = deepcopy(dae_store)
    polluted.artifacts[artifact_key] = low_condition_report.artifact
    @test_throws ArgumentError cache_typed_dae_initialization(polluted, dae_plan)
    extra_polluted = deepcopy(dae_store)
    foreign_hash = canonical_hash(low_condition_report.artifact)
    extra_polluted.artifacts[(key, foreign_hash)] = low_condition_report.artifact
    @test_throws ArgumentError execute_once!(extra_polluted, dae_plan.input,
        dae_plan.provider, dae_plan)
    @test_throws ArgumentError cache_typed_dae_initialization(
        extra_polluted, dae_plan)
end

@testset "D2.1 sealed chain adversarial controls" begin
    @test_throws Exception TypedDAEInitializationPlanV4(Val(:bad))
    @test_throws Exception TypedDAEInitializationResultV4(Val(:bad))
    @test_throws Exception TypedDAEInitializationReceiptV4(Val(:bad))
    @test_throws Exception TypedDAEInitializationReportV4(Val(:bad))

    r = dae_report
    bad_hash = TypedDAEInitializationReportV4(FusionRuntimeV4._TDAE_TOKEN,
        r.artifact, r.evidence, r.receipt, r.numerical_status,
        r.unresolved_gaps, r.executed_scope, r.unexecuted_scopes,
        r.claim_ceiling, r.credible_physical_candidate_count, r.p5_ready,
        r.unsupported_emitted, nothing, digest256_text("bad-report"))
    @test_throws ArgumentError validate_typed_dae_initialization_report(
        dae_plan, bad_hash)

    a = dae_report.artifact
    altered_fields = (a.status, a.failure_code, a.failure_reason,
        a.differential_refs, a.algebraic_refs, a.initial_values,
        (a.final_values[1],
         StateValueV4(a.final_values[2].state_ref,
             a.final_values[2].value + 0.25, a.final_values[2].unit),
         a.final_values[3]),
        a.initial_algebraic_residual, a.final_algebraic_residual,
        a.initial_derivative, a.differential_mass_residual,
        a.correction_norm, a.differential_unchanged, a.mass_matrix,
        a.jacobian_zz, a.mass_condition, a.jacobian_condition)
    altered_draft = TypedDAEInitializationResultV4(
        FusionRuntimeV4._TDAE_TOKEN, altered_fields..., digest256_text("draft"))
    altered = TypedDAEInitializationResultV4(FusionRuntimeV4._TDAE_TOKEN,
        altered_fields..., canonical_hash(FusionRuntimeV4._tdae_result_identity(altered_draft)))
    altered_report = FusionRuntimeV4._tdae_build_report(dae_plan, altered, 1)
    @test_throws ArgumentError validate_typed_dae_initialization_report(
        dae_plan, altered_report)

    receipt = dae_report.receipt
    receipt_fields = (receipt.invocation_hash, receipt.solver_input_hash,
        receipt.provider_manifest_hash, receipt.plan_hash,
        receipt.physical_subject_hash, receipt.scenario_hash, receipt.status,
        receipt.failure_code, receipt.failure_reason, receipt.artifact_hash,
        receipt.evidence_id, 2)
    receipt_draft = TypedDAEInitializationReceiptV4(
        FusionRuntimeV4._TDAE_TOKEN, receipt_fields..., digest256_text("draft"))
    bad_receipt = TypedDAEInitializationReceiptV4(
        FusionRuntimeV4._TDAE_TOKEN, receipt_fields...,
        canonical_hash(FusionRuntimeV4._tdae_receipt_identity(receipt_draft)))
    report_fields = (dae_report.artifact, dae_report.evidence, bad_receipt,
        dae_report.numerical_status, dae_report.unresolved_gaps,
        dae_report.executed_scope, dae_report.unexecuted_scopes, screen_only,
        0, false, false, nothing)
    report_draft = TypedDAEInitializationReportV4(
        FusionRuntimeV4._TDAE_TOKEN, report_fields..., digest256_text("draft"))
    bad_count_report = TypedDAEInitializationReportV4(
        FusionRuntimeV4._TDAE_TOKEN, report_fields...,
        canonical_hash(FusionRuntimeV4._tdae_report_identity(report_draft)))
    @test_throws ArgumentError validate_typed_dae_initialization_report(
        dae_plan, bad_count_report)

    manifest = typed_dae_initialization_manifest()
    @test manifest.claim_ceiling === screen_only
    @test manifest.credible_physical_candidate_count == 0
    @test !manifest.p5_ready && !manifest.unsupported_emitted
    @test manifest.trajectory === nothing
end
