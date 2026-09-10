"""Generic-gap and exact two-region 3-D physical-input composition fixtures."""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_three_d_physical_provider_input.jl"))
for file in ("ThreeDRegionLawCompilerV4.jl",
             "ThreeDOrientedInterfaceInputV4.jl",
             "ThreeDRegionLawSetCompilerV4.jl",
             "ThreeDGoverningResidualJacobianV4.jl",
             "ThreeDDiscretizationControlsV4.jl",
             "ThreeDPhysicalInputCompositionV4.jl")
    Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4", file))
end
const TDPIC = TDPI

const tdpic_generic_resolution =
    TDPIC.compose_three_d_physical_inputs(generic_3d_context)

const tdpic_unit = UnitSignature()
const tdpic_length_unit = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const tdpic_metric_unit = UnitSignature((0, 2, 0, 0, 0, 0, 0))
const tdpic_pressure_unit = UnitSignature((1, -1, -2, 0, 0, 0, 0))
const tdpic_flux_unit = UnitSignature((1, 2, -2, -1, 0, 0, 0))
const tdpic_coordinate_type = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), tdpic_length_unit)
const tdpic_metric_type = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), tdpic_metric_unit)
const tdpic_state_type = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), tdpic_unit)
const tdpic_residual_type = PhysicalType(:governing_residual, 0, 3,
    TemporalTypeV1(static_time), tdpic_unit)
const tdpic_jacobian_type = PhysicalType(:residual_jacobian, 0, 3,
    TemporalTypeV1(static_time), tdpic_unit)
const tdpic_region_type = PhysicalType(:manufactured_region_scalar, 0, 3,
    TemporalTypeV1(static_time), tdpic_unit)

function tdpic_exact_manifest(id, role, input_type, output_type; effects=())
    rule = ExactTypeRuleV1((input_type,), (output_type,))
    OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        allowed_roles=(role,),
        locality=role === :boundary ? :boundary : :local,
        allowed_conservation_effects=effects)
end

function tdpic_operator_registry()
    registry = default_operator_registry()
    for (id, role, output_type) in (
            ("TDPIC_LEFT_RESIDUAL", :governing, tdpic_residual_type),
            ("TDPIC_RIGHT_RESIDUAL", :governing, tdpic_residual_type),
            ("TDPIC_LEFT_JACOBIAN", :constraint, tdpic_jacobian_type),
            ("TDPIC_RIGHT_JACOBIAN", :constraint, tdpic_jacobian_type))
        registry = register_operator(registry,
            tdpic_exact_manifest(id, role, tdpic_state_type, output_type))
    end
    interface_manifest = OperatorManifestV1(
        OperatorRefV1("TDPIC_INTERFACE", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:interface,),
        allowed_conservation_effects=(:interface_flux,))
    registry = register_operator(registry, interface_manifest)
    for (id, role, effects) in (
            ("TDPIC_CONSTITUTIVE", :governing, ()),
            ("TDPIC_SOURCE", :source, (:net_creation,)),
            ("TDPIC_BOUNDARY", :boundary, ()))
        registry = register_operator(registry,
            tdpic_exact_manifest(id, role, tdpic_region_type,
                tdpic_region_type; effects=effects))
    end
    registry
end

const tdpic_ops = tdpic_operator_registry()

function tdpic_program(id, input_type, output_type)
    input = ASTInputV1(1, input_type)
    root = ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=tdpic_ops, input_types=(input_type,))
    root.output_type == output_type || error("fixture operator output mismatch")
    TypedASTProgramV1((input, root), (2,), (1,); registry=tdpic_ops)
end

const tdpic_coordinate_site = FieldOperatorSiteRefV1("tdpic-coordinate-root")
const tdpic_metric_site = FieldOperatorSiteRefV1("tdpic-metric-root")
const tdpic_coordinate_ast = ast_leaf(:constant, tdpic_coordinate_type;
    parameters=(value=(0.0, 0.0, 0.0),))
const tdpic_metric_ast = ast_leaf(:constant, tdpic_metric_type;
    parameters=(value=(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),))

