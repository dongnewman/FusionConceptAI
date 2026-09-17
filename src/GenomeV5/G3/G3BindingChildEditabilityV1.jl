"""Typed-absence G3 binding editability precursor.

This additive slice has no feedback child, authority adapter, registry,
provider, mesh, solver, or physical execution path.  Link CAS is disabled
until a checked-present T0 authority recheck exists.
"""

const G3_BINDING_CHILD_EDIT_SCHEMA_ID_V1 = "GenomeV5/G3/G3BindingChildEditabilityV1"
const G3_BINDING_CHILD_EDIT_VERSION_V1 = "v1"
const G3_BINDING_CHILD_EDIT_CONTRACT_URI_V1 = "fusionconceptai://GenomeV5/G3/binding-child-editability"
const G3_BINDING_CHILD_EDIT_PROFILE_V1 = "closed-binding-link-edit-v1"
const G3_BINDING_CHILD_EDIT_SOURCE_URI_V1 = "fusionconceptai://GenomeV5/G3/binding-source-record"
const G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V1 = "v1"
const G3_BINDING_CHILD_EDIT_KIND_V1 = :binding
const G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V1 = Digest256(repeat("0", 64))
const G3_BINDING_CHILD_EDIT_LAYERS_V1 = (:G1, :G2)
const G3_BINDING_CHILD_EDIT_OPERATIONS_V1 = (:insert_link, :replace_link, :delete_link)
const G3_BINDING_CHILD_EDIT_ABSENCE_REASONS_V1 = (:authority_recheck_not_published, :binding_authority_typed_absent)

const _G3_BINDING_SCHEMA_SOURCE_V1 = "schema=GenomeV5/G3/G3BindingChildEditabilityV1;version=v1;source=immutable initial_links;body=exact canonical copy;hash_layers=source_content,binding_child_identity,initial_body,initial_source_state,body,operation,state;operations=insert_link,replace_link,delete_link;absence=authority_recheck_not_published|binding_authority_typed_absent"
const _G3_BINDING_CANONICAL_SOURCE_V1 = "encoding=UTF-8;line_endings=LF;tuple_order=declared;symbols=ordinal;rationals=normalized;failed_CAS=canonical_bytes_history_receipts_hashes_unchanged"
const _G3_BINDING_PROFILE_SOURCE_V1 = "admission=closed typed binding body and exact G1/G2 pairing;missing_authority=typed_absent;resolution=terminal_deferred;stale_or_contradictory=fail_closed;physical=independent"
g3_binding_child_edit_schema_hash_v1() = digest256_text(_G3_BINDING_SCHEMA_SOURCE_V1)
g3_binding_child_edit_canonicalization_hash_v1() = digest256_text(_G3_BINDING_CANONICAL_SOURCE_V1)
g3_binding_child_edit_profile_hash_v1() = digest256_text(_G3_BINDING_PROFILE_SOURCE_V1)

_g3be_text(x, f) = begin
    x isa AbstractString || throw(ArgumentError("$f must be String")); s=String(x)
    !isempty(s) && isvalid(s) || throw(ArgumentError("$f must be non-empty UTF-8")); s
end
_g3be_ref(x, f) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$f must be QualifiedRefV1"))
_g3be_digest(x, f) = x isa Digest256 ? x : throw(ArgumentError("$f must be Digest256"))
_g3be_unit(x, f) = x isa UnitSignature ? x : throw(ArgumentError("$f must be UnitSignature"))
_g3be_tuple(x, f) = x isa Tuple ? x : throw(ArgumentError("$f must be immutable Tuple"))
_g3be_symbol(x, allowed, f) = begin s=x isa Symbol ? x : Symbol(x); s in allowed || throw(ArgumentError("$f is invalid: $s")); s end
_g3be_candidate(x) = begin r=_g3be_ref(x,"candidate_ref"); r.version=="v5" || throw(ArgumentError("candidate_ref must use v5")); r end
_g3be_parent(x) = begin r=_g3be_ref(x,"parent_g3_declaration_ref"); r.version=="v1" || throw(ArgumentError("parent ref must use v1")); r end
_g3be_sign(x) = begin (x isa Bool || !(x isa Integer) || !(x in (-1,1))) && throw(ArgumentError("sign must be +1 or -1")); Int8(x) end

