using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_region_law_set_compiler.jl"))

function tdrls_context_with(bindings; payload=(case="law-set-test",))
    subject = TDRLS.ExecutablePhysicalSubjectV4(
        tdrls_compiled.prefix_hash,
        tdrls_candidate.canonical_hashes.genome_bundle_hash,
        tdrls_compiled.minimality_scope.mission_hash,
        tdrls_compiled.minimality_scope.bounds_hash, bindings,
        (tdrls_scenario,), payload,
        TDRLS.derive_capability_obligations(tdrls_compiled))
    TDRLS.make_forward_chain_context(tdrls_candidate, tdrls_compiled,
        generic_3d_registry, tdrls_mission, tdrls_bounds,
        tdrls_comparison, tdrls_scenarios, subject, tdrls_scenario)
end

@testset "generic G2 reports exact law-set gaps" begin
    result = tdrls_generic_resolution
    @test result.status === :recoverable_gap
    @test result.recoverable_gaps == TDRLS._TDRLS_REQUIRED_GAPS
    @test result.declaration === nothing
    @test result.claim_ceiling == screen_only
    @test !result.provider_selected
    @test !result.provider_executed
    @test !result.solver_executed
    @test !result.emits_evidence
    @test !result.grants_pass
    @test !result.p5_ready
    @test !result.terminal_authority
    @test result.credible_physical_device_count == 0
end

@testset "two oriented regions own six independent laws" begin
    result = tdrls_resolution
    @test result.status === :compiled
    @test result.ordered_region_ids == ("left-region", "right-region")
    @test Tuple(x.region_node_id for x in result.laws) ==
        result.ordered_region_ids
    @test length(result.laws) == 2
    @test length(result.ordered_edge_identity_hashes) == 6
    @test length(unique(result.ordered_edge_identity_hashes)) == 6
    @test length(unique(result.ordered_ast_root_identity_hashes)) == 6
    @test length(unique(result.ordered_output_node_identity_hashes)) == 6
    @test canonical_hash(tdrls_declaration) == tdrls_declaration.declaration_hash
    @test canonical_hash(tdrls_binding) == tdrls_binding.binding_hash
    @test canonical_hash(result) == result.compilation_hash
end

@testset "missing duplicate extra shared and foreign selectors fail closed" begin
    missing = (tdrls_selectors[1],
        merge(tdrls_selectors[2], (region_id="foreign-region",)))
    duplicate = (tdrls_selectors[1], tdrls_selectors[1])
    extra = (tdrls_selectors...,
        (region_id="extra-region", constitutive_edge_id="missing-c",
         source_edge_id="missing-s", boundary_edge_id="missing-b"))
    shared = (tdrls_selectors[1],
        merge(tdrls_selectors[2],
            (constitutive_edge_id=tdrls_selectors[1].constitutive_edge_id,)))
    @test_throws ArgumentError TDRLS.declare_three_d_region_law_set(
        tdrls_prebinding, tdrls_oriented_declaration;
        declaration_id="missing", law_selectors=missing)
    @test_throws ArgumentError TDRLS.declare_three_d_region_law_set(
        tdrls_prebinding, tdrls_oriented_declaration;
        declaration_id="duplicate", law_selectors=duplicate)
    @test_throws ArgumentError TDRLS.declare_three_d_region_law_set(
        tdrls_prebinding, tdrls_oriented_declaration;
        declaration_id="extra", law_selectors=extra)
    @test_throws ArgumentError TDRLS.declare_three_d_region_law_set(
        tdrls_prebinding, tdrls_oriented_declaration;
        declaration_id="shared", law_selectors=shared)
end

@testset "missing duplicate foreign and forged bindings fail closed" begin
    missing = TDRLS.compile_three_d_region_law_set(
        tdrls_context_with((tdrls_oriented_binding,);
            payload=(case="missing-law-set-binding",)))
    @test missing.status === :recoverable_gap
    @test missing.recoverable_gaps ==
        (TDRLS._TDRLS_REQUIRED_GAPS[4],)

    duplicate = tdrls_context_with((tdrls_oriented_binding, tdrls_binding,
        tdrls_binding); payload=(case="duplicate-law-set-binding",))
    duplicate_result = TDRLS.compile_three_d_region_law_set(duplicate)
    @test duplicate_result.status === :recoverable_gap
    @test duplicate_result.recoverable_gaps ==
        ("ambiguous_three_d_region_law_set_subject_binding",)

    forged = TDRLS.ThreeDRegionLawSetBindingV4(TDRLS._TDRLS_TOKEN,
        tdrls_binding.candidate_hash, tdrls_binding.compiled_prefix_hash,
        tdrls_binding.field_geometry_genome_hash,
        tdrls_binding.field_geometry_graph_hash,
        tdrls_binding.field_geometry_graph_binding_hash,
        tdrls_binding.declaration_hash,
        tdrls_binding.oriented_declaration_hash,
        tdrls_binding.oriented_binding_hash, tdrls_binding.ordered_region_ids,
        tdrls_binding.ordered_law_hashes,
        tdrls_binding.ordered_edge_identity_hashes,
        tdrls_binding.ordered_ast_root_identity_hashes,
        tdrls_binding.ordered_output_node_identity_hashes,
        tdrls_binding.mission_hash, tdrls_binding.bounds_hash,
        tdrls_binding.scenario_hash, digest256_text("forged-binding"))
    @test_throws ArgumentError canonical_hash(forged)
end

@testset "manifest preserves the authority ceiling" begin
    manifest = TDRLS.three_d_region_law_set_compiler_manifest()
    @test manifest.exact_oriented_order
    @test manifest.minimum_region_count == 2
    @test manifest.laws_per_region == 3
    @test manifest.forbids_shared_edges
    @test manifest.forbids_shared_ast_roots
    @test manifest.forbids_shared_outputs
    @test manifest.claim_ceiling == screen_only
    @test !manifest.provider_selected
    @test !manifest.provider_executed
    @test !manifest.solver_executed
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end