const tdpic_residual_edges = (
    AtomicMIMOHyperedgeV1("tdpic-left-residual-edge",
        (MIMOInputBindingV1(1, 4),), (MIMOOutputBindingV1(1, 5),),
        tdpic_program("TDPIC_LEFT_RESIDUAL", tdpic_state_type,
            tdpic_residual_type), governing; registry=tdpic_ops),
    AtomicMIMOHyperedgeV1("tdpic-right-residual-edge",
        (MIMOInputBindingV1(1, 3),), (MIMOOutputBindingV1(1, 6),),
        tdpic_program("TDPIC_RIGHT_RESIDUAL", tdpic_state_type,
            tdpic_residual_type), governing; registry=tdpic_ops))
const tdpic_jacobian_edges = (
    AtomicMIMOHyperedgeV1("tdpic-left-jacobian-edge",
        (MIMOInputBindingV1(1, 4),), (MIMOOutputBindingV1(1, 7),),
        tdpic_program("TDPIC_LEFT_JACOBIAN", tdpic_state_type,
            tdpic_jacobian_type), constraint; registry=tdpic_ops),
    AtomicMIMOHyperedgeV1("tdpic-right-jacobian-edge",
        (MIMOInputBindingV1(1, 3),), (MIMOOutputBindingV1(1, 8),),
        tdpic_program("TDPIC_RIGHT_JACOBIAN", tdpic_state_type,
            tdpic_jacobian_type), constraint; registry=tdpic_ops))

const tdpic_interface_ledger = ConservationLedgerIdentityV1(
    QualifiedRefV1("tdpic-interface-flux", "v1"),
    digest256_text("tdpic-interface-flux-ontology"), tdpic_unit)
