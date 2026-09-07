using Test
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_typed_dae_composition_fixture.jl"))

@testset "D2.3 composition public compatibility" begin
    authority = FusionRuntimeV4._tdae_compile_authority(composition_compiled, tdae_drefs, tdae_arefs, tdae_rows)
    @test length(authority.payload_states) == 6
    @test Tuple(s.state_ref.value for s in authority.states) == ("x", "z1", "z2")
    @test composition_init_report.numerical_status === :pass
    @test composition_time_report.numerical_status === :pass
    @test composition_g2_report.status === :evaluated_screen
    @test composition_d3_report.status === :terminal_deferred
    @test Tuple(v.state_ref.value for v in
        composition_init_report.artifact.initial_values) == ("x", "z1", "z2")
    @test Tuple(v.state_ref.value for v in composition_time_report.artifact.trajectory[1].states) == ("x", "z1", "z2")
    @test Tuple(v.state_ref.value for v in composition_init_report.artifact.final_values) == ("x", "z1", "z2")
    @test all(Tuple(v.state_ref.value for v in p.states) == ("x", "z1", "z2")
        for p in composition_time_report.artifact.trajectory)
    @test composition_candidate.canonical_hashes.mechanism_hash !=
        d3_candidate.canonical_hashes.mechanism_hash
    @test composition_candidate.canonical_hashes.genome_bundle_hash !=
        d3_candidate.canonical_hashes.genome_bundle_hash
    @test composition_compiled.prefix_hash != d3_compiled.prefix_hash
    @test composition_d3_report.claim_ceiling === none
    @test composition_d3_report.credible_physical_candidate_count == 0
    @test !composition_d3_report.p5_ready
    @test !composition_d3_report.unsupported_emitted
end

@testset "D2.3 public negative gates" begin
    extra = ConsistentInitializationScenarioV4("extra-static", (dae_scenario.initial_values..., StateValueV4(StateGeneRefV1("u"), 0.0, composition_unit)))
    @test_throws ArgumentError FusionRuntimeV4.compile_typed_dae_initialization_plan(composition_compiled, tdae_registry; differential_refs=tdae_drefs, algebraic_refs=tdae_arefs, row_bindings=tdae_rows, scenario=extra)
    missing = ConsistentInitializationScenarioV4("missing-executed",
        dae_scenario.initial_values[1:2])
    @test_throws ArgumentError FusionRuntimeV4.compile_typed_dae_initialization_plan(
        composition_compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=tdae_rows, scenario=missing)
    @test_throws ArgumentError FusionRuntimeV4.compile_typed_dae_initialization_plan(composition_compiled, tdae_registry; differential_refs=tdae_drefs, algebraic_refs=(tdae_arefs..., StateGeneRefV1("u")), row_bindings=tdae_rows, scenario=dae_scenario)
    @test_throws ArgumentError FusionRuntimeV4.compile_typed_dae_initialization_plan(composition_compiled, tdae_registry; differential_refs=(StateGeneRefV1("u"),), algebraic_refs=tdae_arefs, row_bindings=tdae_rows, scenario=dae_scenario)
    static_row = DAEAlgebraicRowBindingV4(StateGeneRefV1("u"),
        tdae_rows[2].governing_edge_hash, tdae_rows[2].residual_edge_hash,
        tdae_rows[2].residual_root_position, tdae_rows[2].operator_manifest_bindings)
    @test_throws ArgumentError FusionRuntimeV4.compile_typed_dae_initialization_plan(
        composition_compiled, tdae_registry; differential_refs=tdae_drefs,
        algebraic_refs=tdae_arefs, row_bindings=(tdae_rows[1], static_row, tdae_rows[3]),
        scenario=dae_scenario)
    @test_throws ArgumentError FusionRuntimeV4.validate_typed_field_time_bridge(
        composition_candidate, d3_compiled, tdae_registry, d3_operator_registry,
        composition_time_plan, composition_time_report, composition_g2_plan,
        composition_g2_report, dae_scenario, d3_g2_scenario,
        composition_d3_report;
        g2_provider=composition_g2_provider)
end