struct G3BindingChildKeyV1
    candidate_ref::QualifiedRefV1; parent_g3_declaration_hash::Digest256; child_kind::Symbol; child_id::String
    function G3BindingChildKeyV1(c,p,k,i)
        new(_g3be_candidate(c),_g3be_digest(p,"parent_g3_declaration_hash"),_g3be_symbol(k,(G3_BINDING_CHILD_EDIT_KIND_V1,),"child_kind"),_g3be_text(i,"child_id"))
    end
end

struct G3BindingLinkV1
    link_id::String; target_layer::Symbol; target_path::String; quantity::Symbol; unit::UnitSignature; direction::Symbol; sign::Int8; source_id::String; owner_scope::String; authority::G3SFAuthorityV1
    function G3BindingLinkV1(id,layer,path,q,unit,dir,sign,source,owner,auth)
        l=_g3be_symbol(layer,G3_BINDING_CHILD_EDIT_LAYERS_V1,"target_layer"); auth isa G3SFAuthorityV1 || throw(ArgumentError("authority must be typed")); auth.layer==l || throw(ArgumentError("link authority layer mismatch"))
        new(_g3be_text(id,"link_id"),l,_g3be_text(path,"target_path"),_g3be_symbol(q,(:residual,:loss,:thermal_load,:deformation),"quantity"),_g3be_unit(unit,"unit"),_g3be_symbol(dir,(:in,:out,:bidirectional),"direction"),_g3be_sign(sign),_g3be_text(source,"source_id"),_g3be_text(owner,"owner_scope"),auth)
    end
end

struct G3BindingSchemaV1
    schema_id::String; version::String; schema_hash::Digest256; canonicalization_hash::Digest256; profile_hash::Digest256
end

struct G3BindingProvenanceSlotV1
    slot_kind::Symbol; status::Symbol; ref::Union{Nothing,QualifiedRefV1}; content_hash::Union{Nothing,Digest256}; candidate_ref::Union{Nothing,QualifiedRefV1}; reason::Union{Nothing,String}
    function G3BindingProvenanceSlotV1(k,s,r,h,c,reason=nothing)
        kk=_g3be_symbol(k,(:schema,:canonicalization,:profile,:evidence_receipt),"slot_kind"); ss=_g3be_symbol(s,(:present,:typed_absent),"slot status")
        rr=r===nothing ? nothing : _g3be_ref(r,"slot ref"); hh=h===nothing ? nothing : _g3be_digest(h,"slot content_hash"); cc=c===nothing ? nothing : _g3be_candidate(c)
        ss===:present && (rr===nothing || hh===nothing || cc===nothing) && throw(ArgumentError("present slot requires ref/hash/candidate"))
        ss===:typed_absent && (rr!==nothing || hh!==nothing || cc!==nothing) && throw(ArgumentError("typed absent slot cannot fabricate provenance"))
        new(kk,ss,rr,hh,cc,reason===nothing ? nothing : _g3be_text(reason,"slot reason"))
    end
end

struct G3BindingSourceRecordV1
    source_uri::String; source_version::String; schema::G3BindingProvenanceSlotV1; canonicalization::G3BindingProvenanceSlotV1; profile::G3BindingProvenanceSlotV1; evidence_receipt::G3BindingProvenanceSlotV1; source_record_hash::Digest256
    function G3BindingSourceRecordV1(uri,ver,s,c,p,e,h)
        xs=(s,c,p,e); all(x->x isa G3BindingProvenanceSlotV1,xs) || throw(ArgumentError("source slots must be typed")); length(unique(x.slot_kind for x in xs))==4 || throw(ArgumentError("source slots must be unique"))
        body=(source_uri=_g3be_text(uri,"source_uri"),source_version=_g3be_text(ver,"source_version"),schema=s,canonicalization=c,profile=p,evidence_receipt=e); _g3be_digest(h,"source_record_hash")==canonical_hash(body) || throw(ArgumentError("source_record_hash mismatch")); new(body.source_uri,body.source_version,s,c,p,e,h)
    end
end

struct AbsentChildBindingV1
    child_kind::Symbol; reason::Symbol; absence_digest::Digest256
    function AbsentChildBindingV1(k,r,h); new(_g3be_symbol(k,(:realization,:control),"child_kind"),_g3be_symbol(r,G3_BINDING_CHILD_EDIT_ABSENCE_REASONS_V1,"reason"),_g3be_digest(h,"absence_digest")) end