const tdpic_interface_pair = InterfaceFluxPairV1(
    PortAccountEffectV1(ConservationAccountRefV1(
        tdpic_interface_ledger, :output, 1, :minus), -1 // 1),
    PortAccountEffectV1(ConservationAccountRefV1(
        tdpic_interface_ledger, :output, 2, :plus), 1 // 1))
const tdpic_interface_program = let
    left = ASTApplyV1(OperatorRefV1("TDPIC_INTERFACE", "v1"), (1,), (;);
        registry=tdpic_ops, input_types=(tdpic_state_type,))
    right = ASTApplyV1(OperatorRefV1("TDPIC_INTERFACE", "v1"), (2,), (;);
        registry=tdpic_ops, input_types=(tdpic_state_type,))
    TypedASTProgramV1((ASTInputV1(1, tdpic_state_type),
        ASTInputV1(2, tdpic_state_type), left, right), (3, 4), (1, 2);
        registry=tdpic_ops)
end
const tdpic_interface_edge = AtomicMIMOHyperedgeV1("tdpic-interface-edge",
    (MIMOInputBindingV1(1, 4), MIMOInputBindingV1(2, 3)),
    (MIMOOutputBindingV1(1, 4), MIMOOutputBindingV1(2, 3)),
    tdpic_interface_program, interface;
    interface_flux_pairs=(tdpic_interface_pair,), registry=tdpic_ops)

const tdpic_source_ledger = ConservationLedgerIdentityV1(
    QualifiedRefV1("tdpic-region-source", "v1"),
    digest256_text("tdpic-region-source-ontology"), tdpic_unit)
const tdpic_source_effect = PortAccountEffectV1(
    ConservationAccountRefV1(tdpic_source_ledger, :output, 1, :plus), 1 // 1)
function tdpic_region_edges(stem, region_index, source_index, boundary_index)
    (AtomicMIMOHyperedgeV1("tdpic-$stem-constitutive-edge",
        (MIMOInputBindingV1(1, region_index),),
        (MIMOOutputBindingV1(1, region_index),),
        tdpic_program("TDPIC_CONSTITUTIVE", tdpic_region_type,
            tdpic_region_type), governing; registry=tdpic_ops),
    AtomicMIMOHyperedgeV1("tdpic-$stem-source-edge",
        (MIMOInputBindingV1(1, region_index),),
        (MIMOOutputBindingV1(1, source_index),),
        tdpic_program("TDPIC_SOURCE", tdpic_region_type,
            tdpic_region_type), source; account_effects=(tdpic_source_effect,),
        registry=tdpic_ops),
    AtomicMIMOHyperedgeV1("tdpic-$stem-boundary-edge",
        (MIMOInputBindingV1(1, region_index),),
        (MIMOOutputBindingV1(1, boundary_index),),
        tdpic_program("TDPIC_BOUNDARY", tdpic_region_type,
            tdpic_region_type), boundary; registry=tdpic_ops))
end

const tdpic_left_region_edges = tdpic_region_edges("left", 9, 11, 12)
const tdpic_right_region_edges = tdpic_region_edges("right", 10, 13, 14)

const tdpic_graph = TypedOperatorHypergraphV1(
    (node(:coordinate, tdpic_coordinate_type; id="tdpic-coordinate"),
     node(:metric, tdpic_metric_type; id="tdpic-metric"),
     node(:state, tdpic_state_type; id="tdpic-right-state"),
     node(:state, tdpic_state_type; id="tdpic-left-state"),
     node(:residual, tdpic_residual_type; id="tdpic-left-residual"),
     node(:residual, tdpic_residual_type; id="tdpic-right-residual"),
     node(:jacobian, tdpic_jacobian_type; id="tdpic-left-jacobian"),
     node(:jacobian, tdpic_jacobian_type; id="tdpic-right-jacobian"),
     node(:region, tdpic_region_type; id="left-region"),
     node(:region, tdpic_region_type; id="right-region"),
     node(:source, tdpic_region_type; id="tdpic-left-source"),
     node(:boundary, tdpic_region_type; id="tdpic-left-boundary"),
     node(:source, tdpic_region_type; id="tdpic-right-source"),
     node(:boundary, tdpic_region_type; id="tdpic-right-boundary")),
    (TypedHyperedge(tdpic_coordinate_site.value, (), (1,),
         tdpic_coordinate_ast, :constraint),
     TypedHyperedge(tdpic_metric_site.value, (), (2,),
         tdpic_metric_ast, :constraint),
     tdpic_residual_edges..., tdpic_jacobian_edges...,
     tdpic_interface_edge, tdpic_left_region_edges...,
     tdpic_right_region_edges...); registry=tdpic_ops)
const tdpic_prebinding = TDPIC._make_forward_graph_binding(
    :field_geometry, tdpic_graph)

const tdpic_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(-1, 1, false), tdpic_unit), 3)
function tdpic_support(support_ref, stem; graph_roots=false)
    frame = CoordinateFrameRefV1("$(stem)-frame")
    chart = ChartRefV1("$(stem)-chart")
    coordinate_site = graph_roots ? tdpic_coordinate_site :
        FieldOperatorSiteRefV1("$(stem)-coordinate-unexecuted")
    metric_site = graph_roots ? tdpic_metric_site :
        FieldOperatorSiteRefV1("$(stem)-metric-unexecuted")
    SpatialSupportGeneV1(support_ref, 3, (frame,),
        (CoordinateChartGeneV1(chart, frame, tdpic_chart_bounds, (),
            SpatialProgramRootRefV1(coordinate_site, 1,
                chart_coordinate_type_v1(),
                normalized_ambient_coordinate_type_v1()),
            SpatialProgramRootRefV1(metric_site, 1,
                chart_coordinate_type_v1(),
                normalized_covariant_metric_type_v1())),), (),
        NonnegativeQuantityV1(1, tdpic_length_unit))
end

const tdpic_left_support_ref = SpatialSupportRefV1("tdpic-left-support")
const tdpic_right_support_ref = SpatialSupportRefV1("tdpic-right-support")
const tdpic_interface_support_ref = SpatialSupportRefV1("tdpic-interface-support")
const tdpic_left_support = tdpic_support(tdpic_left_support_ref,
    "tdpic-left"; graph_roots=true)
const tdpic_right_support = tdpic_support(tdpic_right_support_ref,
    "tdpic-right")
const tdpic_interface_support = tdpic_support(tdpic_interface_support_ref,
    "tdpic-interface")

const tdpic_coordinate_metric = TDPIC.ThreeDCoordinateMetricV4(
    tdpic_left_support_ref, ChartRefV1("tdpic-left-chart"),
    tdpic_coordinate_site, tdpic_metric_site,
    tdpic_prebinding.ast_root_identity_hashes[1],
    tdpic_prebinding.ast_root_identity_hashes[2], tdpic_coordinate_type,
    tdpic_metric_type, tdpic_chart_bounds)
const tdpic_boundary = TDPIC.ThreeDFourierBoundaryV4("tdpic-boundary", 5,
    true, (TDPIC.ThreeDFourierCoefficientV4(0, 0, 5.5),
           TDPIC.ThreeDFourierCoefficientV4(1, 0, 0.4)),
    (TDPIC.ThreeDFourierCoefficientV4(1, 0, 0.4),))
const tdpic_radial_domain = QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), tdpic_unit)
const tdpic_profiles = TDPIC.ThreeDProfilesFluxV4("tdpic-profiles",
    TDPIC.ThreeDRadialProfileV4("tdpic-pressure", :pressure,
        (1000.0, -900.0), tdpic_pressure_unit, tdpic_radial_domain),
    TDPIC.ThreeDRadialProfileV4("tdpic-iota", :iota,
        (0.4, 0.1), tdpic_unit, tdpic_radial_domain), 1.0,
    tdpic_flux_unit)
