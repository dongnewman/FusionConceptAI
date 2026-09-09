using Test

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_discretization_controls.jl"))

const TDDCH = digest256_text("three-d-discretization-controls-adversarial")

function tddc_private_binding(; declaration_hash=tddc_binding.declaration_hash,
        candidate_hash=tddc_binding.candidate_hash,
        genome_hash=tddc_binding.field_geometry_genome_hash,
        graph_hash=tddc_binding.field_geometry_graph_hash,
        graph_binding_hash=tddc_binding.field_geometry_graph_binding_hash,
        mesh_id=tddc_binding.mesh_id,
        space_hashes=tddc_binding.discrete_space_identity_hashes,
        oriented_declaration_hash=tddc_binding.oriented_declaration_hash,
        oriented_binding_hash=tddc_binding.oriented_binding_hash,
        region_hashes=tddc_binding.oriented_region_ref_hashes,
        interface_hashes=tddc_binding.oriented_interface_ref_hashes,
        mission_hash=tddc_binding.mission_hash,
        bounds_hash=tddc_binding.bounds_hash,
        scenario_hash=tddc_binding.scenario_hash)
    body = TDOI._tddc_binding_body(declaration_hash, candidate_hash,
        genome_hash, graph_hash, graph_binding_hash, mesh_id, space_hashes,
        oriented_declaration_hash, oriented_binding_hash, region_hashes,
        interface_hashes, mission_hash, bounds_hash, scenario_hash)
    TDOI.ThreeDDiscretizationControlBindingV4(TDOI._TDDC_TOKEN,
        declaration_hash, candidate_hash, genome_hash, graph_hash,
        graph_binding_hash, mesh_id, space_hashes,
        oriented_declaration_hash, oriented_binding_hash, region_hashes,
        interface_hashes, mission_hash, bounds_hash, scenario_hash,
        canonical_hash(body))
end

function tddc_context_with_bindings(bindings, tag::String)
    subject = TDOI.ExecutablePhysicalSubjectV4(tddc_compiled.prefix_hash,
        tddc_candidate.canonical_hashes.genome_bundle_hash,
        tddc_compiled.minimality_scope.mission_hash,
        tddc_compiled.minimality_scope.bounds_hash, Tuple(bindings),
        (tddc_scenario,), (materialization=tag,),
        TDOI.derive_capability_obligations(tddc_compiled))
    TDOI.make_forward_chain_context(tddc_candidate, tddc_compiled,
        generic_3d_registry, tddc_mission, tddc_bounds,
        tddc_comparison_scope, tddc_scenario_scope, subject, tddc_scenario)
end

@testset "generic G2 retains exact discretization gaps" begin
    @test TDOI.validate_forward_chain_context(generic_3d_context) ==
        generic_3d_context.context_hash
    @test tddc_generic_resolution.status === :recoverable_gap
    @test tddc_generic_resolution.input === nothing
    @test tddc_generic_resolution.recoverable_gaps ==
        TDOI._TDDC_REQUIRED_GAPS
    @test canonical_hash(tddc_generic_resolution) ==
        tddc_generic_resolution.resolution_hash
end

@testset "manufactured controls are exact current-context input" begin
    @test TDOI.validate_forward_chain_context(tddc_context) ==
        tddc_context.context_hash
    @test canonical_hash(tddc_declaration) == tddc_declaration.declaration_hash
    @test canonical_hash(tddc_binding) == tddc_binding.binding_hash
    @test tddc_resolution.status === :input_complete
    @test tddc_resolution.input === tddc_input
    @test isempty(tddc_resolution.recoverable_gaps)
    @test canonical_hash(tddc_resolution) == tddc_resolution.resolution_hash
    @test canonical_hash(tddc_input) == tddc_input.input_hash
    @test TDOI.validate_three_d_discretization_control_input(tddc_context,
        tddc_input) == tddc_input.input_hash

    graph = TDOI.forward_graph_binding(tddc_context, :field_geometry)
    @test tddc_binding.candidate_hash == tddc_context.candidate_hash
    @test tddc_binding.field_geometry_genome_hash ==
        field_geometry_hash(tddc_candidate.field_geometry_genome_ref)
    @test tddc_binding.field_geometry_graph_hash == graph.canonical_graph_hash
    @test tddc_binding.field_geometry_graph_binding_hash == canonical_hash(graph)
    @test tddc_binding.mesh_id == tddc_mesh.mesh_id
    @test tddc_binding.oriented_declaration_hash ==
        canonical_hash(tdoi_declaration)
    @test tddc_binding.oriented_binding_hash ==
        canonical_hash(tddc_oriented_binding)
    @test tddc_binding.mission_hash == TDOI._runtime_decl_hash(tddc_mission)
    @test tddc_binding.bounds_hash == TDOI._runtime_decl_hash(tddc_bounds)
    @test tddc_binding.scenario_hash == tddc_context.scenario_hash

    regions, interfaces = TDOI._tdoi_compile_declaration(tddc_candidate,
        graph, tdoi_declaration)
    spaces = TDOI._tddc_oriented_spaces(regions, interfaces)
    @test Tuple(x.space_id for x in tddc_input.discrete_spaces) ==
        Tuple(x.space_id for x in spaces)
    @test tddc_binding.discrete_space_identity_hashes ==
        Tuple(canonical_hash(x) for x in spaces)
    @test tddc_binding.oriented_region_ref_hashes ==
        Tuple(x.ref_hash for x in regions)
    @test tddc_binding.oriented_interface_ref_hashes ==
        Tuple(x.ref_hash for x in interfaces)
    @test all(zip(tddc_input.discrete_spaces, spaces)) do pair
        pair[1].polynomial_order == pair[2].polynomial_order &&
            pair[1].quadrature_order == pair[2].quadrature_order
    end
    @test tddc_input.mesh.radial_resolution == 16
    @test tddc_input.mesh.poloidal_resolution == 32
    @test tddc_input.mesh.toroidal_resolution == 12
    @test tddc_input.nonlinear_policy.method === TDOI.trust_region_newton
    @test tddc_input.nonlinear_policy.jacobian_policy ===
        TDOI.assembled_jacobian
    @test tddc_input.linear_policy.method === TDOI.gmres
    @test tddc_input.linear_policy.preconditioner === TDOI.amg_preconditioner
    @test tddc_input.refinement_policy.strategy ===
        TDOI.residual_adaptive_refinement