end
struct PresentChildBindingV1
    child_kind::Symbol; child_ref::QualifiedRefV1; contract_ref::GenomeContractRef; identity_hash::Digest256; state_hash::Digest256
    function PresentChildBindingV1(k,r,c,i,s)
        # V1 has no checked-present T0 authority verifier.  Keeping an inner
        # rejecting constructor removes Julia's generated public constructor;
        # a future checked-present path must be versioned separately.
        throw(ArgumentError("binding_authority_typed_absent"))
    end
end

struct G3BindingSourcePayloadV1
    key::G3BindingChildKeyV1; child_contract_ref::GenomeContractRef; source_uri::String; source_version::String; source_record::G3BindingSourceRecordV1; immutable_binding_schema::G3BindingSchemaV1; initial_links::Tuple{Vararg{G3BindingLinkV1}}; realization_slot::Union{PresentChildBindingV1,AbsentChildBindingV1}; control_slot::Union{PresentChildBindingV1,AbsentChildBindingV1}; source_content_hash::Digest256
    function G3BindingSourcePayloadV1(k,c,u,v,r,s,links,rs,cs,h)
        k isa G3BindingChildKeyV1 || throw(ArgumentError("key must be typed")); c isa GenomeContractRef || throw(ArgumentError("contract must be typed")); xs=_g3be_tuple(links,"initial_links"); all(x->x isa G3BindingLinkV1,xs) || throw(ArgumentError("initial links must be typed")); length(unique(x.link_id for x in xs))==length(xs) || throw(ArgumentError("initial link ids must be unique")); rs isa Union{PresentChildBindingV1,AbsentChildBindingV1} || throw(ArgumentError("invalid realization slot")); cs isa Union{PresentChildBindingV1,AbsentChildBindingV1} || throw(ArgumentError("invalid control slot")); (rs isa PresentChildBindingV1 || cs isa PresentChildBindingV1) && throw(ArgumentError("binding_authority_typed_absent"))
        body=(domain="g3-binding-source-content-v1",key=k,child_contract_ref=c,source_uri=_g3be_text(u,"source_uri"),source_version=_g3be_text(v,"source_version"),source_record=r,immutable_binding_schema=s,initial_links=Tuple(xs),realization_slot=rs,control_slot=cs); _g3be_digest(h,"source_content_hash")==canonical_hash(body) || throw(ArgumentError("source_content_hash mismatch")); new(k,c,body.source_uri,body.source_version,r,s,Tuple(xs),rs,cs,h)
    end
end
struct G3BindingEditableBodyV1
    key::G3BindingChildKeyV1; links::Tuple{Vararg{G3BindingLinkV1}}
    function G3BindingEditableBodyV1(k,links); k isa G3BindingChildKeyV1 || throw(ArgumentError("body key must be typed")); xs=_g3be_tuple(links,"links"); all(x->x isa G3BindingLinkV1,xs) || throw(ArgumentError("links must be typed")); length(unique(x.link_id for x in xs))==length(xs) || throw(ArgumentError("link ids must be unique")); new(k,Tuple(xs)) end
end

struct G3BindingOperationDigestV1
    operation_id::String; operation::Symbol; key::G3BindingChildKeyV1; link_id::String; expected_prior_state_hash::Digest256; before_link::Union{Nothing,G3BindingLinkV1}; after_link::Union{Nothing,G3BindingLinkV1}; prior_body_hash::Digest256; resulting_body_hash::Digest256; previous_state_hash::Digest256; state_hash::Digest256; operation_hash::Digest256
end
struct G3BindingOperationV1
    operation_id::String; operation::Symbol; key::G3BindingChildKeyV1; link_id::String; expected_prior_state_hash::Digest256; before_link::Union{Nothing,G3BindingLinkV1}; after_link::Union{Nothing,G3BindingLinkV1}; prior_body_hash::Digest256; resulting_body_hash::Digest256; operation_hash::Digest256
