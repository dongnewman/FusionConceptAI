# D1.2b candidate-bound typed threshold events over the D1.1 continuous path.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TTE_REVISION = "typed-time-events-v2"
const _TTE_TOKEN = Val(:typed_time_events_private)
const _TTE_TIME = UnitSignature((0,0,1,0,0,0,0))

struct TimeEventProtocolV4
    step::Float64; max_steps::Int; event_time_tol::Float64; event_value_tol::Float64
    max_bisections::Int; max_events::Int; protocol_hash::Digest256
    function TimeEventProtocolV4(step,max_steps; event_time_tol=1e-10,event_value_tol=1e-10,max_bisections=80,max_events=16)
        step isa Bool && throw(ArgumentError("step must not be Bool")); max_steps isa Bool && throw(ArgumentError("max_steps must not be Bool"))
        max_bisections isa Bool && throw(ArgumentError("max_bisections must not be Bool")); max_events isa Bool && throw(ArgumentError("max_events must not be Bool")); event_time_tol isa Bool && throw(ArgumentError("event_time_tol must not be Bool")); event_value_tol isa Bool && throw(ArgumentError("event_value_tol must not be Bool")); h=Float64(step); n=Int(max_steps); et=Float64(event_time_tol); ev=Float64(event_value_tol); mb=Int(max_bisections); me=Int(max_events)
        isfinite(h)&&h>0&&n>0&&isfinite(et)&&et>0&&isfinite(ev)&&ev>0&&mb>0&&me>0 || throw(ArgumentError("invalid event protocol"))
        body=(revision=_TTE_REVISION,step=h,max_steps=n,event_time_tol=et,event_value_tol=ev,max_bisections=mb,max_events=me)
        new(h,n,et,ev,mb,me,canonical_hash(body))
    end
end

struct TimeEventBindingV4
    carrier_edge_hash::Digest256; target_state_ref::StateGeneRefV1; threshold::Float64
    threshold_unit::UnitSignature; direction::Symbol; priority::Int; terminal::Bool
    manifest_hash::Digest256; binding_hash::Digest256
    function TimeEventBindingV4(edge,target,threshold,unit,direction,priority,terminal;manifest_hash=operator_manifest(default_operator_registry(),"THRESHOLD_SWITCH").manifest_hash)
        edge isa Digest256 || throw(ArgumentError("typed carrier hash required")); target isa StateGeneRefV1 || throw(ArgumentError("typed target required"))
        threshold isa Bool && throw(ArgumentError("threshold must not be Bool")); q=Float64(threshold); isfinite(q)||throw(ArgumentError("threshold must be finite"))
        direction in (:rising,:falling,:either) || throw(ArgumentError("invalid direction")); priority isa Int&&priority>0 || throw(ArgumentError("positive priority required")); terminal isa Bool || throw(ArgumentError("terminal must be Bool"))
        b=(revision=_TTE_REVISION,edge=edge,target=target,threshold=q,unit=unit,direction=direction,priority=priority,terminal=terminal)
        new(edge,target,q,unit,direction,priority,terminal,manifest_hash,canonical_hash((b,manifest_hash)))
    end
end

struct _TTECarrier
    edge::AtomicMIMOHyperedgeV1; guard_state::StateGeneRefV1; reset_state::StateGeneRefV1; carrier_hash::Digest256
end
struct EventContinuousFormV4
    prefix_hash::Digest256; state_refs::Tuple; state_types::Tuple; rows::Tuple; mass_matrix::Matrix{Float64}; form_hash::Digest256
    function EventContinuousFormV4(token::Val{:typed_time_events_private},prefix,refs,types,rows,matrix,h)
        token===_TTE_TOKEN || throw(ArgumentError("private constructor"))
        matrix isa Matrix{Float64} || throw(ArgumentError("mass matrix must be derived"))
        new(prefix,refs,types,rows,matrix,h)
    end
end
struct TypedTimeEventPlanV4
    residual_plan::EventContinuousFormV4; mechanism_graph::TypedOperatorHypergraphV1; carriers::Tuple; bindings::Tuple; protocol::TimeEventProtocolV4; plan_hash::Digest256
    function TypedTimeEventPlanV4(token::Val{:typed_time_events_private},rp,graph,cs,bs,p,h)
        token===_TTE_TOKEN || throw(ArgumentError("private constructor")); graph isa TypedOperatorHypergraphV1 || throw(ArgumentError("mechanism graph authority required")); new(rp,graph,cs,bs,p,h)
    end
end

