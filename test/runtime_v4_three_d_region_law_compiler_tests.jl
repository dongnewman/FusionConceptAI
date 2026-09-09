using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_region_law_compiler.jl"))

const TDRLH = digest256_text("three-d-region-law-adversarial")

@testset "generic G2 retains exact recoverable region-law gap" begin
    @test TDRL.validate_forward_chain_context(tdrl_generic_context) ==
        tdrl_generic_context.context_hash
    @test tdrl_generic_resolution.status === :recoverable_gap
    @test tdrl_generic_resolution.declaration_hash === nothing
    @test tdrl_generic_resolution.binding_hash === nothing
    @test isempty(tdrl_generic_resolution.compiled_law_root_hashes)
    @test tdrl_generic_resolution.recoverable_gaps ==
        (TDRL._TDRL_GAP, TDRL._TDRL_BINDING_GAP,
         TDRL._TDRL_DOWNSTREAM_GAPS...)
    @test canonical_hash(tdrl_generic_resolution) ==
        tdrl_generic_resolution.compilation_hash
end

@testset "manufactured laws compile from current G2 identities" begin
    @test TDRL.validate_forward_chain_context(tdrl_context) ==
        tdrl_context.context_hash
    @test canonical_hash(tdrl_declaration) == tdrl_declaration.declaration_hash
    @test canonical_hash(tdrl_binding) == tdrl_binding.binding_hash
    @test tdrl_resolution.status === :compiled
    @test tdrl_resolution.declaration_hash == tdrl_declaration.declaration_hash
    @test tdrl_resolution.binding_hash == tdrl_binding.binding_hash
    @test tdrl_resolution.compiled_law_root_hashes == (
        tdrl_declaration.constitutive_law.ast_root_identity_hash,
        tdrl_declaration.source_law.ast_root_identity_hash,
        tdrl_declaration.boundary_law.ast_root_identity_hash)
    @test tdrl_resolution.recoverable_gaps == TDRL._TDRL_DOWNSTREAM_GAPS
    @test canonical_hash(tdrl_resolution) == tdrl_resolution.compilation_hash

    graph_binding = TDRL.forward_graph_binding(tdrl_context, :field_geometry)
    @test tdrl_declaration.field_geometry_graph_hash ==
        graph_binding.canonical_graph_hash
    @test tdrl_declaration.field_geometry_graph_binding_hash ==
        canonical_hash(graph_binding)
    @test tdrl_binding.field_geometry_genome_hash ==
        field_geometry_hash(tdrl_candidate.field_geometry_genome_ref)
    @test tdrl_binding.field_geometry_graph_hash ==
        graph_binding.canonical_graph_hash
    @test tdrl_binding.field_geometry_graph_binding_hash ==
        canonical_hash(graph_binding)
    @test tdrl_binding.law_root_identity_hashes ==
        tdrl_resolution.compiled_law_root_hashes
    @test tdrl_binding.mission_hash == TDRL._runtime_decl_hash(tdrl_mission)
    @test tdrl_binding.bounds_hash == TDRL._runtime_decl_hash(tdrl_bounds)
    @test tdrl_binding.scenario_hash == tdrl_context.scenario_hash
    @test tdrl_declaration.region_node_identity_hash in
        graph_binding.node_identity_hashes
    @test all(h -> h in graph_binding.hyperedge_identity_hashes,
        (tdrl_declaration.constitutive_law.edge_identity_hash,
         tdrl_declaration.source_law.edge_identity_hash,
         tdrl_declaration.boundary_law.edge_identity_hash))
    @test all(h -> h in graph_binding.ast_root_identity_hashes,
        tdrl_resolution.compiled_law_root_hashes)
    @test (tdrl_declaration.constitutive_law.edge_role,
        tdrl_declaration.source_law.edge_role,
        tdrl_declaration.boundary_law.edge_role) ==
        (:governing, :source, :boundary)
    @test all(x -> x.output_type.spatial_dimension == 3 &&
        x.output_type.temporal_type == TemporalTypeV1(static_time),
        (tdrl_declaration.constitutive_law,
         tdrl_declaration.source_law,
         tdrl_declaration.boundary_law))
end

function tdrl_context_with_bindings(bindings, tag::String)
    subject = TDRL.ExecutablePhysicalSubjectV4(tdrl_compiled.prefix_hash,
        tdrl_candidate.canonical_hashes.genome_bundle_hash,
        tdrl_compiled.minimality_scope.mission_hash,
        tdrl_compiled.minimality_scope.bounds_hash, Tuple(bindings),
        (tdrl_scenario,), (materialization=tag,),
        TDRL.derive_capability_obligations(tdrl_compiled))
    TDRL.make_forward_chain_context(tdrl_candidate, tdrl_compiled,
        tdrl_registry, tdrl_mission, tdrl_bounds, tdrl_comparison,
        tdrl_scenarios, subject, tdrl_scenario)
end