end
struct G3BindingStateV1
    source_payload::G3BindingSourcePayloadV1; editable_body::G3BindingEditableBodyV1; state_status::Symbol; absence_reason::Union{Nothing,Symbol}; absence_digest::Union{Nothing,Digest256}; contract_admission::Symbol; physical_resolution::Symbol; source_content_hash::Digest256; binding_child_identity_hash::Digest256; initial_body_hash::Digest256; initial_source_state_hash::Digest256; body_hash::Digest256; operation_hash::Digest256; state_hash::Digest256; operation_history::Tuple{Vararg{G3BindingOperationDigestV1}}
end
struct G3BindingPairingResultV1
    status::Symbol; resolution::Symbol; links::Tuple{Vararg{G3BindingLinkV1}}; errors::Tuple{Vararg{String}}; legacy_actual::Symbol; reason::String
end

semantic_view(x::G3BindingChildKeyV1)=(candidate_ref=x.candidate_ref,parent_g3_declaration_hash=x.parent_g3_declaration_hash,child_kind=x.child_kind,child_id=x.child_id)
semantic_view(x::G3BindingLinkV1)=(link_id=x.link_id,target_layer=x.target_layer,target_path=x.target_path,quantity=x.quantity,unit=x.unit,direction=x.direction,sign=x.sign,source_id=x.source_id,owner_scope=x.owner_scope,authority=x.authority)
semantic_view(x::G3BindingSchemaV1)=(schema_id=x.schema_id,version=x.version,schema_hash=x.schema_hash,canonicalization_hash=x.canonicalization_hash,profile_hash=x.profile_hash)
semantic_view(x::G3BindingProvenanceSlotV1)=(slot_kind=x.slot_kind,status=x.status,ref=x.ref,content_hash=x.content_hash,candidate_ref=x.candidate_ref,reason=x.reason)
_g3be_record_body(x::G3BindingSourceRecordV1)=(source_uri=x.source_uri,source_version=x.source_version,schema=x.schema,canonicalization=x.canonicalization,profile=x.profile,evidence_receipt=x.evidence_receipt)
semantic_view(x::G3BindingSourceRecordV1)=merge(_g3be_record_body(x),(source_record_hash=x.source_record_hash,))
semantic_view(x::AbsentChildBindingV1)=(child_kind=x.child_kind,status=:typed_absent,reason=x.reason,absence_digest=x.absence_digest)
semantic_view(x::PresentChildBindingV1)=(child_kind=x.child_kind,status=:present,child_ref=x.child_ref,contract_ref=x.contract_ref,identity_hash=x.identity_hash,state_hash=x.state_hash)
_g3be_source_body(x::G3BindingSourcePayloadV1)=(domain="g3-binding-source-content-v1",key=x.key,child_contract_ref=x.child_contract_ref,source_uri=x.source_uri,source_version=x.source_version,source_record=x.source_record,immutable_binding_schema=x.immutable_binding_schema,initial_links=x.initial_links,realization_slot=x.realization_slot,control_slot=x.control_slot)
semantic_view(x::G3BindingSourcePayloadV1)=merge(_g3be_source_body(x),(source_content_hash=x.source_content_hash,))
semantic_view(x::G3BindingEditableBodyV1)=(key=x.key,links=x.links)
semantic_view(x::G3BindingOperationDigestV1)=(operation_id=x.operation_id,operation=x.operation,key=x.key,link_id=x.link_id,expected_prior_state_hash=x.expected_prior_state_hash,before_link=x.before_link,after_link=x.after_link,prior_body_hash=x.prior_body_hash,resulting_body_hash=x.resulting_body_hash,previous_state_hash=x.previous_state_hash,state_hash=x.state_hash,operation_hash=x.operation_hash)
semantic_view(x::G3BindingOperationV1)=(operation_id=x.operation_id,operation=x.operation,key=x.key,link_id=x.link_id,expected_prior_state_hash=x.expected_prior_state_hash,before_link=x.before_link,after_link=x.after_link,prior_body_hash=x.prior_body_hash,resulting_body_hash=x.resulting_body_hash,operation_hash=x.operation_hash)
semantic_view(x::G3BindingStateV1)=(source_payload=x.source_payload,editable_body=x.editable_body,state_status=x.state_status,absence_reason=x.absence_reason,absence_digest=x.absence_digest,contract_admission=x.contract_admission,physical_resolution=x.physical_resolution,source_content_hash=x.source_content_hash,binding_child_identity_hash=x.binding_child_identity_hash,initial_body_hash=x.initial_body_hash,initial_source_state_hash=x.initial_source_state_hash,body_hash=x.body_hash,operation_hash=x.operation_hash,state_hash=x.state_hash,operation_history=x.operation_history)
semantic_view(x::G3BindingPairingResultV1)=(status=x.status,resolution=x.resolution,links=x.links,errors=x.errors,legacy_actual=x.legacy_actual,reason=x.reason)
for T in (G3BindingChildKeyV1,G3BindingLinkV1,G3BindingSchemaV1,G3BindingProvenanceSlotV1,G3BindingSourceRecordV1,AbsentChildBindingV1,PresentChildBindingV1,G3BindingSourcePayloadV1,G3BindingEditableBodyV1,G3BindingOperationDigestV1,G3BindingOperationV1,G3BindingStateV1,G3BindingPairingResultV1)
    @eval canonical_json(x::$T)=canonical_json(semantic_view(x))