end

@testset "controls and policies reject malformed values" begin
    family = QualifiedRefV1("mesh", "v1")
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "wild*", family, 0.1, 2, 2, 1, 1)
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "zero-spacing", family, 0.0, 2, 2, 1, 1)
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "nan-spacing", family, NaN, 2, 2, 1, 1)
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "bool-resolution", family, 0.1, true, 2, 1, 1)
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "low-resolution", family, 0.1, 1, 2, 1, 1)
    @test_throws ArgumentError TDOI.ThreeDMeshResolutionControlV4(
        "high-order", family, 0.1, 2, 2, 1, 13)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceControlV4(
        "zero-order", 0, 2)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceControlV4(
        "high-quadrature", 2, 33)
    @test_throws ArgumentError TDOI.ThreeDNonlinearSolverPolicyV4(
        TDOI.trust_region_newton, TDOI.assembled_jacobian,
        0.0, 1.0e-8, 1.0e-8, 10)
    @test_throws ArgumentError TDOI.ThreeDNonlinearSolverPolicyV4(
        TDOI.line_search_newton, TDOI.matrix_free_jacobian,
        1.0e-8, Inf, 1.0e-8, 10)
    @test_throws ArgumentError TDOI.ThreeDNonlinearSolverPolicyV4(
        TDOI.line_search_newton, TDOI.matrix_free_jacobian,
        1.0e-8, 1.0e-8, 1.0e-8, true)
    @test_throws ArgumentError TDOI.ThreeDLinearSolverPolicyV4(
        TDOI.sparse_direct, TDOI.amg_preconditioner, 1.0e-8, 10, 1)
    @test_throws ArgumentError TDOI.ThreeDLinearSolverPolicyV4(
        TDOI.sparse_direct, TDOI.no_preconditioner, 1.0e-8, 10, 2)
    @test_throws ArgumentError TDOI.ThreeDLinearSolverPolicyV4(
        TDOI.minres, TDOI.ilu_preconditioner, 1.0e-8, 10, 20)
    @test_throws ArgumentError TDOI.ThreeDLinearSolverPolicyV4(
        TDOI.gmres, TDOI.ilu_preconditioner, -1.0, 10, 20)
    @test_throws ArgumentError TDOI.ThreeDRefinementPolicyV4(
        TDOI.uniform_refinement, 0.0, 1, 2)
    @test_throws ArgumentError TDOI.ThreeDRefinementPolicyV4(
        TDOI.uniform_refinement, 1.0e-4, 13, 2)
    @test_throws ArgumentError TDOI.ThreeDRefinementPolicyV4(
        TDOI.uniform_refinement, 1.0e-4, 1, 5)
    @test_throws ArgumentError TDOI.ThreeDDiscretizationControlDeclarationV4(
        "mutable-spaces", tddc_mesh, collect(tddc_spaces), tddc_nonlinear,
        tddc_linear, tddc_refinement)
    @test_throws ArgumentError TDOI.ThreeDDiscretizationControlDeclarationV4(
        "duplicate-space", tddc_mesh, (tddc_spaces[1], tddc_spaces[1]),
        tddc_nonlinear, tddc_linear, tddc_refinement)

    changed = TDOI.ThreeDDiscreteSpaceControlV4(
        tddc_spaces[1].space_id, tddc_spaces[1].polynomial_order + 1,
        tddc_spaces[1].quadrature_order)
    mismatched = TDOI.ThreeDDiscretizationControlDeclarationV4(
        "mismatched-oriented-space", tddc_mesh,
        (changed, tddc_spaces[2:end]...), tddc_nonlinear, tddc_linear,
        tddc_refinement)
    mismatch_genome = FieldGeometryGenomeV4(20260910,
        GenericThreeDG2Fixture._fixture_refs[2], tdoi_graph;
        fields=(tdoi_left_support, tdoi_right_support,
            tdoi_interface_support, tdoi_declaration, mismatched))
    mismatch_candidate = CandidateStatePackageV4("tddc-mismatch",
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mission,
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mechanism,
        mismatch_genome,
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_realization,
        generic_3d_registry)
    mismatch_compiled = TDOI.compile_candidate(mismatch_candidate,
        generic_3d_registry; mission_payload=tddc_mission,
        bounds_payload=tddc_bounds, comparison_scope=tddc_comparison_scope,
        scenario_scope=tddc_scenario_scope)
    mismatch_oriented = TDOI.make_three_d_oriented_interface_binding(
        mismatch_compiled, generic_3d_registry, tddc_mission, tddc_bounds,
        tddc_comparison_scope, tddc_scenario_scope, tddc_scenario,
        tdoi_declaration)
    @test_throws ArgumentError TDOI.make_three_d_discretization_control_binding(
        mismatch_compiled, generic_3d_registry, tddc_mission, tddc_bounds,
        tddc_comparison_scope, tddc_scenario_scope, tddc_scenario,
        mismatched, mismatch_oriented)
