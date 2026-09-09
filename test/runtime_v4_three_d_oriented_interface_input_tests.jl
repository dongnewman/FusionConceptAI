using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_oriented_interface_input.jl"))

const TDOIH = digest256_text("three-d-oriented-interface-adversarial")

function tdoi_private_binding(; declaration_hash=tdoi_subject_binding.declaration_hash,
        genome_hash=tdoi_subject_binding.field_geometry_genome_hash,
        graph_hash=tdoi_subject_binding.field_geometry_graph_hash,
        graph_binding_hash=tdoi_subject_binding.field_geometry_graph_binding_hash,
        region_hashes=tdoi_subject_binding.region_ref_hashes,
        interface_hashes=tdoi_subject_binding.interface_ref_hashes,
        mission_hash=tdoi_subject_binding.mission_hash,
        bounds_hash=tdoi_subject_binding.bounds_hash,
        scenario_hash=tdoi_subject_binding.scenario_hash)
    body = TDOI._tdoi_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, region_hashes, interface_hashes, mission_hash,
        bounds_hash, scenario_hash)
    TDOI.ThreeDOrientedInterfaceBindingV4(TDOI._TDOI_TOKEN,
        declaration_hash, genome_hash, graph_hash, graph_binding_hash,
        region_hashes, interface_hashes, mission_hash, bounds_hash,
        scenario_hash, canonical_hash(body))
end

function tdoi_private_input(; input_hash=tdoi_input.input_hash,
        terminal_authority=tdoi_input.terminal_authority)
    values = (tdoi_input.context_hash, tdoi_input.candidate_hash,
        tdoi_input.compiled_prefix_hash, tdoi_input.physical_subject_hash,
        tdoi_input.mission_hash, tdoi_input.bounds_hash,
        tdoi_input.scenario_hash, tdoi_input.field_geometry_genome_hash,
        tdoi_input.field_geometry_graph_hash,
        tdoi_input.field_geometry_graph_binding_hash,
        tdoi_input.declaration_hash, tdoi_input.binding_hash,
        tdoi_input.regions, tdoi_input.interfaces, tdoi_input.model_class,
        tdoi_input.claim_ceiling, tdoi_input.provider_selected,
        tdoi_input.solver_executed, tdoi_input.emits_evidence,
        tdoi_input.p5_ready, terminal_authority,
        tdoi_input.credible_physical_device_count, input_hash)
    TDOI.ThreeDOrientedInterfaceInputV4(TDOI._TDOI_TOKEN, values...)
end

function tdoi_candidate_with_declaration(candidate_id, declaration)
    genome = FieldGeometryGenomeV4(20260910,
        GenericThreeDG2Fixture._fixture_refs[2], tdoi_graph;
        fields=(tdoi_left_support, tdoi_right_support,
            tdoi_interface_support, declaration))
    CandidateStatePackageV4(candidate_id,
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mission,
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mechanism,
        genome,
        GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_realization,
        generic_3d_registry)
end

@testset "generic G2 reports exact oriented-interface gaps" begin
    @test TDOI.validate_forward_chain_context(generic_3d_context) ==
        generic_3d_context.context_hash
    @test generic_3d_oriented_interface_resolution.status === :recoverable_gap
    @test generic_3d_oriented_interface_resolution.input === nothing
    @test generic_3d_oriented_interface_resolution.recoverable_gaps ==
        TDOI._TDOI_REQUIRED_GAPS
    @test canonical_hash(generic_3d_oriented_interface_resolution) ==
        generic_3d_oriented_interface_resolution.resolution_hash
    @test generic_3d_oriented_interface_resolution.claim_ceiling == screen_only
    @test !generic_3d_oriented_interface_resolution.provider_selected
    @test !generic_3d_oriented_interface_resolution.solver_executed
    @test !generic_3d_oriented_interface_resolution.emits_evidence
    @test !generic_3d_oriented_interface_resolution.p5_ready
    @test !generic_3d_oriented_interface_resolution.terminal_authority
    @test generic_3d_oriented_interface_resolution.credible_physical_device_count == 0
end