end

_g3be_projection(a)=(layer=a.layer,candidate_ref=a.candidate_ref,contract_ref=a.contract_ref,contract_hash=a.contract_hash,status=a.status,attestation=a.attestation)
_g3be_target_key(x)=(x.target_layer,x.target_path,x.quantity,x.unit,x.direction,x.sign,x.source_id,x.owner_scope)
function g3_binding_pairing_v1(candidate_ref,targets,upstream)
    errors=String[]; links=G3BindingLinkV1[]
    try
        c=_g3be_candidate(candidate_ref); us=_g3be_tuple(upstream,"upstream_authority");
        for a in us
            hasproperty(a,:layer) || (push!(errors,"unknown_upstream_authority_layer");continue)
            a.layer in G3_BINDING_CHILD_EDIT_LAYERS_V1 || push!(errors,"unknown_upstream_authority_layer")
            hasproperty(a,:candidate_ref) && a.candidate_ref==c || push!(errors,"upstream_authority_candidate_mismatch")
        end
        for l in G3_BINDING_CHILD_EDIT_LAYERS_V1
            n=count(a->hasproperty(a,:layer)&&a.layer==l,us); n==1 || push!(errors,n==0 ? "missing_upstream_authority_layer" : "duplicate_upstream_authority_layer")
        end
        xs=_g3be_tuple(targets,"feedback_targets"); ids=String[]; keys=Any[]
        for t in xs
            hasproperty(t,:target_layer) || (push!(errors,"unknown_target_layer");continue); t.target_layer in G3_BINDING_CHILD_EDIT_LAYERS_V1 || (push!(errors,"unknown_target_layer");continue)
            any(a->hasproperty(a,:layer)&&a.layer==t.target_layer,us) || push!(errors,"missing_upstream_authority_layer")
            if hasproperty(t,:authority)
                a=t.authority; (a.layer==t.target_layer&&a.candidate_ref==c) || push!(errors,"legacy_target_authority_layer_or_candidate_mismatch")
                expected_matches = [a0 for a0 in us if hasproperty(a0,:layer) && a0.layer == t.target_layer]
                isempty(expected_matches) || (_g3be_projection(a)==_g3be_projection(first(expected_matches)) || push!(errors,"legacy_target_upstream_projection_mismatch"))
            end
            push!(ids,String(t.target_id)); push!(keys,_g3be_target_key(t)); t isa G3SFFeedbackTargetV1 && push!(links,G3BindingLinkV1(t.target_id,t.target_layer,t.target_path,t.quantity,t.unit,t.direction,t.sign,t.source_id,t.owner_scope,t.authority))
        end
        length(unique(ids))==length(ids) || push!(errors,"duplicate_feedback_target_id"); length(unique(keys))==length(keys) || push!(errors,"duplicate_or_ambiguous_feedback_target"); unique!(errors)
        isempty(errors) || return G3BindingPairingResultV1(:fail_closed,:fail_closed,Tuple(links),Tuple(errors),:typed_absent,"pairing_fail_closed")
        if any(a->a.status===:stale,us); return G3BindingPairingResultV1(:fail_closed,:fail_closed,Tuple(links),("legacy_stale_authority",),:typed_absent,"legacy_stale_authority") end
        if any(a->a.status===:contradictory,us); return G3BindingPairingResultV1(:fail_closed,:fail_closed,Tuple(links),("legacy_contradictory_authority",),:typed_absent,"legacy_contradictory_authority") end
        reason = any(a->a.status===:actual,us) ? "legacy_actual_without_declaration_authority" : any(a->a.status===:historical_absent,us) ? "legacy_historical_absent_authority" : "legacy_missing_authority"
        G3BindingPairingResultV1(:typed_absent,:terminal_deferred,Tuple(links),(),:typed_absent,reason)
    catch e
        G3BindingPairingResultV1(:fail_closed,:fail_closed,(),(string(typeof(e)),),:typed_absent,"pairing_program_exception")
    end