function _tte_form(compiled,registry,bs)
    payload=compiled.candidate.mechanism_genome_ref.payload; graph=payload.operator_graph; states=Tuple(sort(collect(payload.states),by=s->s.state_ref.value)); n=length(states); refs=Tuple(s.state_ref for s in states)
    length(bs)==n || throw(ArgumentError("row coverage mismatch")); all(s->s.physical_type.tensor_rank==0&&s.physical_type.spatial_dimension==0&&s.physical_type.temporal_type.kind===differential_time&&s.physical_type.temporal_type.derivative_order==0&&s.physical_type.value_kind in (:scalar_field,:control_signal),states)||throw(ArgumentError("event form state type unsupported")); M=zeros(n,n); rows=Vector{_TTRRow}(undef,n)
    for (k,s) in enumerate(states)
        b=only(x for x in bs if x.state_ref==s.state_ref); ge=_ttr_edge(graph,b.governing_edge_hash); _ttr_validate_program(ge.program,registry); ge.role===governing||throw(ArgumentError("governing role")); id=ge.program.nodes[ge.program.roots[1]]; id isa ASTApplyV1&&id.operator_ref==OperatorRefV1("IDENTITY","v1")||throw(ArgumentError("identity root")); outs=[o for o in ge.output_bindings if o.program_position==1]; length(outs)==1&&graph.nodes[only(outs).graph_node_index].node_id==s.state_ref.value||throw(ArgumentError("identity ownership")); M[k,:].=_ttr_mass(ge.program,_ttr_ports(ge,graph,states),n,b.mass_root_position,registry); re=_ttr_edge(graph,b.rhs_edge_hash); re.role===additive||throw(ArgumentError("RHS role")); _ttr_validate_program(re.program,registry); rp=_ttr_ports(re,graph,states); lo=_ttr_float(s.physical_bounds.interval.lower,"lower bound"); hi=_ttr_float(s.physical_bounds.interval.upper,"upper bound"); lo<=hi||throw(ArgumentError("invalid state bounds")); rows[k]=_TTRRow(b,s.physical_type,lo,hi,M[k,:],re.program,Tuple((port=p[1],state=p[2]) for p in sort(collect(rp),by=first)),b.rhs_root_position)
    end
    rank(M)==n||throw(ArgumentError("singular event mass")); all(isfinite,M)||throw(ArgumentError("nonfinite event mass")); cond(M)<1e12||throw(ArgumentError("ill-conditioned event mass")); rowview=Tuple((binding=r.binding,rhs_program=r.rhs_program,rhs_ports=r.rhs_ports,rhs_root_position=r.rhs_root_position,mass=Tuple(r.mass_coefficients)) for r in rows); h=canonical_hash((revision=_TTE_REVISION,prefix=compiled.prefix_hash,refs,state_types=Tuple(s.physical_type for s in states),rows=rowview,matrix=M)); EventContinuousFormV4(_TTE_TOKEN,compiled.prefix_hash,refs,Tuple(s.physical_type for s in states),Tuple(rows),M,h)
end
struct TimeEventRecordV4
    edge_hash::Digest256; event_time::Float64; pre_state::Tuple; post_state::Tuple; guard_value::Float64; direction::Symbol; priority::Int; terminal::Bool; iterations::Int; record_hash::Digest256
    function TimeEventRecordV4(token::Val{:typed_time_events_private},x...)
        token===_TTE_TOKEN || throw(ArgumentError("private constructor")); new(x...)
    end
end
struct EventLocationArtifactV4
    edge_hash::Digest256
    bracket_times::Tuple{Float64,Float64}
    bracket_guards::Tuple{Float64,Float64}
    approximate_time::Float64
    approximate_guard::Float64
    iterations::Int
    artifact_hash::Digest256
    function EventLocationArtifactV4(token::Val{:typed_time_events_private},e,bt,bg,t,g,it,h)
        token===_TTE_TOKEN || throw(ArgumentError("private constructor")); new(e,bt,bg,t,g,it,h)
    end
end
semantic_view(a::EventLocationArtifactV4)=(edge=a.edge_hash,bracket_times=a.bracket_times,bracket_guards=a.bracket_guards,time=a.approximate_time,guard=a.approximate_guard,iterations=a.iterations,artifact_hash=a.artifact_hash)
canonical_hash(a::EventLocationArtifactV4) = begin
    h=canonical_hash((edge=a.edge_hash,bracket_times=a.bracket_times,bracket_guards=a.bracket_guards,time=a.approximate_time,guard=a.approximate_guard,iterations=a.iterations)); h==a.artifact_hash || throw(ArgumentError("location artifact tampered")); h
end
struct TypedTimeEventResultV4
    status::Symbol; times::Tuple; states::Tuple; events::Tuple; rhs_evaluations::Int; guard_evaluations::Int; reset_evaluations::Int; failure_code::Union{Nothing,Symbol}; failure_reason::Union{Nothing,String}; location_artifacts::Tuple; mass_residual_norm::Union{Nothing,Float64}; trajectory_defect_norm::Union{Nothing,Float64}; residual_norm::Union{Nothing,Float64}; plan_hash::Digest256; scenario_hash::Digest256; result_hash::Digest256
    function TypedTimeEventResultV4(token::Val{:typed_time_events_private},x...)
        token===_TTE_TOKEN || throw(ArgumentError("private constructor"));
        if length(x)==10
            new(x[1],x[2],x[3],x[4],x[5],x[6],x[7],nothing,x[8],(),x[9],nothing,x[9],digest256_text("legacy-result-without-authority"),digest256_text("legacy-result-without-authority"),x[10])
        elseif length(x)==16
            new(x...)
        else
            throw(MethodError(TypedTimeEventResultV4,Tuple{Vararg{Any}}))
        end
    end
