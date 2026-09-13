# Source-bound HELIOTRON G2 AST candidate fixture, screen-only.
using FusionConceptAI
using JSON3
include(joinpath(@__DIR__, "runtime_v4_three_d_normalized_physical_root_bridge.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceGeometryProgramV4.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2ReferenceInputV4.jl"))
const N2G = TDPI.N2SourceGeometryProgramRuntime
const N2R = TDPI.N2ReferenceInputRuntime

const n2g_root = normpath(joinpath(@__DIR__, ".."))
const n2g_source_path = joinpath(n2g_root, "benchmarks",
    "desc_heliotron_v0173", "HELIOTRON_output.h5")
const n2g_interior_path = joinpath(n2g_root, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_interior_r1", "result.json")
const n2g_normalized_path = joinpath(n2g_root, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_normalize_r3", "result.json")
const n2g_scale = NonnegativeQuantityV1(1, tdpi_length_unit)
const n2g_program = N2G.load_n2_source_geometry_program(
    n2g_source_path, n2g_interior_path, Digest256(
        "fe6258bd0e1368dbc4d0eafef092588e3a95d76842d3c48e4f29c14987d7fcb8"),
    n2g_scale)
const n2g_coordinate_site = FieldOperatorSiteRefV1("n2g-coordinate")
const n2g_metric_site = FieldOperatorSiteRefV1("n2g-metric")
const n2g_binding = N2G.n2_source_geometry_typed_binding(n2g_program,
    n2g_coordinate_site, n2g_metric_site)
const n2g_graph = N2G.n2_source_geometry_graph(n2g_binding)
const n2g_prebinding = TDNPRB._make_forward_graph_binding(
    :field_geometry, n2g_graph)

const n2g_support_ref = SpatialSupportRefV1("n2g-support")
const n2g_chart_ref = ChartRefV1("n2g-chart")
const n2g_frame_ref = CoordinateFrameRefV1("n2g-frame")
const n2g_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), UnitSignature()), 3)
const n2g_periodic_axes = (
    PeriodicAxisV1(2, NonnegativeQuantityV1(1, UnitSignature())),
    PeriodicAxisV1(3, NonnegativeQuantityV1(1, UnitSignature())))