const tdpic_physical_declaration = TDPIC.ThreeDPhysicalProviderInputV4(
    "tdpic-geometry-profile", tdpic_boundary, tdpic_coordinate_metric,
    tdpic_profiles)

tdpic_space(id, role, owner, support, family, p, q) =
    TDPIC.ThreeDDiscreteSpaceV4(id, role, owner, support,
        QualifiedRefV1(family, "v1"), tdpic_state_type, p, q)
const tdpic_left_volume = tdpic_space("tdpic-left-volume",
    TDPIC.volume_space, "left-region", tdpic_left_support_ref,
    "lagrange-h1-hexahedron", 2, 4)
const tdpic_right_volume = tdpic_space("tdpic-right-volume",
    TDPIC.volume_space, "right-region", tdpic_right_support_ref,
    "lagrange-h1-hexahedron", 2, 4)
const tdpic_oriented_declaration =
    TDPIC.ThreeDOrientedInterfaceDeclarationSetV4(
        "tdpic-two-region-oriented-interface",
        (TDPIC.ThreeDRegionSpaceDeclarationV4("left-region",
             "tdpic-left-state", tdpic_left_support_ref, tdpic_left_volume),
         TDPIC.ThreeDRegionSpaceDeclarationV4("right-region",
             "tdpic-right-state", tdpic_right_support_ref,
             tdpic_right_volume)),
        (TDPIC.ThreeDOrientedInterfaceDeclarationV4(
             "left-to-right", "tdpic-interface-edge", "left-region",
             "right-region", tdpic_interface_ledger,
             tdpic_space("tdpic-left-trace", TDPIC.trace_space,
                 "left-region", tdpic_left_support_ref, "mortar-trace", 2, 4),
             tdpic_space("tdpic-right-trace", TDPIC.trace_space,
                 "right-region", tdpic_right_support_ref, "mortar-trace", 2, 4),
             tdpic_space("tdpic-interface-multiplier", TDPIC.multiplier_space,
                 "left-to-right", tdpic_interface_support_ref,
                 "mortar-multiplier", 1, 4)),))

const tdpic_region_law_set_declaration =
    TDPIC.declare_three_d_region_law_set(tdpic_prebinding,
        tdpic_oriented_declaration;
        declaration_id="tdpic-two-region-law-exact-cover",
        law_selectors=(
            (region_id="right-region",
             constitutive_edge_id="tdpic-right-constitutive-edge",
             source_edge_id="tdpic-right-source-edge",
             boundary_edge_id="tdpic-right-boundary-edge"),
            (region_id="left-region",
             constitutive_edge_id="tdpic-left-constitutive-edge",
             source_edge_id="tdpic-left-source-edge",
             boundary_edge_id="tdpic-left-boundary-edge")))

