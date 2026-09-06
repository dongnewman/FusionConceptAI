using Test
using Pkg
Pkg.activate(joinpath(@__DIR__,".."))
using FusionConceptAI
include(joinpath(@__DIR__,"..","src","RuntimeV4","FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeResidual.jl"))
Base.include(FusionRuntimeV4,joinpath(@__DIR__,"..","src","RuntimeV4","TypedTimeEvents.jl"))
using .FusionRuntimeV4
const TypedTimeEventPlanV4=FusionRuntimeV4.TypedTimeEventPlanV4
const TypedTimeEventResultV4=FusionRuntimeV4.TypedTimeEventResultV4
const TimeEventRecordV4=FusionRuntimeV4.TimeEventRecordV4
const typed_time_events_manifest=FusionRuntimeV4.typed_time_events_manifest
const replay_typed_time_events=FusionRuntimeV4.replay_typed_time_events
function result_hash_like(r; events=r.events, rhs_evaluations=r.rhs_evaluations,
                          trajectory_defect_norm=r.trajectory_defect_norm,
                          residual_norm=r.residual_norm)
    canonical_hash((revision="typed-time-events-v2",plan=r.plan_hash,scenario=r.scenario_hash,
        times=r.times,states=r.states,events=Tuple(e.record_hash for e in events),
        rhs_evaluations=rhs_evaluations,guard_evaluations=r.guard_evaluations,
        reset_evaluations=r.reset_evaluations,failure_code=r.failure_code,
        reason=r.failure_reason,locations=r.location_artifacts,
        mass_residual_norm=r.mass_residual_norm,trajectory_defect_norm=trajectory_defect_norm,
        residual_norm=residual_norm,status=r.status))
end
include(joinpath(@__DIR__,"..","examples","runtime_v4_typed_time_event_fixture.jl"))

