"""Candidate/context-bound fixture for the DESC geometry interpreter."""

using FusionConceptAI

include(joinpath(@__DIR__,
    "runtime_v4_three_d_normalized_physical_root_bridge.jl"))
const DGPI = TDNPRB
Base.include(DGPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCGeometryProgramInterpreterV4.jl"))

const dgpi_scale = NonnegativeQuantityV1(11 // 2, tdpi_length_unit)
const dgpi_boundary = DGPI.ThreeDFourierBoundaryV4(
    "dgpi-desc-eligible-boundary", 5, true,
    (DGPI.ThreeDFourierCoefficientV4(0, 0, 5.5),
     DGPI.ThreeDFourierCoefficientV4(1, 0, 0.4),
     DGPI.ThreeDFourierCoefficientV4(1, 1, 0.05)),
    (DGPI.ThreeDFourierCoefficientV4(-1, 0, -0.4),
     DGPI.ThreeDFourierCoefficientV4(-1, 1, -0.05)))
const dgpi_program = DGPI.DESCFourierGeometryProgramV4(
    dgpi_boundary, dgpi_scale, (0, 1, 1), (1, 1))
const dgpi_coordinate_site = FieldOperatorSiteRefV1("dgpi-coordinate")
const dgpi_metric_site = FieldOperatorSiteRefV1("dgpi-metric")
const dgpi_program_binding = DGPI.desc_geometry_typed_binding(
    dgpi_program, dgpi_coordinate_site, dgpi_metric_site)

const dgpi_graph = TypedOperatorHypergraphV1(
    (node(:chart_coordinate, chart_coordinate_type_v1(); id="dgpi-chart-input"),
     node(:normalized_coordinate, normalized_ambient_coordinate_type_v1();
        id="dgpi-normalized-coordinate"),
     node(:physical_coordinate, tdpi_coordinate_type;
        id="dgpi-physical-coordinate"),
     node(:normalized_metric, normalized_covariant_metric_type_v1();
        id="dgpi-normalized-metric"),
     node(:physical_metric, tdpi_metric_type; id="dgpi-physical-metric")),
    (dgpi_program_binding.coordinate_edge,
     dgpi_program_binding.metric_edge);
    registry=dgpi_program_binding.registry)
const dgpi_prebinding = DGPI._make_forward_graph_binding(
    :field_geometry, dgpi_graph)

const dgpi_support_ref = SpatialSupportRefV1("dgpi-support")
const dgpi_chart_ref = ChartRefV1("dgpi-chart")
const dgpi_frame_ref = CoordinateFrameRefV1("dgpi-frame")
const dgpi_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), UnitSignature()), 3)
const dgpi_periodic_axes = (
    PeriodicAxisV1(2, NonnegativeQuantityV1(1, UnitSignature())),
    PeriodicAxisV1(3, NonnegativeQuantityV1(1, UnitSignature())))
const dgpi_support = SpatialSupportGeneV1(dgpi_support_ref, 3,
    (dgpi_frame_ref,),
    (CoordinateChartGeneV1(dgpi_chart_ref, dgpi_frame_ref,
        dgpi_chart_bounds, dgpi_periodic_axes,
        SpatialProgramRootRefV1(dgpi_coordinate_site, 1,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(dgpi_metric_site, 1,
            chart_coordinate_type_v1(), normalized_covariant_metric_type_v1())),),
    (), dgpi_scale)
const dgpi_coordinate_metric = DGPI.ThreeDCoordinateMetricV4(
    dgpi_support_ref, dgpi_chart_ref, dgpi_coordinate_site, dgpi_metric_site,
    dgpi_prebinding.ast_root_identity_hashes[2],
    dgpi_prebinding.ast_root_identity_hashes[4], tdpi_coordinate_type,
    tdpi_metric_type, dgpi_chart_bounds)
const dgpi_declaration = DGPI.ThreeDPhysicalProviderInputV4(
    "dgpi-declaration", dgpi_boundary, dgpi_coordinate_metric,
    tdpi_profiles_flux)

const dgpi_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const dgpi_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], dgpi_graph;
    fields=(dgpi_support, dgpi_declaration))
const dgpi_candidate = CandidateStatePackageV4("dgpi-candidate",
    dgpi_base._fixture_mission, dgpi_base._fixture_mechanism,
    dgpi_field_genome, dgpi_base._fixture_realization, generic_3d_registry)
const dgpi_mission = (mission="desc-geometry-program-interpreter",
    contract=dgpi_candidate.mission_contract_ref)
const dgpi_bounds = (declaration_hash=canonical_hash(dgpi_declaration),
    scope="candidate-owned-desc-geometry-program")
const dgpi_comparison_scope = ("desc-geometry-program-only",)
const dgpi_scenario = (name="dgpi-manufactured-scenario",
    fixture="interpreter-only")
const dgpi_scenario_scope = (dgpi_scenario.name,)
const dgpi_compiled = DGPI.compile_candidate(dgpi_candidate,
    generic_3d_registry; mission_payload=dgpi_mission,
    bounds_payload=dgpi_bounds, comparison_scope=dgpi_comparison_scope,
    scenario_scope=dgpi_scenario_scope)
const dgpi_subject_binding = DGPI.make_three_d_physical_provider_input_binding(
    dgpi_compiled, generic_3d_registry, dgpi_mission, dgpi_bounds,
    dgpi_comparison_scope, dgpi_scenario_scope, dgpi_scenario,
    dgpi_declaration)
const dgpi_subject = DGPI.ExecutablePhysicalSubjectV4(
    dgpi_compiled.prefix_hash,
    dgpi_candidate.canonical_hashes.genome_bundle_hash,
    dgpi_compiled.minimality_scope.mission_hash,
    dgpi_compiled.minimality_scope.bounds_hash, (dgpi_subject_binding,),
    (dgpi_scenario,),
    (materialization="candidate-owned-desc-geometry-program",
     declaration_hash=canonical_hash(dgpi_declaration)),
    DGPI.derive_capability_obligations(dgpi_compiled))
const dgpi_context = DGPI.make_forward_chain_context(
    dgpi_candidate, dgpi_compiled, generic_3d_registry, dgpi_mission,
    dgpi_bounds, dgpi_comparison_scope, dgpi_scenario_scope, dgpi_subject,
    dgpi_scenario)
const dgpi_bridge_resolution =
    DGPI.compile_three_d_normalized_physical_root_bridge(dgpi_context)
const dgpi_evaluation = DGPI.interpret_desc_geometry_program(
    dgpi_context, dgpi_bridge_resolution, (0.75, 0.23, 0.17))

function run_desc_geometry_program_interpreter_example(io::IO=stdout)
    println(io, "bridge_status=", dgpi_bridge_resolution.status)
    println(io, "interpreter_status=", dgpi_evaluation.status)
    println(io, "geometry_program_interpreted=",
        dgpi_evaluation.geometry_program_interpreted)
    println(io, "geometry_proved=", dgpi_evaluation.geometry_proved)
    println(io, "claim_ceiling=", dgpi_evaluation.claim_ceiling)
    println(io, "credible_physical_device_count=",
        dgpi_evaluation.credible_physical_device_count)
    println(io, "DESC_GEOMETRY_PROGRAM_INTERPRETER_OK")
    dgpi_evaluation
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_geometry_program_interpreter_example()
end