@testset "manufactured G2 compiles exact typed interface identities" begin
    @test TDOI.validate_forward_chain_context(tdoi_context) ==
        tdoi_context.context_hash
    @test canonical_hash(tdoi_declaration) == tdoi_declaration.declaration_hash
    @test canonical_hash(tdoi_subject_binding) == tdoi_subject_binding.binding_hash
    @test tdoi_resolution.status === :input_complete
    @test tdoi_resolution.input === tdoi_input
    @test isempty(tdoi_resolution.recoverable_gaps)
    @test canonical_hash(tdoi_resolution) == tdoi_resolution.resolution_hash
    @test TDOI.validate_three_d_oriented_interface_input(tdoi_context,
        tdoi_input) == tdoi_input.input_hash
    @test canonical_hash(tdoi_input) == tdoi_input.input_hash

    graph_binding = TDOI.forward_graph_binding(tdoi_context, :field_geometry)
    @test tdoi_subject_binding.field_geometry_genome_hash ==
        field_geometry_hash(tdoi_candidate.field_geometry_genome_ref)
    @test tdoi_subject_binding.field_geometry_graph_hash ==
        canonical_hash(tdoi_compiled.field_geometry_graph)
    @test tdoi_subject_binding.field_geometry_graph_binding_hash ==
        canonical_hash(graph_binding)
    @test tdoi_subject_binding.region_ref_hashes ==
        Tuple(x.ref_hash for x in tdoi_input.regions)
    @test tdoi_subject_binding.interface_ref_hashes ==
        Tuple(x.ref_hash for x in tdoi_input.interfaces)

    @test length(tdoi_input.regions) == 2
    @test Tuple(x.region_id for x in tdoi_input.regions) == ("left", "right")
    @test Set(x.state_node_identity_hash for x in tdoi_input.regions) ==
        Set(graph_binding.node_identity_hashes)
    @test tdoi_input.regions[1].support_identity_hash ==
        canonical_hash(tdoi_left_support)
    @test tdoi_input.regions[2].support_identity_hash ==
        canonical_hash(tdoi_right_support)
    interface_ref = only(tdoi_input.interfaces)
    edge = only(tdoi_graph.hyperedges)
    pair = only(edge.interface_flux_pairs)
    @test interface_ref.edge_identity_hash == only(graph_binding.hyperedge_identity_hashes)
    @test interface_ref.operator_program_hash == edge.program_hash
    @test interface_ref.ast_root_identity_hashes == graph_binding.ast_root_identity_hashes
    @test interface_ref.pair_position == 1
    @test interface_ref.pair_hash == canonical_hash(pair)
    @test interface_ref.interface_support_identity_hash ==
        canonical_hash(tdoi_interface_support)
    @test interface_ref.minus_state_node_identity_hash ==
        tdoi_input.regions[1].state_node_identity_hash
    @test interface_ref.plus_state_node_identity_hash ==
        tdoi_input.regions[2].state_node_identity_hash
    @test interface_ref.minus_coefficient == pair.minus.coefficient == -1 // 1
    @test interface_ref.plus_coefficient == pair.plus.coefficient == 1 // 1
    @test interface_ref.ledger_identity == tdoi_ledger
    @test interface_ref.minus_trace_space.role === TDOI.trace_space
    @test interface_ref.plus_trace_space.role === TDOI.trace_space
    @test interface_ref.multiplier_space.role === TDOI.multiplier_space
    @test length(unique((interface_ref.minus_trace_space.support_ref,
        interface_ref.plus_trace_space.support_ref,
        interface_ref.multiplier_space.support_ref))) == 3
    @test interface_ref.minus_trace_space.support_ref ==
        tdoi_left_support_ref
    @test interface_ref.plus_trace_space.support_ref ==
        tdoi_right_support_ref
    @test interface_ref.multiplier_space.support_ref ==
        tdoi_interface_support_ref
    @test !hasfield(TDOI.ThreeDOrientedInterfaceDeclarationV4,
        :minus_coefficient)
    @test !hasfield(TDOI.ThreeDOrientedInterfaceDeclarationV4,
        :plus_coefficient)
    @test tdoi_input.model_class === :manufactured_input_fixture
    @test tdoi_input.claim_ceiling == screen_only
    @test !tdoi_input.provider_selected
    @test !tdoi_input.solver_executed
    @test !tdoi_input.emits_evidence
    @test !tdoi_input.p5_ready
    @test !tdoi_input.terminal_authority
    @test tdoi_input.credible_physical_device_count == 0
