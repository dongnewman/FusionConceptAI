using Test
include(joinpath(@__DIR__, "..", "..", "..", "src", "FusionConceptAI.jl"))
const _G3BE2_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3BE2_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_G3BE2_ROOT, "G3BindingChildEditabilityV1.jl"))
Base.include(FusionConceptAI, joinpath(_G3BE2_ROOT, "G3BindingChildEditabilityV2.jl"))
using .FusionConceptAI
const G = FusionConceptAI
const CAND = QualifiedRefV1("local://candidate/g3-binding-v2", "v5")
const PARENT = QualifiedRefV1("local://g3/decl-v2", "v1")
const PHASH = digest256_text("g3-parent-v2")
const UNIT = UnitSignature()

auth(layer) = G.G3SFAuthorityV1(layer, CAND, nothing, nothing, :missing)
link(id, layer=:G1) = G.G3BindingLinkV1(id, layer, "g3/$(layer)/$(id)", :residual,
    UNIT, :in, 1, "source-v2", "local-fixture", auth(layer))
function present_slot(kind, id)
    G.G3BindingChildPresentV2(kind, CAND, PARENT, PHASH,
        QualifiedRefV1("local://child/$(id)", "v1"),
        GenomeContractRef("fusionconceptai://child/$(id)", "v1", digest256_text("schema-$(id)"),
            digest256_text("canonical-$(id)"), "fixture"),
        QualifiedRefV1("local://record/$(id)", "v1"), digest256_text("record-$(id)"), digest256_text("source-$(id)"),
        digest256_text("identity-$(id)"), digest256_text("state-$(id)"))
end

function payload(;present=false, links=(link("g1"), link("g2",:G2)))
    key=G.G3BindingChildKeyV2(CAND,PARENT,PHASH,:binding,"binding-v2")
    rs=present ? present_slot(:realization,"real") : nothing
    cs=present ? present_slot(:control,"control") : nothing
    G.g3_binding_v2_source_payload(key, links; realization_slot=rs, control_slot=cs,
        complete=present, source_hash=present ? digest256_text("fixture-binding-commitment") : nothing)
end

function assert_unchanged(before, result, error_code)
    @test result.status === :fail_closed
    @test result.state === before
    @test result.errors == (error_code,)
    @test G.g3_binding_v2_canonical_bytes(result.state) == G.g3_binding_v2_canonical_bytes(before)
    @test result.state.state_hash == before.state_hash
    @test result.state.operation_history == before.operation_history
end

function _probe_history_digest(rec, id, operation, key, link_id, expected,
        previous_state_hash, previous_history, payload, final_body,
        initial_body_hash, initial_source_state_hash, identity)
    op0=G.G3BindingOperationV2(id,operation,key,link_id,expected,rec.before_link,
        rec.after_link,rec.prior_body_hash,rec.resulting_body_hash,
        G.G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2)
    op_hash=canonical_hash(G._g3be2_operation_body(op0))
    provisional=G.G3BindingOperationDigestV2(op0.operation_id,op0.operation,
        op0.key,op0.link_id,op0.expected_prior_state_hash,op0.before_link,
        op0.after_link,op0.prior_body_hash,op0.resulting_body_hash,
        previous_state_hash,G.G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,op_hash)
    prefix=(previous_history...,provisional)
    state_hash=G._g3be2_state_hash(payload.key,:present,payload,final_body,
        payload.source_content_hash,identity,initial_body_hash,
        initial_source_state_hash,op_hash,prefix)
    G.G3BindingOperationDigestV2(op0.operation_id,op0.operation,op0.key,
        op0.link_id,op0.expected_prior_state_hash,op0.before_link,op0.after_link,
        op0.prior_body_hash,op0.resulting_body_hash,previous_state_hash,
        state_hash,op_hash)
end

