using Test
using FusionConceptAI
const _ROOT = joinpath(@__DIR__, "..", "..", "..")
Base.include(Main, joinpath(@__DIR__, "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "G3", "G3RealizationChildEditabilityV1.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "G3", "G3ControlChildEditabilityV1.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "G3", "G3BindingChildEditabilityV1.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "G3", "G3BindingChildEditabilityV2.jl"))
Base.include(FusionConceptAI, joinpath(_ROOT, "src", "GenomeV5", "Integration", "VNextG3BindingAuthorityBridgeLocalV1.jl"))
const G = FusionConceptAI
const CAND = Main._T0L_CANDIDATE
const UNIT = G.UnitSignature()

function _realization_state(g3; source=100, field=70, returned=20, heat=10)
    parent=g3.declaration_ref; ph=g3.declaration_identity_hash
    ports=(G.G3RealizationSourcePortV1("source-port",:source,UNIT,:out,1,"local-owner"),
        G.G3RealizationSourcePortV1("field-port",:field,UNIT,:in,1,"local-owner"),
        G.G3RealizationSourcePortV1("return-port",:return,UNIT,:in,1,"local-owner"),
        G.G3RealizationSourcePortV1("heat-port",:heat,UNIT,:in,1,"local-owner"))
    comp=G.G3RealizationComponentV1("real-comp",:source_component,Tuple(p.port_id for p in ports),120,UNIT,"local-material","local-process")
    mat=G.G3RealizationMaterialDomainV1("local-material",:strength,0,10,UNIT)
    proc=G.G3RealizationManufacturingDomainV1("local-process",:thickness,1,2,UNIT)
    acct=G.G3RealizationLedgerAccountV1("energy",:energy,UNIT,"local-owner")
    entries=(G.G3RealizationLedgerEntryV1("e-source","energy","source-port","real-comp",source,UNIT,:source),G.G3RealizationLedgerEntryV1("e-field","energy","field-port","real-comp",-field,UNIT,:load),G.G3RealizationLedgerEntryV1("e-return","energy","return-port","real-comp",-returned,UNIT,:return),G.G3RealizationLedgerEntryV1("e-heat","energy","heat-port","real-comp",-heat,UNIT,:heat_rejection))
    closure=G.G3RealizationLedgerClosureV1("energy-close",:energy,("energy",),0)
    body=G.G3RealizationSourceBodyV1("real-child","local-owner",ports,source,field,returned,heat,120,UNIT,0,(comp,),(mat,),(proc,),(acct,),entries,(closure,))
    rec=G.g3_realization_source_record_v1(CAND; schema_ref=QualifiedRefV1("local://schema/real","v1"),schema_hash=digest256_text("schema-real"),canonicalization_ref=QualifiedRefV1("local://canonical/real","v1"),canonicalization_hash=digest256_text("canonical-real"),profile_ref=QualifiedRefV1("local://profile/real","v1"),profile_hash=digest256_text("profile-real"),evidence_receipt_ref=QualifiedRefV1("local://receipt/real","v1"),evidence_receipt_hash=digest256_text("receipt-real"))
    key=G.G3RealizationChildKeyV1(CAND,ph,:realization,body.source_id)
    payload=G.g3_realization_source_payload_v1(key,parent,body,rec)
    G.g3_realization_initial_state_v1(key,payload)
end

