using FusionConceptAI
using .FusionRuntimeV4
const TimeResidualRowBindingV4=FusionRuntimeV4.TimeResidualRowBindingV4
const TimeEventBindingV4=FusionRuntimeV4.TimeEventBindingV4
const TimeEventProtocolV4=FusionRuntimeV4.TimeEventProtocolV4
const compile_typed_time_event_plan=FusionRuntimeV4.compile_typed_time_event_plan
const integrate_typed_time_events=FusionRuntimeV4.integrate_typed_time_events
const TimeIntegrationScenarioV4=FusionRuntimeV4.TimeIntegrationScenarioV4
const StateValueV4=FusionRuntimeV4.StateValueV4

const tte_unit = UnitSignature()
const tte_time_unit = UnitSignature((0,0,1,0,0,0,0))
const tte_scalar_type = PhysicalType(:scalar_field,0,0,TemporalTypeV1(differential_time),tte_unit)
const tte_control_type = PhysicalType(:control_signal,0,0,TemporalTypeV1(differential_time),tte_unit)
tte_type(i)=i==2 ? tte_control_type : tte_scalar_type
const tte_static_type = PhysicalType(:scalar_field,0,0,TemporalTypeV1(static_time),tte_unit)
const tte_refs = (StateGeneRefV1("tte-y1"),StateGeneRefV1("tte-control"),StateGeneRefV1("tte-aux"))
const tte_ops = default_operator_registry()
const tte_ledger=ConservationLedgerIdentityV1(QualifiedRefV1("tte-ledger","v1"),digest256_text("tte-ledger"),tte_unit)

function tte_mass(i)
    ty=tte_type(i); x=ASTInputV1(1,ty)
    d=ASTApplyV1(OperatorRefV1("DT","v1"),(1,);registry=tte_ops,input_types=(ty,))
    id=ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(1,);registry=tte_ops,input_types=(ty,))
    TypedASTProgramV1((x,d,id),(3,2),(1,);registry=tte_ops)
end
function tte_rhs(i)
    ty=tte_type(i); x=ASTInputV1(1,ty)
    neg=ASTApplyV1(OperatorRefV1("NEG","v1"),(1,);registry=tte_ops,input_types=(ty,))
    TypedASTProgramV1((x,neg),(2,),(1,);registry=tte_ops)
