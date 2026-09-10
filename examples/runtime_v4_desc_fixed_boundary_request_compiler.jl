"""Candidate-bound DESC fixed-boundary request-gap fixtures.

The declared fixture exercises candidate/context binding and exact closed-gap
compilation only.  Current typed geometry cannot prove its proposed DESC
coordinate convention, so it cannot emit a request.  It does not select DESC,
serialize files, start a process, or run a solver.
"""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_three_d_physical_input_composition.jl"))
Base.include(TDPIC, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCFixedBoundaryRequestCompilerV4.jl"))
const DFBRC = TDPIC

# The already-accepted composition fixture has no DESC convention declaration
# or provider-specific request declaration/binding.  Its result stays an exact
# recoverable gap rather than inventing a mapping.
const dfbrc_current_fixture_resolution =
    DFBRC.compile_desc_fixed_boundary_request(tdpic_context)

# DESC-eligible Fourier/profile values.  In particular, Z(-1,0) belongs to the
# stellarator-symmetric sine basis, the orientation is strictly right-handed,
# and pressure closes at rho=1.
const dfbrc_boundary = DFBRC.ThreeDFourierBoundaryV4(
    "dfbrc-desc-boundary", 5, true,
    (DFBRC.ThreeDFourierCoefficientV4(0, 0, 5.5),
     DFBRC.ThreeDFourierCoefficientV4(1, 0, 0.4),
     DFBRC.ThreeDFourierCoefficientV4(1, 1, 0.05)),
    (DFBRC.ThreeDFourierCoefficientV4(-1, 0, -0.4),
     DFBRC.ThreeDFourierCoefficientV4(-1, 1, -0.05)))
const dfbrc_profiles = DFBRC.ThreeDProfilesFluxV4(
    "dfbrc-desc-profiles",
    DFBRC.ThreeDRadialProfileV4("dfbrc-pressure", :pressure,
        (1000.0, -1000.0), tdpic_pressure_unit, tdpic_radial_domain),
    DFBRC.ThreeDRadialProfileV4("dfbrc-iota", :iota,
        (0.4, 0.1), tdpic_unit, tdpic_radial_domain),
    1.0, tdpic_flux_unit)
const dfbrc_physical_declaration = DFBRC.ThreeDPhysicalProviderInputV4(
    "dfbrc-desc-geometry-profile", dfbrc_boundary,
    tdpic_coordinate_metric, dfbrc_profiles)
const dfbrc_support_mapping =
    DFBRC.declare_three_d_physical_region_support_mapping(
        dfbrc_physical_declaration, tdpic_oriented_declaration;
        declaration_id="dfbrc-physical-to-region-supports",
        region_supports=(
            (region_id="right-region", support_ref=tdpic_right_support_ref),
            (region_id="left-region", support_ref=tdpic_left_support_ref)))
const dfbrc_compatibility = DFBRC.declare_desc_geometry_convention(
    dfbrc_physical_declaration, dfbrc_support_mapping;
    declaration_id="dfbrc-desc-coordinate-convention")
const dfbrc_request_declaration =
    DFBRC.DESCFixedBoundaryRequestDeclarationV4(
        "dfbrc-desc-request-controls", dfbrc_compatibility;
        L=4, M=4, N=2, L_grid=8, M_grid=8, N_grid=6,
        max_iterations=80, ftol=1.0e-8, xtol=1.0e-8, gtol=1.0e-8,
        pressure_step=0.5, boundary_step=0.5, shaping_first=true,
        max_force_normalized_magnetic=1.0e-3,
        max_fixed_constraint_error=1.0e-10, min_sqrt_g=0.0)

const dfbrc_fields = (
    tdpic_left_support, tdpic_right_support, tdpic_interface_support,
    dfbrc_physical_declaration, dfbrc_support_mapping,
    tdpic_region_law_set_declaration, tdpic_oriented_declaration,
    tdpic_residual_declaration, tdpic_discretization_declaration,
    dfbrc_compatibility, dfbrc_request_declaration)
const dfbrc_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdpic_graph;
    fields=dfbrc_fields)
const dfbrc_candidate = CandidateStatePackageV4(
    "dfbrc-manufactured-desc-request-candidate",
    tdpic_base._fixture_mission, tdpic_base._fixture_mechanism,
    dfbrc_field_genome, tdpic_base._fixture_realization,
    generic_3d_registry)
const dfbrc_scenario = (name="dfbrc-manufactured-desc-request-scenario",
    fixture="request-compilation-only")
const dfbrc_mission = (mission="candidate-bound-desc-request",
    contract=dfbrc_candidate.mission_contract_ref)
