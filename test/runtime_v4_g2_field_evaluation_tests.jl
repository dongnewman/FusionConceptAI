using Test
using FusionConceptAI
using SHA

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_g2_field_fixture.jl"))

const _G2_BOUNDS = (scope="g2",)
const _G2_COMPARISON = ("g2",)
const _G2_SCENARIOS = ("g2-field-scenario",)

function _g2_operator_variant_registry(id="ADD", version="v2", source_id=id)
    base = operator_manifest(default_operator_registry(), QualifiedRefV1(source_id, "v1"))
    variant = OperatorManifestV1(OperatorRefV1(id, version), base.input_arity,
        base.output_arity, base.input_type_rule, base.output_type_rule;
        allowed_roles=base.allowed_roles, parameter_schema=base.parameter_schema,
        locality=base.locality, max_derivative_contribution=Int(base.max_derivative_contribution),
        pure=base.pure, stateful=base.stateful, stochastic=base.stochastic, event=base.event,
        commutative_input_groups=base.commutative_input_groups,
        cse_allowed=base.cse_allowed,
        allowed_conservation_effects=base.allowed_conservation_effects,
        forbidden_conservation_effects=base.forbidden_conservation_effects)
    OperatorRegistryV1((Tuple(o for o in default_operator_registry().operators
        if o.operator_ref.qualified.id != id)..., variant))
end

function _g2_variant_candidate(operator_registry, id="ADD", version="v2")
    site = FieldOperatorSiteRefV1("g2-variant-site")
    coefficient = ASTConstantV1(:coefficient, (2.0, -1.0, 0.0), _g2_chart)
    dot = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 2), (;);
        registry=operator_registry, input_types=(_g2_chart, _g2_chart))
    offset = ASTParameterV1(:offset, _g2_scalar)
    output = ASTApplyV1(OperatorRefV1(id, version), (3, 4), (;);
        registry=operator_registry, input_types=(_g2_scalar, _g2_scalar))
    copy = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (5,), (;);
        registry=operator_registry, input_types=(_g2_scalar,))
    ast = TypedASTProgramV1((ASTInputV1(1, _g2_chart), coefficient, dot, offset,
        output, copy), (5, 6), (1,); registry=operator_registry)
    roots = (SpatialProgramRootRefV1(site, 1, _g2_chart, _g2_scalar),
        SpatialProgramRootRefV1(site, 2, _g2_chart, _g2_scalar))
    prog = TypedFieldProgramGeneV1(site, ast, roots,
        (FieldProgramParameterBindingV1(_g2_parameter.ref, 4),))
    phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("variant-a"), roots[1]),
        PhaseFieldDeclarationV1(PhaseFieldRefV1("variant-b"), roots[2]))
    phase_set = PhaseFieldSetGeneV1(_g2_support_ref, (_g2_parameter,), (prog,), phases)
    field = FieldGeometryGenomeV4(2, _fixture_refs[2], _fixture_graph();
        fields=(_g2_support, phase_set))
    CandidateStatePackageV4("g2-variant", _fixture_mission, _fixture_mechanism,
        field, _fixture_realization, registry)
end

function _g2_dt_candidate()
    # Construct a real DT@v1 AST with the default manifest.  The published G2
    # phase contract rejects its differential root before a candidate can be
    # admitted; this is intentionally a construction-layer boundary test.
    operator_registry = default_operator_registry()
    site = FieldOperatorSiteRefV1("g2-dt-site")
    coefficient = ASTConstantV1(:coefficient, (2.0, -1.0, 0.0), _g2_chart)
    dot = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 2), (;);
        registry=operator_registry, input_types=(_g2_chart, _g2_chart))
    offset = ASTConstantV1(:offset, 1.0, _g2_scalar)
    add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;);
        registry=operator_registry, input_types=(_g2_scalar, _g2_scalar))
    differential_scalar = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(differential_time), UnitSignature())
    time_signal = ASTConstantV1(:time_signal, 1.0, differential_scalar)
    weighted = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (5, 6), (;);
        registry=operator_registry, input_types=(_g2_scalar, differential_scalar))
    derivative = ASTApplyV1(OperatorRefV1("DT", "v1"), (7,), (;);
        registry=operator_registry, input_types=(differential_scalar,))
    # The real DT root is deliberately passed to the phase declaration
    # constructor below.  The published G2 phase contract must reject it
    # because phase roots are static scalar logits.
    ast = TypedASTProgramV1((ASTInputV1(1, _g2_chart), coefficient, dot, offset,
        add, time_signal, weighted, derivative), (8,), (1,);
        registry=operator_registry)
    derivative_root = SpatialProgramRootRefV1(site, 1, _g2_chart, derivative.output_type)
    roots = (derivative_root,)
    program = TypedFieldProgramGeneV1(site, ast, roots, ())
    phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("dt"), roots[1]),)
    phase_set = PhaseFieldSetGeneV1(_g2_support_ref, (_g2_parameter,), (program,), phases)
    field = FieldGeometryGenomeV4(2, _fixture_refs[2], _fixture_graph();
        fields=(_g2_support, phase_set))
    CandidateStatePackageV4("g2-dt", _fixture_mission, _fixture_mechanism,
        field, _fixture_realization, registry)