@testset "D1.2b candidate-bound single event" begin
    @test tte_plan isa TypedTimeEventPlanV4
    @test tte_plan.residual_plan.prefix_hash == tte_compiled.prefix_hash
    @test tte_compiled.compilation_status in (:prefix_consistent,:prefix_incomplete,:certificate_candidate)
    @test all(o -> o isa CapabilitySignatureV4, tte_compiled.capability_obligations)
    @test tte_result.status === :terminated_event
    @test length(tte_result.events)==1
    ev=tte_result.events[1]
    @test 0.0 < ev.event_time < 0.2
    @test ev.post_state[3] ≈ -ev.pre_state[3]
    @test ev.post_state[3] != ev.pre_state[3]
    @test replay_typed_time_events(tte_plan,tte_scenario,tte_result) === true
    @test ev.terminal
    @test tte_result.rhs_evaluations > 4
    @test_throws ArgumentError TimeEventProtocolV4(true,20)
    @test_throws Exception TypedTimeEventResultV4(:integrated,(),(),(),0,nothing,nothing,digest256_text("x"))
    @test canonical_hash(tte_binding) === true
    @test typed_time_events_manifest().claim_ceiling===screen_only
    bad=TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:rising,1,true)
    @test integrate_typed_time_events(compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(bad,),protocol=tte_protocol),tte_scenario).status===:integrated
    @test isempty(integrate_typed_time_events(compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(bad,),protocol=tte_protocol),tte_scenario).events)
    @test_throws ArgumentError compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:rising,1,true),TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.6,tte_unit,:rising,2,true)),protocol=tte_protocol)

    # Protocol boundary: every numerical policy field is typed and bounded.
    @test_throws ArgumentError TimeEventProtocolV4(0.0,20)
    @test_throws ArgumentError TimeEventProtocolV4(-0.1,20)
    @test_throws ArgumentError TimeEventProtocolV4(NaN,20)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,0)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,-1)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;event_time_tol=0.0)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;event_value_tol=-1.0)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;max_bisections=0)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;max_events=0)
    @test tte_protocol.max_events > 0
    @test tte_protocol.max_bisections == 80

    # Binding boundary: direction, priority, finite threshold and exact hash.
    @test tte_binding.threshold == 0.5
    @test tte_binding.threshold_unit == tte_unit
    @test tte_binding.direction === :falling
    @test tte_binding.priority == 1
    @test tte_binding.terminal === true
    @test_throws ArgumentError TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],NaN,tte_unit,:falling,1,true)
    @test_throws ArgumentError TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:sideways,1,true)
    @test_throws ArgumentError TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:falling,0,true)
    @test_throws ArgumentError TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:falling,true,true)
    foreign_binding=TimeEventBindingV4(digest256_text("foreign"),tte_refs[1],0.5,tte_unit,:falling,1,true)
    @test foreign_binding.carrier_edge_hash != tte_binding.carrier_edge_hash

    # Event semantics and split evidence.
    @test ev.event_time ≈ log(1.2) atol=2e-3
    @test ev.pre_state[3] ≈ 5/6 atol=2e-3
    @test ev.post_state[3] ≈ -5/6 atol=2e-3
    @test abs(ev.guard_value) <= tte_protocol.event_value_tol + 1e-8
    @test ev.iterations > 0
    @test isfinite(ev.event_time)
    @test all(isfinite, ev.pre_state)
    @test all(isfinite, ev.post_state)
    @test tte_result.times[end] ≈ ev.event_time
    @test length(tte_result.times) == length(tte_result.states)
    @test tte_result.rhs_evaluations >= 4
    @test tte_result.residual_norm !== nothing
    @test isfinite(tte_result.residual_norm)
    @test tte_result.failure_reason === nothing
    @test ev.edge_hash == tte_binding.carrier_edge_hash
    @test ev.direction === tte_binding.direction
    @test ev.priority == tte_binding.priority

    # Repeatability and replay tamper controls.
    tte_result2=integrate_typed_time_events(tte_plan,tte_scenario)
    @test tte_result.result_hash == tte_result2.result_hash
    @test tte_result.times == tte_result2.times
    @test tte_result.states == tte_result2.states
    @test tte_result.events[1].record_hash == tte_result2.events[1].record_hash
    @test replay_typed_time_events(tte_plan,tte_scenario,tte_result2) === true
    altered=TimeIntegrationScenarioV4("tte-altered",0.0,1.0,tte_time_unit,tte_scenario.initial_values)
    @test_throws ArgumentError replay_typed_time_events(tte_plan,altered,tte_result)
    @test_throws MethodError TypedTimeEventResultV4(:terminated_event,(),(),(),0,nothing,nothing,digest256_text("fake"))

    # Wrong direction is a valid no-event integration, not a failure.
    rising=TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:rising,1,true)
    rising_plan=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(rising,),protocol=tte_protocol)
    rising_result=integrate_typed_time_events(rising_plan,tte_scenario)
    @test rising_result.status === :integrated
    @test isempty(rising_result.events)
    @test rising_result.times[end] ≈ tte_scenario.t_stop
    @test replay_typed_time_events(rising_plan,tte_scenario,rising_result) === true

    # Carrier closure and manifest/role/type gates.
    @test_throws ArgumentError compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(tte_binding,tte_binding),protocol=tte_protocol)
    foreign=TimeEventBindingV4(digest256_text("not-in-graph"),tte_refs[1],0.5,tte_unit,:falling,1,true)
    @test_throws ArgumentError compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(foreign,),protocol=tte_protocol)
    changed_protocol_plan=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(tte_binding,),protocol=TimeEventProtocolV4(0.1,20))
    @test changed_protocol_plan.plan_hash != tte_plan.plan_hash

    # Sol regressions: tolerance must not manufacture a successful event.
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;event_time_tol=true)
    @test_throws ArgumentError TimeEventProtocolV4(0.2,20;event_value_tol=true)
    loose=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(tte_binding,),protocol=TimeEventProtocolV4(0.2,20;event_time_tol=1e-3,event_value_tol=1e-16))
    loose_result=integrate_typed_time_events(loose,tte_scenario)
    @test loose_result.status !== :terminated_event
    @test loose_result.failure_reason !== nothing || loose_result.status !== :integrated
    out_of_bounds=TimeIntegrationScenarioV4("out-of-bounds",0.0,1.0,tte_time_unit,(StateValueV4(tte_refs[1],11.0,tte_unit),StateValueV4(tte_refs[2],0.6,tte_unit),StateValueV4(tte_refs[3],0.2,tte_unit)))
    @test_throws ArgumentError integrate_typed_time_events(tte_plan,out_of_bounds)

    # Nonterminal split integrates the unused remainder and reaches t_stop.
    nonterminal=TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:falling,1,false)
    np=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(nonterminal,),protocol=tte_protocol)
    nr=integrate_typed_time_events(np,tte_scenario)
    @test nr.status === :integrated
    @test length(nr.events)==1
    @test nr.times[end] ≈ tte_scenario.t_stop
    @test nr.times[end] > nr.events[1].event_time
    @test replay_typed_time_events(np,tte_scenario,nr) === true

    # Initial event band is deferred with a preserved partial artifact.
    band=TimeIntegrationScenarioV4("initial-band",0.0,1.0,tte_time_unit,(StateValueV4(tte_refs[1],1.0,tte_unit),StateValueV4(tte_refs[2],0.5,tte_unit),StateValueV4(tte_refs[3],0.2,tte_unit)))
    br=integrate_typed_time_events(tte_plan,band)
    @test br.status === :deferred_initial_event_band
    @test isempty(br.events)
    @test length(br.times)==1
    @test br.failure_reason !== nothing
    @test replay_typed_time_events(tte_plan,band,br) === true

    # Event counters and residual evidence are explicit, finite and nonempty.
    @test tte_result.guard_evaluations > 0
    @test tte_result.reset_evaluations > 0
    @test tte_result.rhs_evaluations > tte_result.guard_evaluations
    @test tte_result.residual_norm !== nothing
    @test isfinite(tte_result.residual_norm)
    @test tte_result.residual_norm >= 0
    @test hasproperty(tte_result,:result_hash)

    # Tampered record/result artifacts are rejected even if stale hashes remain.
    tev=tte_result.events[1]
    forged=TimeEventRecordV4(FusionRuntimeV4._TTE_TOKEN,tev.edge_hash,tev.event_time,Tuple([99.0,99.0,99.0]),tev.post_state,tev.guard_value,tev.direction,tev.priority,tev.terminal,tev.iterations,tev.record_hash)
    forged_result=TypedTimeEventResultV4(FusionRuntimeV4._TTE_TOKEN,tte_result.status,tte_result.times,tte_result.states,(forged,),tte_result.rhs_evaluations,tte_result.guard_evaluations,tte_result.reset_evaluations,tte_result.failure_reason,tte_result.residual_norm,tte_result.result_hash)
    @test_throws ArgumentError replay_typed_time_events(tte_plan,tte_scenario,forged_result)
    @test_throws ArgumentError replay_typed_time_events(tte_plan,tte_scenario,TypedTimeEventResultV4(FusionRuntimeV4._TTE_TOKEN,tte_result.status,tte_result.times,tte_result.states,tte_result.events,tte_result.rhs_evaluations+1,tte_result.guard_evaluations,tte_result.reset_evaluations,tte_result.failure_reason,tte_result.residual_norm,tte_result.result_hash))

    # Plan/form/record protocol identities are independently checked.
    @test canonical_hash(tte_plan.protocol) === true
    @test canonical_hash(tte_plan) isa Digest256
    @test canonical_hash(tev) isa Digest256
    @test tev.record_hash == canonical_hash((edge=tev.edge_hash,time=tev.event_time,pre=tev.pre_state,post=tev.post_state,guard=tev.guard_value,direction=tev.direction,priority=tev.priority,terminal=tev.terminal,iterations=tev.iterations))
    @test tte_result.status in (:terminated_event,:integrated)
    @test all(isfinite, tte_result.times)
    @test all(all(isfinite,s) for s in tte_result.states)
    @test length(tte_result.times)==length(tte_result.states)
    @test tte_plan.protocol.max_events >= 1
    @test tte_plan.protocol.event_time_tol > 0
    @test tte_plan.protocol.event_value_tol > 0

    # Guard/reset provenance is part of the sealed carrier authority.  Reusing
    # the original edge/hash while rebinding guard_state to reset_state must
    # fail both canonical validation and public execution.
    original_carrier=tte_plan.carriers[1]
    rebound_carrier=FusionRuntimeV4._TTECarrier(original_carrier.edge,original_carrier.reset_state,
        original_carrier.reset_state,original_carrier.carrier_hash)
    rebound_plan=TypedTimeEventPlanV4(FusionRuntimeV4._TTE_TOKEN,tte_plan.residual_plan,
        tte_plan.mechanism_graph,(rebound_carrier,),tte_plan.bindings,tte_plan.protocol,tte_plan.plan_hash)
    @test_throws ArgumentError canonical_hash(rebound_plan)
    @test_throws ArgumentError integrate_typed_time_events(rebound_plan,tte_scenario)

    # Sol P0-1: self-consistent result tampering is rejected by replay.
    rhs_tampered=TypedTimeEventResultV4(FusionRuntimeV4._TTE_TOKEN,tte_result.status,tte_result.times,tte_result.states,
            tte_result.events,tte_result.rhs_evaluations+1,tte_result.guard_evaluations,tte_result.reset_evaluations,
            tte_result.failure_code,tte_result.failure_reason,tte_result.location_artifacts,
            tte_result.mass_residual_norm,tte_result.trajectory_defect_norm,tte_result.residual_norm,
            tte_result.plan_hash,tte_result.scenario_hash,result_hash_like(tte_result;rhs_evaluations=tte_result.rhs_evaluations+1))
    @test_throws ArgumentError replay_typed_time_events(tte_plan,tte_scenario,rhs_tampered)
    defect=max(tte_result.mass_residual_norm, tte_result.trajectory_defect_norm+1.0e-6)
    defect_tampered=TypedTimeEventResultV4(FusionRuntimeV4._TTE_TOKEN,tte_result.status,tte_result.times,tte_result.states,
            tte_result.events,tte_result.rhs_evaluations,tte_result.guard_evaluations,tte_result.reset_evaluations,
            tte_result.failure_code,tte_result.failure_reason,tte_result.location_artifacts,
            tte_result.mass_residual_norm,defect,defect,tte_result.plan_hash,tte_result.scenario_hash,
            result_hash_like(tte_result;trajectory_defect_norm=defect,residual_norm=defect))
    @test_throws ArgumentError replay_typed_time_events(tte_plan,tte_scenario,defect_tampered)

    # Sol P0-2: a record whose hash is recomputed after priority mutation still
    # cannot be replayed as the original event result.
    ev2=TimeEventRecordV4(FusionRuntimeV4._TTE_TOKEN,ev.edge_hash,ev.event_time,ev.pre_state,ev.post_state,
        ev.guard_value,ev.direction,ev.priority+1,ev.terminal,ev.iterations,
        canonical_hash((edge=ev.edge_hash,time=ev.event_time,pre=ev.pre_state,post=ev.post_state,guard=ev.guard_value,
            direction=ev.direction,priority=ev.priority+1,terminal=ev.terminal,iterations=ev.iterations)))
    @test ev2.record_hash != ev.record_hash
    @test_throws ArgumentError replay_typed_time_events(tte_plan,tte_scenario,
        TypedTimeEventResultV4(FusionRuntimeV4._TTE_TOKEN,tte_result.status,tte_result.times,tte_result.states,(ev2,),
            tte_result.rhs_evaluations,tte_result.guard_evaluations,tte_result.reset_evaluations,tte_result.failure_code,
            tte_result.failure_reason,tte_result.location_artifacts,tte_result.mass_residual_norm,
            tte_result.trajectory_defect_norm,tte_result.residual_norm,tte_result.plan_hash,tte_result.scenario_hash,
            canonical_hash((revision="typed-time-events-v2",plan=tte_result.plan_hash,scenario=tte_result.scenario_hash,
                times=tte_result.times,states=tte_result.states,events=(ev2.record_hash,),rhs_evaluations=tte_result.rhs_evaluations,
                guard_evaluations=tte_result.guard_evaluations,reset_evaluations=tte_result.reset_evaluations,
                failure_code=tte_result.failure_code,reason=tte_result.failure_reason,locations=tte_result.location_artifacts,
                mass_residual_norm=tte_result.mass_residual_norm,trajectory_defect_norm=tte_result.trajectory_defect_norm,
                residual_norm=tte_result.residual_norm,status=tte_result.status))))

    # Sol P0-3: carrier metadata cannot be rebound from guard state to reset state.
    @test tte_plan.carriers[1].guard_state != tte_plan.carriers[1].reset_state
    rebound=TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[3],0.5,tte_unit,:falling,1,true)
    @test_throws ArgumentError compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(rebound,),protocol=tte_protocol)

    # Sol P0-4: large-step stage failure is a numerical artifact, not success.
    stage_plan=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,
        event_bindings=(tte_binding,),protocol=TimeEventProtocolV4(10.0,1))
    stage_scenario=TimeIntegrationScenarioV4("stage-failure",0.0,11.0,tte_time_unit,tte_scenario.initial_values)
    stage_result=integrate_typed_time_events(stage_plan,stage_scenario)
    @test stage_result.status === :numerical_failure
    @test stage_result.failure_code === :execution_failure
    @test stage_result.rhs_evaluations == 2
    @test length(stage_result.times)==1
    @test length(stage_result.states)==1
    @test all(all(isfinite,s) for s in stage_result.states)
    @test all(all(-10.0 <= x <= 10.0 for x in s) for s in stage_result.states)

    # Sol P0-5: changing the public mass matrix fails at authority validation.
    m0=tte_plan.residual_plan.mass_matrix[1,1]
    tte_plan.residual_plan.mass_matrix[1,1]=m0+1.0
    @test_throws ArgumentError integrate_typed_time_events(tte_plan,tte_scenario)
    tte_plan.residual_plan.mass_matrix[1,1]=m0

    # Sol P0-6: continuous residual evidence is finite and not a fabricated zero.
    @test tte_result.mass_residual_norm !== nothing
    @test tte_result.trajectory_defect_norm !== nothing
    @test tte_result.residual_norm >= max(tte_result.mass_residual_norm,tte_result.trajectory_defect_norm)
    @test tte_result.trajectory_defect_norm > 0
end