end
const tte_in_effect=PortAccountEffectV1(ConservationAccountRefV1(tte_ledger,:input,1,:inflow),1//1)
const tte_out_effect=PortAccountEffectV1(ConservationAccountRefV1(tte_ledger,:output,1,:outflow),-1//1)
function tte_edge(id,prog,role,i;effects=())
    outs=role===governing ? (MIMOOutputBindingV1(1,i),MIMOOutputBindingV1(2,i==2 ? 4 : 5)) : (MIMOOutputBindingV1(1,i==2 ? 6 : 7),)
    AtomicMIMOHyperedgeV1(id,(MIMOInputBindingV1(1,i),),outs,prog,role;registry=tte_ops,account_effects=effects)
end
const tte_m1=tte_mass(1); const tte_m2=tte_mass(2); const tte_m3=tte_mass(3)
const tte_r1=tte_rhs(1); const tte_r2=tte_rhs(2); const tte_r3=tte_rhs(3)
const tte_g1=tte_edge("tte-g1",tte_m1,governing,1;effects=(tte_in_effect,tte_out_effect)); const tte_g2=tte_edge("tte-g2",tte_m2,governing,2); const tte_g3=tte_edge("tte-g3",tte_m3,governing,3)
const tte_a1=tte_edge("tte-a1",tte_r1,additive,1); const tte_a2=tte_edge("tte-a2",tte_r2,additive,2); const tte_a3=tte_edge("tte-a3",tte_r3,additive,3)
const tte_control=ASTInputV1(2,tte_control_type); const tte_target=ASTInputV1(1,tte_scalar_type)
const tte_reset=ASTApplyV1(OperatorRefV1("NEG","v1"),(1,);registry=tte_ops,input_types=(tte_scalar_type,))
const tte_switch=ASTApplyV1(OperatorRefV1("THRESHOLD_SWITCH","v1"),(2,3);registry=tte_ops,input_types=(tte_control_type,tte_scalar_type))
const tte_carrier_program=TypedASTProgramV1((tte_target,tte_control,tte_reset,tte_switch),(4,),(1,2);registry=tte_ops)
const tte_carrier=AtomicMIMOHyperedgeV1("tte-carrier",(MIMOInputBindingV1(1,1),MIMOInputBindingV1(2,2)),(MIMOOutputBindingV1(1,1),),tte_carrier_program,additive;registry=tte_ops)
const tte_graph=TypedOperatorHypergraphV1((node(:state,tte_scalar_type;id="tte-y1"),node(:state,tte_control_type;id="tte-control"),node(:state,tte_scalar_type;id="tte-aux"),node(:non_state,tte_m2.nodes[tte_m2.roots[2]].output_type;id="m-control"),node(:non_state,tte_m1.nodes[tte_m1.roots[2]].output_type;id="m-scalar"),node(:non_state,tte_control_type;id="r-control"),node(:non_state,tte_scalar_type;id="r-scalar"),node(:non_state,tte_scalar_type;id="carrier")),(tte_g1,tte_g2,tte_g3,tte_a1,tte_a2,tte_a3,tte_carrier);registry=tte_ops)
const tte_bounds=QuantityIntervalV1(ExactFiniteIntervalV1(-10,10,false),tte_unit)
const tte_states=ntuple(i->StateGeneV1(tte_refs[i],tte_type(i),tte_bounds,(),(),(),state_derived),3)
const tte_obs_program=let x=ASTInputV1(1,tte_scalar_type); id=ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(1,);registry=tte_ops,input_types=(tte_scalar_type,)); TypedASTProgramV1((x,id),(2,),(1,);registry=tte_ops) end
const tte_invariant=InvariantV1(InvariantRefV1("tte-invariant"),tte_ledger,GlobalConservationScopeV1(),(InvariantTermV1(tte_refs[1],1),),(ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("tte-g1"),:input,1,:inflow,occurrence_internal_effect,tte_ledger),ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("tte-g1"),:output,1,:outflow,occurrence_internal_effect,tte_ledger)),0,entropy_conserved)
const tte_observable=ObservableGeneV1(ObservableRefV1("tte-observable"),ProgramRootRefV1(OperatorSiteRefV1("tte-g1"),1,tte_scalar_type),QualifiedRefV1("tte-intervention","v1"),tte_obs_program,tte_bounds,QualifiedRefV1("tte-noise","v1"),NonnegativeQuantityV1(1//10,tte_unit),NonnegativeQuantityV1(1//10,tte_unit),NonnegativeQuantityV1(1//2,tte_unit),(QualifiedRefV1("tte-prediction","v1"),))
const tte_payload=MechanismGenomePayloadV1(tte_states,(tte_invariant,),tte_graph,(),(),(tte_observable,),())
const tte_mech_ref=g1_occurrence_ownership_contract_ref("urn:fusion:tte:mechanism")
const tte_field_ref=GenomeContractRef("urn:fusion:tte:field","v1",digest256_text("tte-f"),digest256_text("tte-f-c"),"tte")
const tte_real_ref=GenomeContractRef("urn:fusion:tte:real","v1",digest256_text("tte-r"),digest256_text("tte-r-c"),"tte")
const tte_registry=GenomeContractRegistryV4(tte_mech_ref,tte_field_ref,tte_real_ref)
const tte_mech=MechanismGenomeV4(1,tte_mech_ref,tte_payload)
const tte_aux=TypedOperatorHypergraphV1((node(:region,tte_scalar_type;id="tte-region"),node(:boundary,tte_scalar_type;id="tte-boundary")),();registry=tte_ops)
const tte_candidate=CandidateStatePackageV4("tte-three-state",MissionContractRef("urn:fusion:tte:mission","v1",digest256_text("tte-m"),digest256_text("tte-m-c")),tte_mech,FieldGeometryGenomeV4(2,tte_field_ref,tte_aux),RealizationControlGenomeV4(3,4,tte_real_ref,tte_aux,tte_aux),tte_registry)
const tte_compiled=compile_candidate(tte_candidate,tte_registry;mission_payload=tte_candidate.mission_contract_ref,bounds_payload=nothing,comparison_scope=("tte",),scenario_scope=("single-event",))
const tte_rows=ntuple(i->TimeResidualRowBindingV4(tte_refs[i],canonical_hash((tte_g1,tte_g2,tte_g3)[i]),2,canonical_hash((tte_a1,tte_a2,tte_a3)[i]),1),3)
const tte_binding=TimeEventBindingV4(canonical_hash(tte_carrier),tte_refs[1],0.5,tte_unit,:falling,1,true)
const tte_protocol=TimeEventProtocolV4(0.2,20)
const tte_plan=compile_typed_time_event_plan(tte_compiled,tte_registry;row_bindings=tte_rows,event_bindings=(tte_binding,),protocol=tte_protocol)
const tte_scenario=TimeIntegrationScenarioV4("tte-single",0.0,1.0,tte_time_unit,(StateValueV4(tte_refs[1],1.0,tte_unit),StateValueV4(tte_refs[2],0.6,tte_unit),StateValueV4(tte_refs[3],0.2,tte_unit)))
const tte_result=integrate_typed_time_events(tte_plan,tte_scenario)
