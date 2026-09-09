using Test
push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_gridap_field_evidence_fixture.jl"))
@testset "B3 exact bindings and replay" begin
    b = gridap_b3_bundle
    @test b.status === :pass
    @test FusionRuntimeV4.validate_gridap_field_evidence(b)
    @test b.provider.kind === :gridap_weak_form_field_residual
    @test b.provider.claim_ceiling === screen_only
    @test b.evidence.provider_manifest_hash == b.provider.manifest_hash
    @test b.input.provider_manifest_hash == b.provider.manifest_hash
    @test b.replay.report_hash == b.report.report_hash
    @test FusionRuntimeV4.replay_gridap_field_evidence!(gridap_b3_store, b)
    @test FusionRuntimeV4.replay_gridap_field_evidence_fresh(b)
end
@testset "B3 adversarial scenario control" begin
    b = gridap_b3_bundle
    @test_throws ArgumentError FusionRuntimeV4.execute_gridap_field_evidence!(Dict{Digest256,Any}(), gridap_b1_compilation; candidate=composition_candidate, compiled=composition_compiled, genome_registry=tdae_registry, scenario=(foreign=true,))
    forged_input = SolverInputV4(b.input.physical_subject_hash, b.input.scenario_hash, digest256_text("foreign-provider"), b.input.input_schema_hash, b.input.payload)
    @test_throws ArgumentError execute_once!(Dict{Digest256,Any}(), forged_input, b.provider)
    @test b.subject.bounds_hash == composition_compiled.minimality_scope.bounds_hash
    @test b.provider.code_hash == canonical_hash((FusionRuntimeV4._gridap_b3_source_hash(), gridap_b1_compilation.plan.adapter_code_hash, gridap_b1_compilation.plan.dependency_identity.dependency_hash))
    @test b.evidence.claim_ceiling === screen_only
    @test b.report.credible_physical_candidate_count == 0
    @test !b.report.p5_ready
    repeated=FusionRuntimeV4.execute_gridap_field_evidence!(Dict{Digest256,Any}(),
        gridap_b1_compilation; candidate=composition_candidate,
        compiled=composition_compiled,genome_registry=tdae_registry,
        scenario=gridap_b3_scenario)
    @test repeated.provider === b.provider
    @test repeated.bundle_hash == b.bundle_hash
end