end
function _tte_record_check(r::TimeEventRecordV4)
    h=canonical_hash((edge=r.edge_hash,time=r.event_time,pre=r.pre_state,post=r.post_state,guard=r.guard_value,direction=r.direction,priority=r.priority,terminal=r.terminal,iterations=r.iterations)); h==r.record_hash||throw(ArgumentError("event record tampered")); true
end
semantic_view(r::TimeEventRecordV4)=(edge_hash=r.edge_hash,event_time=r.event_time,pre_state=r.pre_state,post_state=r.post_state,guard_value=r.guard_value,direction=r.direction,priority=r.priority,terminal=r.terminal,iterations=r.iterations,record_hash=r.record_hash)
canonical_hash(r::TimeEventRecordV4)=(_tte_record_check(r); r.record_hash)
function _tte_result_check(r::TypedTimeEventResultV4)
    r.plan_hash isa Digest256 && r.scenario_hash isa Digest256 || throw(ArgumentError("result authority hashes missing"))
    h=canonical_hash((revision=_TTE_REVISION,plan=r.plan_hash,scenario=r.scenario_hash,times=r.times,states=r.states,events=Tuple(e.record_hash for e in r.events),rhs_evaluations=r.rhs_evaluations,guard_evaluations=r.guard_evaluations,reset_evaluations=r.reset_evaluations,failure_code=r.failure_code,reason=r.failure_reason,locations=r.location_artifacts,mass_residual_norm=r.mass_residual_norm,trajectory_defect_norm=r.trajectory_defect_norm,residual_norm=r.residual_norm,status=r.status)); h==r.result_hash || throw(ArgumentError("event result tampered")); true
end
semantic_view(r::TypedTimeEventResultV4)=(revision=_TTE_REVISION,plan_hash=r.plan_hash,scenario_hash=r.scenario_hash,status=r.status,times=r.times,states=r.states,events=r.events,rhs_evaluations=r.rhs_evaluations,guard_evaluations=r.guard_evaluations,reset_evaluations=r.reset_evaluations,failure_code=r.failure_code,failure_reason=r.failure_reason,location_artifacts=r.location_artifacts,mass_residual_norm=r.mass_residual_norm,trajectory_defect_norm=r.trajectory_defect_norm,residual_norm=r.residual_norm,result_hash=r.result_hash)

function _tte_check(p::TimeEventProtocolV4)
    canonical_hash((revision=_TTE_REVISION,step=p.step,max_steps=p.max_steps,event_time_tol=p.event_time_tol,event_value_tol=p.event_value_tol,max_bisections=p.max_bisections,max_events=p.max_events))==p.protocol_hash || throw(ArgumentError("event protocol tampered")); true
end
function _tte_check(b::TimeEventBindingV4)
    canonical_hash(((revision=_TTE_REVISION,edge=b.carrier_edge_hash,target=b.target_state_ref,threshold=b.threshold,unit=b.threshold_unit,direction=b.direction,priority=b.priority,terminal=b.terminal),b.manifest_hash))==b.binding_hash || throw(ArgumentError("event binding tampered")); true
end

