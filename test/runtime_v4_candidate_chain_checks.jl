using Test
using FusionConceptAI

function test_candidate_chain(R, result, context, physics, engineering, validation)
    @testset "same-candidate end-to-end execution accounting" begin
        @test canonical_hash(result)==result.result_hash
        @test result.identity.candidate_hash==context.candidate_hash
        @test result.identity.genome_bundle_hash==context.candidate.canonical_hashes.genome_bundle_hash
        @test all(s -> s.identity_hash==result.identity.identity_hash,result.stages)
        @test result.whole_device_assessment_executed && !result.whole_device_physics_executed
        @test result.outcome===:deferred && !result.p5_ready && result.credible_device_count==0
        @test !result.terminal_authority
        @test all(s -> !s.complete_requested_stage,result.stages[2:end])
        @test !engineering.engineering_executed && !engineering.control_executed && !engineering.fault_executed
        @test !physics.execution.coupled_solve_attempted
        @test !validation.physical_validation_executed && !validation.parametric_uq_executed
        @test length(result.dependency_queue)>10
        @test any(g -> g.code===:unconverged_local_residual_integral &&
            g.status===validation.numerical_status,result.dependency_queue)
        @test_throws ArgumentError R.CandidateChainMetricV4(:invalid,NaN,UnitSignature(),"invalid")
        @test_throws ArgumentError R.CandidateChainGapV4(:whole_device,:fake,:pass,(),"data","check")
        @test_throws ArgumentError R._candidate_chain_stage(result.identity,:whole_device,
            (context.context_hash,),:observed,(:solve,),(:solve,),(),())
        body=merge(semantic_view(result.identity),(candidate_hash=digest256_text("foreign-candidate"),))
        foreign=R.CandidateChainIdentityV4(R._CANDIDATE_CHAIN_TOKEN,values(body)...,canonical_hash(body))
        mixed=merge(semantic_view(result),(identity=foreign,))
        forged=R.CandidateEndToEndResultV4(R._CANDIDATE_CHAIN_TOKEN,values(mixed)...,canonical_hash(mixed))
        @test_throws ArgumentError canonical_hash(forged)
        # Same identity and valid hashes cannot turn a fabricated metric into a report.
        old=result.stages[2]
        staged=merge(semantic_view(old),(metrics=(R.CandidateChainMetricV4(
            :jacobian_fd_max_scaled_error,123.0,UnitSignature(),"fabricated"),),))
        changed=R.CandidateChainStageV4(R._CANDIDATE_CHAIN_TOKEN,values(staged)...,canonical_hash(staged))
        staged_report=merge(semantic_view(result),
            (stages=(result.stages[1],changed,result.stages[3:end]...),))
        fabricated=R.CandidateEndToEndResultV4(R._CANDIDATE_CHAIN_TOKEN,
            values(staged_report)...,canonical_hash(staged_report))
        @test_throws ArgumentError R.write_candidate_chain_report(fabricated,mktempdir())
        for update in ((p5_ready=true,),(whole_device_physics_executed=true,),
                (credible_device_count=1,),(terminal_authority=true,),(outcome=:pass,))
            b=merge(semantic_view(result),update)
            bad=R.CandidateEndToEndResultV4(R._CANDIDATE_CHAIN_TOKEN,values(b)...,canonical_hash(b))
            @test_throws ArgumentError canonical_hash(bad)
        end
        foreign_result=merge(semantic_view(validation),(candidate_hash=digest256_text("another"),))
        bad_validation=R.CandidateValidationPropagationResultV4(values(foreign_result)...,canonical_hash(foreign_result))
        @test_throws ArgumentError R._chain_bound_to(context,bad_validation)
    end
end