function _probe_forged_history(state; duplicate=false, wrong_prior=false,
        foreign_key=false, invalid_operation=false, wrong_link=false)
    h1,h2,h3=state.operation_history
    initial=G.G3BindingEditableBodyV2(state.editable_body.key,state.source_payload.initial_links)
    h1op=G.G3BindingOperationV2(h1.operation_id,h1.operation,h1.key,h1.link_id,
        h1.expected_prior_state_hash,h1.before_link,h1.after_link,h1.prior_body_hash,
        h1.resulting_body_hash,h1.operation_hash)
    after_h1,_=G._g3be2_apply_body(initial,h1op)
    h2op=G.G3BindingOperationV2(h2.operation_id,h2.operation,h2.key,h2.link_id,
        h2.expected_prior_state_hash,h2.before_link,h2.after_link,h2.prior_body_hash,
        h2.resulting_body_hash,h2.operation_hash)
    after_h2,_=G._g3be2_apply_body(after_h1,h2op)
    key=foreign_key ? G.G3BindingChildKeyV2(QualifiedRefV1("local://foreign","v5"),
        PARENT,PHASH,:binding,"binding-v2") : h2.key
    id=duplicate ? h1.operation_id : h2.operation_id
    operation=invalid_operation ? :unknown_operation : h2.operation
    link_id=wrong_link ? "not-the-replaced-link" : h2.link_id
    expected=wrong_prior ? digest256_text("wrong-prior") : h1.state_hash
    forged_h2=_probe_history_digest(h2,id,operation,key,link_id,expected,h1.state_hash,
        (h1,),state.source_payload,after_h2,state.initial_body_hash,
        state.initial_source_state_hash,state.binding_child_identity_hash)
    forged_h3=_probe_history_digest(h3,h3.operation_id,h3.operation,h3.key,h3.link_id,
        forged_h2.state_hash,forged_h2.state_hash,(h1,forged_h2),state.source_payload,
        state.editable_body,state.initial_body_hash,state.initial_source_state_hash,
        state.binding_child_identity_hash)
    G.G3BindingStateV2(state.source_payload,state.editable_body,:present,nothing,nothing,
        :declared_consistent,:unknown,state.source_record_hash,state.source_content_hash,
        state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,
        state.body_hash,forged_h3.operation_hash,forged_h3.state_hash,(h1,forged_h2,forged_h3))
end