end

@testset "subject binding is exact and fail-closed" begin
    absent_context = tddc_context_with_bindings(
        (tddc_oriented_binding,), "absent-discretization-binding")
    absent = TDOI.resolve_three_d_discretization_controls(absent_context)
    @test absent.status === :recoverable_gap
    @test absent.input === nothing
    @test absent.recoverable_gaps ==
        (TDOI._TDDC_REQUIRED_GAPS[2],)

    ambiguous_context = tddc_context_with_bindings(
        (tddc_oriented_binding, tddc_binding, tddc_binding),
        "ambiguous-discretization-binding")
    ambiguous = TDOI.resolve_three_d_discretization_controls(ambiguous_context)
    @test ambiguous.status === :recoverable_gap
    @test ambiguous.recoverable_gaps ==
        ("ambiguous_three_d_discretization_controls_subject_binding",)

    foreign_binding = tddc_private_binding(candidate_hash=TDDCH)
    @test canonical_hash(foreign_binding) == foreign_binding.binding_hash
    foreign_context = tddc_context_with_bindings(
        (tddc_oriented_binding, foreign_binding),
        "foreign-discretization-binding")
    @test_throws ArgumentError TDOI.resolve_three_d_discretization_controls(
        foreign_context)

    forged_binding = TDOI.ThreeDDiscretizationControlBindingV4(
        TDOI._TDDC_TOKEN, tddc_binding.declaration_hash,
        tddc_binding.candidate_hash, tddc_binding.field_geometry_genome_hash,
        tddc_binding.field_geometry_graph_hash,
        tddc_binding.field_geometry_graph_binding_hash, tddc_binding.mesh_id,
        tddc_binding.discrete_space_identity_hashes,
        tddc_binding.oriented_declaration_hash,
        tddc_binding.oriented_binding_hash,
        tddc_binding.oriented_region_ref_hashes,
        tddc_binding.oriented_interface_ref_hashes,
        tddc_binding.mission_hash, tddc_binding.bounds_hash,
        tddc_binding.scenario_hash, TDDCH)
    @test_throws ArgumentError canonical_hash(forged_binding)
end

@testset "input and manifest retain zero authority" begin
    types = (TDOI.ThreeDMeshResolutionControlV4,
        TDOI.ThreeDDiscreteSpaceControlV4,
        TDOI.ThreeDNonlinearSolverPolicyV4,
        TDOI.ThreeDLinearSolverPolicyV4,
        TDOI.ThreeDRefinementPolicyV4,
        TDOI.ThreeDDiscretizationControlDeclarationV4,
        TDOI.ThreeDDiscretizationControlBindingV4,
        TDOI.ThreeDDiscretizationControlInputV4,
        TDOI.ThreeDDiscretizationControlResolutionV4)
    @test all(!Base.ismutabletype(T) for T in types)
    @test all(T -> all(ft -> ft !== Any && !(ft <: AbstractDict) &&
        !(ft <: Function), fieldtypes(T)), types)
    for value in (tddc_declaration, tddc_input, tddc_resolution)
        @test value.claim_ceiling == screen_only
        @test !value.provider_selected
        @test !value.solver_executed
        @test !value.emits_evidence
        @test !value.grants_pass
        @test !value.p5_ready
        @test !value.terminal_authority
        @test value.credible_physical_device_count == 0
    end
    @test !tddc_input.provider_executed
    manifest = TDOI.three_d_discretization_controls_manifest()
    @test manifest.statuses == (:input_complete, :recoverable_gap)
    @test manifest.model_class === :manufactured_input_fixture
    @test manifest.claim_ceiling == screen_only
    @test !manifest.provider_selected
    @test !manifest.provider_executed
    @test !manifest.solver_executed
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.physical_validation
    @test !manifest.engineering_validation
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end

println("THREE_D_DISCRETIZATION_CONTROLS_FOCUSED_EXIT_CODE=0")
