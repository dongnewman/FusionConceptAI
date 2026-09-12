using Test

"Run with the already executed integration candidate; never starts a provider."
function test_candidate_validation_propagation_integration(result, upstream,
        traction_request,traction_result,q2_request,q2_result,q2_execution,
        q3_execution,q4_execution,independent_execution)
    owner=parentmodule(typeof(result))
    @testset "candidate validation propagation real-chain receipt" begin
        @test result.candidate_hash==upstream[1].candidate_hash
        @test result.context_hash==upstream[1].context_hash
        @test result.numerical_status in (:fail,:deferred)
        @test result.numerical_diagnostic_executed && result.error_propagation_executed
        @test !result.physical_validation_executed && !result.parametric_uq_executed
        @test result.physical_validation_credit==0
        @test result.benchmark.status==:pass
        @test length(result.quadrature_diagnostics)==3
        @test result.force_spread.region_ids==result.region_ids
        @test all(d -> d.value.local_force_magnitude_integral_N>=0,result.quadrature_diagnostics)
        @test owner.validate_candidate_validation_propagation(result,upstream,
            traction_request,traction_result,q2_request,q2_result,q2_execution,
            q3_execution,q4_execution,independent_execution)==result.result_hash
        forged_body=merge(owner.semantic_view(result),(candidate_hash=owner.canonical_hash(:foreign_candidate),))
        forged=owner.CandidateValidationPropagationResultV4(values(forged_body)...,owner.canonical_hash(forged_body))
        @test_throws ArgumentError owner.validate_candidate_validation_propagation(forged,upstream,
            traction_request,traction_result,q2_request,q2_result,q2_execution,
            q3_execution,q4_execution,independent_execution)
    end
end

"Cross-check independently coded cylindrical and Cartesian periodic reductions."
function test_candidate_periodic_physics_agreement(physics,validation)
    diagnostic=only(d.value for d in validation.quadrature_diagnostics if d.label==:midpoint_independent)
    @testset "independent periodic formulation versus weak-moment provider" begin
        @test physics.candidate_hash==validation.candidate_hash
        @test physics.context_hash==validation.context_hash
        @test physics.region_ids==validation.region_ids
        @test physics.nfp==validation.nfp
        errors=Float64[]
        for (i,r) in enumerate(diagnostic.regions)
            scale=max(r.local_force_magnitude_integral_N,1.0)
            expected=r.periodic_full_torus_force_N
            observed=physics.region_strong_moments_N[i][1]
            delta=sqrt(sum((observed[k]-expected[k])^2 for k in 1:3))
            push!(errors,delta)
            @test delta<=1e-12*scale
            @test isapprox(physics.region_force_magnitude_integral_N[i],r.local_force_magnitude_integral_N;rtol=1e-12,atol=1e-10)
            @test isapprox(physics.region_volume_m3[i],r.volume_m3;rtol=1e-12,atol=1e-10)
        end
        println("INDEPENDENT_PERIODIC_FORMULATION_MAX_DIFFERENCE_N=",maximum(errors))
    end
end
