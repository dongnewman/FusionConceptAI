using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_physical_provider_input.jl"))

const TDPIH = digest256_text("three-d-physical-input-adversarial")

@testset "generic G2 reports exact 3-D provider-input gaps" begin
    @test TDPI.validate_forward_chain_context(generic_3d_context) ==
        generic_3d_context.context_hash
    @test generic_3d_input_resolution.status === :recoverable_gap
    @test generic_3d_input_resolution.declaration_hash === nothing
    @test generic_3d_input_resolution.binding_hash === nothing
    @test generic_3d_input_resolution.recoverable_gaps ==
        TDPI._TDPI_REQUIRED_GAPS
    @test canonical_hash(generic_3d_input_resolution) ==
        generic_3d_input_resolution.resolution_hash
    @test generic_3d_input_resolution.claim_ceiling == screen_only
    @test !generic_3d_input_resolution.provider_selected
    @test !generic_3d_input_resolution.solver_executed
    @test !generic_3d_input_resolution.emits_evidence
    @test !generic_3d_input_resolution.p5_ready
    @test generic_3d_input_resolution.credible_physical_device_count == 0
end

@testset "manufactured typed G2 closes only geometry/profile ownership" begin
    @test TDPI.validate_forward_chain_context(tdpi_context) ==
        tdpi_context.context_hash
    @test canonical_hash(tdpi_input_declaration) ==
        tdpi_input_declaration.declaration_hash
    @test canonical_hash(tdpi_subject_binding) ==
        tdpi_subject_binding.binding_hash
    @test TDPI._tdpi_context_binding(tdpi_context,
        tdpi_input_declaration) === tdpi_subject_binding
    @test tdpi_input_resolution.status === :recoverable_gap
    @test tdpi_input_resolution.declaration_hash ==
        tdpi_input_declaration.declaration_hash
    @test tdpi_input_resolution.binding_hash == tdpi_subject_binding.binding_hash
    @test tdpi_input_resolution.recoverable_gaps == TDPI._TDPI_REQUIRED_GAPS[4:7]
    @test tdpi_subject_binding.field_geometry_genome_hash ==
        field_geometry_hash(tdpi_candidate.field_geometry_genome_ref)
    @test tdpi_subject_binding.field_geometry_graph_hash ==
        canonical_hash(tdpi_compiled.field_geometry_graph)
    @test tdpi_subject_binding.field_geometry_graph_binding_hash ==
        canonical_hash(TDPI.forward_graph_binding(tdpi_context, :field_geometry))
    @test tdpi_subject_binding.ast_root_identity_hashes ==
        TDPI.forward_graph_binding(tdpi_context, :field_geometry).ast_root_identity_hashes
    @test tdpi_subject_binding.mission_hash ==
        TDPI._runtime_decl_hash(tdpi_context.mission_payload)
    @test tdpi_subject_binding.bounds_hash ==
        TDPI._runtime_decl_hash(tdpi_context.bounds_payload)
    @test tdpi_subject_binding.scenario_hash == tdpi_context.scenario_hash
    @test tdpi_input_resolution.claim_ceiling == screen_only
    @test !tdpi_input_resolution.provider_selected
    @test !tdpi_input_resolution.solver_executed
    @test !tdpi_input_resolution.emits_evidence
    @test !tdpi_input_resolution.p5_ready
    @test tdpi_input_resolution.credible_physical_device_count == 0
end

@testset "typed constructors and identity checks fail closed" begin
    @test_throws ArgumentError TDPI.ThreeDFourierCoefficientV4(0, 0, 0.0)
    @test_throws ArgumentError TDPI.ThreeDFourierCoefficientV4(65, 0, 1.0)
    @test_throws ArgumentError TDPI.ThreeDFourierBoundaryV4("wild*", 5, true,
        (TDPI.ThreeDFourierCoefficientV4(0, 0, 5.0),),
        (TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),))
    @test_throws ArgumentError TDPI.ThreeDFourierBoundaryV4("no-r00", 5, true,
        (TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),),
        (TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),))
    duplicate = TDPI.ThreeDFourierCoefficientV4(0, 0, 5.0)
    @test_throws ArgumentError TDPI.ThreeDFourierBoundaryV4("duplicate", 5,
        true, (duplicate, duplicate),
        (TDPI.ThreeDFourierCoefficientV4(1, 0, 0.5),))
    @test_throws ArgumentError TDPI.ThreeDRadialProfileV4("bad-pressure",
        :pressure, (0.0,), tdpi_pressure_unit, tdpi_radial_domain)
    @test_throws ArgumentError TDPI.ThreeDRadialProfileV4("bad-iota-unit",
        :iota, (0.4,), tdpi_pressure_unit, tdpi_radial_domain)
    @test_throws ArgumentError TDPI.ThreeDProfilesFluxV4("zero-flux",
        tdpi_pressure_profile, tdpi_iota_profile, 0.0, tdpi_flux_unit)

    forged_declaration = TDPI.ThreeDPhysicalProviderInputV4(TDPI._TDPI_TOKEN,
        tdpi_input_declaration.declaration_id,
        tdpi_input_declaration.fourier_boundary,
        tdpi_input_declaration.coordinate_metric,
        tdpi_input_declaration.profiles_flux,
        tdpi_input_declaration.model_class,
        tdpi_input_declaration.claim_ceiling,
        tdpi_input_declaration.provider_selected,
        tdpi_input_declaration.solver_executed,
        tdpi_input_declaration.emits_evidence,
        tdpi_input_declaration.p5_ready,
        tdpi_input_declaration.credible_physical_device_count, TDPIH)
    @test_throws ArgumentError canonical_hash(forged_declaration)

    forged_binding = TDPI.ThreeDPhysicalProviderInputBindingV4(TDPI._TDPI_TOKEN,
        tdpi_subject_binding.declaration_hash,
        tdpi_subject_binding.field_geometry_genome_hash,
        tdpi_subject_binding.field_geometry_graph_hash,
        tdpi_subject_binding.field_geometry_graph_binding_hash,
        tdpi_subject_binding.ast_root_identity_hashes,
        tdpi_subject_binding.mission_hash, tdpi_subject_binding.bounds_hash,
        TDPIH, tdpi_subject_binding.binding_hash)
    @test_throws ArgumentError canonical_hash(forged_binding)
    @test_throws ArgumentError TDPI._tdpi_context_binding(generic_3d_context,
        tdpi_input_declaration)
    @test_throws ArgumentError TDPI.make_three_d_physical_provider_input_binding(
        tdpi_compiled, generic_3d_registry, tdpi_mission, tdpi_bounds,
        tdpi_comparison_scope, tdpi_scenario_scope,
        (name="foreign-scenario",), tdpi_input_declaration)
end

@testset "manifest states the authority boundary" begin
    manifest = TDPI.three_d_physical_provider_input_manifest()
    @test manifest.implemented_status === :recoverable_gap
    @test manifest.deferred_input_complete_edges == TDPI._TDPI_REQUIRED_GAPS[4:7]
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

println("THREE_D_PHYSICAL_PROVIDER_INPUT_FOCUSED_EXIT_CODE=0")
