"""Manufactured typed 3-D geometry/profile declaration and exact gap example.

The complete current G2 fixture still reports every missing physical-input
edge.  A second manufactured fixture closes only geometry/profile ownership and
therefore retains the four deferred multi-region input gaps.  No provider or
solver is selected or executed.
"""

using FusionConceptAI

module ThreeDPhysicalProviderInputRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ThreeDPhysicalProviderInputV4.jl"))
end

module GenericThreeDG2Fixture
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
end

const TDPI = ThreeDPhysicalProviderInputRuntime

# Revalidate the existing generic G2 fixture and compile its exact missing
# physical-input declarations rather than guessing them from graph dimension.
const generic_3d_candidate = GenericThreeDG2Fixture.candidate
const generic_3d_registry = GenericThreeDG2Fixture.registry
const generic_3d_scenario = GenericThreeDG2Fixture.scenario
const generic_3d_mission = (mission="generic-g2-three-d-input-gap",
    contract=generic_3d_candidate.mission_contract_ref)
const generic_3d_bounds = (scope="generic-g2-structural-fixture",)
const generic_3d_comparison_scope = ("typed-three-d-input-gap",)
const generic_3d_scenario_scope = (generic_3d_scenario.name,)
const generic_3d_compiled = TDPI.compile_candidate(generic_3d_candidate,
    generic_3d_registry; mission_payload=generic_3d_mission,
    bounds_payload=generic_3d_bounds,
    comparison_scope=generic_3d_comparison_scope,
    scenario_scope=generic_3d_scenario_scope)
const generic_3d_subject = TDPI.ExecutablePhysicalSubjectV4(
    generic_3d_compiled.prefix_hash,
    generic_3d_candidate.canonical_hashes.genome_bundle_hash,
    generic_3d_compiled.minimality_scope.mission_hash,
    generic_3d_compiled.minimality_scope.bounds_hash,
    ((binding_kind="generic-g2-structural-only",),),
    (generic_3d_scenario,), (materialization="generic-g2-no-3d-input",),
    TDPI.derive_capability_obligations(generic_3d_compiled))
const generic_3d_context = TDPI.make_forward_chain_context(
    generic_3d_candidate, generic_3d_compiled, generic_3d_registry,
    generic_3d_mission, generic_3d_bounds, generic_3d_comparison_scope,
    generic_3d_scenario_scope, generic_3d_subject, generic_3d_scenario)
const generic_3d_input_resolution =
    TDPI.resolve_three_d_physical_provider_input(generic_3d_context)

# A bounded manufactured declaration proving only typed geometry/profile
# compilation and identity binding.
const tdpi_length_unit = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const tdpi_metric_unit = UnitSignature((0, 2, 0, 0, 0, 0, 0))
const tdpi_pressure_unit = UnitSignature((1, -1, -2, 0, 0, 0, 0))
const tdpi_flux_unit = UnitSignature((1, 2, -2, -1, 0, 0, 0))
const tdpi_coordinate_type = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), tdpi_length_unit)
const tdpi_metric_type = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), tdpi_metric_unit)
const tdpi_coordinate_site = FieldOperatorSiteRefV1("tdpi-coordinate-map-root")
const tdpi_metric_site = FieldOperatorSiteRefV1("tdpi-metric-root")
const tdpi_coordinate_ast = ast_leaf(:constant, tdpi_coordinate_type;
    parameters=(value=(0.0, 0.0, 0.0),))
const tdpi_metric_ast = ast_leaf(:constant, tdpi_metric_type;
    parameters=(value=(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),))
const tdpi_field_graph = TypedOperatorHypergraphV1(
    (node(:coordinate, tdpi_coordinate_type; id="tdpi-coordinate"),
     node(:metric, tdpi_metric_type; id="tdpi-metric")),
    (TypedHyperedge(tdpi_coordinate_site.value, (), (1,),
         tdpi_coordinate_ast, :constraint),
     TypedHyperedge(tdpi_metric_site.value, (), (2,),
         tdpi_metric_ast, :constraint)))
const tdpi_prebinding = TDPI._make_forward_graph_binding(
    :field_geometry, tdpi_field_graph)