end

function _g3be_absent(k,r,key); AbsentChildBindingV1(k,r,canonical_hash((domain="g3-binding-child-absence-v1",key=key,child_kind=k,reason=r))) end
function g3_binding_source_record_v1(candidate_ref; complete=false)
    c=_g3be_candidate(candidate_ref); slot(k,n)=G3BindingProvenanceSlotV1(k,:typed_absent,nothing,nothing,nothing,"authority recheck not published"); xs=(slot(:schema,"schema"),slot(:canonicalization,"canonicalization"),slot(:profile,"profile"),slot(:evidence_receipt,"evidence_receipt")); b=(source_uri=G3_BINDING_CHILD_EDIT_SOURCE_URI_V1,source_version=G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V1,schema=xs[1],canonicalization=xs[2],profile=xs[3],evidence_receipt=xs[4]); G3BindingSourceRecordV1(b.source_uri,b.source_version,xs...,canonical_hash(b))
end
function g3_binding_source_payload_v1(key::G3BindingChildKeyV1,links=(); realization_slot=nothing,control_slot=nothing,complete=false)
    r=g3_binding_source_record_v1(key.candidate_ref;complete=complete); s=G3BindingSchemaV1(G3_BINDING_CHILD_EDIT_SCHEMA_ID_V1,G3_BINDING_CHILD_EDIT_VERSION_V1,g3_binding_child_edit_schema_hash_v1(),g3_binding_child_edit_canonicalization_hash_v1(),g3_binding_child_edit_profile_hash_v1()); rs=realization_slot===nothing ? _g3be_absent(:realization,:authority_recheck_not_published,key) : realization_slot; cs=control_slot===nothing ? _g3be_absent(:control,:authority_recheck_not_published,key) : control_slot; c=GenomeContractRef(G3_BINDING_CHILD_EDIT_CONTRACT_URI_V1,G3_BINDING_CHILD_EDIT_VERSION_V1,g3_binding_child_edit_schema_hash_v1(),g3_binding_child_edit_canonicalization_hash_v1(),G3_BINDING_CHILD_EDIT_PROFILE_V1); (rs isa PresentChildBindingV1 || cs isa PresentChildBindingV1) && throw(ArgumentError("binding_authority_typed_absent")); b=(domain="g3-binding-source-content-v1",key=key,child_contract_ref=c,source_uri=G3_BINDING_CHILD_EDIT_SOURCE_URI_V1,source_version=G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V1,source_record=r,immutable_binding_schema=s,initial_links=Tuple(links),realization_slot=rs,control_slot=cs); G3BindingSourcePayloadV1(key,c,G3_BINDING_CHILD_EDIT_SOURCE_URI_V1,G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V1,r,s,Tuple(links),rs,cs,canonical_hash(b))
end
function g3_binding_initial_state_v1(p::G3BindingSourcePayloadV1)
    body=G3BindingEditableBodyV1(p.key,p.initial_links); identity=canonical_hash((domain="g3-binding-child-identity-v1",key=p.key,child_contract_ref=p.child_contract_ref,source_uri=p.source_uri,source_version=p.source_version)); reason=:authority_recheck_not_published; absence=_g3be_absent(:realization,reason,p.key).absence_digest; initial_body=canonical_hash(body); initial_source=canonical_hash((domain="g3-binding-initial-source-state-v1",key=p.key,source_content_hash=p.source_content_hash,binding_child_identity_hash=identity,initial_body_hash=initial_body,state_status=:typed_absent,absence_reason=reason,absence_digest=absence,operation_hash=G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V1,operation_history=())); state=canonical_hash((domain="g3-binding-state-v1",key=p.key,state_status=:typed_absent,source_content_hash=p.source_content_hash,binding_child_identity_hash=identity,initial_body_hash=initial_body,initial_source_state_hash=initial_source,body_hash=initial_body,absence_reason=reason,absence_digest=absence,operation_hash=G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V1,operation_history=())); G3BindingStateV1(p,body,:typed_absent,reason,absence,:terminal_deferred,:unknown,p.source_content_hash,identity,initial_body,initial_source,initial_body,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V1,state,())