const tdpic_support_mapping =
    TDPIC.declare_three_d_physical_region_support_mapping(
        tdpic_physical_declaration, tdpic_oriented_declaration;
        declaration_id="tdpic-physical-to-region-supports",
        region_supports=(
            (region_id="right-region", support_ref=tdpic_right_support_ref),
            (region_id="left-region", support_ref=tdpic_left_support_ref)))

const tdpic_residual_declaration =
    TDPIC.declare_three_d_governing_residual_jacobian_set(tdpic_prebinding;
        declaration_id="tdpic-two-state-residual-jacobian",
        pair_selectors=(
            (state_node_id="tdpic-left-state",
             residual_edge_id="tdpic-left-residual-edge",
             jacobian_edge_id="tdpic-left-jacobian-edge"),
            (state_node_id="tdpic-right-state",
             residual_edge_id="tdpic-right-residual-edge",
             jacobian_edge_id="tdpic-right-jacobian-edge")))

const tdpic_space_controls = let spaces = TDPIC.ThreeDDiscreteSpaceV4[]
    append!(spaces, (x.volume_space for x in tdpic_oriented_declaration.regions))
    for item in tdpic_oriented_declaration.interfaces
        push!(spaces, item.minus_trace_space, item.plus_trace_space,
            item.multiplier_space)
    end
    Tuple(TDPIC.ThreeDDiscreteSpaceControlV4(x.space_id,
        x.polynomial_order, x.quadrature_order)
        for x in sort(spaces, by=x -> x.space_id))
end
const tdpic_discretization_declaration =
    TDPIC.ThreeDDiscretizationControlDeclarationV4(
        "tdpic-discretization-controls",
        TDPIC.ThreeDMeshResolutionControlV4("tdpic-two-region-mesh",
            QualifiedRefV1("conforming-hexahedral-mortar", "v1"),
            0.05, 16, 32, 12, 2), tdpic_space_controls,
        TDPIC.ThreeDNonlinearSolverPolicyV4(TDPIC.trust_region_newton,
            TDPIC.assembled_jacobian, 1.0e-10, 1.0e-8, 1.0e-10, 80),
        TDPIC.ThreeDLinearSolverPolicyV4(TDPIC.gmres,
            TDPIC.amg_preconditioner, 1.0e-10, 2000, 80),
        TDPIC.ThreeDRefinementPolicyV4(
            TDPIC.residual_adaptive_refinement, 1.0e-4, 3, 2))

const tdpic_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdpic_graph;
    fields=(tdpic_left_support, tdpic_right_support, tdpic_interface_support,
        tdpic_physical_declaration, tdpic_support_mapping,
        tdpic_region_law_set_declaration,
        tdpic_oriented_declaration, tdpic_residual_declaration,
        tdpic_discretization_declaration))
const tdpic_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const tdpic_candidate = CandidateStatePackageV4(
    "tdpic-manufactured-two-region-candidate", tdpic_base._fixture_mission,
    tdpic_base._fixture_mechanism, tdpic_field_genome,
    tdpic_base._fixture_realization, generic_3d_registry)
const tdpic_scenario = (name="tdpic-manufactured-scenario",
    fixture="two-region-input-composition-only")
const tdpic_mission = (mission="typed-three-d-physical-input-composition",
    contract=tdpic_candidate.mission_contract_ref)
const tdpic_bounds = (scope="manufactured-input-composition-only",
    region_count=2)
const tdpic_comparison = ("typed-three-d-physical-input-composition",)
const tdpic_scenarios = (tdpic_scenario.name,)
const tdpic_compiled = TDPIC.compile_candidate(tdpic_candidate,
    generic_3d_registry; mission_payload=tdpic_mission,
    bounds_payload=tdpic_bounds, comparison_scope=tdpic_comparison,
    scenario_scope=tdpic_scenarios)