const tdpi_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(-1, 1, false), UnitSignature()), 3)
const tdpi_support_ref = SpatialSupportRefV1("tdpi-support")
const tdpi_chart_ref = ChartRefV1("tdpi-chart")
const tdpi_support = SpatialSupportGeneV1(tdpi_support_ref, 3,
    (CoordinateFrameRefV1("tdpi-frame"),),
    (CoordinateChartGeneV1(tdpi_chart_ref,
        CoordinateFrameRefV1("tdpi-frame"), tdpi_chart_bounds, (),
        SpatialProgramRootRefV1(tdpi_coordinate_site, 1,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(tdpi_metric_site, 1,
            chart_coordinate_type_v1(), normalized_covariant_metric_type_v1())),),
    (), NonnegativeQuantityV1(1, tdpi_length_unit))
const tdpi_coordinate_metric = TDPI.ThreeDCoordinateMetricV4(
    tdpi_support_ref, tdpi_chart_ref, tdpi_coordinate_site, tdpi_metric_site,
    tdpi_prebinding.ast_root_identity_hashes[1],
    tdpi_prebinding.ast_root_identity_hashes[2], tdpi_coordinate_type,
    tdpi_metric_type, tdpi_chart_bounds)
const tdpi_fourier_boundary = TDPI.ThreeDFourierBoundaryV4(
    "tdpi-manufactured-boundary", 5, true,
    (TDPI.ThreeDFourierCoefficientV4(0, 0, 5.5),
     TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),
     TDPI.ThreeDFourierCoefficientV4(1, 1, 0.08)),
    (TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),
     TDPI.ThreeDFourierCoefficientV4(1, -1, -0.08)))
const tdpi_radial_domain = QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), UnitSignature())
const tdpi_pressure_profile = TDPI.ThreeDRadialProfileV4(
    "tdpi-pressure", :pressure, (1000.0, -1000.0), tdpi_pressure_unit,
    tdpi_radial_domain)
const tdpi_iota_profile = TDPI.ThreeDRadialProfileV4(
    "tdpi-iota", :iota, (0.4, 0.1), UnitSignature(), tdpi_radial_domain)
const tdpi_profiles_flux = TDPI.ThreeDProfilesFluxV4(
    "tdpi-profiles", tdpi_pressure_profile, tdpi_iota_profile, 1.0,
    tdpi_flux_unit)
const tdpi_input_declaration = TDPI.ThreeDPhysicalProviderInputV4(
    "tdpi-manufactured-geometry-profile", tdpi_fourier_boundary,
    tdpi_coordinate_metric, tdpi_profiles_flux)

const tdpi_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const tdpi_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdpi_field_graph;
    fields=(tdpi_support, tdpi_input_declaration))
const tdpi_candidate = CandidateStatePackageV4(
    "tdpi-manufactured-geometry-profile-candidate", tdpi_base._fixture_mission,
    tdpi_base._fixture_mechanism, tdpi_field_genome,
    tdpi_base._fixture_realization, generic_3d_registry)
const tdpi_mission = (mission="typed-3d-geometry-profile-gap-compiler",
    contract=tdpi_candidate.mission_contract_ref)
const tdpi_bounds = (declaration_hash=canonical_hash(tdpi_input_declaration),
    scope="manufactured-input-only")
const tdpi_comparison_scope = ("typed-three-d-geometry-profile-only",)
const tdpi_scenario = (name="tdpi-manufactured-scenario",
    fixture="compiler-validator-only")
const tdpi_scenario_scope = (tdpi_scenario.name,)
const tdpi_compiled = TDPI.compile_candidate(tdpi_candidate,
    generic_3d_registry; mission_payload=tdpi_mission,
    bounds_payload=tdpi_bounds, comparison_scope=tdpi_comparison_scope,
    scenario_scope=tdpi_scenario_scope)
const tdpi_subject_binding = TDPI.make_three_d_physical_provider_input_binding(
    tdpi_compiled, generic_3d_registry, tdpi_mission, tdpi_bounds,
    tdpi_comparison_scope, tdpi_scenario_scope, tdpi_scenario,
    tdpi_input_declaration)
const tdpi_subject = TDPI.ExecutablePhysicalSubjectV4(
    tdpi_compiled.prefix_hash, tdpi_candidate.canonical_hashes.genome_bundle_hash,
    tdpi_compiled.minimality_scope.mission_hash,
    tdpi_compiled.minimality_scope.bounds_hash, (tdpi_subject_binding,),
    (tdpi_scenario,), (materialization="manufactured-geometry-profile-only",
        declaration_hash=canonical_hash(tdpi_input_declaration)),
    TDPI.derive_capability_obligations(tdpi_compiled))
const tdpi_context = TDPI.make_forward_chain_context(tdpi_candidate,
    tdpi_compiled, generic_3d_registry, tdpi_mission, tdpi_bounds,
    tdpi_comparison_scope, tdpi_scenario_scope, tdpi_subject, tdpi_scenario)
const tdpi_input_resolution =
    TDPI.resolve_three_d_physical_provider_input(tdpi_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", generic_3d_input_resolution.status)
    println("generic_gaps=", join(generic_3d_input_resolution.recoverable_gaps, ","))
    println("typed_status=", tdpi_input_resolution.status)
    println("typed_declaration_hash=", tdpi_input_resolution.declaration_hash)
    println("typed_binding_hash=", tdpi_input_resolution.binding_hash)
    println("typed_remaining_gaps=", join(tdpi_input_resolution.recoverable_gaps, ","))
    println("provider_selected=false")
    println("solver_executed=false")
    println("claim_ceiling=screen_only")
end
