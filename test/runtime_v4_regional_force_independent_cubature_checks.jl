using Test
using FusionConceptAI

"Run against the already executed candidate; no provider process is started."
function test_candidate_independent_cubature(independent_execution, imit_upstream,
        imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, q4_execution)
    RFIC=parentmodule(typeof(independent_execution.request))
@testset "independent regional force cubature" begin
 e=independent_execution
 @test RFIC.canonical_hash(e.request)==e.request.request_hash
 @test RFIC.canonical_hash(e.result)==e.result.result_hash
 @test RFIC.canonical_hash(e.receipt)==e.receipt.receipt_hash
 @test length(e.request.nodes)==125*length(e.request.partition_region_ids)
 @test all(isfinite,e.result.total_force)
 @test RFIC._rfic_sum(e.result.region_force)==e.result.total_force
 @test e.independent_replay_required && !e.independent_code_validation
 @test !e.physical_validation && !e.validation_uq && !e.promotion_authority && !e.terminal_authority && e.credible_device_count==0 && e.claim_ceiling===screen_only
 @test e.comparison_status in (:pass,:fail)
 @test e.request.relative_tolerance==1e-3 && e.request.absolute_tolerance_N==1e-6
 @test e.request.nfp > 0
 @test isapprox(sum(n.weight for n in e.request.nodes),sum((r.rho_upper-r.rho_lower)*4pi^2 for r in imit_upstream[12].regions);rtol=0,atol=1e-10)
 @test all(count(n->n.region_id==id,e.request.nodes)==125 for id in e.request.partition_region_ids)
 missing_body=merge(RFIC.semantic_view(e.request),(nodes=e.request.nodes[1:end-1],))
 missing_req=RFIC.RegionalForceIndependentRequestV4(RFIC._RFIC_TOKEN,values(missing_body)...,RFIC.canonical_hash(missing_body))
 @test_throws ArgumentError RFIC.canonical_hash(missing_req)
 duplicate_body=merge(RFIC.semantic_view(e.request),(nodes=(e.request.nodes[1:end-1]...,e.request.nodes[end-1]),))
 duplicate_req=RFIC.RegionalForceIndependentRequestV4(RFIC._RFIC_TOKEN,values(duplicate_body)...,RFIC.canonical_hash(duplicate_body))
 @test_throws ArgumentError RFIC.canonical_hash(duplicate_req)
 foreign_body=merge(RFIC.semantic_view(e.receipt),(field_receipt_hash=canonical_hash(e.basis_result.receipt),))
 foreign_receipt=RFIC.RegionalForceIndependentReceiptV4(RFIC._RFIC_TOKEN,values(foreign_body)...,RFIC.canonical_hash(foreign_body))
 @test_throws ArgumentError RFIC.validate_regional_force_independent_receipt(foreign_receipt,e.request,e.field_request,e.field_result,e.basis_request,e.basis_result,e.result.region_force,e.result.total_force)
 forged_result_body=merge(RFIC.semantic_view(e.result),(total_force=(e.result.total_force[1]+1,e.result.total_force[2],e.result.total_force[3]),))
 forged_result=RFIC.RegionalForceIndependentResultV4(RFIC._RFIC_TOKEN,values(forged_result_body)...,RFIC.canonical_hash(forged_result_body))
 @test_throws ArgumentError RFIC.canonical_hash(forged_result)
 @test hasmethod(RFIC._rfic_recompute,Tuple{Tuple,Tuple,Tuple})
 @test_throws ArgumentError RFIC.validate_regional_force_independent_execution(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution,merge(e,(absolute_difference_N=e.absolute_difference_N+1,)))
 @test_throws ArgumentError RFIC.validate_regional_force_independent_execution(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution,merge(e,(relative_difference=e.relative_difference+1,)))
 @test_throws ArgumentError RFIC.validate_regional_force_independent_execution(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution,merge(e,(comparison_status=e.comparison_status===:pass ? :fail : :pass,)))
 @test_throws ArgumentError RFIC.validate_regional_force_independent_execution(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution,merge(e,(q4_total_force=(e.q4_total_force[1]+1,e.q4_total_force[2],e.q4_total_force[3]),)))
 forged_tol=merge(RFIC.semantic_view(e.request),(relative_tolerance=1e-2,)); forged_tol_req=RFIC.RegionalForceIndependentRequestV4(RFIC._RFIC_TOKEN,values(forged_tol)...,RFIC.canonical_hash(forged_tol)); @test RFIC.canonical_hash(forged_tol_req)==forged_tol_req.request_hash
 @test_throws ArgumentError RFIC.validate_regional_force_independent_execution(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution,merge(e,(request=forged_tol_req,)))
 forged_body=merge(RFIC.semantic_view(e.request),(quadrature=:forged,))
 forged=RFIC.RegionalForceIndependentRequestV4(RFIC._RFIC_TOKEN,values(forged_body)...,RFIC.canonical_hash(forged_body))
 @test_throws ArgumentError RFIC.canonical_hash(forged)
end
end