const n2g_support = SpatialSupportGeneV1(n2g_support_ref, 3,
    (n2g_frame_ref,),
    (CoordinateChartGeneV1(n2g_chart_ref, n2g_frame_ref,
        n2g_chart_bounds, n2g_periodic_axes,
        SpatialProgramRootRefV1(n2g_coordinate_site, 1,
            chart_coordinate_type_v1(),
            normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(n2g_metric_site, 1,
            chart_coordinate_type_v1(),
            normalized_covariant_metric_type_v1())),), (), n2g_scale)
const n2g_coordinate_metric = TDNPRB.ThreeDCoordinateMetricV4(
    n2g_support_ref, n2g_chart_ref, n2g_coordinate_site,
    n2g_metric_site, n2g_prebinding.ast_root_identity_hashes[2],
    n2g_prebinding.ast_root_identity_hashes[4],
    tdpi_coordinate_type, tdpi_metric_type, n2g_chart_bounds)

const n2g_subject, n2g_subject_wire_hash = N2R._n2r_load_normalized_result(
    n2g_normalized_path, Digest256(
        "2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25"))
const n2g_boundary = TDNPRB.ThreeDFourierBoundaryV4(
    "source-selected-member-boundary", n2g_subject.field_periods,
    n2g_subject.stellarator_symmetric,
    Tuple(TDNPRB.ThreeDFourierCoefficientV4(row.m, row.n,
        row.coefficient_m) for row in n2g_subject.boundary.radial_modes),
    Tuple(TDNPRB.ThreeDFourierCoefficientV4(row.m, row.n,
        row.coefficient_m) for row in n2g_subject.boundary.vertical_modes))
const n2g_pressure = TDNPRB.ThreeDRadialProfileV4(
    "source-selected-member-pressure", :pressure,
    n2g_subject.pressure_profile.coefficients_by_power,
    tdpi_pressure_unit, tdpi_radial_domain)
const n2g_iota = TDNPRB.ThreeDRadialProfileV4(
    "source-selected-member-iota", :iota,
    n2g_subject.rotational_or_current_profile.coefficients_by_power,
    UnitSignature(), tdpi_radial_domain)
const n2g_profiles = TDNPRB.ThreeDProfilesFluxV4(
    "source-selected-member-profiles", n2g_pressure, n2g_iota,
    n2g_subject.toroidal_flux.value, tdpi_flux_unit)
const n2g_declaration = TDNPRB.ThreeDPhysicalProviderInputV4(
    "source-selected-member-declaration", n2g_boundary,
    n2g_coordinate_metric, n2g_profiles)

const n2g_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const n2g_field_genome = FieldGeometryGenomeV4(20260913,
    GenericThreeDG2Fixture._fixture_refs[2], n2g_graph;
    fields=(n2g_support, n2g_declaration))
const n2g_candidate = CandidateStatePackageV4("n2g-source-candidate",
    n2g_base._fixture_mission, n2g_base._fixture_mechanism,
    n2g_field_genome, n2g_base._fixture_realization, generic_3d_registry)
const n2g_mission = (mission="source-geometry-candidate-binding",
    contract=n2g_candidate.mission_contract_ref)
const n2g_bounds = (declaration_hash=canonical_hash(n2g_declaration),
    source_interior_subject_hash=n2g_program.interior.subject_sha256,
    scope="source-owned-Fourier-Zernike-G2")
const n2g_comparison_scope = ("source-owned-G2-geometry-only",)
const n2g_scenario = (name="source-selected-member-geometry",
    source_class="external_simulation")
const n2g_scenario_scope = (n2g_scenario.name,)
const n2g_compiled = TDNPRB.compile_candidate(n2g_candidate,
    generic_3d_registry; mission_payload=n2g_mission,
    bounds_payload=n2g_bounds,
    comparison_scope=n2g_comparison_scope,
    scenario_scope=n2g_scenario_scope)
const n2g_subject_binding =
    TDNPRB.make_three_d_physical_provider_input_binding(
        n2g_compiled, generic_3d_registry, n2g_mission, n2g_bounds,
        n2g_comparison_scope, n2g_scenario_scope, n2g_scenario,
        n2g_declaration)
const n2g_executable_subject = TDNPRB.ExecutablePhysicalSubjectV4(
    n2g_compiled.prefix_hash,
    n2g_candidate.canonical_hashes.genome_bundle_hash,
    n2g_compiled.minimality_scope.mission_hash,
    n2g_compiled.minimality_scope.bounds_hash,
    (n2g_subject_binding,), (n2g_scenario,),
    (materialization="source-owned-G2-geometry-only",
     interior_subject_hash=n2g_program.interior.subject_sha256),
    TDNPRB.derive_capability_obligations(n2g_compiled))
const n2g_context = TDNPRB.make_forward_chain_context(
    n2g_candidate, n2g_compiled, generic_3d_registry,
    n2g_mission, n2g_bounds, n2g_comparison_scope,
    n2g_scenario_scope, n2g_executable_subject, n2g_scenario)
const n2g_reference_binding = N2R.bind_n2_reference_input(
    n2g_context, n2g_declaration, n2g_source_path,
    n2g_program.interior.source_artifact_sha256,
    n2g_normalized_path, Digest256(
        "2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25");
    validator=TDNPRB.validate_forward_chain_context)
const n2g_bridge = TDNPRB.compile_three_d_normalized_physical_root_bridge(
    n2g_context)
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceGeometryCandidateBindingV4.jl"))
const n2g_candidate_geometry_binding =
    TDNPRB.bind_n2_source_candidate_geometry(
        n2g_context, n2g_binding, n2g_reference_binding, n2g_bridge,
        n2g_source_path, n2g_interior_path)
const n2g_evaluation = TDNPRB.evaluate_n2_source_candidate_geometry(
    n2g_candidate_geometry_binding, n2g_context, n2g_binding,
    n2g_reference_binding, n2g_bridge, n2g_source_path, n2g_interior_path,
    N2G.N2SourceUnitTurnChartV4(0.47, 1.1/(2pi), 0.09*19/(2pi)))

function run_n2_source_geometry_candidate_example(io::IO=stdout)
    println(io, "candidate_hash=", n2g_context.candidate_hash)
    println(io, "reference_binding_hash=", n2g_reference_binding.binding_hash)
    println(io, "source_geometry_program_hash=", canonical_hash(n2g_program))
    println(io, "bridge_status=", n2g_bridge.status)
    println(io, "candidate_geometry_binding_hash=",
        n2g_candidate_geometry_binding.binding_hash)
    println(io, "source_geometry_coordinate=",
        n2g_evaluation.source_geometry.coordinate)
    println(io, "geometry_proved=false")
    println(io, "provider_executed=false")
    println(io, "physical_validation=unsupported")
    println(io, "credible_device_count=0")
    n2g_bridge
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_n2_source_geometry_candidate_example()
end