function _control_state(g3)
    parent=g3.declaration_ref; ph=g3.declaration_identity_hash
    sig1=G.G3ControlSignalV1("sensor",:sensor,:in,UNIT,"sensor-owner"); sig2=G.G3ControlSignalV1("actuator",:command,:out,UNIT,"actuator-owner")
    init=G.G3ControlInitialStateV1("initial",UNIT,0//1); event=G.G3ControlEventV1("event",:initial,0//1,:enable)
    controller=G.G3ControlControllerV1("controller",("sensor",),("actuator",),("actuator",),("fault",),(init,),(event,))
    fault=G.G3ControlFaultV1("fault","controller",:open_circuit,:trip,"sensor",1//1)
    plan=G.G3ControlPlanV1(("controller",),("sensor","actuator"),("fault",))
    body=G.G3ControlSourceBodyV1("control-child","local-owner",(sig1,sig2),(controller,),(fault,),plan)
    function slot(kind,label)
        G.G3ControlProvenanceSlotV1(kind,:present,QualifiedRefV1("local://evidence/"*label,"v1"),"fixtures/"*label*".json",digest256_text(label),CAND,nothing,nothing)
    end
    slots=(slot(:payload_schema_version,"schema-control"),slot(:canonicalization_profile_version,"canonical-control"),slot(:applicability_profile_version,"profile-control"),slot(:evidence_receipt_version,"receipt-control"))
    rb=(record_uri=G.G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,record_version=G.G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,payload_schema_version=slots[1],canonicalization_profile_version=slots[2],applicability_profile_version=slots[3],evidence_receipt_version=slots[4])
    rec=G.G3ControlSourceRecordV1(rb.record_uri,rb.record_version,slots...,canonical_hash(rb))
    contract=G.GenomeContractRef(G.G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,G.G3_CONTROL_CHILD_EDIT_VERSION_V1,G.g3_control_child_edit_schema_hash_v1(),G.g3_control_child_edit_canonicalization_hash_v1(),G.G3_CONTROL_CHILD_EDIT_PROFILE_V1)
    key=G.G3ControlChildKeyV1(CAND,ph,:control,body.source_id)
    identity=canonical_hash((child_contract_ref=contract,)); rr=G.G3ControlSourceRecordRefV1(rec.record_uri,rec.record_version,rec.source_record_hash)
    content=canonical_hash((key=key,parent_g3_declaration_ref=parent,child_contract_ref=contract,source_uri=rec.record_uri,source_version=rec.record_version,body=body,source_record_ref=rr))
    payload=G.G3ControlSourcePayloadV1(key,parent,ph,contract,identity,rec.record_uri,rec.record_version,body,rec,content)
    G.g3_control_initial_state_v1(key,payload)
end

function _fixture()
    g1=Main._t0l_g1(); g2=Main._t0l_g2(); g3=Main._t0l_g3()
    declarations=(Main._t0l_present(:G1,g1),Main._t0l_present(:G2,g2;path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),Main._t0l_present(:G3,g3;path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children=(Main._t0l_child(:realization),Main._t0l_child(:control),Main._t0l_child(:binding))
    feedback=(Main._t0l_feedback("g1-residual",declarations[1].declaration_ref),Main._t0l_feedback("g2-thermal",declarations[2].declaration_ref))
    admission=G.vnext_declaration_transport_local_v1(CAND,declarations,children,feedback)
    result=G.vnext_declaration_authority_recheck_local_v1(G.VNextAuthorityRecheckLocalInputV1(CAND,admission.transport,declarations))
    result,result.output.g3
end

@testset "local T0 recheck to G3 binding V2 bridge" begin
    result,g3=_fixture()
    @test result.status===:local_checked_present
    @test G.vnext_g3_binding_self_consistency_v1(result).ok
    rs=_realization_state(g3); cs=_control_state(g3)
    ri,_=G._vnext_g3_state_info(rs,:realization,CAND,result.output.g3.declaration_ref,result.output.g3.declaration_identity_hash)
    ci,_=G._vnext_g3_state_info(cs,:control,CAND,result.output.g3.declaration_ref,result.output.g3.declaration_identity_hash)
    rcommit=G.VNextG3BindingChildExpectedCommitmentV1(ri.child_kind,ri.candidate_ref,ri.parent_g3_declaration_ref,ri.parent_g3_declaration_hash,ri.child_ref,ri.contract_ref,ri.source_record_ref,ri.source_record_hash,ri.source_content_hash,ri.child_identity_hash,ri.state_hash)
    ccommit=G.VNextG3BindingChildExpectedCommitmentV1(ci.child_kind,ci.candidate_ref,ci.parent_g3_declaration_ref,ci.parent_g3_declaration_hash,ci.child_ref,ci.contract_ref,ci.source_record_ref,ci.source_record_hash,ci.source_content_hash,ci.child_identity_hash,ci.state_hash)
    expected=G.vnext_g3_binding_expected_commitment_v1(CAND,result.output.bundle_hash,result.output.g3.declaration_ref,result.output.g3.declaration_identity_hash,rcommit,ccommit)
    key=G.G3BindingChildKeyV2(CAND,g3.declaration_ref,g3.declaration_identity_hash,:binding,"binding-child-v2")
    a1=G.G3SFAuthorityV1(:G1,CAND,nothing,nothing,:missing); a2=G.G3SFAuthorityV1(:G2,CAND,nothing,nothing,:missing)
    l1=G.G3BindingLinkV1("g1",:G1,"/g1",:residual,UNIT,:in,1,"local-g3","local-owner",a1)
    l2=G.G3BindingLinkV1("g2",:G2,"/g2",:thermal_load,UNIT,:in,1,"local-g3","local-owner",a2)
    bridge=G.vnext_g3_binding_authority_bridge_local_v1(result,expected,rs,cs,key;initial_links=(l1,l2))
    @test bridge.status===:local_checked_present
    @test bridge.self_consistency
    @test bridge.authority_verified
    @test bridge.binding_state.state_status===:present
    @test bridge.binding_state.source_payload.realization_slot isa G.G3BindingChildPresentV2
    @test bridge.binding_state.source_payload.control_slot isa G.G3BindingChildPresentV2
    @test bridge.binding_state.source_payload.realization_slot.parent_g3_declaration_hash==g3.declaration_identity_hash

    inserted=G.G3BindingLinkV1("g3",:G1,"/g3",:residual,UNIT,:in,1,"local-g3","local-owner",a1)
    op1=G.g3_binding_v2_insert_operation("bridge-insert",bridge.binding_state.editable_body.key,inserted,bridge.binding_state.state_hash,bridge.binding_state.body_hash,canonical_hash(G.G3BindingEditableBodyV2(bridge.binding_state.editable_body.key,(l1,l2,inserted))))
    r1=G.insert_link(bridge.binding_state,op1)
    @test r1.status===:applied && length(r1.state.operation_history)==1
    replacement=G.G3BindingLinkV1("g1",:G1,"/g1-replaced",:residual,UNIT,:in,1,"local-g3","local-owner",a1)
    op2=G.g3_binding_v2_replace_operation("bridge-replace",r1.state.editable_body.key,"g1",l1,replacement,r1.state.state_hash,r1.state.body_hash,canonical_hash(G.G3BindingEditableBodyV2(r1.state.editable_body.key,(replacement,l2,inserted))))
    r2=G.replace_link(r1.state,op2)
    @test r2.status===:applied && length(r2.state.operation_history)==2
    op3=G.g3_binding_v2_delete_operation("bridge-delete",r2.state.editable_body.key,inserted,r2.state.state_hash,r2.state.body_hash,canonical_hash(G.G3BindingEditableBodyV2(r2.state.editable_body.key,(replacement,l2))))
    r3=G.delete_link(r2.state,op3)
    @test r3.status===:applied && length(r3.state.operation_history)==3
    @test r3.state.state_hash != bridge.binding_state.state_hash

    wrong=G.vnext_g3_binding_expected_commitment_v1(CAND,digest256_text("wrong"),expected.g3_declaration_ref,expected.g3_declaration_identity_hash,rcommit,ccommit)
    bad=G.vnext_g3_binding_authority_bridge_local_v1(result,wrong,rs,cs,key;initial_links=(l1,l2))
    @test bad.status===:fail_closed && bad.binding_state===nothing
    recomputed_rs=_realization_state(g3;source=90,field=60)
    recomputed_info,_=G._vnext_g3_state_info(recomputed_rs,:realization,CAND,result.output.g3.declaration_ref,result.output.g3.declaration_identity_hash)
    recomputed_commit=G.VNextG3BindingChildExpectedCommitmentV1(recomputed_info.child_kind,recomputed_info.candidate_ref,recomputed_info.parent_g3_declaration_ref,recomputed_info.parent_g3_declaration_hash,recomputed_info.child_ref,recomputed_info.contract_ref,recomputed_info.source_record_ref,recomputed_info.source_record_hash,recomputed_info.source_content_hash,recomputed_info.child_identity_hash,recomputed_info.state_hash)
    attack=G.vnext_g3_binding_authority_bridge_local_v1(result,expected,recomputed_rs,cs,key;initial_links=(l1,l2))
    @test attack.status===:fail_closed && attack.errors[1]===:realization_expected_commitment_mismatch
    new_expected=G.vnext_g3_binding_expected_commitment_v1(CAND,result.output.bundle_hash,result.output.g3.declaration_ref,result.output.g3.declaration_identity_hash,recomputed_commit,ccommit)
    @test G.vnext_g3_binding_authority_bridge_local_v1(result,new_expected,recomputed_rs,cs,key;initial_links=(l1,l2)).status===:local_checked_present
    fkey=G.G3ControlChildKeyV1(QualifiedRefV1("local://foreign","v5"),cs.key.parent_g3_declaration_hash,:control,cs.key.child_id)
    foreign=G.g3_control_typed_absent_state_v1(fkey,"foreign";missing_slots=(:payload_schema_version,))
    fb=G.vnext_g3_binding_authority_bridge_local_v1(result,expected,rs,foreign,key;initial_links=(l1,l2))
    @test fb.status===:fail_closed && fb.errors[1]===:child_state_not_present
    typed=G.VNextAuthorityRecheckLocalResultV1(:typed_absent,:terminal_deferred,false,:contract_only,(),(:g3_feedback_material_absent,),nothing,(),result.prior_bundle_sha256)
    tb=G.vnext_g3_binding_authority_bridge_local_v1(typed,expected,rs,cs,key;initial_links=(l1,l2))
    @test tb.status===:typed_absent && tb.resolution===:terminal_deferred
end

println("G3 bridge tests: PASS")
