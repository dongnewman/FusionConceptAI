"""Legacy-gap and exact two-root normalized-to-SI bridge fixtures."""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_three_d_physical_provider_input.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDNormalizedPhysicalRootBridgeV4.jl"))
const TDNPRB = TDPI

const tdnprb_legacy_resolution =
    TDNPRB.compile_three_d_normalized_physical_root_bridge(tdpi_context)
const tdnprb_missing_resolution =
    TDNPRB.compile_three_d_normalized_physical_root_bridge(generic_3d_context)

const tdnprb_chart_type = chart_coordinate_type_v1()
const tdnprb_normalized_coordinate_type = normalized_ambient_coordinate_type_v1()
const tdnprb_normalized_metric_type = normalized_covariant_metric_type_v1()
const tdnprb_length_scale_type = PhysicalType(:support_scale, 0, 3,
    TemporalTypeV1(static_time), tdpi_length_unit)
const tdnprb_metric_scale_type = PhysicalType(:support_scale_squared, 0, 3,
    TemporalTypeV1(static_time), tdpi_metric_unit)

function tdnprb_manifest(id, inputs, output)
    rule = ExactTypeRuleV1(inputs, (output,))
    OperatorManifestV1(OperatorRefV1(id, "v1"), length(inputs), 1,
        rule, rule; allowed_roles=(:constraint,))
end

const tdnprb_operator_registry = let
    registry = default_operator_registry()
    for manifest in (
            tdnprb_manifest("RUNTIME_V4_NORMALIZED_COORDINATE_FIXTURE",
                (tdnprb_chart_type,), tdnprb_normalized_coordinate_type),
            tdnprb_manifest("RUNTIME_V4_SUPPORT_SCALE_COORDINATE",
                (tdnprb_normalized_coordinate_type, tdnprb_length_scale_type),
                tdpi_coordinate_type),
            tdnprb_manifest("RUNTIME_V4_NORMALIZED_METRIC_FIXTURE",
                (tdnprb_chart_type,), tdnprb_normalized_metric_type),
            tdnprb_manifest("RUNTIME_V4_SUPPORT_SCALE_METRIC",
                (tdnprb_normalized_metric_type, tdnprb_metric_scale_type),
                tdpi_metric_type))
        registry = register_operator(registry, manifest)
    end
    registry
end

function tdnprb_program(normalized_operator, normalized_type,
        bridge_operator, scale_type, scale_value, physical_type)
    chart = ASTInputV1(1, tdnprb_chart_type)
    normalized = ASTApplyV1(OperatorRefV1(normalized_operator, "v1"), (1,), (;);
        registry=tdnprb_operator_registry, input_types=(tdnprb_chart_type,))
    scale = ASTConstantV1(:support_scale, scale_value, scale_type)
    physical = ASTApplyV1(OperatorRefV1(bridge_operator, "v1"), (2, 3), (;);
        registry=tdnprb_operator_registry,
        input_types=(normalized_type, scale_type))
    physical.output_type == physical_type || error("bridge fixture output mismatch")
    TypedASTProgramV1((chart, normalized, scale, physical), (2, 4), (1,);
        registry=tdnprb_operator_registry)
end

const tdnprb_support_scale = NonnegativeQuantityV1(11 // 2, tdpi_length_unit)
const tdnprb_coordinate_site = FieldOperatorSiteRefV1("tdnprb-coordinate")
const tdnprb_metric_site = FieldOperatorSiteRefV1("tdnprb-metric")
const tdnprb_coordinate_program = tdnprb_program(
    "RUNTIME_V4_NORMALIZED_COORDINATE_FIXTURE",
    tdnprb_normalized_coordinate_type,
    "RUNTIME_V4_SUPPORT_SCALE_COORDINATE", tdnprb_length_scale_type,
    tdnprb_support_scale.value, tdpi_coordinate_type)
const tdnprb_metric_program = tdnprb_program(
    "RUNTIME_V4_NORMALIZED_METRIC_FIXTURE", tdnprb_normalized_metric_type,
    "RUNTIME_V4_SUPPORT_SCALE_METRIC", tdnprb_metric_scale_type,
    tdnprb_support_scale.value^2, tdpi_metric_type)

const tdnprb_graph = TypedOperatorHypergraphV1(
    (node(:chart_coordinate, tdnprb_chart_type; id="tdnprb-chart-input"),
     node(:normalized_coordinate, tdnprb_normalized_coordinate_type;
        id="tdnprb-normalized-coordinate"),
     node(:physical_coordinate, tdpi_coordinate_type;
        id="tdnprb-physical-coordinate"),
     node(:normalized_metric, tdnprb_normalized_metric_type;
        id="tdnprb-normalized-metric"),
     node(:physical_metric, tdpi_metric_type; id="tdnprb-physical-metric")),
    (AtomicMIMOHyperedgeV1(tdnprb_coordinate_site.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)),
        tdnprb_coordinate_program, constraint; registry=tdnprb_operator_registry),
     AtomicMIMOHyperedgeV1(tdnprb_metric_site.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 4), MIMOOutputBindingV1(2, 5)),
        tdnprb_metric_program, constraint; registry=tdnprb_operator_registry));
    registry=tdnprb_operator_registry)
