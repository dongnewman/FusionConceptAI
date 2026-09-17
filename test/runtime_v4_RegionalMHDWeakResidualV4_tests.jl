using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "RegionalMHDWeakResidualV4.jl"))
@testset "RegionalMHDWeakResidualV4 strict slice" begin
 u=UnitSignature((0,0,0,0,0,0,0)); ty=PhysicalType(:vector,1,3,:algebraic,u); h=canonical_hash(:fixture)
 ast=ast_leaf(:state,ty;input_port=1); graph=TypedOperatorHypergraphV1((node(:state,ty),),())
 tf=RegionalMHDTestFunctionV4("w1","r1","support-a",:force_balance,ty,h;manufactured=true); tf2=RegionalMHDTestFunctionV4("w2","r2","support-a",:force_balance,ty,h;manufactured=true)
 src=RegionalMHDSourceTermV4("r1","support-a",:force_balance,u,(1,2,3),h)
 i1=RegionalMHDBoundaryTermV4("i12","r1","r2","support-a",:force_balance,u,(-1,-2,-3),h); i2=RegionalMHDBoundaryTermV4("i12","r2","r1","support-a",:force_balance,u,(1,2,3),h)
 ext=RegionalMHDBoundaryTermV4("ext","r1",nothing,"support-a",:force_balance,u,(.5,.5,.5),h)
 up=(test_only_desc_regional_observation_binding(:fixture,:candidate,:context;manufactured=true),test_only_static_mhd_interface_ledger_binding(:fixture,:candidate,:context;manufactured=true))
 x=assemble_regional_mhd_weak_residual(:candidate,:context,ast,graph,(tf,tf2),(src,),(i1,i2,ext),up;manufactured_control=true)
 @test x.status==:deferred; @test x.global_ledger.balanced==false; @test length(x.test_function_residuals[1].residual)==3
 @test validate_regional_mhd_weak_residual(x)==x.residual_hash; @test regional_mhd_weak_residual_manifest().vector_components==3
 d=test_only_desc_regional_observation_binding(:missing,:candidate,:context;status=:deferred); y=assemble_regional_mhd_weak_residual(:candidate,:context,ast,graph,(tf,tf2),(src,),(i1,i2),(d,);manufactured_control=true)
 @test y.status==:deferred; @test y.claim_ceiling==screen_only
 @test_throws ArgumentError RegionalMHDTestFunctionV4("bad","r1","s",:x,PhysicalType(:scalar,0,3,:algebraic,u),h)
 @test_throws ArgumentError RegionalMHDSourceTermV4("r9","s",:force_balance,u,(1,2),h)
 @test_throws ArgumentError assemble_regional_mhd_weak_residual(:candidate,:context,ast,graph,(),(src,),(i1,),up;manufactured_control=true)
 bad1=RegionalMHDBoundaryTermV4("i","r1","r2","support-a",:force_balance,u,(1,0,0),h); bad2=RegionalMHDBoundaryTermV4("i","r2","r1","support-a",:force_balance,u,(1,0,0),h)
 @test_throws ArgumentError assemble_regional_mhd_weak_residual(:candidate,:context,ast,graph,(tf,),(src,),(bad1,bad2),up;manufactured_control=true)
 @test_throws MethodError RegionalMHDWeakResidualV4(x.candidate_identity,x.context_identity,x.ast_hash,x.hypergraph_hash,x.test_functions,x.source_terms,x.boundary_terms,x.upstream,x.missing_capabilities,x.test_function_residuals,x.regional_ledger,x.global_ledger,:deferred,true,screen_only,x.residual_hash)
 req,exec,receipt=execute_regional_mhd_weak_residual(x;integration_nodes=(:r1,:r2))
 @test validate_regional_mhd_weak_execution(req,exec,receipt)==canonical_hash(semantic_view(exec))
 @test req.status==:deferred && !exec.provider_executed && receipt.exit_code==0
 @test replay_regional_mhd_weak_residual(x).residual_hash==x.residual_hash
 @test_throws ArgumentError validate_regional_mhd_weak_execution(req,
     RegionalMHDWeakExecutionResultV4(req.request_hash,exec.result_hash,
         receipt.receipt_hash,:deferred,true,true,screen_only),receipt)
end