end

function _g2_compiled()
    compile_candidate(candidate, registry;
        mission_payload=candidate.mission_contract_ref,
        bounds_payload=_G2_BOUNDS,
        comparison_scope=_G2_COMPARISON,
        scenario_scope=_G2_SCENARIOS)
end

function _g2_plan(compiled; root_position=1, scenario=scenario, grid=grid)
    compile_field_evaluation_plan(candidate, compiled, registry, default_operator_registry();
        scenario=scenario, grid=grid, program_site_ref=_g2_site,
        root_position=root_position)
end

@testset "G2 typed field evaluation" begin
    compiled = _g2_compiled()
    plan = _g2_plan(compiled)
    @test plan.status == :ready
    @test "g2_coordinate_map_unexecuted" in plan.unresolved_gaps
    @test "g2_metric_unexecuted" in plan.unresolved_gaps
    @test any(startswith(g, "g2_field_scope_unselected_root") for g in plan.unresolved_gaps)

    result = evaluate_field_program(plan, plan.program, plan.root,
        FusionRuntimeV4._field_parameter_map(plan.program, plan.parameters);
        operator_registry=default_operator_registry())
    @test result.values[1] == 0.0
    @test result.values[7] == -2.0
    @test result.values[19] == 4.0
    @test result.min_value == -2.0
    @test result.max_value == 4.0
    @test result.output_type == plan.root.declared_type
    @test length(result.values) == 27
    @test result.checksum isa Digest256
    @test FusionRuntimeV4._FIELD_EVAL_CODE_HASH == Digest256(bytes2hex(SHA.sha256(read(
        joinpath(@__DIR__, "..", "src", "RuntimeV4", "FieldProgramEvaluation.jl")))))
    @test_throws ArgumentError FieldEvaluationPlanV4(plan.candidate_hash, plan.prefix_hash,
        plan.field_geometry_hash, plan.support_ref, plan.support_hash, plan.chart_ref,
        plan.chart_hash, plan.coordinate_map_hash, plan.metric_hash, plan.program_site_ref,
        plan.program_hash, plan.root_ref_hash, plan.parameter_hashes, plan.program, plan.root,
        plan.parameters, plan.chart_bounds, plan.grid, plan.allowed_opcodes,
        plan.used_manifest_bindings, plan.scenario_hash, plan.code_hash, :ready,
        plan.unresolved_gaps, plan.plan_hash)
end

@testset "G2 provider evidence and cache replay" begin
    compiled = _g2_compiled(); plan = _g2_plan(compiled)
    provider = field_evaluation_provider(plan)
    @test provider.manifest_hash == field_evaluation_manifest(plan).manifest_hash
    @test provider.executor === field_evaluation_manifest(plan).executor
    store = Dict{Digest256,Any}()
    report = execute_field_evaluation(store, candidate, compiled, registry,
        default_operator_registry(), plan, scenario; provider=provider)
    @test report.status == :evaluated_screen
    @test report.evidence.status_vector.applicability == required
    @test report.evidence.status_vector.match_status == unique_match
    @test report.evidence.status_vector.resolution == resolved
    @test report.evidence.status_vector.lifecycle == low_fidelity_evaluated
    @test report.evidence.status_vector.stage_outcome == pass
    @test report.evidence.claim_ceiling == screen_only
    @test report.evidence.artifact_refs == (report.result.result_hash,)
    replay = execute_field_evaluation(store, candidate, compiled, registry,
        default_operator_registry(), plan, scenario; provider=provider)
    @test replay.evidence.evidence_id == report.evidence.evidence_id
    @test replay.result.result_hash == report.result.result_hash
end