const tdnprb_prebinding = TDNPRB._make_forward_graph_binding(
    :field_geometry, tdnprb_graph)

const tdnprb_support_ref = SpatialSupportRefV1("tdnprb-support")
const tdnprb_chart_ref = ChartRefV1("tdnprb-chart")
const tdnprb_support = SpatialSupportGeneV1(tdnprb_support_ref, 3,
    (CoordinateFrameRefV1("tdnprb-frame"),),
    (CoordinateChartGeneV1(tdnprb_chart_ref,
        CoordinateFrameRefV1("tdnprb-frame"), tdpi_chart_bounds, (),
        SpatialProgramRootRefV1(tdnprb_coordinate_site, 1,
            tdnprb_chart_type, tdnprb_normalized_coordinate_type),
        SpatialProgramRootRefV1(tdnprb_metric_site, 1,
            tdnprb_chart_type, tdnprb_normalized_metric_type)),), (),
    tdnprb_support_scale)
const tdnprb_coordinate_metric = TDNPRB.ThreeDCoordinateMetricV4(
    tdnprb_support_ref, tdnprb_chart_ref,
    tdnprb_coordinate_site, tdnprb_metric_site,
    tdnprb_prebinding.ast_root_identity_hashes[2],
    tdnprb_prebinding.ast_root_identity_hashes[4],
    tdpi_coordinate_type, tdpi_metric_type, tdpi_chart_bounds)
const tdnprb_declaration = TDNPRB.ThreeDPhysicalProviderInputV4(
    "tdnprb-two-root-declaration", tdpi_fourier_boundary,
    tdnprb_coordinate_metric, tdpi_profiles_flux)

const tdnprb_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const tdnprb_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdnprb_graph;
    fields=(tdnprb_support, tdnprb_declaration))
const tdnprb_candidate = CandidateStatePackageV4(
    "tdnprb-two-root-candidate", tdnprb_base._fixture_mission,
    tdnprb_base._fixture_mechanism, tdnprb_field_genome,
    tdnprb_base._fixture_realization, generic_3d_registry)
const tdnprb_mission = (mission="normalized-physical-root-bridge",
    contract=tdnprb_candidate.mission_contract_ref)
const tdnprb_bounds = (declaration_hash=canonical_hash(tdnprb_declaration),
    scope="root-bridge-structure-only")
const tdnprb_comparison_scope = ("normalized-physical-root-bridge-only",)
const tdnprb_scenario = (name="tdnprb-manufactured-scenario",
    fixture="compiler-validator-only")
const tdnprb_scenario_scope = (tdnprb_scenario.name,)
const tdnprb_compiled = TDNPRB.compile_candidate(tdnprb_candidate,
    generic_3d_registry; mission_payload=tdnprb_mission,
    bounds_payload=tdnprb_bounds, comparison_scope=tdnprb_comparison_scope,
    scenario_scope=tdnprb_scenario_scope)
const tdnprb_subject_binding =
    TDNPRB.make_three_d_physical_provider_input_binding(
        tdnprb_compiled, generic_3d_registry, tdnprb_mission, tdnprb_bounds,
        tdnprb_comparison_scope, tdnprb_scenario_scope, tdnprb_scenario,
        tdnprb_declaration)
const tdnprb_subject = TDNPRB.ExecutablePhysicalSubjectV4(
    tdnprb_compiled.prefix_hash,
    tdnprb_candidate.canonical_hashes.genome_bundle_hash,
    tdnprb_compiled.minimality_scope.mission_hash,
    tdnprb_compiled.minimality_scope.bounds_hash,
    (tdnprb_subject_binding,), (tdnprb_scenario,),
    (materialization="normalized-physical-root-bridge-only",
     declaration_hash=canonical_hash(tdnprb_declaration)),
    TDNPRB.derive_capability_obligations(tdnprb_compiled))
const tdnprb_context = TDNPRB.make_forward_chain_context(
    tdnprb_candidate, tdnprb_compiled, generic_3d_registry,
    tdnprb_mission, tdnprb_bounds, tdnprb_comparison_scope,
    tdnprb_scenario_scope, tdnprb_subject, tdnprb_scenario)
const tdnprb_resolution =
    TDNPRB.compile_three_d_normalized_physical_root_bridge(tdnprb_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("legacy_status=", tdnprb_legacy_resolution.status)
    println("legacy_gaps=", join(tdnprb_legacy_resolution.recoverable_gaps, ","))
    println("bridge_status=", tdnprb_resolution.status)
    println("bridge_ready_is_geometry_proof=false")
    println("request_emitted=false")
    println("provider_selected=false")
    println("solver_executed=false")
    println("emits_evidence=false")
end
