using Test,FusionConceptAI
function check_spatial_chain_v4(M,ctx,upstream,p,e,v,w)
    @testset "same-revision actual spatial chain" begin
        @test upstream.request.candidate_hash==ctx.candidate_hash
        @test upstream.request.context_hash==ctx.context_hash
        @test upstream.result.provider_executed
        @test p.executed && e.executed && v.executed
        @test p.primary_case_id=="nominal_coarse"
        @test Tuple(c.case_id for c in p.cases)==("nominal_coarse","nominal_fine","flux_low_coarse","flux_high_coarse")
        @test Tuple(length(c.final_state) for c in p.cases)==(360,2640,360,360)
        @test Tuple(c.case_id for c in p.cases)==Tuple(c.case_id for c in e.cases)
        for (pc,ec) in zip(p.cases,e.cases)
            @test pc.executed && ec.executed
            @test !isempty(pc.iterations)
            @test pc.engineering_input.state_hash==pc.state_hash==ec.state_hash
            @test ec.candidate_hash==ctx.candidate_hash && ec.context_hash==ctx.context_hash
            @test ec.static.induced_emf_V==0.0
            @test !ec.static.total_external_field && ec.input_identity_valid && !ec.physical_upstream_valid
            @test isfinite(ec.static.flux_linkage_Wb)
        end
        @test v.physical_validation.status===:unsupported
        @test w.spatial_execution_minimum_reached
        @test w.status===:deferred && !w.p5_ready && w.credible_device_count==0
        @test all(s->s.dependency_links_valid,w.stages)
        @test !only(s.physical_upstream_valid for s in w.stages if s.stage===:upstream_DESC)
        @test canonical_hash(w)==w.result_hash
        @test length(default_operator_registry().operators)==20
    end
    println("SPATIAL_INTEGRATION_TESTS_EXIT_CODE=0")
end