end
g3_binding_admit_v1(p::G3BindingSourcePayloadV1)=g3_binding_initial_state_v1(p)
function g3_binding_operation_v1(id,op,key,link_id,expected,before,after,prior_body,result_body)
    o=_g3be_symbol(op,G3_BINDING_CHILD_EDIT_OPERATIONS_V1,"operation"); i=_g3be_text(id,"operation_id"); d=(domain="g3-binding-operation-v1",operation_id=i,operation=o,key=key,link_id=_g3be_text(link_id,"link_id"),expected_prior_state_hash=expected,before_link=before,after_link=after,prior_body_hash=prior_body,resulting_body_hash=result_body); G3BindingOperationV1(i,o,key,d.link_id,expected,before,after,prior_body,result_body,canonical_hash(d))
end
g3_binding_insert_operation_v1(id,key,link,expected,prior_body,result_body)=g3_binding_operation_v1(id,:insert_link,key,link.link_id,expected,nothing,link,prior_body,result_body)
g3_binding_replace_operation_v1(id,key,idlink,before,after,expected,prior_body,result_body)=g3_binding_operation_v1(id,:replace_link,key,idlink,expected,before,after,prior_body,result_body)
g3_binding_delete_operation_v1(id,key,link,expected,prior_body,result_body)=g3_binding_operation_v1(id,:delete_link,key,link.link_id,expected,link,nothing,prior_body,result_body)
g3_binding_canonical_bytes_v1(x)=Vector{UInt8}(codeunits(canonical_json(semantic_view(x))))
g3_binding_pairing_errors_v1(x::G3BindingPairingResultV1)=x.errors
function _g3be_fail(s); (status=:terminal_deferred,state=s,receipt=nothing,errors=("authority_recheck_not_published",)) end
insert_link(s::G3BindingStateV1,o::G3BindingOperationV1)=s.state_status===:typed_absent ? _g3be_fail(s) : _g3be_fail(s)
replace_link(s::G3BindingStateV1,o::G3BindingOperationV1)=insert_link(s,o)
delete_link(s::G3BindingStateV1,o::G3BindingOperationV1)=insert_link(s,o)
g3_binding_insert_link_v1=insert_link; g3_binding_replace_link_v1=replace_link; g3_binding_delete_link_v1=delete_link

export G3_BINDING_CHILD_EDIT_SCHEMA_ID_V1,G3_BINDING_CHILD_EDIT_VERSION_V1,G3_BINDING_CHILD_EDIT_CONTRACT_URI_V1,G3_BINDING_CHILD_EDIT_PROFILE_V1,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V1,G3BindingChildKeyV1,G3BindingLinkV1,G3BindingSchemaV1,G3BindingProvenanceSlotV1,G3BindingSourceRecordV1,AbsentChildBindingV1,PresentChildBindingV1,G3BindingSourcePayloadV1,G3BindingEditableBodyV1,G3BindingOperationDigestV1,G3BindingOperationV1,G3BindingStateV1,G3BindingPairingResultV1,g3_binding_child_edit_schema_hash_v1,g3_binding_child_edit_canonicalization_hash_v1,g3_binding_child_edit_profile_hash_v1,g3_binding_pairing_v1,g3_binding_pairing_errors_v1,g3_binding_source_record_v1,g3_binding_source_payload_v1,g3_binding_initial_state_v1,g3_binding_admit_v1,g3_binding_operation_v1,g3_binding_insert_operation_v1,g3_binding_replace_operation_v1,g3_binding_delete_operation_v1,g3_binding_canonical_bytes_v1,insert_link,replace_link,delete_link,g3_binding_insert_link_v1,g3_binding_replace_link_v1,g3_binding_delete_link_v1
