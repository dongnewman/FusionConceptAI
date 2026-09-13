using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_n2_source_geometry_candidate.jl"))

@testset "N2 source-owned candidate G2 AST and SI root bridge" begin
    @test n2g_bridge.status === :bridge_ready
    @test n2g_bridge.audit.bridge_ready_is_geometry_proof == false
    @test n2g_candidate_geometry_binding.candidate_hash ==
        n2g_context.candidate_hash
    @test n2g_candidate_geometry_binding.context_hash ==
        n2g_context.context_hash
    @test n2g_candidate_geometry_binding.physical_subject_hash ==
        n2g_context.subject.physical_subject_hash
    @test n2g_candidate_geometry_binding.reference_binding_hash ==
        n2g_reference_binding.binding_hash
    @test n2g_candidate_geometry_binding.source_artifact_sha256 ==
        n2g_reference_binding.source_artifact_sha256
    @test n2g_candidate_geometry_binding.source_interior_subject_sha256 ==
        n2g_program.interior.subject_sha256
    @test n2g_candidate_geometry_binding.normalized_reference_subject_sha256 ==
        n2g_reference_binding.normalized_result_subject_sha256
    @test n2g_candidate_geometry_binding.root_bridge_hash ==
        n2g_bridge.resolution_hash
    @test n2g_candidate_geometry_binding.recoverable_gaps == TDNPRB._N2GC_GAPS
    @test canonical_hash(n2g_candidate_geometry_binding) ==
        n2g_candidate_geometry_binding.binding_hash
    @test n2g_evaluation.candidate_hash == n2g_context.candidate_hash
    @test n2g_evaluation.physical_subject_hash ==
        n2g_context.subject.physical_subject_hash
    @test n2g_evaluation.candidate_geometry_binding_hash ==
        n2g_candidate_geometry_binding.binding_hash
    @test n2g_evaluation.source_geometry.claim_ceiling === screen_only
    @test !n2g_evaluation.geometry_proved && !n2g_evaluation.provider_executed
    @test !n2g_evaluation.physical_validation &&
        n2g_evaluation.credible_device_count == 0
    @test canonical_hash(default_operator_registry()) !=
        canonical_hash(n2g_binding.registry)
end

@testset "N2 candidate geometry rejects foreign context and source" begin
    @test_throws ArgumentError TDNPRB.evaluate_n2_source_candidate_geometry(
        n2g_candidate_geometry_binding, tdpi_context, n2g_binding,
        n2g_reference_binding, n2g_bridge, n2g_source_path,
        n2g_interior_path,
        N2G.N2SourceUnitTurnChartV4(0.47, 1.1/(2pi), 0.09*19/(2pi)))
    @test_throws ArgumentError TDNPRB.bind_n2_source_candidate_geometry(
        tdpi_context, n2g_binding, n2g_reference_binding,
        tdnprb_legacy_resolution, n2g_source_path, n2g_interior_path)
    @test_throws ArgumentError TDNPRB.bind_n2_source_candidate_geometry(
        n2g_context, n2g_binding, n2g_reference_binding, n2g_bridge,
        n2g_source_path, n2g_normalized_path)
    @test_throws ArgumentError TDNPRB.bind_n2_source_candidate_geometry(
        n2g_context, n2g_binding, n2g_reference_binding, n2g_bridge,
        n2g_normalized_path, n2g_interior_path)
    previous = n2g_candidate_geometry_binding
    bad_reference_hash = Digest256(repeat("a",64))
    forged0 = TDNPRB.N2SourceCandidateGeometryBindingV4(
        previous.candidate_hash, previous.context_hash,
        previous.physical_subject_hash, bad_reference_hash,
        previous.source_program_hash, previous.source_graph_binding_hash,
        previous.root_bridge_hash, previous.source_artifact_sha256,
        previous.source_interior_subject_sha256,
        previous.normalized_reference_subject_sha256,
        previous.recoverable_gaps, Digest256(repeat("0",64)))
    forged = TDNPRB.N2SourceCandidateGeometryBindingV4(
        forged0.candidate_hash, forged0.context_hash,
        forged0.physical_subject_hash, forged0.reference_binding_hash,
        forged0.source_program_hash, forged0.source_graph_binding_hash,
        forged0.root_bridge_hash, forged0.source_artifact_sha256,
        forged0.source_interior_subject_sha256,
        forged0.normalized_reference_subject_sha256,
        forged0.recoverable_gaps,
        canonical_hash(TDNPRB._n2gc_body(forged0)))
    @test canonical_hash(forged) == forged.binding_hash
    @test_throws ArgumentError TDNPRB.evaluate_n2_source_candidate_geometry(
        forged, n2g_context, n2g_binding, n2g_reference_binding,
        n2g_bridge, n2g_source_path, n2g_interior_path,
        N2G.N2SourceUnitTurnChartV4(0.47, 1.1/(2pi), 0.09*19/(2pi)))
end