@testset "G3 binding child editability V2" begin
    @test_throws ArgumentError G.g3_binding_v2_source_record(CAND; complete=true)
    p = payload(present=true)
    @test p.initial_links isa Tuple
    @test Vector{UInt8}(codeunits(canonical_json(p.initial_links))) ==
        Vector{UInt8}(codeunits(canonical_json(G.G3BindingEditableBodyV2(p.key,p.initial_links).links)))
    @test p.source_content_hash == canonical_hash(G._g3be2_payload_body(p))
    s = G.g3_binding_v2_admit(p)
    @test s.state_status === :present
    @test s.initial_body_hash == canonical_hash(s.editable_body)
    @test s.body_hash == s.initial_body_hash
    @test s.initial_source_state_hash != s.initial_body_hash
    @test s.source_record_hash == p.source_record.source_record_hash
    @test s.binding_child_identity_hash != s.source_content_hash
    @test G.g3_binding_v2_canonical_bytes(s) == Vector{UInt8}(codeunits(canonical_json(semantic_view(s))))
    swapped=G.G3BindingChildPresentV2(:control,CAND,PARENT,PHASH,QualifiedRefV1("local://child/swapped","v1"),
        GenomeContractRef("fusionconceptai://child/swapped","v1",digest256_text("schema-swapped"),digest256_text("canonical-swapped"),"fixture"),
        QualifiedRefV1("local://record/swapped","v1"),digest256_text("record-swapped"),digest256_text("source-swapped"),digest256_text("identity-swapped"),digest256_text("state-swapped"))
    @test_throws ArgumentError G.g3_binding_v2_source_payload(p.key,p.initial_links;realization_slot=swapped,control_slot=p.control_slot,source_hash=digest256_text("fixture-binding-commitment"))

    # Public construction is not authority: CAS validates every frozen and
    # historical layer before it can transition.
    forged = G.G3BindingStateV2(s.source_payload, s.editable_body, s.state_status,
        s.absence_reason, s.absence_digest, s.contract_admission, s.physical_resolution,
        s.source_record_hash, digest256_text("foreign-source"), s.binding_child_identity_hash,
        s.initial_body_hash, s.initial_source_state_hash, s.body_hash, s.operation_hash,
        s.state_hash, s.operation_history)
    forged_op=G.g3_binding_v2_insert_operation("forged-state",forged.editable_body.key,link("forged-state"),forged.state_hash,forged.body_hash,digest256_text("future"))
    assert_unchanged(forged,insert_link(forged,forged_op),"state_source_content_hash_mismatch")

    absent = G.g3_binding_v2_admit(payload(present=false))
    @test absent.state_status === :typed_absent
    @test absent.contract_admission === :terminal_deferred
    @test isempty(absent.operation_history)
    absent_op=G.g3_binding_v2_insert_operation("absent",absent.editable_body.key,link("absent"),absent.state_hash,absent.body_hash,digest256_text("x"))
    @test insert_link(absent,absent_op).status === :fail_closed
    @test insert_link(absent,absent_op).errors == ("typed_absent_state",)

    inserted=link("g3",:G1)
    op1=G.g3_binding_v2_insert_operation("op-1",s.editable_body.key,inserted,s.state_hash,s.body_hash,
        canonical_hash(G.G3BindingEditableBodyV2(s.editable_body.key,(s.editable_body.links...,inserted))))
    r1=insert_link(s,op1)
    @test r1.status === :applied
    @test length(r1.state.editable_body.links)==3
    @test r1.state.operation_history[1].operation_id=="op-1"
    replacement=link("g1",:G1)
    op2=G.g3_binding_v2_replace_operation("op-2",r1.state.editable_body.key,"g1",s.editable_body.links[1],replacement,
        r1.state.state_hash,r1.state.body_hash,canonical_hash(G.G3BindingEditableBodyV2(r1.state.editable_body.key,(replacement,r1.state.editable_body.links[2],inserted))))
    r2=replace_link(r1.state,op2)
    @test r2.status === :applied
    op3=G.g3_binding_v2_delete_operation("op-3",r2.state.editable_body.key,inserted,r2.state.state_hash,r2.state.body_hash,
        canonical_hash(G.G3BindingEditableBodyV2(r2.state.editable_body.key,(replacement,r2.state.editable_body.links[2]))))
    r3=delete_link(r2.state,op3)
    @test r3.status === :applied
    @test length(r3.state.operation_history)==3

    stale=G.g3_binding_v2_insert_operation("stale",r3.state.editable_body.key,link("stale"),digest256_text("old"),r3.state.body_hash,digest256_text("future"))
    assert_unchanged(r3.state,insert_link(r3.state,stale),"stale_state_hash")
    duplicate=G.g3_binding_v2_insert_operation("op-1",r3.state.editable_body.key,link("duplicate"),r3.state.state_hash,r3.state.body_hash,digest256_text("future"))
    assert_unchanged(r3.state,insert_link(r3.state,duplicate),"duplicate_operation_id")
    foreign_key=G.G3BindingChildKeyV2(QualifiedRefV1("local://foreign","v5"),PARENT,PHASH,:binding,"binding-v2")
    foreign=G.g3_binding_v2_insert_operation("foreign",foreign_key,link("foreign"),r3.state.state_hash,r3.state.body_hash,digest256_text("future"))
    assert_unchanged(r3.state,insert_link(r3.state,foreign),"foreign_key")
    bad=G.G3BindingOperationV2(op3.operation_id,op3.operation,op3.key,op3.link_id,op3.expected_prior_state_hash,op3.before_link,op3.after_link,op3.prior_body_hash,op3.resulting_body_hash,digest256_text("tampered"))
    assert_unchanged(r2.state,delete_link(r2.state,bad),"operation_hash_mismatch")

    broken_history = G.G3BindingStateV2(r3.state.source_payload,r3.state.editable_body,
        r3.state.state_status,r3.state.absence_reason,r3.state.absence_digest,r3.state.contract_admission,
        r3.state.physical_resolution,r3.state.source_record_hash,r3.state.source_content_hash,
        r3.state.binding_child_identity_hash,r3.state.initial_body_hash,r3.state.initial_source_state_hash,
        r3.state.body_hash,r3.state.operation_hash,r3.state.state_hash,
        (G.G3BindingOperationDigestV2(r3.state.operation_history[1].operation_id,
            r3.state.operation_history[1].operation,r3.state.operation_history[1].key,
            r3.state.operation_history[1].link_id,r3.state.operation_history[1].expected_prior_state_hash,
            r3.state.operation_history[1].before_link,r3.state.operation_history[1].after_link,
            digest256_text("broken-prior"),r3.state.operation_history[1].resulting_body_hash,
            r3.state.operation_history[1].previous_state_hash,r3.state.operation_history[1].state_hash,
            r3.state.operation_history[1].operation_hash), r3.state.operation_history[2:end]...))
    broken_op=G.g3_binding_v2_insert_operation("broken-history",broken_history.editable_body.key,link("broken-history"),broken_history.state_hash,broken_history.body_hash,digest256_text("future"))
    broken_result=insert_link(broken_history,broken_op)
    @test broken_result.status===:fail_closed
    @test broken_result.state===broken_history
    @test G.g3_binding_v2_canonical_bytes(broken_result.state)==G.g3_binding_v2_canonical_bytes(broken_history)

    # History is replayed by index, with unique operation IDs and exact prior
    # state/body/key/operation semantics.  These are the independent reviewer's
    # three exact attacks plus equivalent-record prefix and semantic attacks.
    for (opts, code) in (( (;duplicate=true), "history_duplicate_operation_id"),
            ( (;wrong_prior=true), "history_expected_prior_state_mismatch"),
            ( (;foreign_key=true), "history_key_mismatch"),
            ( (;invalid_operation=true), "history_operation_invalid"),
            ( (;wrong_link=true), "history_transition_invalid"))
        forged_history=_probe_forged_history(r3.state; opts...)
        @test G._g3be2_validate_state(forged_history)==(code,)
        future=link("history-attack")
        future_body=G.G3BindingEditableBodyV2(forged_history.editable_body.key,
            (forged_history.editable_body.links...,future))
        future_op=G.g3_binding_v2_insert_operation("history-attack",
            forged_history.editable_body.key,future,forged_history.state_hash,
            forged_history.body_hash,canonical_hash(future_body))
        assert_unchanged(forged_history,insert_link(forged_history,future_op),code)
    end
    semantic_link=link("semantic-after")
    semantic_body=G.G3BindingEditableBodyV2(r3.state.editable_body.key,
        (r3.state.editable_body.links...,semantic_link))
    semantic_op=G.g3_binding_v2_operation("semantic-link",:insert_link,
        r3.state.editable_body.key,"wrong-link-id",r3.state.state_hash,nothing,
        semantic_link,r3.state.body_hash,canonical_hash(semantic_body))
    assert_unchanged(r3.state,insert_link(r3.state,semantic_op),"insert_link_id_mismatch")
