using FusionConceptAI
const _composition_definition_only = isdefined(@__MODULE__, :runtime_v4_field_residual_definition_only) &&
    getfield(@__MODULE__, :runtime_v4_field_residual_definition_only) === true
if _composition_definition_only
    include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
    using .FusionRuntimeV4
    include(joinpath(@__DIR__, "runtime_v4_typed_dae_initialization_fixture.jl"))
    @eval module D3DeclaredG2Dependency
    using FusionConceptAI
    include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
    end
    const d3_g2_scenario = (name="g2-field-scenario",)
    const d3_g2_grid = D3DeclaredG2Dependency.grid
    const d3_g2_site = D3DeclaredG2Dependency._g2_site
    const d3_operator_registry = default_operator_registry()
else
    include(joinpath(@__DIR__, "runtime_v4_typed_field_time_bridge_fixture.jl"))
end

const composition_unit = UnitSignature()
const composition_static3d = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), composition_unit)
const composition_laplace3d = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), UnitSignature((0, -2, 0, 0, 0, 0, 0)))
const composition_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), composition_unit)
const composition_laplace_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false),
    UnitSignature((0, -2, 0, 0, 0, 0, 0)))
const composition_zero_offset = FieldParameterGeneV1(
    FieldParameterRefV1("composition-zero-offset"), composition_unit,
    ParameterTransformSpecV1(transform_linear),
    QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), composition_unit), 0.0)
const composition_u = StateGeneV1(StateGeneRefV1("u"), composition_static3d, composition_bounds, (), (), (), state_derived)
const composition_f = StateGeneV1(StateGeneRefV1("f"), composition_static3d, composition_bounds, (), (), (), state_derived)
const composition_r = StateGeneV1(StateGeneRefV1("r"), composition_laplace3d, composition_laplace_bounds, (), (), (ConstraintRefV1("static-field-residual"),), state_derived)
const composition_residual_program = let
    u = ASTInputV1(1, composition_static3d)
    f = ASTInputV1(2, composition_static3d)
    lap = ASTApplyV1(OperatorRefV1("LAPLACE", "v1"), (1,);
        registry=tdae_ops, input_types=(composition_static3d,))
    kappa = ASTConstantV1(:kappa_m2, 2.0, composition_laplace3d)
    kf = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (4, 2);
        registry=tdae_ops, input_types=(composition_laplace3d, composition_static3d))
    residual = ASTApplyV1(OperatorRefV1("SUB", "v1"), (3, 5);
        registry=tdae_ops, input_types=(composition_laplace3d, composition_laplace3d))
    TypedASTProgramV1((u, f, lap, kappa, kf, residual), (6,), (1, 2);
        registry=tdae_ops)
end
const composition_constraint = AtomicMIMOHyperedgeV1(
    "static-field-residual",
    (MIMOInputBindingV1(1, 8), MIMOInputBindingV1(2, 9)),
    (MIMOOutputBindingV1(1, 10),), composition_residual_program, constraint;
    registry=tdae_ops)
const composition_graph = TypedOperatorHypergraphV1(
    (tdae_graph.nodes..., node(:state, composition_static3d; id="u"),
     node(:state, composition_static3d; id="f"), node(:state, composition_laplace3d; id="r")),
    (tdae_graph.hyperedges..., composition_constraint); registry=tdae_ops)
const composition_payload = MechanismGenomePayloadV1(
    (tdae_x, tdae_z1, tdae_z2, composition_u, composition_f, composition_r),
    tdae_payload.invariants, composition_graph, tdae_payload.parameters,
    tdae_payload.symmetries, tdae_payload.observables, tdae_payload.operator_holes)
