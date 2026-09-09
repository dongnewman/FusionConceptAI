"""Generic-gap and manufactured input-complete discretization examples."""

include(joinpath(@__DIR__, "runtime_v4_three_d_oriented_interface_input.jl"))
Base.include(TDOI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDDiscretizationControlsV4.jl"))

const tddc_generic_resolution =
    TDOI.resolve_three_d_discretization_controls(generic_3d_context)

const tddc_spaces = let values = TDOI.ThreeDDiscreteSpaceV4[]
    append!(values, (x.volume_space for x in tdoi_declaration.regions))
    for interface in tdoi_declaration.interfaces
        push!(values, interface.minus_trace_space, interface.plus_trace_space,
            interface.multiplier_space)
    end
    Tuple(TDOI.ThreeDDiscreteSpaceControlV4(x.space_id,
        x.polynomial_order, x.quadrature_order)
        for x in sort(values, by=x -> x.space_id))
end

const tddc_mesh = TDOI.ThreeDMeshResolutionControlV4(
    "tddc-manufactured-two-region-mesh",
    QualifiedRefV1("conforming-hexahedral-mortar", "v1"),
    0.05, 16, 32, 12, 2)
const tddc_nonlinear = TDOI.ThreeDNonlinearSolverPolicyV4(
    TDOI.trust_region_newton, TDOI.assembled_jacobian,
    1.0e-10, 1.0e-8, 1.0e-10, 80)
const tddc_linear = TDOI.ThreeDLinearSolverPolicyV4(
    TDOI.gmres, TDOI.amg_preconditioner, 1.0e-10, 2000, 80)
const tddc_refinement = TDOI.ThreeDRefinementPolicyV4(
    TDOI.residual_adaptive_refinement, 1.0e-4, 3, 2)
const tddc_declaration = TDOI.ThreeDDiscretizationControlDeclarationV4(
    "tddc-manufactured-controls", tddc_mesh, tddc_spaces,
    tddc_nonlinear, tddc_linear, tddc_refinement)

const tddc_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdoi_graph;
    fields=(tdoi_left_support, tdoi_right_support,
        tdoi_interface_support, tdoi_declaration, tddc_declaration))
const tddc_candidate = CandidateStatePackageV4(
    "tddc-manufactured-discretization-candidate",
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mission,
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mechanism,
    tddc_field_genome,
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_realization,
    generic_3d_registry)
const tddc_scenario = (name="tddc-manufactured-scenario",
    fixture="discretization-input-compiler-only")
const tddc_mission = (mission="typed-three-d-discretization-controls",
    contract=tddc_candidate.mission_contract_ref)
const tddc_bounds = (scope="manufactured-discretization-input-only",
    declaration_hash=canonical_hash(tddc_declaration))
const tddc_comparison_scope = ("typed-three-d-discretization-controls",)
const tddc_scenario_scope = (tddc_scenario.name,)
const tddc_compiled = TDOI.compile_candidate(tddc_candidate,
    generic_3d_registry; mission_payload=tddc_mission,
    bounds_payload=tddc_bounds, comparison_scope=tddc_comparison_scope,
    scenario_scope=tddc_scenario_scope)
const tddc_oriented_binding = TDOI.make_three_d_oriented_interface_binding(
    tddc_compiled, generic_3d_registry, tddc_mission, tddc_bounds,
    tddc_comparison_scope, tddc_scenario_scope, tddc_scenario,
    tdoi_declaration)
const tddc_binding = TDOI.make_three_d_discretization_control_binding(
    tddc_compiled, generic_3d_registry, tddc_mission, tddc_bounds,
    tddc_comparison_scope, tddc_scenario_scope, tddc_scenario,
    tddc_declaration, tddc_oriented_binding)
const tddc_subject = TDOI.ExecutablePhysicalSubjectV4(
    tddc_compiled.prefix_hash,
    tddc_candidate.canonical_hashes.genome_bundle_hash,
    tddc_compiled.minimality_scope.mission_hash,
    tddc_compiled.minimality_scope.bounds_hash,
    (tddc_oriented_binding, tddc_binding), (tddc_scenario,),
    (materialization="manufactured-discretization-input-only",
     declaration_hash=canonical_hash(tddc_declaration),
     binding_hash=canonical_hash(tddc_binding)),
    TDOI.derive_capability_obligations(tddc_compiled))
const tddc_context = TDOI.make_forward_chain_context(tddc_candidate,
    tddc_compiled, generic_3d_registry, tddc_mission, tddc_bounds,
    tddc_comparison_scope, tddc_scenario_scope, tddc_subject,
    tddc_scenario)
const tddc_resolution =
    TDOI.resolve_three_d_discretization_controls(tddc_context)
const tddc_input = something(tddc_resolution.input)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", tddc_generic_resolution.status)
    println("generic_gaps=", join(tddc_generic_resolution.recoverable_gaps, ","))
    println("manufactured_status=", tddc_resolution.status)
    println("mesh_id=", tddc_input.mesh.mesh_id)
    println("discrete_space_count=", length(tddc_input.discrete_spaces))
    println("provider_executed=false")
    println("solver_executed=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("p5_ready=false")
    println("terminal_authority=false")
end