function _tte_carrier_from_graph(graph::TypedOperatorHypergraphV1, states, b::TimeEventBindingV4, registry)
    es=filter(e->canonical_hash(e)==b.carrier_edge_hash, graph.hyperedges); length(es)==1 || throw(ArgumentError("carrier not in candidate graph"))
    e=es[1]; Symbol(e.role)==:additive || throw(ArgumentError("carrier must be additive")); length(e.program.roots)==1 || throw(ArgumentError("carrier must be single-root"))
    root=e.program.nodes[e.program.roots[1]]
    root isa ASTApplyV1 && root.operator_ref==OperatorRefV1("THRESHOLD_SWITCH","v1") || throw(ArgumentError("literal THRESHOLD_SWITCH@v1 required"))
    for node in e.program.nodes
        node isa ASTApplyV1 || continue
        manx=operator_manifest(registry,node.operator_ref.qualified)
        manx.event && !(node === root || (node.operator_ref==OperatorRefV1("NEG","v1"))) && throw(ArgumentError("nested or unsupported event operator is deferred"))
        node.operator_ref==OperatorRefV1("EVENT_RESET","v1") && throw(ArgumentError("EVENT_RESET is deferred"))
    end
    man=operator_manifest(registry,"THRESHOLD_SWITCH"); man.event && (:additive in man.allowed_roles) || throw(ArgumentError("event manifest must be event/additive"))
    b.manifest_hash==man.manifest_hash || throw(ArgumentError("event manifest hash mismatch"))
    length(root.inputs)==2 || throw(ArgumentError("threshold switch arity"))
    g=e.program.nodes[root.inputs[1]]; r=e.program.nodes[root.inputs[2]]
    g isa ASTInputV1 || throw(ArgumentError("guard must be direct ASTInput")); r isa ASTApplyV1 && r.operator_ref==OperatorRefV1("NEG","v1") && length(r.inputs)==1 || throw(ArgumentError("reset must be nontrivial NEG subtree"))
    ri=e.program.nodes[r.inputs[1]]; ri isa ASTInputV1 || throw(ArgumentError("reset subtree must consume direct state")); g.port!=ri.port || throw(ArgumentError("guard/reset alias"))
    refs=Tuple(s.state_ref for s in states); b.target_state_ref in refs || throw(ArgumentError("foreign target"))
    function bound_state(node_index)
        poss=findall(==(node_index),e.program.input_ports); length(poss)==1 || throw(ArgumentError("AST input is not a unique program input")); ib=filter(x->x.program_position==only(poss),e.input_bindings); length(ib)==1 || throw(ArgumentError("input program position is not uniquely bound")); nid=graph.nodes[only(ib).graph_node_index].node_id; ss=filter(s->s.state_ref.value==nid,states); length(ss)==1 || throw(ArgumentError("input binding is not a state")); only(ss)
    end
    gs=bound_state(root.inputs[1]); rs=bound_state(r.inputs[1]); gst=hasproperty(gs,:physical_type) ? gs.physical_type : gs.state_type; gst.value_kind===:control_signal&&gst.tensor_rank==0&&gst.spatial_dimension==0&&gst.temporal_type.kind===differential_time&&gst.temporal_type.derivative_order==0 || throw(ArgumentError("guard must be differential control_signal")); b.threshold_unit==gst.units || throw(ArgumentError("threshold unit mismatch")); rs.state_ref==b.target_state_ref || throw(ArgumentError("reset target mismatch"))
    outs=filter(x->x.program_position==1,e.output_bindings); length(outs)==1 || throw(ArgumentError("carrier root output is not unique")); graph.nodes[only(outs).graph_node_index].node_id==b.target_state_ref.value || throw(ArgumentError("carrier output must target state"))
    _TTECarrier(e,gs.state_ref,rs.state_ref,canonical_hash(e))
end

function _tte_carrier(compiled,b,registry)
    states=Tuple(sort(collect(compiled.candidate.mechanism_genome_ref.payload.states),by=s->s.state_ref.value))
    _tte_carrier_from_graph(compiled.mechanism_graph,states,b,registry)
end

function compile_typed_time_event_plan(compiled::CompiledCandidatePrefixV4,registry::GenomeContractRegistryV4;row_bindings,event_bindings,protocol=TimeEventProtocolV4(0.2,100))
    _runtime_validate_compiled_prefix(compiled,compiled.candidate,registry,compiled.mission_payload,compiled.bounds_payload,compiled.minimality_scope.comparison_scope,compiled.minimality_scope.scenario_scope); _tte_check(protocol); bs=Tuple(event_bindings); isempty(bs)&&throw(ArgumentError("event bindings required")); all(b isa TimeEventBindingV4 for b in bs)||throw(ArgumentError("typed bindings required"))
    length(unique(b.priority for b in bs))==length(bs)||throw(ArgumentError("event priorities must be unique"))
    opreg=default_operator_registry(); rp=_tte_form(compiled,opreg,Tuple(row_bindings))
    cs=Tuple(_tte_carrier(compiled,b,opreg) for b in bs); length(unique(c.carrier_hash for c in cs))==length(cs)||throw(ArgumentError("duplicate carriers"))
    graph=compiled.mechanism_graph; expected=Set{Digest256}(); for e in graph.hyperedges; for node in e.program.nodes; node isa ASTApplyV1 || continue; man=operator_manifest(opreg,node.operator_ref.qualified); if man.event; node.operator_ref==OperatorRefV1("THRESHOLD_SWITCH","v1") && node === e.program.nodes[e.program.roots[1]] || throw(ArgumentError("nested/EVENT_RESET/unsupported event operator is deferred")); end; end; end; for e in graph.hyperedges; if length(e.program.roots)==1 && e.program.nodes[e.program.roots[1]] isa ASTApplyV1 && e.program.nodes[e.program.roots[1]].operator_ref==OperatorRefV1("THRESHOLD_SWITCH","v1"); push!(expected,canonical_hash(e)); end; end; Set(c.carrier_hash for c in cs)==expected || throw(ArgumentError("event carrier closure mismatch"))
    h=canonical_hash((revision=_TTE_REVISION,residual=rp.form_hash,mechanism_graph=canonical_hash(compiled.mechanism_graph),carriers=Tuple(c.carrier_hash for c in cs),bindings=Tuple(b.binding_hash for b in bs),protocol=protocol.protocol_hash))
    TypedTimeEventPlanV4(_TTE_TOKEN,rp,compiled.mechanism_graph,cs,bs,protocol,h)