@testset "subject binding is required and fail-closed" begin
    absent_context = tdrl_context_with_bindings(
        ((binding_kind="no-region-law-binding",),), "absent-binding")
    absent = TDRL.compile_three_d_region_laws(absent_context)
    @test absent.status === :recoverable_gap
    @test absent.declaration_hash == tdrl_declaration.declaration_hash
    @test absent.binding_hash === nothing
    @test absent.recoverable_gaps ==
        (TDRL._TDRL_BINDING_GAP, TDRL._TDRL_DOWNSTREAM_GAPS...)

    ambiguous_context = tdrl_context_with_bindings(
        (tdrl_binding, tdrl_binding), "ambiguous-binding")
    @test_throws ArgumentError TDRL.compile_three_d_region_laws(
        ambiguous_context)

    foreign_scenario_hash = TDRLH
    foreign_body = TDRL._tdrl_binding_body(tdrl_binding.declaration_hash,
        tdrl_binding.field_geometry_genome_hash,
        tdrl_binding.field_geometry_graph_hash,
        tdrl_binding.field_geometry_graph_binding_hash,
        tdrl_binding.law_root_identity_hashes, tdrl_binding.mission_hash,
        tdrl_binding.bounds_hash, foreign_scenario_hash)
    foreign_binding = TDRL.ThreeDRegionLawBindingV4(TDRL._TDRL_TOKEN,
        tdrl_binding.declaration_hash, tdrl_binding.field_geometry_genome_hash,
        tdrl_binding.field_geometry_graph_hash,
        tdrl_binding.field_geometry_graph_binding_hash,
        tdrl_binding.law_root_identity_hashes, tdrl_binding.mission_hash,
        tdrl_binding.bounds_hash, foreign_scenario_hash,
        canonical_hash(foreign_body))
    @test canonical_hash(foreign_binding) == foreign_binding.binding_hash
    foreign_context = tdrl_context_with_bindings(
        (foreign_binding,), "foreign-binding")
    @test_throws ArgumentError TDRL.compile_three_d_region_laws(foreign_context)

    forged_binding = TDRL.ThreeDRegionLawBindingV4(TDRL._TDRL_TOKEN,
        tdrl_binding.declaration_hash, tdrl_binding.field_geometry_genome_hash,
        tdrl_binding.field_geometry_graph_hash,
        tdrl_binding.field_geometry_graph_binding_hash,
        tdrl_binding.law_root_identity_hashes, tdrl_binding.mission_hash,
        tdrl_binding.bounds_hash, tdrl_binding.scenario_hash, TDRLH)
    @test_throws ArgumentError canonical_hash(forged_binding)
end

@testset "compiler rejects fabricated or foreign identities" begin
    @test_throws ArgumentError TDRL.declare_three_d_region_laws(tdrl_prebinding;
        declaration_id="missing-edge", region_node_id="tdrl-plasma-region",
        constitutive_edge_id="not-in-current-g2",
        source_edge_id="tdrl-source-edge",
        boundary_edge_id="tdrl-boundary-edge")
    @test_throws ArgumentError TDRL.declare_three_d_region_laws(tdrl_prebinding;
        declaration_id="wrong-region-kind", region_node_id="tdrl-wall-boundary",
        constitutive_edge_id="tdrl-constitutive-edge",
        source_edge_id="tdrl-source-edge",
        boundary_edge_id="tdrl-boundary-edge")
    @test_throws ArgumentError TDRL.declare_three_d_region_laws(tdrl_prebinding;
        declaration_id="wild*", region_node_id="tdrl-plasma-region",
        constitutive_edge_id="tdrl-constitutive-edge",
        source_edge_id="tdrl-source-edge",
        boundary_edge_id="tdrl-boundary-edge")

    forged = TDRL.ThreeDRegionConstitutiveSourceBoundaryV4(TDRL._TDRL_TOKEN,
        tdrl_declaration.declaration_id,
        tdrl_declaration.field_geometry_graph_hash,
        tdrl_declaration.field_geometry_graph_binding_hash,
        tdrl_declaration.region_node_id,
        tdrl_declaration.region_node_identity_hash,
        tdrl_declaration.region_type,
        tdrl_declaration.constitutive_law,
        tdrl_declaration.source_law,
        tdrl_declaration.boundary_law,
        tdrl_declaration.model_class,
        tdrl_declaration.claim_ceiling,
        tdrl_declaration.provider_selected,
        tdrl_declaration.provider_executed,
        tdrl_declaration.emits_evidence,
        tdrl_declaration.grants_pass,
        tdrl_declaration.promotion_authority,
        tdrl_declaration.p5_ready,
        tdrl_declaration.terminal_authority,
        tdrl_declaration.credible_physical_device_count, TDRLH)
    @test_throws ArgumentError canonical_hash(forged)
end

@testset "authority boundary remains below provider and evidence" begin
    for result in (tdrl_generic_resolution, tdrl_resolution)
        @test result.claim_ceiling == screen_only
        @test !result.provider_selected
        @test !result.provider_executed
        @test !result.emits_evidence
        @test !result.grants_pass
        @test !result.promotion_authority
        @test !result.p5_ready
        @test !result.terminal_authority
        @test result.credible_physical_device_count == 0
    end
    manifest = TDRL.three_d_region_law_compiler_manifest()
    @test manifest.manufactured_fixture_status === :compiled
    @test manifest.generic_status === :recoverable_gap
    @test manifest.resolved_gap == TDRL._TDRL_GAP
    @test manifest.required_subject_binding_gap == TDRL._TDRL_BINDING_GAP
    @test manifest.downstream_gaps == TDRL._TDRL_DOWNSTREAM_GAPS
    @test !manifest.provider_executed
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.promotion_authority
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
end

println("THREE_D_REGION_LAW_COMPILER_FOCUSED_EXIT_CODE=0")