end

@testset "interface declarations and bindings fail closed" begin
    bad_dim = PhysicalType(:scalar_field, 0, 2, TemporalTypeV1(static_time),
        tdoi_unit)
    bad_time = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(differential_time), tdoi_unit)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceV4("wild*",
        TDOI.volume_space, "left", tdoi_left_support_ref,
        QualifiedRefV1("lagrange", "v1"), tdoi_state_type, 1, 2)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceV4("bad-dim",
        TDOI.volume_space, "left", tdoi_left_support_ref,
        QualifiedRefV1("lagrange", "v1"), bad_dim, 1, 2)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceV4("bad-time",
        TDOI.volume_space, "left", tdoi_left_support_ref,
        QualifiedRefV1("lagrange", "v1"), bad_time, 1, 2)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceV4("bool-order",
        TDOI.volume_space, "left", tdoi_left_support_ref,
        QualifiedRefV1("lagrange", "v1"), tdoi_state_type, true, 2)
    @test_throws ArgumentError TDOI.ThreeDDiscreteSpaceV4("high-order",
        TDOI.volume_space, "left", tdoi_left_support_ref,
        QualifiedRefV1("lagrange", "v1"), tdoi_state_type, 9, 2)
    @test_throws ArgumentError TDOI.ThreeDRegionSpaceDeclarationV4(
        "right", "tdoi-left-state", tdoi_left_support_ref, tdoi_left_volume)
    @test_throws ArgumentError TDOI.ThreeDRegionSpaceDeclarationV4(
        "left", "tdoi-left-state", SpatialSupportRefV1("other-support"),
        tdoi_left_volume)
    @test_throws ArgumentError TDOI.ThreeDOrientedInterfaceDeclarationV4(
        "same-end", "tdoi-interface-edge", "left", "left", tdoi_ledger,
        tdoi_interface.minus_trace_space, tdoi_interface.plus_trace_space,
        tdoi_interface.multiplier_space)
    @test_throws ArgumentError TDOI.ThreeDOrientedInterfaceDeclarationV4(
        "wrong-role", "tdoi-interface-edge", "left", "right", tdoi_ledger,
        tdoi_left_volume, tdoi_interface.plus_trace_space,
        tdoi_interface.multiplier_space)
    @test_throws ArgumentError TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
        "vector-input", [tdoi_left_region, tdoi_right_region],
        (tdoi_interface,))
    @test_throws ArgumentError TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
        "one-region", (tdoi_left_region,), (tdoi_interface,))
    @test_throws ArgumentError TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
        "no-interface", (tdoi_left_region, tdoi_right_region), ())
    @test_throws ArgumentError TDOI.make_three_d_oriented_interface_binding(
        tdoi_compiled, generic_3d_registry, tdoi_mission, tdoi_bounds,
        tdoi_comparison_scope, tdoi_scenario_scope,
        (name="foreign-scenario",), tdoi_declaration)

    swapped_minus_trace = tdoi_space("tdoi-swapped-left-trace",
        TDOI.trace_space, "left", tdoi_right_support_ref,
        "mortar-trace", 2, 4)
    swapped_interface = TDOI.ThreeDOrientedInterfaceDeclarationV4(
        "left-to-right", "tdoi-interface-edge", "left", "right", tdoi_ledger,
        swapped_minus_trace, tdoi_interface.plus_trace_space,
        tdoi_interface.multiplier_space)
    swapped_declaration = TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
        "tdoi-swapped-supports",
        (tdoi_left_region, tdoi_right_region), (swapped_interface,))
    swapped_candidate = tdoi_candidate_with_declaration(
        "tdoi-swapped-support-candidate", swapped_declaration)
    @test_throws ArgumentError TDOI._tdoi_compile_declaration(
        swapped_candidate,
        TDOI.forward_graph_binding(tdoi_context, :field_geometry),
        swapped_declaration)

    foreign_multiplier = tdoi_space("tdoi-foreign-interface-multiplier",
        TDOI.multiplier_space, "left-to-right",
        SpatialSupportRefV1("tdoi-foreign-support"),
        "mortar-multiplier", 1, 4)
    foreign_interface = TDOI.ThreeDOrientedInterfaceDeclarationV4(
        "left-to-right", "tdoi-interface-edge", "left", "right", tdoi_ledger,
        tdoi_interface.minus_trace_space, tdoi_interface.plus_trace_space,
        foreign_multiplier)
    foreign_declaration = TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
        "tdoi-foreign-support",
        (tdoi_left_region, tdoi_right_region), (foreign_interface,))
    foreign_support_candidate = tdoi_candidate_with_declaration(
        "tdoi-foreign-support-candidate", foreign_declaration)
    @test_throws ArgumentError TDOI._tdoi_compile_declaration(
        foreign_support_candidate,
        TDOI.forward_graph_binding(tdoi_context, :field_geometry),
        foreign_declaration)

    foreign_binding = tdoi_private_binding(scenario_hash=TDOIH)
    @test canonical_hash(foreign_binding) == foreign_binding.binding_hash
    foreign_subject = TDOI.ExecutablePhysicalSubjectV4(
        tdoi_compiled.prefix_hash,
        tdoi_candidate.canonical_hashes.genome_bundle_hash,
        tdoi_compiled.minimality_scope.mission_hash,
        tdoi_compiled.minimality_scope.bounds_hash, (foreign_binding,),
        (tdoi_scenario,), (materialization="foreign-interface-binding",),
        TDOI.derive_capability_obligations(tdoi_compiled))
    foreign_context = TDOI.make_forward_chain_context(tdoi_candidate,
        tdoi_compiled, generic_3d_registry, tdoi_mission, tdoi_bounds,
        tdoi_comparison_scope, tdoi_scenario_scope, foreign_subject,
        tdoi_scenario)
    @test_throws ArgumentError TDOI.resolve_three_d_oriented_interface_input(
        foreign_context)

    forged_hash_input = tdoi_private_input(input_hash=TDOIH)
    @test_throws ArgumentError canonical_hash(forged_hash_input)
    authority_body = TDOI._tdoi_input_body(tdoi_context, tdoi_subject_binding,
        tdoi_input.regions, tdoi_input.interfaces)
    authority_body = merge(authority_body, (terminal_authority=true,))
    forged_authority_input = tdoi_private_input(
        input_hash=canonical_hash(authority_body), terminal_authority=true)
    @test_throws ArgumentError canonical_hash(forged_authority_input)