end

function _tte_check(p::TypedTimeEventPlanV4)
    rowview=Tuple((binding=r.binding,rhs_program=r.rhs_program,rhs_ports=r.rhs_ports,rhs_root_position=r.rhs_root_position,mass=Tuple(r.mass_coefficients)) for r in p.residual_plan.rows); p.residual_plan.form_hash==canonical_hash((revision=_TTE_REVISION,prefix=p.residual_plan.prefix_hash,refs=p.residual_plan.state_refs,state_types=p.residual_plan.state_types,rows=rowview,matrix=p.residual_plan.mass_matrix)) || throw(ArgumentError("event form tampered")); _tte_check(p.protocol); length(p.carriers)==length(p.bindings) || throw(ArgumentError("carrier/binding cardinality mismatch")); all(_tte_check,p.bindings)
    states=Tuple((state_ref=r,state_type=t) for (r,t) in zip(p.residual_plan.state_refs,p.residual_plan.state_types))
    all(i->begin c=p.carriers[i]; b=p.bindings[i]; canonical_hash(c.edge)==c.carrier_hash==b.carrier_edge_hash || throw(ArgumentError("carrier edge authority mismatch")); fresh=_tte_carrier_from_graph(p.mechanism_graph,states,b,default_operator_registry()); fresh.guard_state==c.guard_state && fresh.reset_state==c.reset_state && fresh.carrier_hash==c.carrier_hash || throw(ArgumentError("carrier metadata tampered")); true end,eachindex(p.carriers)) || throw(ArgumentError("carrier authority mismatch"))
    h=canonical_hash((revision=_TTE_REVISION,residual=p.residual_plan.form_hash,mechanism_graph=canonical_hash(p.mechanism_graph),carriers=Tuple(c.carrier_hash for c in p.carriers),bindings=Tuple(b.binding_hash for b in p.bindings),protocol=p.protocol.protocol_hash)); h==p.plan_hash||throw(ArgumentError("event plan tampered")); h
end

mutable struct _TTECounter
    rhs::Int
    guard::Int
    reset::Int
end
const _TTE_LIVE=Ref{Any}(nothing)
_tte_rhs(rp,y,c::_TTECounter)=begin c.rhs+=1; f=Float64[_ttr_eval_rhs(r.rhs_program,r.rhs_ports,r.rhs_root_position,y) for r in rp.rows]; all(isfinite,f)||throw(ArgumentError("nonfinite RHS")); z=lu(rp.mass_matrix)\f; all(isfinite,z)||throw(ArgumentError("nonfinite derivative")); z end
_tte_rhs(rp,y)=_tte_rhs(rp,y,_TTECounter(0,0,0))
_tte_residual(rp,y)=begin f=Float64[_ttr_eval_rhs(r.rhs_program,r.rhs_ports,r.rhs_root_position,y) for r in rp.rows]; k=lu(rp.mass_matrix)\f; maximum(abs.(rp.mass_matrix*k-f)) end
function _tte_step(rp,y,h,counter; bounds=nothing)
    all(isfinite,y)||throw(ArgumentError("nonfinite RK4 input")); k1=_tte_rhs(rp,y,counter); z2=y .+ h*k1/2; all(isfinite,z2)||throw(ArgumentError("nonfinite RK4 stage 2")); bounds===nothing || all(i->bounds[i][1] <= z2[i] <= bounds[i][2],eachindex(z2)) || throw(ArgumentError("stage 2 bound exceeded")); k2=_tte_rhs(rp,z2,counter); z3=y .+ h*k2/2; all(isfinite,z3)||throw(ArgumentError("nonfinite RK4 stage 3")); bounds===nothing || all(i->bounds[i][1] <= z3[i] <= bounds[i][2],eachindex(z3)) || throw(ArgumentError("stage 3 bound exceeded")); k3=_tte_rhs(rp,z3,counter); z4=y .+ h*k3; all(isfinite,z4)||throw(ArgumentError("nonfinite RK4 stage 4")); bounds===nothing || all(i->bounds[i][1] <= z4[i] <= bounds[i][2],eachindex(z4)) || throw(ArgumentError("stage 4 bound exceeded")); k4=_tte_rhs(rp,z4,counter); out=y .+ h*(k1+2k2+2k3+k4)/6; all(isfinite,out)||throw(ArgumentError("nonfinite RK4 output")); bounds===nothing || all(i->bounds[i][1] <= out[i] <= bounds[i][2],eachindex(out)) || throw(ArgumentError("state bound exceeded")); out