@testset "G2 exact identity and fail-closed boundaries" begin
    compiled = _g2_compiled(); plan = _g2_plan(compiled)
    provider = field_evaluation_provider(plan)
    @test_throws ArgumentError execute_field_evaluation(Dict{Digest256,Any}(), candidate,
        compiled, registry, default_operator_registry(), plan, (name="other",);
        provider=provider)
    @test_throws ArgumentError execute_field_evaluation(Dict{Digest256,Any}(), candidate,
        compiled, registry, default_operator_registry(), plan, scenario;
        provider=ProviderManifestV4(provider.schema, provider.revision, provider.kind,
            provider.capability, provider.domain, provider.backend, provider.backend_revision,
            digest256_text("foreign-code"), provider.independence_group, provider.claim_ceiling;
            input_schema_hash=provider.input_schema_hash, executor=provider.executor))
    @test_throws ArgumentError FieldGridSpecV4(((0.0, 0.0), (0.0, 1.0), (0.0, 1.0)))
    @test_throws ArgumentError FieldGridSpecV4(((0.0, Inf), (0.0, 1.0), (0.0, 1.0)))
    @test_throws ArgumentError _g2_plan(compiled; grid=((-2.0, 0.0, 1.0),
        (-1.0, 0.0, 1.0), (-1.0, 0.0, 1.0)))
    @test_throws UndefKeywordError evaluate_field_program(plan, plan.program, plan.root,
        FusionRuntimeV4._field_parameter_map(plan.program, plan.parameters))
    @test_throws ArgumentError FieldEvaluationResultV4((), (), plan.root.declared_type)
    @test_throws ArgumentError FieldEvaluationResultV4((), (), nothing, nothing,
        digest256_text("x"), digest256_text("y"))
    alpha = CandidateStatePackageV4("different-display-id", candidate.mission_contract_ref,
        candidate.mechanism_genome_ref, candidate.field_geometry_genome_ref,
        candidate.realization_control_genome_ref, registry)
    alpha_compiled = compile_candidate(alpha, registry;
        mission_payload=alpha.mission_contract_ref, bounds_payload=_G2_BOUNDS,
        comparison_scope=_G2_COMPARISON, scenario_scope=_G2_SCENARIOS)
    alpha_plan = compile_field_evaluation_plan(alpha, alpha_compiled, registry,
        default_operator_registry(); scenario=scenario, grid=grid,
        program_site_ref=_g2_site, root_position=1)
    @test alpha_plan.candidate_hash == plan.candidate_hash
    @test alpha_plan.plan_hash == plan.plan_hash
    unused_parameter = FieldParameterGeneV1(FieldParameterRefV1("unused"), _g2_unit,
        ParameterTransformSpecV1(transform_linear),
        QuantityIntervalV1(ExactFiniteIntervalV1(0, 2, false), _g2_unit), 0.0)
    unused_site = FieldOperatorSiteRefV1("g2-unused-field-site")
    unused_coefficient = ASTConstantV1(:coefficient, (2.0, -1.0, 0.0), _g2_chart)
    unused_dot = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 2), (;);
        registry=_g2_ops, input_types=(_g2_chart, _g2_chart))
    unused_ast_parameter = ASTParameterV1(:unused, _g2_scalar)
    unused_output = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;);
        registry=_g2_ops, input_types=(_g2_scalar, _g2_scalar))
    unused_copy = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (5,), (;);
        registry=_g2_ops, input_types=(_g2_scalar,))
    unused_ast = TypedASTProgramV1((ASTInputV1(1, _g2_chart), unused_coefficient,
        unused_dot, unused_ast_parameter, unused_output, unused_copy), (5, 6), (1,);
        registry=_g2_ops)
    unused_roots = (SpatialProgramRootRefV1(unused_site, 1, _g2_chart, _g2_scalar),
        SpatialProgramRootRefV1(unused_site, 2, _g2_chart, _g2_scalar))
    unused_program = TypedFieldProgramGeneV1(unused_site, unused_ast, unused_roots,
        (FieldProgramParameterBindingV1(unused_parameter.ref, 4),))
    unused_phase = PhaseFieldDeclarationV1(PhaseFieldRefV1("unused-phase"), unused_roots[1])
    unused_phase2 = PhaseFieldDeclarationV1(PhaseFieldRefV1("unused-phase-2"), unused_roots[2])
    unused_phase_set = PhaseFieldSetGeneV1(_g2_support_ref,
        (_g2_parameter, unused_parameter), (_g2_typed_program, unused_program),
        (_g2_phase, _g2_phase2, unused_phase, unused_phase2))
    unused_field = FieldGeometryGenomeV4(2, _fixture_refs[2], _fixture_graph();
        fields=(_g2_support, unused_phase_set))
    unused_candidate = CandidateStatePackageV4("unused-parameter", _fixture_mission,
        _fixture_mechanism, unused_field, _fixture_realization, registry)
    unused_compiled = compile_candidate(unused_candidate, registry;
        mission_payload=unused_candidate.mission_contract_ref, bounds_payload=_G2_BOUNDS,
        comparison_scope=_G2_COMPARISON, scenario_scope=_G2_SCENARIOS)
    unused_plan = compile_field_evaluation_plan(unused_candidate, unused_compiled, registry,
        default_operator_registry(); scenario=scenario, grid=grid,
        program_site_ref=_g2_site, root_position=1)
    @test "g2_field_scope_unselected_parameter:$(canonical_hash(unused_parameter))" in unused_plan.unresolved_gaps
    forged = CompiledCandidatePrefixV4(candidate, compiled.mission_payload,
        compiled.bounds_payload, compiled.minimality_scope, compiled.mechanism_graph,
        compiled.field_geometry_graph, compiled.realization_graph, compiled.control_graph,
        compiled.normalized_regions, compiled.normalized_interfaces,
        compiled.normalized_boundaries, ("tampered_prefix_gap",),
        compiled.capability_obligations, compiled.compilation_status)
    @test_throws ArgumentError execute_field_evaluation(Dict{Digest256,Any}(), candidate,
        forged, registry, default_operator_registry(), plan, scenario; provider=provider)
    variant_registry = _g2_operator_variant_registry()
    variant_candidate = _g2_variant_candidate(variant_registry)
    variant_compiled = compile_candidate(variant_candidate, registry;
        mission_payload=variant_candidate.mission_contract_ref, bounds_payload=_G2_BOUNDS,
        comparison_scope=_G2_COMPARISON, scenario_scope=_G2_SCENARIOS)
    variant_plan = compile_field_evaluation_plan(variant_candidate, variant_compiled,
        registry, variant_registry; scenario=scenario, grid=grid,
        program_site_ref=FieldOperatorSiteRefV1("g2-variant-site"), root_position=1)
    @test variant_plan.status == :deferred
    @test any(occursin("operator_manifest:ADD@v2", g) for g in variant_plan.unresolved_gaps)
    @test_throws ArgumentError field_evaluation_provider(variant_plan)
    variant_report = execute_field_evaluation(Dict{Digest256,Any}(), variant_candidate,
        variant_compiled, registry, variant_registry, variant_plan, scenario)
    @test variant_report.subject === nothing && variant_report.input === nothing && variant_report.evidence === nothing
    unknown_registry = _g2_operator_variant_registry("G2_UNKNOWN", "v1", "ADD")
    unknown_candidate = _g2_variant_candidate(unknown_registry, "G2_UNKNOWN", "v1")
    unknown_compiled = compile_candidate(unknown_candidate, registry;
        mission_payload=unknown_candidate.mission_contract_ref, bounds_payload=_G2_BOUNDS,
        comparison_scope=_G2_COMPARISON, scenario_scope=_G2_SCENARIOS)
    unknown_plan = compile_field_evaluation_plan(unknown_candidate, unknown_compiled,
        registry, unknown_registry; scenario=scenario, grid=grid,
        program_site_ref=FieldOperatorSiteRefV1("g2-variant-site"), root_position=1)
    @test unknown_plan.status == :deferred
    @test any(occursin("unknown_operator:G2_UNKNOWN", g) for g in unknown_plan.unresolved_gaps)
    @test_throws ArgumentError field_evaluation_provider(unknown_plan)
    unknown_report = execute_field_evaluation(Dict{Digest256,Any}(), unknown_candidate,
        unknown_compiled, registry, unknown_registry, unknown_plan, scenario)
    @test unknown_report.subject === nothing && unknown_report.input === nothing && unknown_report.evidence === nothing
    dt_registry = default_operator_registry()
    dt_input_type = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(differential_time), UnitSignature())
    dt_node = ASTApplyV1(OperatorRefV1("DT", "v1"), (1,), (;);
        registry=dt_registry, input_types=(dt_input_type,))
    dt_manifest = operator_manifest(dt_registry, QualifiedRefV1("DT", "v1"))
    dt_default = only(o for o in default_operator_registry().operators
        if o.operator_ref.qualified.id == "DT" && o.operator_ref.qualified.version == "v1")
    @test dt_manifest.manifest_hash == dt_default.manifest_hash
    @test dt_node.output_type.temporal_type.kind == differential_time
    dt_error = try
        _g2_dt_candidate()
        nothing
    catch err
        err
    end
    @test dt_error isa ArgumentError
    @test dt_error isa ArgumentError &&
        occursin("phase logit root output must be scalar_field", sprint(showerror, dt_error))
end