end

@testset "interface input types and manifest stay non-authoritative" begin
    contract_types = (TDOI.ThreeDDiscreteSpaceV4,
        TDOI.ThreeDRegionSpaceDeclarationV4,
        TDOI.ThreeDOrientedInterfaceDeclarationV4,
        TDOI.ThreeDOrientedInterfaceDeclarationSetV4,
        TDOI.ThreeDRegionSpaceRefV4, TDOI.ThreeDOrientedInterfaceRefV4,
        TDOI.ThreeDOrientedInterfaceBindingV4,
        TDOI.ThreeDOrientedInterfaceInputV4,
        TDOI.ThreeDOrientedInterfaceResolutionV4)
    @test all(!Base.ismutabletype(T) for T in contract_types)
    @test all(T -> all(ft -> ft !== Any && !(ft <: AbstractDict) &&
        !(ft <: Function), fieldtypes(T)), contract_types)

    manifest = TDOI.three_d_oriented_interface_input_manifest()
    @test manifest.statuses == (:input_complete, :recoverable_gap)
    @test manifest.model_class === :manufactured_input_fixture
    @test manifest.claim_ceiling == screen_only
    @test !manifest.provider_selected
    @test !manifest.solver_executed
    @test !manifest.emits_evidence
    @test !manifest.physical_validation
    @test !manifest.engineering_validation
    @test !manifest.terminal_authority
    @test !manifest.p5_ready
    @test manifest.credible_physical_device_count == 0
end

println("THREE_D_ORIENTED_INTERFACE_INPUT_FOCUSED_EXIT_CODE=0")