end
_tte_guard(c,b,rp,y,count=nothing)=(count===nothing || (count.guard+=1); y[findfirst(==(c.guard_state),rp.state_refs)]-b.threshold)
function _tte_result(plan,scenario,status,times,states,events,evals,reason; failure_code=nothing, locations=(), guard_evaluations=0, reset_evaluations=0, mass_residual_norm=nothing, trajectory_defect_norm=nothing)
    ts=Tuple(times); ys=Tuple(Tuple(y) for y in states); rr=reason===nothing ? maximum(_tte_residual(plan.residual_plan,Float64[y...]) for y in states) : nothing; ge=2*length(times)+2*length(events); re=length(events)
    ge=guard_evaluations; re=reset_evaluations; mc=mass_residual_norm===nothing ? rr : mass_residual_norm; defect=trajectory_defect_norm; diagnostic_rhs=0
    if defect===nothing && reason===nothing && length(ts)>1
        ds=Float64[]
        for k in 2:length(ts)
            ehits=[e for e in events if abs(ts[k]-e.event_time)<1e-13]; ev=isempty(ehits) ? nothing : ehits[1]
            hseg=ts[k]-ts[k-1]; endpoint=ev===nothing ? ys[k] : ev.pre_state; cc=_TTECounter(0,0,0); full=_tte_step(plan.residual_plan,Float64[ys[k-1]...],hseg,cc); half=_tte_step(plan.residual_plan,Float64[ys[k-1]...],hseg/2,cc); half=_tte_step(plan.residual_plan,half,hseg/2,cc); push!(ds,maximum(abs.(half-Float64[endpoint...]))/15); diagnostic_rhs+=cc.rhs
        end
        defect=isempty(ds) ? nothing : maximum(ds)
    end
    total_rhs=evals+diagnostic_rhs; combined=(rr===nothing && defect===nothing) ? nothing : maximum(x for x in (rr,defect) if x!==nothing)
    h=canonical_hash((revision=_TTE_REVISION,plan=plan.plan_hash,scenario=scenario.scenario_hash,times=ts,states=ys,events=Tuple(e.record_hash for e in events),rhs_evaluations=total_rhs,guard_evaluations=ge,reset_evaluations=re,failure_code,reason,locations=Tuple(locations),mass_residual_norm=mc,trajectory_defect_norm=defect,residual_norm=combined,status)); TypedTimeEventResultV4(_TTE_TOKEN,status,ts,ys,Tuple(events),total_rhs,ge,re,failure_code,reason,Tuple(locations),mc,defect,combined,plan.plan_hash,scenario.scenario_hash,h)
end

function replay_typed_time_events(plan::TypedTimeEventPlanV4,scenario::TimeIntegrationScenarioV4,result::TypedTimeEventResultV4)
    _tte_check(plan); _tte_result_check(result); result.plan_hash==plan.plan_hash || throw(ArgumentError("result plan authority mismatch")); result.scenario_hash==scenario.scenario_hash || throw(ArgumentError("result scenario authority mismatch")); all(_tte_record_check,e for e in result.events)
    length(result.times)==length(result.states) || throw(ArgumentError("trajectory shape mismatch"));
    y=Float64[result.states[1]...]; y==Float64[only(v.value for v in scenario.initial_values if v.state_ref==r) for r in plan.residual_plan.state_refs] || throw(ArgumentError("replay initial state mismatch")); c=_TTECounter(0,0,0); evmap=Dict(e.event_time=>e for e in result.events)
    for k in 2:length(result.times)
        t0=result.times[k-1]; t1=result.times[k]; h=t1-t0; h>=0 || throw(ArgumentError("nonmonotone replay times")); z=_tte_step(plan.residual_plan,y,h,c); e=get(evmap,t1,nothing)
        if e===nothing
            isapprox(z,Float64[result.states[k]...];atol=1e-12,rtol=1e-12) || throw(ArgumentError("smooth segment replay mismatch")); y=z
        else
            isapprox(z,Float64[e.pre_state...];atol=1e-12,rtol=1e-12) || throw(ArgumentError("event pre-state replay mismatch")); j=findfirst(==(e.edge_hash),Tuple(x.carrier_hash for x in plan.carriers)); j===nothing && throw(ArgumentError("event carrier replay mismatch")); b=plan.bindings[j]; e.direction===b.direction || throw(ArgumentError("event direction replay mismatch")); e.priority===b.priority || throw(ArgumentError("event priority replay mismatch")); e.terminal===b.terminal || throw(ArgumentError("event terminal replay mismatch")); abs(e.guard_value)<=plan.protocol.event_value_tol || throw(ArgumentError("event guard tolerance replay mismatch")); ti=findfirst(==(b.target_state_ref),plan.residual_plan.state_refs); rv=z[findfirst(==(plan.carriers[j].reset_state),plan.residual_plan.state_refs)]; z[ti]=-rv; isapprox(z,Float64[e.post_state...];atol=1e-12,rtol=1e-12) || throw(ArgumentError("event reset replay mismatch")); y=z
        end
    end
    fresh=_integrate_typed_time_events_impl(plan,scenario); fresh.status==result.status && fresh.times==result.times && fresh.states==result.states || throw(ArgumentError("replay trajectory mismatch")); fresh.rhs_evaluations==result.rhs_evaluations && fresh.guard_evaluations==result.guard_evaluations && fresh.reset_evaluations==result.reset_evaluations || throw(ArgumentError("replay count mismatch")); fresh.mass_residual_norm==result.mass_residual_norm && fresh.trajectory_defect_norm==result.trajectory_defect_norm && fresh.residual_norm==result.residual_norm || throw(ArgumentError("replay diagnostics mismatch")); Tuple(e.record_hash for e in fresh.events)==Tuple(e.record_hash for e in result.events) || throw(ArgumentError("event records mismatch")); true
