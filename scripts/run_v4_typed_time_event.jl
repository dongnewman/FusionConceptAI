using Pkg
Pkg.activate(joinpath(@__DIR__,".."))
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeResidual.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeEvents.jl"))
using .FusionRuntimeV4
const replay_typed_time_events=FusionRuntimeV4.replay_typed_time_events
const typed_time_events_manifest=FusionRuntimeV4.typed_time_events_manifest
include(joinpath(@__DIR__,"..","examples","runtime_v4_typed_time_event_fixture.jl"))
e=tte_result.events[1]
println("status=",tte_result.status," event_time=",e.event_time," pre_target=",e.pre_state[3]," post_target=",e.post_state[3]," remainder=",length(tte_result.times)>2 ? tte_result.times[end]-e.event_time : 0.0," rhs_evaluations=",tte_result.rhs_evaluations," guard_evaluations=",tte_result.guard_evaluations," reset_evaluations=",tte_result.reset_evaluations," residual=",tte_result.residual_norm," exit=terminal")
println("claim_ceiling=screen_only; simultaneous_events=deferred")
replay_ok=replay_typed_time_events(tte_plan,tte_scenario,tte_result)
terminal_gate=tte_result.status===:terminated_event && e.terminal && abs(e.event_time-log(1.2))<2e-3 && all(isapprox.(e.pre_state,(1/6,1/2,5/6);atol=2e-3)) && all(isapprox.(e.post_state,(1/6,1/2,-5/6);atol=2e-3))
count_gate=tte_result.rhs_evaluations>4 && tte_result.guard_evaluations>=4 && tte_result.reset_evaluations==1
artifact_gate=canonical_hash(tte_plan) isa Digest256 && canonical_hash(tte_result) isa Digest256 && replay_ok
np=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:falling,1,false),),protocol=tte_protocol)
nr=integrate_typed_time_events(np,tte_scenario)
nonterminal_gate=nr.status===:integrated && nr.times[end]≈tte_scenario.t_stop && nr.times[end]>nr.events[1].event_time
exit(terminal_gate && nonterminal_gate && count_gate && artifact_gate && isfinite(tte_result.residual_norm) && tte_result.trajectory_defect_norm!==nothing && typed_time_events_manifest().claim_ceiling===screen_only ? 0 : 1)
