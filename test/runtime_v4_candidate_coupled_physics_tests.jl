using Test
function test_candidate_coupled_physics(CCPP,upstream,regional_execution,e)
@testset "candidate-bound real DESC weak-volume execution" begin
    @test e.candidate_hash==upstream[1].candidate_hash
    @test e.context_hash==upstream[1].context_hash
    @test CCPP.validate_candidate_coupled_physics(upstream,regional_execution,e)==e.result_hash
    @test length(e.region_weak_volume_N)==length(upstream[12].regions)
    @test length(e.jacobian_column_ownership)==4length(CCPP._ccp_artifacts(regional_execution).request.nodes)
    @test length(e.jacobian_row_ownership)==12length(upstream[12].regions)
    @test e.sampled_constitutive_jacobian_verified
    @test e.execution.weak_volume_executed && e.execution.nonconstant_strong_moment_executed
    @test !e.execution.complete_weak_residual_executed && !e.execution.coupled_solve_attempted
    @test !e.execution.external_source_term_executed && !e.execution.boundary_term_executed
    @test e.status===:deferred && e.evidence_credit==0
    @test :candidate_owned_external_body_source_declaration in e.missing_capabilities
    forged=merge(CCPP.semantic_view(e),(candidate_hash=CCPP.canonical_hash(:wrong_candidate),))
    wrong=CCPP.CandidateCoupledPhysicsResultV4(CCPP._CCP_TOKEN,values(forged)...,CCPP.canonical_hash(forged))
    @test_throws ArgumentError CCPP.validate_candidate_coupled_physics(upstream,regional_execution,wrong)
    forged=merge(CCPP.semantic_view(e),(execution=merge(e.execution,(coupled_solve_attempted=true,)),))
    wrong=CCPP.CandidateCoupledPhysicsResultV4(CCPP._CCP_TOKEN,values(forged)...,CCPP.canonical_hash(forged))
    @test_throws ArgumentError CCPP.canonical_hash(wrong)
    # A hash-resealed fabricated weak integral must fail exact provider replay.
    values0=e.region_weak_volume_N; rows0=values0[1]
    forged_values=(((rows0[1][1]+1.0,rows0[1][2],rows0[1][3]),rows0[2:end]...),values0[2:end]...)
    forged=merge(CCPP.semantic_view(e),(region_weak_volume_N=forged_values,))
    wrong=CCPP.CandidateCoupledPhysicsResultV4(CCPP._CCP_TOKEN,values(forged)...,CCPP.canonical_hash(forged))
    @test_throws ArgumentError CCPP.validate_candidate_coupled_physics(upstream,regional_execution,wrong)
end
println("CANDIDATE_COUPLED_PHYSICS_FOCUSED_EXIT_CODE=0")
end