const composition_mechanism = MechanismGenomeV4(1, tdae_mech_ref, composition_payload)
const composition_g2_program = let
    c = ASTInputV1(1, D3DeclaredG2Dependency._g2_chart)
    rho2 = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 1);
        registry=D3DeclaredG2Dependency._g2_ops,
        input_types=(D3DeclaredG2Dependency._g2_chart,
                     D3DeclaredG2Dependency._g2_chart))
    u = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (2, 2);
        registry=D3DeclaredG2Dependency._g2_ops,
        input_types=(D3DeclaredG2Dependency._g2_scalar,
                     D3DeclaredG2Dependency._g2_scalar))
    ten = ASTConstantV1(:ten, 10.0, D3DeclaredG2Dependency._g2_scalar)
    f0 = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (4, 2);
        registry=D3DeclaredG2Dependency._g2_ops,
        input_types=(D3DeclaredG2Dependency._g2_scalar,
                     D3DeclaredG2Dependency._g2_scalar))
    offset = ASTParameterV1(:offset, D3DeclaredG2Dependency._g2_scalar)
    f = ASTApplyV1(OperatorRefV1("ADD", "v1"), (5, 6);
        registry=D3DeclaredG2Dependency._g2_ops,
        input_types=(D3DeclaredG2Dependency._g2_scalar,
                     D3DeclaredG2Dependency._g2_scalar))
    TypedASTProgramV1((c, rho2, u, ten, f0, offset, f), (3, 7), (1,);
        registry=D3DeclaredG2Dependency._g2_ops)
end
const composition_g2_roots = (
    SpatialProgramRootRefV1(d3_g2_site, 1, D3DeclaredG2Dependency._g2_chart,
        D3DeclaredG2Dependency._g2_scalar),
    SpatialProgramRootRefV1(d3_g2_site, 2, D3DeclaredG2Dependency._g2_chart,
        D3DeclaredG2Dependency._g2_scalar))
const composition_g2_typed = TypedFieldProgramGeneV1(
    d3_g2_site, composition_g2_program, composition_g2_roots,
    (FieldProgramParameterBindingV1(composition_zero_offset.ref, 6),))
const composition_g2_phases = PhaseFieldSetGeneV1(
    D3DeclaredG2Dependency._g2_support_ref,
    (composition_zero_offset,), (composition_g2_typed,),
    (PhaseFieldDeclarationV1(PhaseFieldRefV1("u"), composition_g2_roots[1]),
     PhaseFieldDeclarationV1(PhaseFieldRefV1("f"), composition_g2_roots[2])))
const composition_field = FieldGeometryGenomeV4(2, tdae_field_ref, tdae_aux;
    fields=(D3DeclaredG2Dependency._g2_support, composition_g2_phases))
const composition_candidate = CandidateStatePackageV4("typed-dae-composition-fixture", tdae_mission,
    composition_mechanism, composition_field, tdae_real, tdae_registry)
const composition_compiled = compile_candidate(composition_candidate, tdae_registry;
    mission_payload=tdae_mission, bounds_payload=tdae_bounds,
    comparison_scope=("typed-dae", "typed-field-time-bridge", "composition"),
    scenario_scope=("mixed-state", "g2-field-scenario", "static-composition"))
if !_composition_definition_only
const composition_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(composition_compiled, tdae_registry;
    differential_refs=tdae_drefs, algebraic_refs=tdae_arefs, row_bindings=tdae_rows, scenario=dae_scenario)
const composition_init_report = FusionRuntimeV4.execute_once!(FusionRuntimeV4.TypedDAEInitializationStoreV4(), composition_plan.input, composition_plan.provider, composition_plan)
const composition_time_plan = FusionRuntimeV4.compile_typed_dae_time_execution_plan(composition_plan, composition_init_report; protocol=d3_time_protocol)
const composition_time_report = FusionRuntimeV4.execute_once!(FusionRuntimeV4.TypedDAETimeStoreV4(), composition_time_plan.input, composition_time_plan.provider, composition_time_plan)
const composition_g2_plan = FusionRuntimeV4.compile_field_evaluation_plan(composition_candidate, composition_compiled, tdae_registry, d3_operator_registry; scenario=d3_g2_scenario, grid=d3_g2_grid, program_site_ref=d3_g2_site, root_position=1)
const composition_g2_provider = FusionRuntimeV4.field_evaluation_provider(composition_g2_plan)
const composition_g2_report = FusionRuntimeV4.execute_field_evaluation(Dict{Digest256,Any}(), composition_candidate, composition_compiled, tdae_registry, d3_operator_registry, composition_g2_plan, d3_g2_scenario; provider=composition_g2_provider)
const composition_d3_report = build_typed_field_time_bridge(composition_candidate, composition_compiled, tdae_registry, d3_operator_registry, composition_time_plan, composition_time_report, composition_g2_plan, composition_g2_report, dae_scenario, d3_g2_scenario; g2_provider=composition_g2_provider)
end
const composition_static_refs = (StateGeneRefV1("u"), StateGeneRefV1("f"), StateGeneRefV1("r"))