end

@testset "V1 legacy remains typed absent" begin
    legacy_contract=GenomeContractRef("fusionconceptai://legacy", "v5", digest256_text("legacy-schema"), digest256_text("legacy-canonical"), "legacy")
    a1=G.G3SFAuthorityV1(:G1,CAND,legacy_contract,digest256_text("legacy-g1"),:actual)
    a2=G.G3SFAuthorityV1(:G2,CAND,legacy_contract,digest256_text("legacy-g2"),:actual)
    t1=G.G3SFFeedbackTargetV1("legacy-g1",:G1,"/g1",:residual,UNIT,:in,1,"source","owner",a1)
    t2=G.G3SFFeedbackTargetV1("legacy-g2",:G2,"/g2",:residual,UNIT,:in,1,"source","owner",a2)
    pair=G.g3_binding_pairing_v1(CAND,(t1,t2),(a1,a2))
    @test pair.status === :typed_absent
    @test pair.resolution === :terminal_deferred
    @test pair.legacy_actual === :typed_absent
    @test pair.reason == "legacy_actual_without_declaration_authority"
    @test_throws ArgumentError G.PresentChildBindingV1(:realization, QualifiedRefV1("x","v1"),
        GenomeContractRef("u","v1",digest256_text("s"),digest256_text("c"),"p"),digest256_text("i"),digest256_text("h"))
end

println("G3 binding V2 tests: PASS")