end

function _integrate_typed_time_events_impl(plan::TypedTimeEventPlanV4,scenario::TimeIntegrationScenarioV4)
    _tte_check(plan); scenario.time_unit==_TTE_TIME||throw(ArgumentError("time unit mismatch")); rp=plan.residual_plan
    vals=Tuple(scenario.initial_values); Tuple(sort(collect(v.state_ref.value for v in vals)))==Tuple(sort(collect(r.value for r in rp.state_refs))) || throw(ArgumentError("scenario state coverage mismatch")); length(unique(v.state_ref for v in vals))==length(vals) || throw(ArgumentError("duplicate scenario ref")); all(v->v.state_ref in rp.state_refs && v.unit==rp.state_types[findfirst(==(v.state_ref),rp.state_refs)].units && isfinite(v.value),vals) || throw(ArgumentError("scenario state type/unit/value mismatch")); y=Float64[only(v.value for v in vals if v.state_ref==r) for r in rp.state_refs]; all(i->rp.rows[i].lower<=y[i]<=rp.rows[i].upper,eachindex(y)) || throw(ArgumentError("initial state outside physical bounds")); t=scenario.t_start; times=Float64[t]; states=Vector{Vector{Float64}}([copy(y)]); events=TimeEventRecordV4[]; counter=_TTECounter(0,0,0); armed=trues(length(plan.carriers)); n=0; terminal_hit=false
    for (c,b) in zip(plan.carriers,plan.bindings); abs(_tte_guard(c,b,rp,y,counter))<=plan.protocol.event_value_tol && return _tte_result(plan,scenario,:deferred_initial_event_band,times,states,events,counter.rhs,"initial event value band";failure_code=:initial_event_band,guard_evaluations=counter.guard,reset_evaluations=counter.reset) end
    while t<scenario.t_stop
        n+=1; n<=plan.protocol.max_steps||return _tte_result(plan,scenario,:numerical_failure,times,states,events,counter.rhs,"step budget exhausted";guard_evaluations=counter.guard,reset_evaluations=counter.reset)
        h=min(plan.protocol.step,scenario.t_stop-t); step_start=t; y0=copy(y); y1=try
            _tte_step(rp,y0,h,counter;bounds=Tuple((r.lower,r.upper) for r in rp.rows))
        catch err
            err isa InterruptException && rethrow()
            return _tte_result(plan,scenario,:numerical_failure,times,states,events,counter.rhs,sprint(showerror,err);failure_code=:execution_failure,guard_evaluations=counter.guard,reset_evaluations=counter.reset)
        end; hits=Int[]
        hit_times=Float64[]
        for (j,c) in enumerate(plan.carriers); b=plan.bindings[j]; g0=_tte_guard(c,b,rp,y0,counter); g1=_tte_guard(c,b,rp,y1,counter); !armed[j] && abs(g0)>plan.protocol.event_value_tol && (armed[j]=true); crossed=armed[j] && ((b.direction===:rising&&g0<0&&g1>=0)||(b.direction===:falling&&g0>0&&g1<=0)||(b.direction===:either&&g0*g1<=0&&g0!=g1)); if crossed; push!(hits,j); push!(hit_times,t+h*abs(g0)/(abs(g0)+abs(g1))); end end
        if length(hits)>1
            ord=sortperm(hit_times); hit_times=hit_times[ord]; hits=hits[ord]
            locs=Tuple(begin g0a=_tte_guard(plan.carriers[j],plan.bindings[j],rp,y0,counter); g1a=_tte_guard(plan.carriers[j],plan.bindings[j],rp,y1,counter); ah=canonical_hash((edge=plan.carriers[j].carrier_hash,bracket_times=(t,t+h),bracket_guards=(g0a,g1a),time=hit_times[k],guard=0.0,iterations=0)); EventLocationArtifactV4(_TTE_TOKEN,plan.carriers[j].carrier_hash,(t,t+h),(g0a,g1a),hit_times[k],0.0,0,ah) end for (k,j) in enumerate(hits))
            return _tte_result(plan,scenario,:deferred_multi_event,times,states,events,counter.rhs,"multiple event brackets deferred";failure_code=:multi_event_deferred,locations=locs,guard_evaluations=counter.guard,reset_evaluations=counter.reset)
        end
        if isempty(hits); t+=h;y=y1;push!(times,t);push!(states,copy(y));continue end
        length(events)>=plan.protocol.max_events&&return _tte_result(plan,scenario,:numerical_failure,times,states,events,counter.rhs,"max_events exceeded";guard_evaluations=counter.guard,reset_evaluations=counter.reset); j=hits[1]; c=plan.carriers[j]; b=plan.bindings[j]; g0=_tte_guard(c,b,rp,y0,counter); lo=0.0;hi=h;it=0
        gmid=Inf
        while it<plan.protocol.max_bisections && (hi-lo>plan.protocol.event_time_tol || abs(gmid)>plan.protocol.event_value_tol)
            it+=1; mid=(lo+hi)/2; ym=_tte_step(rp,y0,mid,counter;bounds=Tuple((r.lower,r.upper) for r in rp.rows)); gm=_tte_guard(c,b,rp,ym,counter); gmid=gm; left=(b.direction===:falling&&g0>0&&gm<=0)||(b.direction===:rising&&g0<0&&gm>=0)||(b.direction===:either&&g0*gm<=0&&g0!=gm); left ? (hi=mid) : (lo=mid)
        end
        τ=(lo+hi)/2; yloc=_tte_step(rp,y0,τ,counter;bounds=Tuple((r.lower,r.upper) for r in rp.rows)); gloc=_tte_guard(c,b,rp,yloc,counter); loc_hash=canonical_hash((edge=b.carrier_edge_hash,bracket_times=(t+lo,t+hi),bracket_guards=(_tte_guard(c,b,rp,y0,counter),_tte_guard(c,b,rp,y1,counter)),time=t+τ,guard=gloc,iterations=it)); loc=EventLocationArtifactV4(_TTE_TOKEN,b.carrier_edge_hash,(t+lo,t+hi),(_tte_guard(c,b,rp,y0,counter),_tte_guard(c,b,rp,y1,counter)),t+τ,gloc,it,loc_hash); (it>=plan.protocol.max_bisections || hi-lo>plan.protocol.event_time_tol || abs(gloc)>plan.protocol.event_value_tol) && return _tte_result(plan,scenario,:numerical_failure,times,states,events,counter.rhs,"event bisection tolerance exhausted";failure_code=:event_locator_tolerance,locations=(loc,),guard_evaluations=counter.guard,reset_evaluations=counter.reset)
        yp=yloc; pre=Tuple(copy(yp)); ti=findfirst(==(b.target_state_ref),rp.state_refs); rv=yp[findfirst(==(c.reset_state),rp.state_refs)]; counter.reset+=1; yp[ti]= -rv; post=Tuple(copy(yp)); te=t+τ; gv=gloc; rh=canonical_hash((edge=b.carrier_edge_hash,time=te,pre,post,guard=gv,direction=b.direction,priority=b.priority,terminal=b.terminal,iterations=it)); push!(events,TimeEventRecordV4(_TTE_TOKEN,b.carrier_edge_hash,te,pre,post,gv,b.direction,b.priority,b.terminal,it,rh)); armed[j]=false; t=te;y=yp;push!(times,t);push!(states,copy(y)); terminal_hit=b.terminal; b.terminal&&break
        step_end=min(step_start+h,scenario.t_stop); rem=step_end-te; rem>plan.protocol.event_time_tol&&(y=_tte_step(rp,y,rem,counter;bounds=Tuple((r.lower,r.upper) for r in rp.rows));t+=rem;push!(times,t);push!(states,copy(y)))
    end
    _tte_result(plan,scenario, terminal_hit ? :terminated_event : :integrated,times,states,events,counter.rhs,nothing;guard_evaluations=counter.guard,reset_evaluations=counter.reset,mass_residual_norm=maximum(_tte_residual(rp,Float64[y...]) for y in states))