const dfbrc_bounds = (scope="desc-fixed-boundary-request-only",
    region_count=2)
const dfbrc_comparison = ("desc-fixed-boundary-request",)
const dfbrc_scenarios = (dfbrc_scenario.name,)
const dfbrc_compiled = DFBRC.compile_candidate(dfbrc_candidate,
    generic_3d_registry; mission_payload=dfbrc_mission,
    bounds_payload=dfbrc_bounds, comparison_scope=dfbrc_comparison,
    scenario_scope=dfbrc_scenarios)

const dfbrc_physical_binding =
    DFBRC.make_three_d_physical_provider_input_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_physical_declaration)
const dfbrc_oriented_binding =
    DFBRC.make_three_d_oriented_interface_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        tdpic_oriented_declaration)
const dfbrc_region_law_set_binding =
    DFBRC.make_three_d_region_law_set_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        tdpic_region_law_set_declaration, dfbrc_oriented_binding)
const dfbrc_support_mapping_binding =
    DFBRC.make_three_d_physical_region_support_mapping_binding(
        dfbrc_compiled, generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_physical_declaration, tdpic_oriented_declaration,
        dfbrc_support_mapping)
const dfbrc_residual_binding =
    DFBRC.make_three_d_governing_residual_jacobian_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        tdpic_residual_declaration)
const dfbrc_discretization_binding =
    DFBRC.make_three_d_discretization_control_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        tdpic_discretization_declaration, dfbrc_oriented_binding)
const dfbrc_composition_binding =
    DFBRC.make_three_d_physical_input_composition_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_physical_declaration, dfbrc_support_mapping,
        tdpic_region_law_set_declaration, tdpic_oriented_declaration,
        tdpic_residual_declaration, tdpic_discretization_declaration,
        dfbrc_physical_binding, dfbrc_support_mapping_binding,
        dfbrc_region_law_set_binding, dfbrc_oriented_binding,
        dfbrc_residual_binding, dfbrc_discretization_binding)
const dfbrc_request_binding =
    DFBRC.make_desc_fixed_boundary_request_binding(dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_composition_binding, dfbrc_physical_binding,
        dfbrc_support_mapping_binding, dfbrc_region_law_set_binding,
        dfbrc_oriented_binding, dfbrc_residual_binding,
        dfbrc_discretization_binding, dfbrc_compatibility,
        dfbrc_request_declaration)

const dfbrc_component_bindings = (
    dfbrc_physical_binding, dfbrc_support_mapping_binding,
    dfbrc_region_law_set_binding, dfbrc_oriented_binding,
    dfbrc_residual_binding, dfbrc_discretization_binding,
    dfbrc_composition_binding)
const dfbrc_subject = DFBRC.ExecutablePhysicalSubjectV4(
    dfbrc_compiled.prefix_hash,
    dfbrc_candidate.canonical_hashes.genome_bundle_hash,
    dfbrc_compiled.minimality_scope.mission_hash,
    dfbrc_compiled.minimality_scope.bounds_hash,
    (dfbrc_component_bindings..., dfbrc_request_binding),
    (dfbrc_scenario,),
    (materialization="manufactured-desc-request-compilation",
     composition_binding_hash=canonical_hash(dfbrc_composition_binding),
     request_binding_hash=canonical_hash(dfbrc_request_binding)),
    DFBRC.derive_capability_obligations(dfbrc_compiled))
const dfbrc_context = DFBRC.make_forward_chain_context(dfbrc_candidate,
    dfbrc_compiled, generic_3d_registry, dfbrc_mission, dfbrc_bounds,
    dfbrc_comparison, dfbrc_scenarios, dfbrc_subject, dfbrc_scenario)
const dfbrc_composition_resolution =
    DFBRC.compose_three_d_physical_inputs(dfbrc_context)
const dfbrc_resolution =
    DFBRC.compile_desc_fixed_boundary_request(dfbrc_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("current_fixture_status=",
        dfbrc_current_fixture_resolution.status)
    println("current_fixture_gaps=",
        join(dfbrc_current_fixture_resolution.recoverable_gaps, ","))
    println("declared_fixture_status=", dfbrc_resolution.status)
    println("declared_fixture_gaps=",
        join(dfbrc_resolution.recoverable_gaps, ","))
    println("request_emitted=", dfbrc_resolution.request !== nothing)
    println("provider_selected=false")
    println("provider_executed=false")
    println("solver_execution_attempted=false")
    println("solver_executed=false")
    println("physical_validation=false")
    println("engineering_validation=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("p5_ready=false")
    println("terminal_authority=false")
end
