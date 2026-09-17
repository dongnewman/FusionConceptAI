using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "RegionalMHDWeakResidualV4.jl"))
u=UnitSignature((0,0,0,0,0,0,0)); ty=PhysicalType(:vector,1,3,:algebraic,u); h=canonical_hash(:example)
ast=ast_leaf(:state,ty;input_port=1); graph=TypedOperatorHypergraphV1((node(:state,ty),),())
tf=RegionalMHDTestFunctionV4("w","r1","support",:force_balance,ty,h;manufactured=true)
src=RegionalMHDSourceTermV4("r1","support",:force_balance,u,(0.,0.,0.),h)
up=(test_only_desc_regional_observation_binding(:missing,:candidate,:context;status=:deferred),)
result=assemble_regional_mhd_weak_residual(:candidate,:context,ast,graph,(tf,),(src,),(),up;manufactured_control=true)
println((status=result.status,global_ledger=result.global_ledger,claim_ceiling=result.claim_ceiling))