end
function integrate_typed_time_events(plan::TypedTimeEventPlanV4,scenario::TimeIntegrationScenarioV4)
    _tte_check(plan)
    vals=Tuple(scenario.initial_values)
    any(v->begin i=findfirst(==(v.state_ref),plan.residual_plan.state_refs); i!==nothing && !(plan.residual_plan.rows[i].lower <= v.value <= plan.residual_plan.rows[i].upper) end,vals) && throw(ArgumentError("initial state outside physical bounds"))
    try
        _integrate_typed_time_events_impl(plan,scenario)
    catch err
        err isa InterruptException && rethrow()
        msg=sprint(showerror,err)
        times=(scenario.t_start,); states=(Tuple(v.value for v in scenario.initial_values),)
        _tte_result(plan,scenario,:numerical_failure,times,states,TimeEventRecordV4[],0,msg;failure_code=:execution_failure)
    end
end
canonical_hash(x::TimeEventProtocolV4)=(_tte_check(x)); canonical_hash(x::TimeEventBindingV4)=(_tte_check(x)); canonical_hash(x::TypedTimeEventPlanV4)=(_tte_check(x))
canonical_hash(x::TypedTimeEventResultV4)=(_tte_result_check(x); x.result_hash)
typed_time_events_manifest()=(schema="fusionconceptai:runtime-v4-typed-time-events",revision=_TTE_REVISION,claim_ceiling=screen_only)