const tdpic_physical_binding =
    TDPIC.make_three_d_physical_provider_input_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario, tdpic_physical_declaration)
const tdpic_oriented_binding =
    TDPIC.make_three_d_oriented_interface_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario, tdpic_oriented_declaration)
const tdpic_region_law_set_binding =
    TDPIC.make_three_d_region_law_set_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario,
        tdpic_region_law_set_declaration, tdpic_oriented_binding)
const tdpic_support_mapping_binding =
    TDPIC.make_three_d_physical_region_support_mapping_binding(
        tdpic_compiled, generic_3d_registry, tdpic_mission, tdpic_bounds,
        tdpic_comparison, tdpic_scenarios, tdpic_scenario,
        tdpic_physical_declaration, tdpic_oriented_declaration,
        tdpic_support_mapping)
const tdpic_residual_binding =
    TDPIC.make_three_d_governing_residual_jacobian_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario, tdpic_residual_declaration)
const tdpic_discretization_binding =
    TDPIC.make_three_d_discretization_control_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario, tdpic_discretization_declaration,
        tdpic_oriented_binding)
const tdpic_composition_binding =
    TDPIC.make_three_d_physical_input_composition_binding(tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds, tdpic_comparison,
        tdpic_scenarios, tdpic_scenario, tdpic_physical_declaration,
        tdpic_support_mapping, tdpic_region_law_set_declaration,
        tdpic_oriented_declaration,
        tdpic_residual_declaration, tdpic_discretization_declaration,
        tdpic_physical_binding, tdpic_support_mapping_binding,
        tdpic_region_law_set_binding,
        tdpic_oriented_binding, tdpic_residual_binding,
        tdpic_discretization_binding)

const tdpic_subject = TDPIC.ExecutablePhysicalSubjectV4(
    tdpic_compiled.prefix_hash,
    tdpic_candidate.canonical_hashes.genome_bundle_hash,
    tdpic_compiled.minimality_scope.mission_hash,
    tdpic_compiled.minimality_scope.bounds_hash,
    (tdpic_physical_binding, tdpic_support_mapping_binding,
     tdpic_region_law_set_binding,
     tdpic_oriented_binding,
     tdpic_residual_binding, tdpic_discretization_binding,
     tdpic_composition_binding), (tdpic_scenario,),
    (materialization="manufactured-two-region-input-composition",
     composition_binding_hash=canonical_hash(tdpic_composition_binding)),
    TDPIC.derive_capability_obligations(tdpic_compiled))
const tdpic_context = TDPIC.make_forward_chain_context(tdpic_candidate,
    tdpic_compiled, generic_3d_registry, tdpic_mission, tdpic_bounds,
    tdpic_comparison, tdpic_scenarios, tdpic_subject, tdpic_scenario)
const tdpic_resolution = TDPIC.compose_three_d_physical_inputs(tdpic_context)
const tdpic_input = something(tdpic_resolution.input)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", tdpic_generic_resolution.status)
    println("generic_gap_count=",
        length(tdpic_generic_resolution.recoverable_gaps))
    println("manufactured_status=", tdpic_resolution.status)
    println("candidate_hash_matches=",
        tdpic_input.candidate_hash == tdpic_context.candidate_hash)
    println("compiled_prefix_matches=",
        tdpic_input.compiled_prefix_hash == tdpic_compiled.prefix_hash)
    println("subject_hash_matches=",
        tdpic_input.physical_subject_hash == tdpic_subject.physical_subject_hash)
    println("region_count=", length(tdpic_input.ordered_region_ids))
    println("state_count=", length(tdpic_input.ordered_state_node_ids))
    println("interface_count=",
        length(tdpic_input.ordered_interface_ref_hashes))
    println("discrete_space_count=",
        length(tdpic_input.ordered_discrete_space_identity_hashes))
    println("provider_selected=false")
    println("provider_executed=false")
    println("solver_executed=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("p5_ready=false")
    println("terminal_authority=false")
end
