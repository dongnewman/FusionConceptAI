"""Versioned checked-present G3 binding child editability.

This file is additive to the V1 typed-absence binding contract.  V1 is not
reopened and its rejecting PresentChildBindingV1 constructor remains the
legacy behaviour.  A V2 state can only be made present by the local authority
bridge after it has consumed a checked-present T0 recheck and independently
checked the realization/control source states.
"""

const G3_BINDING_CHILD_EDIT_SCHEMA_ID_V2 = "GenomeV5/G3/G3BindingChildEditabilityV2"
const G3_BINDING_CHILD_EDIT_VERSION_V2 = "v2"
const G3_BINDING_CHILD_EDIT_CONTRACT_URI_V2 =
    "fusionconceptai://GenomeV5/G3/binding-child-editability"
const G3_BINDING_CHILD_EDIT_PROFILE_V2 = "closed-binding-link-edit-v2-local"
const G3_BINDING_CHILD_EDIT_SOURCE_URI_V2 =
    "fusionconceptai://GenomeV5/G3/binding-source-record"
const G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V2 = "v2"
const G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 = Digest256(repeat("0", 64))
const G3_BINDING_CHILD_EDIT_OPERATIONS_V2 = (:insert_link, :replace_link, :delete_link)
const G3_BINDING_CHILD_EDIT_KINDS_V2 = (:binding,)
const G3_BINDING_CHILD_EDIT_SLOT_KINDS_V2 = (:realization, :control)

const _G3BE2_SCHEMA_SOURCE =
    "schema=GenomeV5/G3/G3BindingChildEditabilityV2;version=v2;" *
    "initial_links=immutable Tuple{Vararg{G3BindingLinkV1}};" *
    "hash_layers=source_record,source_content,binding_child_identity,initial_body," *
    "initial_source_state,body,operation,state;cas=fail_atomic"
const _G3BE2_CANONICAL_SOURCE =
    "encoding=UTF-8;line_endings=LF;tuple_order=declared;symbols=ordinal;" *
    "rational=normalized;failed_CAS=bytes_history_hashes_unchanged"
const _G3BE2_PROFILE_SOURCE =
    "checked_present=local-T0-recheck-plus-independent-child-source-commitment;" *
    "missing=typed_absent;resolution=terminal_deferred;physical=independent"
g3_binding_child_edit_schema_hash_v2() = digest256_text(_G3BE2_SCHEMA_SOURCE)
g3_binding_child_edit_canonicalization_hash_v2() = digest256_text(_G3BE2_CANONICAL_SOURCE)
g3_binding_child_edit_profile_hash_v2() = digest256_text(_G3BE2_PROFILE_SOURCE)

_g3be2_text(x, f) = begin
    x isa AbstractString || throw(ArgumentError("$f must be String"))
    s = String(x); !isempty(s) && isvalid(s) || throw(ArgumentError("$f must be non-empty UTF-8")); s
end
_g3be2_ref(x, f) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$f must be QualifiedRefV1"))
_g3be2_digest(x, f) = x isa Digest256 ? x : throw(ArgumentError("$f must be Digest256"))
_g3be2_tuple(x, f) = x isa Tuple ? x : throw(ArgumentError("$f must be immutable Tuple"))
_g3be2_candidate(x) = begin r=_g3be2_ref(x,"candidate_ref"); r.version=="v5" || throw(ArgumentError("candidate_ref must use v5")); r end
_g3be2_parent(x) = begin r=_g3be2_ref(x,"parent_g3_declaration_ref"); r.version=="v1" || throw(ArgumentError("parent declaration ref must use v1")); r end
_g3be2_symbol(x, allowed, f) = begin s=x isa Symbol ? x : Symbol(x); s in allowed || throw(ArgumentError("$f is invalid: $s")); s end

struct G3BindingChildKeyV2
    candidate_ref::QualifiedRefV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_kind::Symbol
    child_id::String
    function G3BindingChildKeyV2(c, p, h, k, id)
        new(_g3be2_candidate(c), _g3be2_parent(p), _g3be2_digest(h,"parent hash"),
            _g3be2_symbol(k, G3_BINDING_CHILD_EDIT_KINDS_V2, "child_kind"), _g3be2_text(id,"child_id"))
    end
end

struct G3BindingSchemaV2
    schema_id::String; version::String; schema_hash::Digest256
    canonicalization_hash::Digest256; profile_hash::Digest256
end

struct G3BindingChildAbsentV2
    child_kind::Symbol; status::Symbol; reason::Symbol; absence_digest::Digest256
    function G3BindingChildAbsentV2(k, r)
        kk=_g3be2_symbol(k,G3_BINDING_CHILD_EDIT_SLOT_KINDS_V2,"child_kind")
        rr=_g3be2_symbol(r,(:missing_child,:missing_provenance,:t0_typed_absent,
            :t0_terminal_deferred,:foreign_child,:stale_child),"absence reason")
        new(kk,:typed_absent,rr,canonical_hash((domain="g3-binding-child-absence-v2",
            child_kind=kk,reason=rr)))
    end
end

struct G3BindingChildPresentV2
    child_kind::Symbol; candidate_ref::QualifiedRefV1
    parent_g3_declaration_ref::QualifiedRefV1; parent_g3_declaration_hash::Digest256
    child_ref::QualifiedRefV1; contract_ref::GenomeContractRef
    source_record_ref::QualifiedRefV1; source_record_hash::Digest256; source_content_hash::Digest256
    child_identity_hash::Digest256; state_hash::Digest256
    function G3BindingChildPresentV2(k,c,p,ph,cr,contract,sr,srh,sch,ih,sth)
        kk=_g3be2_symbol(k,G3_BINDING_CHILD_EDIT_SLOT_KINDS_V2,"child_kind")
        cc=_g3be2_candidate(c); pp=_g3be2_parent(p); hh=_g3be2_digest(ph,"parent hash")
        rr=_g3be2_ref(cr,"child_ref"); co=contract isa GenomeContractRef ? contract : throw(ArgumentError("contract_ref must be GenomeContractRef"))
        srr=_g3be2_ref(sr,"source_record_ref")
        new(kk,cc,pp,hh,rr,co,srr,_g3be2_digest(srh,"source_record_hash"),_g3be2_digest(sch,"source_content_hash"),
            _g3be2_digest(ih,"child_identity_hash"),_g3be2_digest(sth,"state_hash"))
    end
end

struct G3BindingSourceRecordV2
    candidate_ref::QualifiedRefV1; source_uri::String; source_version::String
    schema::G3BindingProvenanceSlotV1; canonicalization::G3BindingProvenanceSlotV1
    profile::G3BindingProvenanceSlotV1; evidence_receipt::G3BindingProvenanceSlotV1
    source_record_hash::Digest256
    function G3BindingSourceRecordV2(candidate,uri,ver,s,c,p,e,h)
        candidate=_g3be2_candidate(candidate)
        xs=(s,c,p,e); all(x->x isa G3BindingProvenanceSlotV1,xs) || throw(ArgumentError("V2 source slots must be typed"))
        Tuple(x.slot_kind for x in xs)==(:schema,:canonicalization,:profile,:evidence_receipt) || throw(ArgumentError("V2 source slots must be ordered"))
        all(x->x.status===:typed_absent || x.candidate_ref==candidate,xs) || throw(ArgumentError("V2 source slot candidate mismatch"))
        Tuple(x.status for x in xs) in ((:present,:present,:present,:present),(:typed_absent,:typed_absent,:typed_absent,:typed_absent)) || throw(ArgumentError("V2 source slot status mismatch"))
        body=(domain="g3-binding-source-record-v2",candidate_ref=candidate,source_uri=_g3be2_text(uri,"source_uri"),
            source_version=_g3be2_text(ver,"source_version"),schema=s,canonicalization=c,profile=p,evidence_receipt=e)
        _g3be2_digest(h,"source_record_hash")==canonical_hash(body) || throw(ArgumentError("source_record_hash mismatch"))
        new(candidate,body.source_uri,body.source_version,s,c,p,e,h)
    end
end

struct G3BindingSourcePayloadV2
    key::G3BindingChildKeyV2; child_contract_ref::GenomeContractRef
    source_uri::String; source_version::String; source_record::G3BindingSourceRecordV2
    immutable_binding_schema::G3BindingSchemaV2
    initial_links::Tuple{Vararg{G3BindingLinkV1}}
    realization_slot::Union{G3BindingChildPresentV2,G3BindingChildAbsentV2}
    control_slot::Union{G3BindingChildPresentV2,G3BindingChildAbsentV2}
    source_content_hash::Digest256
    function G3BindingSourcePayloadV2(k,c,u,v,r,s,links,rs,cs,h)
        k isa G3BindingChildKeyV2 || throw(ArgumentError("key must be V2")); c isa GenomeContractRef || throw(ArgumentError("contract must be typed"))
        xs=_g3be2_tuple(links,"initial_links"); all(x->x isa G3BindingLinkV1,xs) || throw(ArgumentError("initial links must be V1 link values"))
        length(unique(x.link_id for x in xs))==length(xs) || throw(ArgumentError("initial link ids must be unique"))
        rs isa Union{G3BindingChildPresentV2,G3BindingChildAbsentV2} || throw(ArgumentError("invalid realization slot"))
        cs isa Union{G3BindingChildPresentV2,G3BindingChildAbsentV2} || throw(ArgumentError("invalid control slot"))
        body=(domain="g3-binding-source-content-v2",key=k,child_contract_ref=c,source_uri=_g3be2_text(u,"source_uri"),source_version=_g3be2_text(v,"source_version"),source_record=r,immutable_binding_schema=s,initial_links=Tuple(xs),realization_slot=rs,control_slot=cs)
        _g3be2_digest(h,"source_content_hash")==canonical_hash(body) || throw(ArgumentError("source_content_hash mismatch"))
        new(k,c,body.source_uri,body.source_version,r,s,Tuple(xs),rs,cs,h)
    end
end

struct G3BindingEditableBodyV2
    key::G3BindingChildKeyV2; links::Tuple{Vararg{G3BindingLinkV1}}
    function G3BindingEditableBodyV2(k, links)
        k isa G3BindingChildKeyV2 || throw(ArgumentError("body key must be V2")); xs=_g3be2_tuple(links,"links")
        all(x->x isa G3BindingLinkV1,xs) || throw(ArgumentError("links must be typed")); length(unique(x.link_id for x in xs))==length(xs) || throw(ArgumentError("link ids must be unique")); new(k,Tuple(xs))
    end
end

struct G3BindingOperationV2
    operation_id::String; operation::Symbol; key::G3BindingChildKeyV2; link_id::String
    expected_prior_state_hash::Digest256; before_link::Union{Nothing,G3BindingLinkV1}
    after_link::Union{Nothing,G3BindingLinkV1}; prior_body_hash::Digest256
    resulting_body_hash::Digest256; operation_hash::Digest256
end
struct G3BindingOperationDigestV2
    operation_id::String; operation::Symbol; key::G3BindingChildKeyV2; link_id::String
    expected_prior_state_hash::Digest256; before_link::Union{Nothing,G3BindingLinkV1}
    after_link::Union{Nothing,G3BindingLinkV1}; prior_body_hash::Digest256
    resulting_body_hash::Digest256; previous_state_hash::Digest256
    state_hash::Digest256; operation_hash::Digest256
end
struct G3BindingStateV2
    source_payload::G3BindingSourcePayloadV2; editable_body::G3BindingEditableBodyV2
    state_status::Symbol; absence_reason::Union{Nothing,Symbol}; absence_digest::Union{Nothing,Digest256}
    contract_admission::Symbol; physical_resolution::Symbol
    source_record_hash::Digest256; source_content_hash::Digest256; binding_child_identity_hash::Digest256
    initial_body_hash::Digest256; initial_source_state_hash::Digest256; body_hash::Digest256
    operation_hash::Digest256; state_hash::Digest256
    operation_history::Tuple{Vararg{G3BindingOperationDigestV2}}
end
struct G3BindingCASResultV2
    status::Symbol; state::G3BindingStateV2
    operation::Union{Nothing,G3BindingOperationV2}; errors::Tuple{Vararg{String}}
end

semantic_view(x::G3BindingChildKeyV2)=(candidate_ref=x.candidate_ref,parent_g3_declaration_ref=x.parent_g3_declaration_ref,parent_g3_declaration_hash=x.parent_g3_declaration_hash,child_kind=x.child_kind,child_id=x.child_id)
semantic_view(x::G3BindingSchemaV2)=(schema_id=x.schema_id,version=x.version,schema_hash=x.schema_hash,canonicalization_hash=x.canonicalization_hash,profile_hash=x.profile_hash)
semantic_view(x::G3BindingChildAbsentV2)=(child_kind=x.child_kind,status=x.status,reason=x.reason,absence_digest=x.absence_digest)
semantic_view(x::G3BindingChildPresentV2)=(child_kind=x.child_kind,candidate_ref=x.candidate_ref,parent_g3_declaration_ref=x.parent_g3_declaration_ref,parent_g3_declaration_hash=x.parent_g3_declaration_hash,child_ref=x.child_ref,contract_ref=x.contract_ref,source_record_ref=x.source_record_ref,source_record_hash=x.source_record_hash,source_content_hash=x.source_content_hash,child_identity_hash=x.child_identity_hash,state_hash=x.state_hash)
_g3be2_record_body(x::G3BindingSourceRecordV2)=(domain="g3-binding-source-record-v2",candidate_ref=x.candidate_ref,source_uri=x.source_uri,source_version=x.source_version,schema=x.schema,canonicalization=x.canonicalization,profile=x.profile,evidence_receipt=x.evidence_receipt)
semantic_view(x::G3BindingSourceRecordV2)=merge(_g3be2_record_body(x),(source_record_hash=x.source_record_hash,))
_g3be2_payload_body(x::G3BindingSourcePayloadV2)=(domain="g3-binding-source-content-v2",key=x.key,child_contract_ref=x.child_contract_ref,source_uri=x.source_uri,source_version=x.source_version,source_record=x.source_record,immutable_binding_schema=x.immutable_binding_schema,initial_links=x.initial_links,realization_slot=x.realization_slot,control_slot=x.control_slot)
semantic_view(x::G3BindingSourcePayloadV2)=merge(_g3be2_payload_body(x),(source_content_hash=x.source_content_hash,))
semantic_view(x::G3BindingEditableBodyV2)=(key=x.key,links=x.links)
_g3be2_operation_body(x::G3BindingOperationV2)=(domain="g3-binding-operation-v2",operation_id=x.operation_id,operation=x.operation,key=x.key,link_id=x.link_id,expected_prior_state_hash=x.expected_prior_state_hash,before_link=x.before_link,after_link=x.after_link,prior_body_hash=x.prior_body_hash,resulting_body_hash=x.resulting_body_hash)
semantic_view(x::G3BindingOperationV2)=merge(_g3be2_operation_body(x),(operation_hash=x.operation_hash,))
semantic_view(x::G3BindingOperationDigestV2)=(operation_id=x.operation_id,operation=x.operation,key=x.key,link_id=x.link_id,expected_prior_state_hash=x.expected_prior_state_hash,before_link=x.before_link,after_link=x.after_link,prior_body_hash=x.prior_body_hash,resulting_body_hash=x.resulting_body_hash,previous_state_hash=x.previous_state_hash,state_hash=x.state_hash,operation_hash=x.operation_hash)
semantic_view(x::G3BindingStateV2)=(source_payload=x.source_payload,editable_body=x.editable_body,state_status=x.state_status,absence_reason=x.absence_reason,absence_digest=x.absence_digest,contract_admission=x.contract_admission,physical_resolution=x.physical_resolution,source_record_hash=x.source_record_hash,source_content_hash=x.source_content_hash,binding_child_identity_hash=x.binding_child_identity_hash,initial_body_hash=x.initial_body_hash,initial_source_state_hash=x.initial_source_state_hash,body_hash=x.body_hash,operation_hash=x.operation_hash,state_hash=x.state_hash,operation_history=x.operation_history)
for T in (G3BindingChildKeyV2,G3BindingSchemaV2,G3BindingChildAbsentV2,G3BindingChildPresentV2,G3BindingSourceRecordV2,G3BindingSourcePayloadV2,G3BindingEditableBodyV2,G3BindingOperationV2,G3BindingOperationDigestV2,G3BindingStateV2)
    @eval canonical_json(x::$T)=canonical_json(semantic_view(x))
end

function _g3be2_schema()
    G3BindingSchemaV2(G3_BINDING_CHILD_EDIT_SCHEMA_ID_V2,G3_BINDING_CHILD_EDIT_VERSION_V2,
        g3_binding_child_edit_schema_hash_v2(),g3_binding_child_edit_canonicalization_hash_v2(),g3_binding_child_edit_profile_hash_v2())
end
function _g3be2_contract()
    GenomeContractRef(G3_BINDING_CHILD_EDIT_CONTRACT_URI_V2,G3_BINDING_CHILD_EDIT_VERSION_V2,
        g3_binding_child_edit_schema_hash_v2(),g3_binding_child_edit_canonicalization_hash_v2(),G3_BINDING_CHILD_EDIT_PROFILE_V2)
end
function _g3be2_slot(k,candidate; present_ref=nothing, hash=nothing, reason=nothing)
    if present_ref===nothing
        r=reason===nothing ? "checked-present source unavailable" : String(reason)
        G3BindingProvenanceSlotV1(k,:typed_absent,nothing,nothing,nothing,r)
    else
        G3BindingProvenanceSlotV1(k,:present,present_ref,hash,candidate,nothing)
    end
end

function g3_binding_v2_source_record(candidate; complete=true, source_hash=nothing)
    c=_g3be2_candidate(candidate)
    complete && source_hash===nothing && throw(ArgumentError("checked-present source_hash is required"))
    slots=if complete
        (_g3be2_slot(:schema,c;present_ref=QualifiedRefV1("local://g3-binding/v2/schema","v2"),hash=g3_binding_child_edit_schema_hash_v2()),
         _g3be2_slot(:canonicalization,c;present_ref=QualifiedRefV1("local://g3-binding/v2/canonicalization","v2"),hash=g3_binding_child_edit_canonicalization_hash_v2()),
         _g3be2_slot(:profile,c;present_ref=QualifiedRefV1("local://g3-binding/v2/profile","v2"),hash=g3_binding_child_edit_profile_hash_v2()),
         _g3be2_slot(:evidence_receipt,c;present_ref=QualifiedRefV1("local://g3-binding/v2/local-receipt","v1"),hash=source_hash))
    else
        (_g3be2_slot(:schema,c),_g3be2_slot(:canonicalization,c),_g3be2_slot(:profile,c),_g3be2_slot(:evidence_receipt,c))
    end
    b=(domain="g3-binding-source-record-v2",candidate_ref=c,source_uri=G3_BINDING_CHILD_EDIT_SOURCE_URI_V2,source_version=G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V2,schema=slots[1],canonicalization=slots[2],profile=slots[3],evidence_receipt=slots[4])
    G3BindingSourceRecordV2(c,b.source_uri,b.source_version,slots...,canonical_hash(b))
end

function _g3be2_slot_valid(slot, kind, key)
    slot.child_kind===kind || throw(ArgumentError("binding child slot kind mismatch"))
    if slot isa G3BindingChildPresentV2
        slot.candidate_ref==key.candidate_ref || throw(ArgumentError("binding child slot candidate mismatch"))
        slot.parent_g3_declaration_ref==key.parent_g3_declaration_ref || throw(ArgumentError("binding child slot parent ref mismatch"))
        slot.parent_g3_declaration_hash==key.parent_g3_declaration_hash || throw(ArgumentError("binding child slot parent hash mismatch"))
        slot.source_record_hash != G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 || throw(ArgumentError("binding child source record hash cannot be zero"))
        slot.source_content_hash != G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 || throw(ArgumentError("binding child source hash cannot be zero"))
        slot.child_identity_hash != G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 || throw(ArgumentError("binding child identity hash cannot be zero"))
        slot.state_hash != G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 || throw(ArgumentError("binding child state hash cannot be zero"))
    end
    true
end
function _g3be2_payload_valid(p)
    p.key.child_kind===:binding || return false
    p.child_contract_ref==_g3be2_contract() || return false
    p.source_uri==G3_BINDING_CHILD_EDIT_SOURCE_URI_V2 && p.source_version==G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V2 || return false
    p.immutable_binding_schema.schema_id==G3_BINDING_CHILD_EDIT_SCHEMA_ID_V2 && p.immutable_binding_schema.version==G3_BINDING_CHILD_EDIT_VERSION_V2 || return false
    p.immutable_binding_schema.schema_hash==g3_binding_child_edit_schema_hash_v2() && p.immutable_binding_schema.canonicalization_hash==g3_binding_child_edit_canonicalization_hash_v2() && p.immutable_binding_schema.profile_hash==g3_binding_child_edit_profile_hash_v2() || return false
    p.source_record.candidate_ref==p.key.candidate_ref && p.source_record.source_uri==p.source_uri && p.source_record.source_version==p.source_version || return false
    _g3be2_slot_valid(p.realization_slot,:realization,p.key); _g3be2_slot_valid(p.control_slot,:control,p.key)
    present=(p.realization_slot isa G3BindingChildPresentV2 && p.control_slot isa G3BindingChildPresentV2)
    statuses=Tuple(x.status for x in (p.source_record.schema,p.source_record.canonicalization,p.source_record.profile,p.source_record.evidence_receipt))
    statuses == (present ? (:present,:present,:present,:present) : (:typed_absent,:typed_absent,:typed_absent,:typed_absent)) || return false
    canonical_hash(_g3be2_payload_body(p))==p.source_content_hash
end
function g3_binding_v2_source_payload(key::G3BindingChildKeyV2, links=(); realization_slot=nothing, control_slot=nothing, complete=true, source_hash=nothing)
    rs=realization_slot===nothing ? G3BindingChildAbsentV2(:realization,:missing_child) : realization_slot
    cs=control_slot===nothing ? G3BindingChildAbsentV2(:control,:missing_child) : control_slot
    c=_g3be2_contract(); r=g3_binding_v2_source_record(key.candidate_ref;complete=complete,source_hash=source_hash); s=_g3be2_schema()
    b=(domain="g3-binding-source-content-v2",key=key,child_contract_ref=c,source_uri=G3_BINDING_CHILD_EDIT_SOURCE_URI_V2,source_version=G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V2,source_record=r,immutable_binding_schema=s,initial_links=Tuple(links),realization_slot=rs,control_slot=cs)
    p=G3BindingSourcePayloadV2(key,c,G3_BINDING_CHILD_EDIT_SOURCE_URI_V2,G3_BINDING_CHILD_EDIT_SOURCE_VERSION_V2,r,s,Tuple(links),rs,cs,canonical_hash(b))
    _g3be2_payload_valid(p) || throw(ArgumentError("V2 source payload cross-field validation failed")); p
end

function _g3be2_history_projection(history)
    Tuple((operation_id=x.operation_id,operation=x.operation,key=x.key,link_id=x.link_id,expected_prior_state_hash=x.expected_prior_state_hash,before_link=x.before_link,after_link=x.after_link,prior_body_hash=x.prior_body_hash,resulting_body_hash=x.resulting_body_hash,previous_state_hash=x.previous_state_hash,state_hash=G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,operation_hash=x.operation_hash) for x in history)
end
function _g3be2_state_hash(key,status,payload,body,src,identity,initial_body,initial_source,op,history)
    canonical_hash((domain="g3-binding-state-v2",key=key,state_status=status,source_record_hash=payload.source_record.source_record_hash,source_content_hash=payload.source_content_hash,binding_child_identity_hash=identity,initial_body_hash=initial_body,initial_source_state_hash=initial_source,body_hash=canonical_hash(body),operation_hash=op,operation_history=_g3be2_history_projection(history)))
end
function _g3be2_identity(p)
    canonical_hash((domain="g3-binding-child-identity-v2",key=p.key,child_contract_ref=p.child_contract_ref,source_record_hash=p.source_record.source_record_hash,source_content_hash=p.source_content_hash))
end
function g3_binding_v2_initial_state(p::G3BindingSourcePayloadV2)
    _g3be2_payload_valid(p) || throw(ArgumentError("V2 source payload cross-field validation failed"))
    body=G3BindingEditableBodyV2(p.key,p.initial_links); initial_body=canonical_hash(body); identity=_g3be2_identity(p)
    present=(p.realization_slot isa G3BindingChildPresentV2 && p.control_slot isa G3BindingChildPresentV2)
    status=present ? :present : :typed_absent; reason=present ? nothing : :missing_provenance
    absence=present ? nothing : G3BindingChildAbsentV2(:realization,reason).absence_digest
    initial_source=canonical_hash((domain="g3-binding-initial-source-state-v2",key=p.key,source_record_hash=p.source_record.source_record_hash,source_content_hash=p.source_content_hash,binding_child_identity_hash=identity,initial_body_hash=initial_body,state_status=status,absence_reason=reason,absence_digest=absence,operation_hash=G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,operation_history=()))
    state_hash=_g3be2_state_hash(p.key,status,p,body, p.source_content_hash,identity,initial_body,initial_source,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,())
    G3BindingStateV2(p,body,status,reason,absence,present ? :declared_consistent : :terminal_deferred,:unknown,p.source_record.source_record_hash,p.source_content_hash,identity,initial_body,initial_source,initial_body,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,state_hash,())
end
g3_binding_v2_admit(p::G3BindingSourcePayloadV2)=g3_binding_v2_initial_state(p)
g3_binding_v2_canonical_bytes(x)=Vector{UInt8}(codeunits(canonical_json(semantic_view(x))))

function _g3be2_validate_state(state::G3BindingStateV2)
    errors=String[]
    record_error(code) = isempty(errors) && push!(errors,String(code))
    p=state.source_payload; body=state.editable_body
    p.key==body.key || record_error("state_body_key_mismatch")
    payload_valid=try _g3be2_payload_valid(p) catch; false end
    payload_valid || record_error("source_payload_cross_field_mismatch")
    state.source_record_hash==p.source_record.source_record_hash || record_error("state_source_record_hash_mismatch")
    state.source_content_hash==p.source_content_hash || record_error("state_source_content_hash_mismatch")
    _g3be2_identity(p)==state.binding_child_identity_hash || record_error("state_child_identity_hash_mismatch")
    initial_body=try G3BindingEditableBodyV2(p.key,p.initial_links) catch; nothing end
    initial_body===nothing && record_error("initial_body_invalid")
    initial_body===nothing || canonical_hash(initial_body)==state.initial_body_hash || record_error("initial_body_hash_mismatch")
    if state.state_status===:present
        p.realization_slot isa G3BindingChildPresentV2 && p.control_slot isa G3BindingChildPresentV2 || record_error("present_state_slot_absent")
        state.absence_reason===nothing && state.absence_digest===nothing || record_error("present_state_carries_absence")
        state.contract_admission===:declared_consistent || record_error("present_state_admission_mismatch")
    elseif state.state_status===:typed_absent
        state.absence_reason!==nothing && state.absence_digest!==nothing || record_error("absent_state_missing_reason")
        state.contract_admission===:terminal_deferred || record_error("absent_state_admission_mismatch")
        isempty(state.operation_history) || record_error("absent_state_has_history")
    else
        record_error("state_status_invalid")
    end
    initial_source=canonical_hash((domain="g3-binding-initial-source-state-v2",key=p.key,source_record_hash=p.source_record.source_record_hash,source_content_hash=p.source_content_hash,binding_child_identity_hash=state.binding_child_identity_hash,initial_body_hash=state.initial_body_hash,state_status=state.state_status,absence_reason=state.absence_reason,absence_digest=state.absence_digest,operation_hash=G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,operation_history=()))
    initial_source==state.initial_source_state_hash || record_error("initial_source_state_hash_mismatch")
    canonical_hash(body)==state.body_hash || record_error("body_hash_mismatch")
    base_state=_g3be2_state_hash(p.key,state.state_status,p,initial_body,state.source_content_hash,state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,())
    prev_state=base_state; current_body=initial_body; seen_ids=Set{String}()
    for (i,rec) in enumerate(state.operation_history)
        isempty(rec.operation_id) && record_error("history_operation_id_empty")
        rec.operation_id in seen_ids && record_error("history_duplicate_operation_id")
        push!(seen_ids,rec.operation_id)
        rec.key==p.key && rec.key==body.key || record_error("history_key_mismatch")
        rec.operation in G3_BINDING_CHILD_EDIT_OPERATIONS_V2 || record_error("history_operation_invalid")
        rec.expected_prior_state_hash==rec.previous_state_hash || record_error("history_expected_prior_state_mismatch")
        rec.previous_state_hash==prev_state || record_error("history_previous_state_mismatch")
        current_body===nothing || rec.prior_body_hash==canonical_hash(current_body) || record_error("history_prior_body_hash_mismatch")
        op=G3BindingOperationV2(rec.operation_id,rec.operation,rec.key,rec.link_id,rec.expected_prior_state_hash,rec.before_link,rec.after_link,rec.prior_body_hash,rec.resulting_body_hash,rec.operation_hash)
        rec.operation_hash==canonical_hash(_g3be2_operation_body(op)) || record_error("history_operation_hash_mismatch")
        next_body,err=current_body===nothing ? (nothing,"body_missing") : _g3be2_apply_body(current_body,op)
        next_body===nothing && record_error("history_transition_invalid")
        next_body===nothing || canonical_hash(next_body)==rec.resulting_body_hash || record_error("history_result_body_hash_mismatch")
        prefix=Tuple(state.operation_history[j] for j in 1:i)
        expected_rec_state=_g3be2_state_hash(p.key,:present,p,next_body===nothing ? current_body : next_body,state.source_content_hash,state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,rec.operation_hash,prefix)
        expected_rec_state==rec.state_hash || record_error("history_state_hash_mismatch")
        prev_state=rec.state_hash; current_body=next_body===nothing ? current_body : next_body
    end
    isempty(state.operation_history) ? (state.operation_hash==G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2 || record_error("last_operation_hash_mismatch")) : (state.operation_hash==state.operation_history[end].operation_hash || record_error("last_operation_hash_mismatch"))
    expected_state=_g3be2_state_hash(p.key,state.state_status,p,body,state.source_content_hash,state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,state.operation_hash,state.operation_history)
    expected_state==state.state_hash || record_error("state_hash_mismatch")
    current_body===nothing || canonical_hash(current_body)==canonical_hash(body) || record_error("history_final_body_mismatch")
    Tuple(errors)
end

function g3_binding_v2_operation(id,op,key,link_id,expected,before,after,prior_body,result_body)
    o=_g3be2_symbol(op,G3_BINDING_CHILD_EDIT_OPERATIONS_V2,"operation"); i=_g3be2_text(id,"operation_id")
    d=(domain="g3-binding-operation-v2",operation_id=i,operation=o,key=key,link_id=_g3be2_text(link_id,"link_id"),expected_prior_state_hash=expected,before_link=before,after_link=after,prior_body_hash=prior_body,resulting_body_hash=result_body)
    G3BindingOperationV2(i,o,key,d.link_id,_g3be2_digest(expected,"expected prior state"),before,after,_g3be2_digest(prior_body,"prior body"),_g3be2_digest(result_body,"result body"),canonical_hash(d))
end
g3_binding_v2_insert_operation(id,key,link,expected,prior,result)=g3_binding_v2_operation(id,:insert_link,key,link.link_id,expected,nothing,link,prior,result)
g3_binding_v2_replace_operation(id,key,idlink,before,after,expected,prior,result)=g3_binding_v2_operation(id,:replace_link,key,idlink,expected,before,after,prior,result)
g3_binding_v2_delete_operation(id,key,link,expected,prior,result)=g3_binding_v2_operation(id,:delete_link,key,link.link_id,expected,link,nothing,prior,result)

function _g3be2_fail(state,op,err)
    G3BindingCASResultV2(:fail_closed,state,op,(String(err),))
end
function _g3be2_links(body); body.links end
function _g3be2_apply_body(body,op)
    xs=collect(body.links); idx=findfirst(x->x.link_id==op.link_id,xs)
    if op.operation===:insert_link
        idx===nothing || return nothing,"duplicate_link_id"; op.before_link===nothing || return nothing,"insert_before_must_be_nothing"; op.after_link===nothing && return nothing,"insert_after_missing"; op.link_id==op.after_link.link_id || return nothing,"insert_link_id_mismatch"; push!(xs,op.after_link)
    elseif op.operation===:replace_link
        idx===nothing && return nothing,"unknown_link_id"; op.before_link===nothing && return nothing,"replace_before_missing"; op.before_link==xs[idx] || return nothing,"before_link_mismatch"; op.after_link===nothing && return nothing,"replace_after_missing"; op.link_id==op.before_link.link_id==op.after_link.link_id || return nothing,"replace_link_id_mismatch"; xs[idx]=op.after_link
    elseif op.operation===:delete_link
        idx===nothing && return nothing,"unknown_link_id"; op.before_link===nothing && return nothing,"delete_before_missing"; op.before_link==xs[idx] || return nothing,"before_link_mismatch"; op.link_id==op.before_link.link_id || return nothing,"delete_link_id_mismatch"; op.after_link===nothing || return nothing,"delete_after_must_be_nothing"; deleteat!(xs,idx)
    else
        return nothing,"invalid_operation"
    end
    try return G3BindingEditableBodyV2(body.key,Tuple(xs)), nothing catch; return nothing,"resulting_body_invalid" end
end
function _g3be2_apply(state::G3BindingStateV2, op::G3BindingOperationV2)
    state_errors=_g3be2_validate_state(state)
    isempty(state_errors) || return _g3be2_fail(state,op,first(state_errors))
    state.state_status===:present || return _g3be2_fail(state,op,"typed_absent_state")
    op.key==state.editable_body.key || return _g3be2_fail(state,op,"foreign_key")
    op.operation_id in Tuple(x.operation_id for x in state.operation_history) && return _g3be2_fail(state,op,"duplicate_operation_id")
    op.expected_prior_state_hash==state.state_hash || return _g3be2_fail(state,op,"stale_state_hash")
    op.prior_body_hash==state.body_hash || return _g3be2_fail(state,op,"prior_body_hash_mismatch")
    canonical_hash(_g3be2_operation_body(op))==op.operation_hash || return _g3be2_fail(state,op,"operation_hash_mismatch")
    newbody,err=_g3be2_apply_body(state.editable_body,op); newbody===nothing && return _g3be2_fail(state,op,err)
    canonical_hash(newbody)==op.resulting_body_hash || return _g3be2_fail(state,op,"resulting_body_hash_mismatch")
    provisional=G3BindingOperationDigestV2(op.operation_id,op.operation,op.key,op.link_id,op.expected_prior_state_hash,op.before_link,op.after_link,op.prior_body_hash,op.resulting_body_hash,state.state_hash,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,op.operation_hash)
    final_history=(state.operation_history...,provisional)
    final_hash=_g3be2_state_hash(state.editable_body.key,:present,state.source_payload,newbody,state.source_content_hash,state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,op.operation_hash,final_history)
    rec=G3BindingOperationDigestV2(op.operation_id,op.operation,op.key,op.link_id,op.expected_prior_state_hash,op.before_link,op.after_link,op.prior_body_hash,op.resulting_body_hash,state.state_hash,final_hash,op.operation_hash)
    final_history=(state.operation_history...,rec)
    newstate=G3BindingStateV2(state.source_payload,newbody,:present,nothing,nothing,:declared_consistent,:unknown,state.source_record_hash,state.source_content_hash,state.binding_child_identity_hash,state.initial_body_hash,state.initial_source_state_hash,canonical_hash(newbody),op.operation_hash,final_hash,final_history)
    G3BindingCASResultV2(:applied,newstate,op,())
end
insert_link(s::G3BindingStateV2,o::G3BindingOperationV2)=_g3be2_apply(s,o)
replace_link(s::G3BindingStateV2,o::G3BindingOperationV2)=_g3be2_apply(s,o)
delete_link(s::G3BindingStateV2,o::G3BindingOperationV2)=_g3be2_apply(s,o)

export G3_BINDING_CHILD_EDIT_SCHEMA_ID_V2,G3_BINDING_CHILD_EDIT_VERSION_V2,G3_BINDING_CHILD_EDIT_CONTRACT_URI_V2,G3_BINDING_CHILD_EDIT_PROFILE_V2,G3_BINDING_CHILD_EDIT_ZERO_DIGEST_V2,G3BindingChildKeyV2,G3BindingSchemaV2,G3BindingChildAbsentV2,G3BindingChildPresentV2,G3BindingSourceRecordV2,G3BindingSourcePayloadV2,G3BindingEditableBodyV2,G3BindingOperationV2,G3BindingOperationDigestV2,G3BindingStateV2,G3BindingCASResultV2,g3_binding_child_edit_schema_hash_v2,g3_binding_child_edit_canonicalization_hash_v2,g3_binding_child_edit_profile_hash_v2,g3_binding_v2_source_record,g3_binding_v2_source_payload,g3_binding_v2_initial_state,g3_binding_v2_admit,g3_binding_v2_canonical_bytes,g3_binding_v2_operation,g3_binding_v2_insert_operation,g3_binding_v2_replace_operation,g3_binding_v2_delete_operation,insert_link,replace_link,delete_link

"""Candidate-authored, source-pinned realization evidence for an opt-in G3 descriptor.

This payload deliberately does not relax `RealizationGenomeV5` or the default
`RealizationControlGenomeV5` admission path. It carries the exact authored
network/laws/source maps needed by a separate source-backed descriptor branch;
it supplies no provider or physical authority.
"""
struct G3AuthoredRealizationPayloadV1
    candidate_ref::QualifiedRefV1
    candidate_id::String
    scenario_id::String
    source_ref::QualifiedRefV1
    source_path::String
    source_sha256::Digest256
    builder_source_ref::QualifiedRefV1
    builder_source_sha256::Digest256
    source_admission::NamedTuple
    source_proof::NamedTuple
    source_realization::G3RealizationSourceBodyV1
    control_source::G3ControlSourceBodyV1
    network::G3ResourceNetworkV2
    effort_ports_without_ledger::Tuple{Vararg{String}}
    power_laws::Tuple{Vararg{G3AuthoredPowerLawV1}}
    control_resource_links::Tuple{Vararg{G3ControlResourceLinkV2}}
    command_to_current_map::NamedTuple
    command_to_power_map::NamedTuple
    power_status_signal_id::String
    feedback_source_maps::Tuple
    authored_heat_lift::NamedTuple
    claim_scope::Symbol
    payload_hash::Digest256
    function G3AuthoredRealizationPayloadV1(record::Any, children::Any,
            rebuilt_child::Any; frozen_context, g3_factory_invocation=nothing)
        fields = _g3_authored_payload_fields_v1(record, children,
            rebuilt_child; frozen_context=frozen_context,
            g3_factory_invocation=g3_factory_invocation)
        new(fields...)
    end
end

struct _G3AuthoredCandidateBindingProofV1
    candidate_ref::QualifiedRefV1
    payload::G3AuthoredRealizationPayloadV1
    payload_hash::Digest256
    function _G3AuthoredCandidateBindingProofV1(payload::Any)
        candidate_ref = _g3_replay_authored_payload_candidate_v1(payload)
        new(candidate_ref, payload, canonical_hash(semantic_view(payload)))
    end
end

function _g3_validate_authored_realization_source_v1(candidate_ref, candidate_id,
        scenario_id, source_ref, source_sha256, source_path, source_realization,
        control_source, network, waiver_ids, laws, links, current_map,
        power_map, power_status_signal_id, feedback_maps, authored_heat_lift;
        g3_factory_invocation=nothing)
    candidate_ref.id == "fusionconceptai://candidate-design/" * candidate_id ||
        throw(ArgumentError("authored G3 candidate id is not bound to the actual candidate ref"))
    if g3_factory_invocation === nothing
        candidate_id == "local-authored-up4-g123-20260928-r2" ||
            throw(ArgumentError("authored G3 source candidate id mismatch"))
        scenario_id == "scenario-local-authored-up4-g123-20260928-r2" ||
            throw(ArgumentError("authored G3 source scenario id mismatch"))
        source_path == "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_child_design_source.jl" ||
            throw(ArgumentError("authored G3 source path is not the admitted child source"))
    else
        required=(:candidate_id,:scenario_id,:source_path,:re_enable_threshold_kelvin)
        all(k->hasproperty(g3_factory_invocation,k),required) &&
            g3_factory_invocation.candidate_id==candidate_id &&
            g3_factory_invocation.scenario_id==scenario_id &&
            g3_factory_invocation.source_path==source_path ||
            throw(ArgumentError("authored G3 source differs from its selected factory invocation"))
        threshold=g3_factory_invocation.re_enable_threshold_kelvin
        threshold===nothing || (threshold isa Rational{Int64} && 0<=threshold<350) ||
            throw(ArgumentError("authored G3 clear threshold is not exact Kelvin below the 350 K trip"))
    end
    source_realization.source_id == "local-authored-realization-r3" &&
        control_source.source_id == "local-authored-control-r3" ||
        throw(ArgumentError("authored G3 source child ids differ from pinned candidate design"))
    length(waiver_ids) == 1 && only(waiver_ids) == "source_voltage" ||
        throw(ArgumentError("authored source may waive only the unique source_voltage effort entry"))
    isempty(g3_validate_resource_network(network;
        effort_ports_without_ledger=waiver_ids)) ||
        throw(ArgumentError("authored network fails strict V2 structure/closure under the exact effort waiver"))
    effort = Tuple(p for p in network.resource_ports if p.kind === :effort)
    length(effort) == 1 && only(effort).port_id == "source_voltage" &&
        only(effort).unit == UnitSignature((1, 2, -3, -1, 0, 0, 0)) ||
        throw(ArgumentError("authored source voltage effort is missing, ambiguous, or has the wrong SI unit"))
    isempty(Tuple(e for e in network.entries if e.port_id == "source_voltage")) ||
        throw(ArgumentError("waived source_voltage effort must have no consumable ledger entry"))
    account_ids = Set(a.account_id for a in network.accounts)
    closure_ids = Set(id for c in network.closures for id in c.account_ids)
    only(effort).account_id in account_ids && only(effort).account_id in closure_ids ||
        throw(ArgumentError("waived source_voltage still requires a real account and closure join"))

    hasproperty(authored_heat_lift, :budget_join) &&
        authored_heat_lift.schema == "g3-authored-scalar-heat-lift-v1" &&
        authored_heat_lift.candidate_id == candidate_id && authored_heat_lift.scenario_id == scenario_id &&
        authored_heat_lift.source_unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
        authored_heat_lift.native_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
        authored_heat_lift.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) &&
        authored_heat_lift.budget_join.entry_id == "field_allocation" &&
        authored_heat_lift.budget_join.account_id == "design_energy" &&
        authored_heat_lift.budget_join.port_id == "diffusion_load" &&
        authored_heat_lift.budget_join.component_id == "diffusion_core" &&
        authored_heat_lift.budget_join.coefficient_w == -500 &&
        authored_heat_lift.budget_join.limit_w == 500 ||
        throw(ArgumentError("authored scalar heat lift is not pinned to exact candidate field-allocation budget/basis"))
    length(laws) == 2 && Set(x.law_id for x in laws) == Set(("source_bus_VI", "return_bus_VI")) ||
        throw(ArgumentError("authored network requires exactly the source and return V-I-P laws"))
    voltage_unit = UnitSignature((1, 2, -3, -1, 0, 0, 0))
    current_unit = UnitSignature((0, 0, 0, 1, 0, 0, 0))
    power_unit = UnitSignature((1, 2, -3, 0, 0, 0, 0))
    old_ports = Dict(p.port_id => p for p in source_realization.ports)
    old_entries = Dict(e.port_id => e for e in source_realization.ledger_entries)
    network_entries = Dict(e.port_id => e for e in network.entries)
    expected_laws = (
        ("source_bus_VI", "source_supply_current", "source_bus", 500//1, 2//1, 1000//1,
            :flow, :out, "source_module", :source, 1000//1),
        ("return_bus_VI", "return_current", "return_bus", 500//1, 1//2, 250//1,
            :return, :in, "return_manifold", :return, -250//1),
    )
    for expected in expected_laws
        law = only(Tuple(x for x in laws if x.law_id == expected[1]))
        law.effort_port_id == "source_voltage" &&
            law.current_port_id == expected[2] && law.power_endpoint_id == expected[3] &&
            law.voltage == expected[4] && law.current == expected[5] &&
            law.power == expected[6] && law.voltage_unit == voltage_unit &&
            law.current_unit == current_unit && law.power_unit == power_unit &&
            law.claim_scope === :candidate_design_only ||
            throw(ArgumentError("authored V-I-P law does not match exact candidate circuit join: " * expected[1]))
        haskey(old_ports, law.power_endpoint_id) && haskey(old_entries, law.power_endpoint_id) ||
            throw(ArgumentError("authored V-I-P power endpoint lacks its existing W ledger port/entry: " * law.power_endpoint_id))
        haskey(network_entries, law.current_port_id) ||
            throw(ArgumentError("authored V-I-P current port lacks its network accounting entry: " * law.current_port_id))
        old_ports[law.power_endpoint_id].unit == power_unit &&
            old_ports[law.power_endpoint_id].direction == (expected[1] == "source_bus_VI" ? :out : :in) &&
            old_entries[law.power_endpoint_id].unit == power_unit &&
            old_entries[law.power_endpoint_id].coefficient == expected[11] &&
            old_entries[law.power_endpoint_id].effect === expected[10] ||
            throw(ArgumentError("authored V-I-P law does not exactly join the existing W power ledger"))
        current_entry = network_entries[law.current_port_id]
        current_port = only(Tuple(p for p in network.resource_ports if p.port_id == law.current_port_id))
        current_port.kind === expected[7] && current_port.direction === expected[8] &&
            current_port.unit == current_unit && current_port.account_id == only(effort).account_id &&
            current_entry.account_id == current_port.account_id &&
            current_entry.component_id == expected[9] && current_entry.unit == power_unit &&
            current_entry.coefficient == expected[11] && current_entry.effect === expected[10] ||
            throw(ArgumentError("authored V-I-P law does not exactly join its V2 network power accounting"))
    end

    length(links) == 1 || throw(ArgumentError("candidate source requires its exact single current-flow control link"))
    link = only(links)
    length(control_source.controllers) == 1 || throw(ArgumentError("candidate control source controller is missing or ambiguous"))
    controller = only(control_source.controllers)
    link.controller_id == controller.controller_id &&
        link.sensor_port_id in controller.sensor_port_ids &&
        link.actuator_port_id in controller.actuator_port_ids &&
        link.fault_id in controller.fault_ids &&
        link.resource_port_id == "source_supply_current" &&
        !(link.resource_port_id in controller.actuator_resource_port_ids) ||
        throw(ArgumentError("authored control link does not map the existing controller to the distinct current-flow target"))
    link.resource_port_id == current_map.target_resource_port_id &&
        current_map.law === :fraction_of_rated_current &&
        current_map.rated_current == 2 && current_map.rated_current_unit == current_unit &&
        current_map.output_unit == current_unit && current_map.offset == 0 ||
        throw(ArgumentError("authored command/current map does not prove the 2A source-flow join"))
    current_map.command_unit == only(Tuple(s for s in control_source.signal_ports
        if s.port_id == link.actuator_port_id)).unit ||
        throw(ArgumentError("authored command/current map unit differs from its actual command signal"))
    power_map.coefficient == 1000 && power_map.coefficient_unit == power_unit &&
        power_map.command_unit == current_map.command_unit &&
        power_map.output_unit == power_unit && power_map.offset == 0 ||
        throw(ArgumentError("authored command/power status map differs from 500V*2A source law"))
    haskey(Dict(s.port_id => s for s in control_source.signal_ports), power_status_signal_id) ||
        throw(ArgumentError("authored power status signal is absent"))
    power_status = only(Tuple(s for s in control_source.signal_ports
        if s.port_id == power_status_signal_id))
    power_status.signal_kind === :status && power_status.direction === :out &&
        power_status.unit == power_unit && power_status.account_id == "design_energy" &&
        power_status.port_id != link.resource_port_id &&
        power_status.port_id in controller.actuator_resource_port_ids ||
        throw(ArgumentError("authored power status signal must remain distinct from current-flow actuation"))

    feedback_ids = Set(("feedback_g1_r2", "feedback_g2_r2"))
    length(feedback_maps) == 2 && Set(x.target_id for x in feedback_maps) == feedback_ids ||
        throw(ArgumentError("candidate feedback mapping must cover exactly the two authored G1/G2 targets"))
    source_signals = Dict(s.port_id => s for s in control_source.signal_ports)
    expected_feedback = (
        ("feedback_g1_r2", :G1, "design.residual",
            UnitSignature((-2, 0, 0, 0, 0, 0, 0)),
            UnitSignature((0, -2, 0, 0, 0, 0, 0)), "g1_residual_feedback"),
        ("feedback_g2_r2", :G2, "design.boundary_residual",
            UnitSignature(), UnitSignature(), "g2_residual_feedback"),
    )
    for expected in expected_feedback
        mapping = only(Tuple(x for x in feedback_maps if x.target_id == expected[1]))
        mapping.target_layer == expected[2] && mapping.target_path == expected[3] &&
            mapping.quantity === :residual && mapping.target_unit == expected[4] &&
            mapping.signal_unit == expected[5] &&
            mapping.target_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
            mapping.signal_unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
            mapping.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) &&
            mapping.unit_scale == 1//1 &&
            UnitSignature(ntuple(i -> mapping.target_unit.exponents[
                mapping.native_basis_permutation[i]], 7)) == mapping.signal_unit &&
            mapping.signal_port_id == expected[6] && mapping.channel === :residual &&
            mapping.kind === :implementation_error && mapping.scope === :candidate_design_only &&
            mapping.authority === :missing ||
            throw(ArgumentError("candidate feedback mapping differs from exact authored target: " * expected[1]))
        haskey(source_signals, mapping.signal_port_id) ||
            throw(ArgumentError("feedback mapping signal is absent from authored control source"))
        signal = source_signals[mapping.signal_port_id]
        signal.signal_kind === :sensor && signal.direction === :in && signal.unit == mapping.signal_unit ||
            throw(ArgumentError("feedback mapping signal kind/direction/unit does not match target"))
    end
    nothing
end

"""Build payload only from the exact current T1 G3 record, all three T1 children, and T2-rebuilt child.

The T1 records must carry independently hash-checked builder/child bytes, a present
factory receipt, and the semantic body produced by the current G3 source builder.
"""
function _g3_authored_source_context_identity_v1(context)
    if context isa AbstractString
        root = realpath(String(context))
        return (kind=:current_source, source_root=root)
    elseif isdefined(@__MODULE__, :NativeGitReadCompatibilityV1) &&
            context isa NativeGitReadCompatibilityV1.FrozenSourceContextV1
        return (kind=:frozen_source, identity=
            NativeGitReadCompatibilityV1.frozen_source_identity(context))
    elseif isdefined(@__MODULE__, :NativeGitReadCompatibilityV1) &&
            context isa NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1
        return (kind=:up1_frozen_source, identity=
            NativeGitReadCompatibilityV1.frozen_source_identity(context))
    end
    throw(ArgumentError("G3 authored source context must be current-root or a supported frozen context"))
end

function _g3_authored_payload_fields_v1(record, children, rebuilt_child; frozen_context,
        g3_factory_invocation=nothing)
    record isa VNextT0LocalPresentDeclarationV1 && record.layer === :G3 ||
        throw(ArgumentError("G3 authored payload requires the exact present T1 G3 declaration record"))
    record.factory_receipt isa VNextT0LocalFactoryReceiptV1 &&
        record.factory_receipt.layer === :G3 &&
        record.factory_receipt.candidate_ref == record.candidate_ref &&
        record.factory_receipt.source_ref == record.source_ref &&
        record.factory_receipt.status === :present &&
        record.factory_receipt.factory_result_hash == canonical_hash(record.factory_receipt.factory_result) &&
        record.factory_receipt.bytes.bytes == _vnl_t0_factory_result_bytes(record.factory_receipt.factory_result).bytes &&
        record.factory_receipt.bytes.sha256 == Digest256(bytes2hex(SHA.sha256(record.factory_receipt.bytes.bytes))) &&
        record.factory_receipt.factory_result.source_bytes.sha256 == record.source_bytes.sha256 &&
        record.factory_receipt.factory_result.source_bytes.bytes == record.source_bytes.bytes ||
        throw(ArgumentError("G3 authored payload requires a matching present T1 factory receipt"))
    children isa Tuple && length(children) == 3 &&
        all(child -> child isa VNextT0LocalChildPresentV1, children) &&
        Set(child.kind for child in children) == Set((:realization, :control, :binding)) ||
        throw(ArgumentError("G3 authored payload requires all three present T1 child records"))
    all(child -> child.layer === :G3 && child.candidate_ref == record.candidate_ref &&
        child.child_id == String(child.kind), children) ||
        throw(ArgumentError("T1 G3 child records do not share the admitted candidate/layer"))
    binding_child = only(Tuple(child for child in children if child.kind === :binding))
    body = record.semantic_body.body
    body isa NamedTuple && hasproperty(body, :authored_child_design_input) &&
        hasproperty(body, :authored_builder_input) &&
        hasproperty(body, :authored_typed_ledger_source) &&
        hasproperty(body, :authored_child_design) ||
        throw(ArgumentError("T1 G3 semantic receipt omits the exact authored builder/child pins"))
    source_input = body.authored_child_design_input
    builder_input = body.authored_builder_input
    all(child -> child.source_ref == binding_child.source_ref &&
        child.source_bytes.bytes == binding_child.source_bytes.bytes &&
        child.source_bytes.sha256 == binding_child.source_bytes.sha256 &&
        child.source_locator.source_ref == child.source_ref &&
        child.source_locator.source_path == body.authored_child_design.source_path &&
        child.source_locator.source_sha256 == child.source_bytes.sha256 &&
        child.source_locator.source_size == length(child.source_bytes.bytes) &&
        child.source_bytes.sha256 == Digest256(bytes2hex(SHA.sha256(child.source_bytes.bytes))) &&
        child.body.kind === child.kind && child.body.source_ref == child.source_ref &&
        child.body.source_sha256 == child.source_bytes.sha256 &&
        canonical_hash(child.body.child_design) == canonical_hash(body.authored_child_design) &&
        child.body_hash == canonical_hash(child.body) &&
        child.child_identity_hash == canonical_hash((candidate_ref=child.candidate_ref,
            layer=:G3, child_id=child.child_id, kind=child.kind,
            child_ref=child.child_ref, body_hash=child.body_hash,
            source_ref=child.source_ref, source_sha256=child.source_bytes.sha256)), children) ||
        throw(ArgumentError("one or more T1 G3 child bytes, locators, bodies or identities differ"))
    source_input isa VNextT0LocalBytesV1 &&
        source_input.bytes == binding_child.source_bytes.bytes &&
        source_input.sha256 == binding_child.source_bytes.sha256 &&
        source_input.sha256 == Digest256(bytes2hex(SHA.sha256(source_input.bytes))) &&
        binding_child.source_locator.source_sha256 == source_input.sha256 &&
        binding_child.source_locator.source_size == length(source_input.bytes) ||
        throw(ArgumentError("T1 G3 child source bytes do not match their SHA-256 pin"))
    builder_input isa VNextT0LocalBytesV1 &&
        builder_input.bytes == record.source_bytes.bytes &&
        builder_input.sha256 == record.source_bytes.sha256 &&
        builder_input.sha256 == Digest256(bytes2hex(SHA.sha256(builder_input.bytes))) &&
        record.source_locator.source_sha256 == builder_input.sha256 &&
        record.source_locator.source_size == length(builder_input.bytes) ||
        throw(ArgumentError("T1 G3 builder source bytes differ from its source locator/record"))
    record.semantic_body.bytes.sha256 == Digest256(bytes2hex(SHA.sha256(record.semantic_body.bytes.bytes))) &&
        record.semantic_body.bytes.bytes == Vector{UInt8}(codeunits(canonical_json(body))) ||
        throw(ArgumentError("T1 G3 semantic body is not bound to its canonical receipt bytes"))
    isdefined(@__MODULE__, :_vnext_t2_v3_materialize_g3) ||
        throw(ArgumentError("full T2 G3 source materializer is unavailable"))
    materialize_errors = Symbol[]
    declaration = if g3_factory_invocation === nothing
        _vnext_t2_v3_materialize_g3(record, materialize_errors;
            frozen_context=frozen_context, children=children)
    else
        _vnext_t2_v3_materialize_g3(record, materialize_errors;
            frozen_context=frozen_context, children=children,
            g3_factory_invocation=g3_factory_invocation)
    end
    isempty(materialize_errors) && declaration isa G3SFDeclarationV1 ||
        throw(ArgumentError("full T1/T2 G3 declaration/source projection failed: " *
            join(String.(materialize_errors), ",")))
    declaration_receipt_errors = _vnl_t0_errors(record, record.candidate_ref;
        frozen_context=frozen_context)
    isempty(declaration_receipt_errors) ||
        throw(ArgumentError("T1 G3 declaration/factory receipt validation failed: " *
            join(String.(declaration_receipt_errors), ",")))
    isdefined(@__MODULE__, :vnext_t2_v3_rebuild_g3_child_design_source_v1) ||
        throw(ArgumentError("independent G3 child source rebuilder is unavailable"))
    minimum_compiler = frozen_context isa AbstractString &&
        get(ENV, "FCA_G3_WITNESS_MIN_COMPILE", "") == "1"
    if g3_factory_invocation === nothing
        rebuilt = vnext_t2_v3_rebuild_g3_child_design_source_v1(
            source_input, source_input.sha256, body.authored_child_design.source_path;
            minimum_compiler=minimum_compiler)
    else
        required=(:candidate_id,:scenario_id,:source_path,:re_enable_threshold_kelvin)
        all(k->hasproperty(g3_factory_invocation,k),required) &&
            g3_factory_invocation.candidate_id==String(record.candidate_ref.id)[
                length("fusionconceptai://candidate-design/")+1:end] &&
            g3_factory_invocation.scenario_id==body.authored_child_design.scenario_id &&
            g3_factory_invocation.source_path==body.authored_child_design.source_path==
                binding_child.source_locator.source_path ||
            throw(ArgumentError("G3 factory invocation differs from T1 child binding"))
        rebuilt = vnext_t2_v3_rebuild_g3_child_design_source_v1(
            source_input,source_input.sha256,binding_child.source_locator.source_path;
            candidate_id=g3_factory_invocation.candidate_id,
            scenario_id=g3_factory_invocation.scenario_id,
            re_enable_threshold_kelvin=g3_factory_invocation.re_enable_threshold_kelvin,
            minimum_compiler=minimum_compiler)
    end
    binding_child.source_ref.id == "fusionconceptai://candidate-design/" *
        replace(String(record.candidate_ref.id), "fusionconceptai://candidate-design/" => "") *
        "/g3-child-design" && binding_child.body.source_ref == binding_child.source_ref &&
        binding_child.body.source_sha256 == binding_child.source_bytes.sha256 &&
        binding_child.body_hash == canonical_hash(binding_child.body) &&
        binding_child.child_identity_hash == canonical_hash((candidate_ref=binding_child.candidate_ref,
            layer=:G3, child_id=binding_child.child_id, kind=binding_child.kind,
            child_ref=binding_child.child_ref, body_hash=binding_child.body_hash,
            source_ref=binding_child.source_ref, source_sha256=binding_child.source_bytes.sha256)) &&
        canonical_hash(rebuilt) == canonical_hash(body.authored_child_design) &&
        canonical_hash(rebuilt) == canonical_hash(rebuilt_child) ||
        throw(ArgumentError("T1 child source bytes do not rebuild to the admitted authored source"))
    child = rebuilt
    typed = body.authored_typed_ledger_source
    typed isa NamedTuple && typed.source_sha256 == source_input.sha256 &&
        typed.source_path == child.source_path &&
        typed.candidate_ref == record.candidate_ref &&
        typed.resource_network === child.resource_network &&
        typed.effort_ports_without_ledger == child.effort_ports_without_ledger &&
        typed.authored_power_laws == child.authored_power_laws &&
        typed.authored_heat_lift == child.authored_heat_lift &&
        typed.control_resource_links == child.control_resource_links ||
        throw(ArgumentError("G3 typed source fields are not the exact current-builder child values"))
    candidate_id = String(body.candidate_ref.id)
    prefix = "fusionconceptai://candidate-design/"
    startswith(candidate_id, prefix) || throw(ArgumentError("T1 G3 candidate ref namespace is invalid"))
    candidate_id = candidate_id[length(prefix)+1:end]
    child.candidate_id == candidate_id || throw(ArgumentError("G3 candidate ID differs from pinned candidate ref"))
    record.source_identity_hash == canonical_hash((kind=:source, ref=record.source_ref,
        bytes_sha256=record.source_bytes.sha256)) ||
        throw(ArgumentError("T1 G3 source identity hash differs from source bytes"))
    record.declaration_identity_hash == canonical_hash((kind=:declaration,
        ref=record.declaration_ref, bytes_sha256=record.declaration_bytes.sha256)) ||
        throw(ArgumentError("T1 G3 declaration identity hash differs from declaration bytes"))
    source_ref = record.source_ref
    targets = Dict(x.target_id => x for x in declaration.feedback_targets)
    for mapping in child.feedback_source_maps
        haskey(targets, mapping.target_id) || throw(ArgumentError("candidate feedback map has no declaration target"))
        target = targets[mapping.target_id]
        target.target_layer == mapping.target_layer && target.target_path == mapping.target_path &&
            target.quantity == mapping.quantity && target.unit == mapping.target_unit &&
            target.authority.status === :missing ||
            throw(ArgumentError("candidate feedback map differs from exact G3 declaration or asserts authority"))
    end
    source_admission_base = (factory_receipt_hash=canonical_hash(record.factory_receipt),
        declaration_receipt_hash=canonical_hash(record.declaration_receipt),
        factory_result_hash=record.factory_receipt.factory_result_hash,
        declaration_identity_hash=record.declaration_identity_hash,
        source_identity_hash=record.source_identity_hash,
        binding_child_identity_hash=binding_child.child_identity_hash,
        child_identity_hashes=Tuple((kind=child.kind,
            identity_hash=child.child_identity_hash)
            for child in sort(collect(children); by=x -> String(x.kind))),
        child_source_ref=binding_child.source_ref, child_source_sha256=source_input.sha256,
        builder_source_ref=record.source_ref, builder_source_sha256=record.source_bytes.sha256,
        source_context_identity=_g3_authored_source_context_identity_v1(frozen_context))
    source_proof_base = (record=record, children=Tuple(children), rebuilt_child=rebuilt,
        frozen_context=frozen_context)
    source_admission = g3_factory_invocation === nothing ? source_admission_base :
        merge(source_admission_base,(g3_factory_invocation=g3_factory_invocation,))
    source_proof = g3_factory_invocation === nothing ? source_proof_base :
        merge(source_proof_base,(g3_factory_invocation=g3_factory_invocation,))
    _g3_validate_authored_realization_source_v1(record.candidate_ref, candidate_id,
        child.scenario_id, binding_child.source_ref, source_input.sha256,
        child.source_path, child.realization, child.control, typed.resource_network,
        typed.effort_ports_without_ledger, typed.authored_power_laws,
        typed.control_resource_links, typed.command_to_current_map,
        typed.command_to_power_map, typed.power_status_signal_id,
        child.feedback_source_maps, typed.authored_heat_lift;
        g3_factory_invocation=g3_factory_invocation)
    body = (domain="g3-authored-realization-payload-v1",
        candidate_ref=record.candidate_ref, candidate_id=candidate_id,
        scenario_id=child.scenario_id, source_ref=binding_child.source_ref,
        source_path=child.source_path, source_sha256=source_input.sha256,
        builder_source_ref=record.source_ref, builder_source_sha256=record.source_bytes.sha256,
        source_admission=source_admission,
        source_proof_identity=merge((record_candidate_ref=record.candidate_ref,
            record_source_ref=record.source_ref, record_source_sha256=record.source_bytes.sha256,
            record_declaration_ref=record.declaration_ref,
            record_declaration_sha256=record.declaration_bytes.sha256,
            factory_receipt_hash=canonical_hash(record.factory_receipt),
            declaration_receipt_hash=canonical_hash(record.declaration_receipt),
            child_identity_hashes=source_admission.child_identity_hashes,
            rebuilt_child_hash=canonical_hash(rebuilt)),
            g3_factory_invocation===nothing ? NamedTuple() :
                (g3_factory_invocation=g3_factory_invocation,)),
        source_realization=child.realization,
        control_source=child.control, network=typed.resource_network,
        effort_ports_without_ledger=typed.effort_ports_without_ledger,
        power_laws=typed.authored_power_laws,
        control_resource_links=typed.control_resource_links,
        command_to_current_map=typed.command_to_current_map,
        command_to_power_map=typed.command_to_power_map,
        power_status_signal_id=typed.power_status_signal_id,
        feedback_source_maps=child.feedback_source_maps,
        authored_heat_lift=typed.authored_heat_lift,
        claim_scope=:candidate_design_only)
    (record.candidate_ref, candidate_id, child.scenario_id,
        binding_child.source_ref, child.source_path, source_input.sha256,
        record.source_ref, record.source_bytes.sha256, source_admission, source_proof,
        child.realization, child.control, typed.resource_network,
        Tuple(typed.effort_ports_without_ledger), Tuple(typed.authored_power_laws),
        Tuple(typed.control_resource_links), typed.command_to_current_map,
        typed.command_to_power_map, typed.power_status_signal_id,
        Tuple(child.feedback_source_maps), typed.authored_heat_lift,
        :candidate_design_only, canonical_hash(body))
end

g3_authored_realization_payload_v1(record, children, rebuilt_child; frozen_context,
        g3_factory_invocation=nothing) =
    G3AuthoredRealizationPayloadV1(record, children, rebuilt_child;
        frozen_context=frozen_context, g3_factory_invocation=g3_factory_invocation)

semantic_view(x::G3AuthoredRealizationPayloadV1) =
    (candidate_ref=x.candidate_ref, candidate_id=x.candidate_id,
     scenario_id=x.scenario_id, source_ref=x.source_ref, source_path=x.source_path,
     source_sha256=x.source_sha256, builder_source_ref=x.builder_source_ref,
     builder_source_sha256=x.builder_source_sha256, source_admission=x.source_admission,
     source_proof_identity=merge((record_candidate_ref=x.source_proof.record.candidate_ref,
        record_source_ref=x.source_proof.record.source_ref,
        record_source_sha256=x.source_proof.record.source_bytes.sha256,
        record_declaration_ref=x.source_proof.record.declaration_ref,
        record_declaration_sha256=x.source_proof.record.declaration_bytes.sha256,
        factory_receipt_hash=canonical_hash(x.source_proof.record.factory_receipt),
        declaration_receipt_hash=canonical_hash(x.source_proof.record.declaration_receipt),
        child_identity_hashes=Tuple((kind=child.kind, identity_hash=child.child_identity_hash)
            for child in sort(collect(x.source_proof.children); by=c -> String(c.kind))),
        rebuilt_child_hash=canonical_hash(x.source_proof.rebuilt_child)),
        hasproperty(x.source_proof,:g3_factory_invocation) ?
            (g3_factory_invocation=x.source_proof.g3_factory_invocation,) : NamedTuple()),
     source_realization=x.source_realization,
     control_source=x.control_source, network=x.network,
     effort_ports_without_ledger=x.effort_ports_without_ledger,
     power_laws=x.power_laws, control_resource_links=x.control_resource_links,
     command_to_current_map=x.command_to_current_map,
     command_to_power_map=x.command_to_power_map,
     power_status_signal_id=x.power_status_signal_id,
     feedback_source_maps=x.feedback_source_maps, authored_heat_lift=x.authored_heat_lift,
     claim_scope=x.claim_scope, payload_hash=x.payload_hash)

"""Convert the pinned authored G3 source into existing V5 child values.

The return intentionally omits `RealizationControlGenomeV5`: its frozen default
contract requires a ledger entry for every effort port and must reject this
candidate's source_voltage waiver. A source-aware descriptor can consume these
children together with `payload` and retain the strict-default distinction.
"""
function g3_authored_v5_children_v1(payload::G3AuthoredRealizationPayloadV1;
        realization_binding, control_binding, binding_binding, target_refs)
    for b in (realization_binding, control_binding, binding_binding)
        b isa G3ContractBindingV2 && b.candidate_ref == payload.candidate_ref ||
            throw(ArgumentError("authored G3 V5 child binding is not bound to pinned candidate"))
    end
    target_refs isa NamedTuple && hasproperty(target_refs, :G1) &&
        hasproperty(target_refs, :G2) ||
        throw(ArgumentError("authored feedback conversion requires exact G1/G2 contract refs"))
    target_refs.G1 isa GenomeContractRef && target_refs.G2 isa GenomeContractRef ||
        throw(ArgumentError("authored feedback conversion requires GenomeContractRef values"))

    materials = Tuple(G3MaterialDomainV2(x.material_id, x.property,
        x.lower, x.upper, x.unit) for x in payload.source_realization.material_domains)
    manufacturing = Tuple(G3ManufacturingDomainV2(x.process_id, x.parameter,
        x.lower, x.upper, x.unit) for x in payload.source_realization.manufacturing_domains)
    realization = RealizationGenomeV5(realization_binding, payload.network,
        materials, manufacturing; provider_match=:no_match)

    control_source = payload.control_source
    signals = Tuple(G3SignalPortV2(x.port_id, x.signal_kind, x.direction,
        x.unit, x.account_id) for x in control_source.signal_ports)
    links_by_controller = Dict{String,Vector{G3ControlResourceLinkV2}}()
    for link in payload.control_resource_links
        push!(get!(links_by_controller, link.controller_id, G3ControlResourceLinkV2[]), link)
    end
    controllers = Tuple(begin
        links = get(links_by_controller, x.controller_id, G3ControlResourceLinkV2[])
        length(links) == length(x.actuator_port_ids) ||
            throw(ArgumentError("each authored command requires exactly one explicit V2 resource-flow map"))
        for (actuator_id, link) in zip(x.actuator_port_ids, links)
            link.actuator_port_id == actuator_id &&
                link.sensor_port_id in x.sensor_port_ids &&
                link.fault_id in x.fault_ids ||
                throw(ArgumentError("authored current-flow mapping does not join its V1 controller ports"))
        end
        G3ControllerV2(x.controller_id, x.sensor_port_ids, x.actuator_port_ids,
            Tuple(link.resource_port_id for link in links), x.fault_ids,
            Tuple(G3InitialStateV2(s.state_id, s.unit, s.value) for s in x.initial_states),
            Tuple(G3EventV2(e.event_id, e.trigger, e.time, e.action) for e in x.events))
    end for x in control_source.controllers)
    faults = Tuple(G3FaultPathV2(x.fault_id, x.target_id, x.mode,
        x.safe_action, x.detection_signal_id, x.deadline) for x in control_source.faults)
    plan = G3ControlPlanV2(control_source.plan.controller_ids,
        control_source.plan.signal_port_ids, control_source.plan.fault_ids)
    control = ControlGenomeV5(control_binding, signals, controllers, faults, plan;
        provider_match=:no_match)
    control_errors = g3_validate_control(control)
    isempty(control_errors) || throw(ArgumentError("authored G3 V5 control conversion failed: " * join(control_errors, ",")))

    feedback = Tuple(G3FeedbackChannelV2(m.target_id, m.target_layer,
        getproperty(target_refs, m.target_layer), m.channel, m.signal_unit, m.kind,
        m.signal_port_id) for m in payload.feedback_source_maps)
    binding = CoupledRealizationControlBindingV2(binding_binding,
        realization_binding, control_binding, payload.control_resource_links, feedback)
    binding_errors, binding_gaps = g3_validate_binding(binding, realization,
        control; target_refs=target_refs)
    isempty(binding_errors) || throw(ArgumentError("authored G3 V5 binding conversion failed: " * join(binding_errors, ",")))
    (payload=payload, realization=realization, control=control,
     binding=binding, feedback_authority_gaps=binding_gaps,
     bundle_admission=:not_attempted_strict_effort_ledger)
end

const _G3_AUTHORED_SOURCE_DESIGN_SCHEMA_V1 = """
schema_id=GenomeV5/G3/AuthoredSourceDesignAggregateV1
version=v5
fields=contract_binding:G3AuthoredSourceDesignBindingV1,realization:RealizationGenomeV5,
control:ControlGenomeV5,binding:CoupledRealizationControlBindingV2,
authored_payload:G3AuthoredRealizationPayloadV1,admission:G3AdmissionResultV2,candidate_hash:Digest256
payload=child_source_ref/path/SHA,builder_source_ref/SHA,T1 factory/declaration/child identity receipt hashes,
typed network and exact source_voltage effort waiver,two V-I-P laws,control/status/current joins,
heat-lift exact field_allocation budget,feedback target/source SI basis/permutation and exact G1/G2 refs
identity=authored payload hash and three existing V5 child hashes
claims=authored candidate design only; provider_match=no_match; feedback authority unresolved;
no physical, engineering, measurement, provider, or lossless migration credit
"""
const _G3_AUTHORED_SOURCE_DESIGN_CANONICALIZATION_V1 =
    "encoding=UTF-8;line_endings=LF;symbols=ordinal;rationals=normalized;typed_tuple_order=declared"
const _G3_AUTHORED_SOURCE_DESIGN_PROFILE_V1 =
    "admission=source-pinned exact typed joins; effort waiver restricted to source_voltage;
    old G3 V5 default schema remains strict; authority and provider gaps are preserved"

function g3_authored_source_design_contract_ref_v1()
    GenomeContractRef("fusionconceptai://GenomeV5/G3/authored-source-design",
        "v5", digest256_text(_G3_AUTHORED_SOURCE_DESIGN_SCHEMA_V1),
        digest256_text(_G3_AUTHORED_SOURCE_DESIGN_CANONICALIZATION_V1),
        "g3-authored-source-design-v1-" *
            digest256_text(_G3_AUTHORED_SOURCE_DESIGN_PROFILE_V1).value)
end

function g3_authored_source_design_axes_v1()
    uri = "fusionconceptai://GenomeV5/G3/authored-source-design"
    G3VersionAxesV2(QualifiedRefV1(uri * "/payload-schema", "v5"),
        QualifiedRefV1(uri * "/canonicalization-profile", "v5"),
        QualifiedRefV1(uri * "/applicability-profile", "v5"),
        QualifiedRefV1(uri * "/evidence-receipt", "v5"))
end

struct G3AuthoredSourceDesignBindingV1
    contract_ref::GenomeContractRef
    candidate_ref::QualifiedRefV1
    version_axes::G3VersionAxesV2
    binding_hash::Digest256
    function G3AuthoredSourceDesignBindingV1(contract_ref::Any,
            candidate_ref::Any, version_axes::Any)
        contract_ref isa GenomeContractRef && contract_ref == g3_authored_source_design_contract_ref_v1() ||
            throw(ArgumentError("authored source design requires its distinct public v5 contract ref"))
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("authored source design requires a v5 candidate ref"))
        version_axes isa G3VersionAxesV2 &&
            canonical_hash(version_axes) == canonical_hash(g3_authored_source_design_axes_v1()) ||
            throw(ArgumentError("authored source design axes are not authoritative"))
        body = (contract_ref=contract_ref, candidate_ref=candidate_ref,
            version_axes=version_axes)
        new(contract_ref, candidate_ref, version_axes, canonical_hash(body))
    end
end
semantic_view(x::G3AuthoredSourceDesignBindingV1) =
    (contract_ref=x.contract_ref, candidate_ref=x.candidate_ref,
     version_axes=x.version_axes, binding_hash=x.binding_hash)

struct G3AuthoredSourceDesignAggregateV1
    contract_binding::G3AuthoredSourceDesignBindingV1
    realization::RealizationGenomeV5
    control::ControlGenomeV5
    binding::CoupledRealizationControlBindingV2
    authored_payload::G3AuthoredRealizationPayloadV1
    admission::G3AdmissionResultV2
    candidate_hash::Digest256
    function G3AuthoredSourceDesignAggregateV1(payload::Any,
            target_refs::Any)
        payload isa G3AuthoredRealizationPayloadV1 ||
            throw(ArgumentError("G3 source descriptor requires the exact typed authored payload"))
        target_refs isa NamedTuple && hasproperty(target_refs, :G1) &&
            hasproperty(target_refs, :G2) && target_refs.G1 isa GenomeContractRef &&
            target_refs.G2 isa GenomeContractRef ||
            throw(ArgumentError("G3 source descriptor requires actual G1/G2 public contract refs"))
        candidate_binding_proof = _G3AuthoredCandidateBindingProofV1(payload)
        candidate = candidate_binding_proof.candidate_ref
        realization_binding = G3ContractBindingV2(g3_contract_ref(:realization),
            candidate_binding_proof, g3_version_axes(:realization))
        control_binding = G3ContractBindingV2(g3_contract_ref(:control),
            candidate_binding_proof, g3_version_axes(:control))
        binding_binding = G3ContractBindingV2(g3_contract_ref(:binding),
            candidate_binding_proof, g3_version_axes(:binding))
        children = g3_authored_v5_children_v1(payload;
            realization_binding=realization_binding,
            control_binding=control_binding, binding_binding=binding_binding,
            target_refs=target_refs)

        errors = String[]
        default_network_errors = g3_validate_resource_network(payload.network)
        Tuple(sort(default_network_errors)) ==
            ("missing_consumable_entry:source_voltage",) ||
            push!(errors, "default_v5_network_rejection_not_exact_authored_effort_waiver")
        append!(errors, g3_validate_resource_network(payload.network;
            effort_ports_without_ledger=payload.effort_ports_without_ledger))
        append!(errors, g3_validate_control(children.control))
        binding_errors, binding_gaps = g3_validate_binding(children.binding,
            children.realization, children.control; target_refs=target_refs)
        append!(errors, binding_errors)
        material_ids = Set(x.material_id for x in children.realization.material_domains)
        process_ids = Set(x.process_id for x in children.realization.manufacturing_domains)
        for component in payload.network.components
            component.material_id in material_ids || push!(errors, "component_material_domain_missing:" * component.component_id)
            component.manufacturing_process_id in process_ids ||
                push!(errors, "component_manufacturing_domain_missing:" * component.component_id)
        end
        resource_ports = payload.network.resource_ports
        effort_ids = Set(x.port_id for x in resource_ports if x.kind === :effort)
        flow_ids = Set(x.port_id for x in resource_ports if x.kind === :flow)
        any(any(id in effort_ids for id in c.resource_port_ids) &&
            any(id in flow_ids for id in c.resource_port_ids) for c in payload.network.components) ||
            push!(errors, "source_effort_flow_are_not_paired")
        isempty(children.binding.links) && push!(errors, "open_loop_control_binding")
        unique!(errors)
        isempty(errors) || throw(ArgumentError("authored G3 source descriptor failed strict admission: " * join(errors, ",")))

        contract_ref = g3_authored_source_design_contract_ref_v1()
        axes = g3_authored_source_design_axes_v1()
        contract_binding = G3AuthoredSourceDesignBindingV1(contract_ref,
            candidate, axes)
        body = (domain="g3-authored-source-design-aggregate-v1",
            contract_binding=contract_binding, realization=children.realization,
            control=children.control, binding=children.binding,
            authored_payload=payload)
        candidate_hash = canonical_hash(body)
        gaps = Tuple(unique((binding_gaps...,
            "authored_source_contract_only:candidate_design_only")))
        admission = G3AdmissionResultV2(:valid, :no_match, :terminal_deferred,
            (), gaps, children.realization.plan_hash, children.control.plan_hash,
            children.binding.binding_hash, candidate_hash)
        new(contract_binding, children.realization, children.control,
            children.binding, payload, admission, candidate_hash)
    end
end
semantic_view(x::G3AuthoredSourceDesignAggregateV1) =
    (contract_binding=x.contract_binding, realization=x.realization,
     control=x.control, binding=x.binding, authored_payload=x.authored_payload,
     admission=x.admission, candidate_hash=x.candidate_hash)

"Build the source-aware G3 descriptor with actual current G1/G2 public refs."
g3_authored_source_design_aggregate_v1(payload::G3AuthoredRealizationPayloadV1;
    g1_contract_ref::GenomeContractRef, g2_contract_ref::GenomeContractRef) =
    G3AuthoredSourceDesignAggregateV1(payload,
        (G1=g1_contract_ref, G2=g2_contract_ref))



"""Rebuild and verify the G3 authored descriptor from its actual T1/T2 source pins."""
function g3_authored_source_design_payload_valid_v1(g3, record, children,
        rebuilt_child; frozen_context, g3_factory_invocation=nothing)
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa G3AuthoredSourceDesignAggregateV1 || return false
    try
        payload = g3_authored_realization_payload_v1(record, children,
            rebuilt_child; frozen_context=frozen_context,
            g3_factory_invocation=g3_factory_invocation)
        canonical_hash(semantic_view(payload)) == canonical_hash(semantic_view(g3.authored_payload)) ||
            return false
        g1_targets = Tuple(x for x in g3.binding.feedback if x.target_layer === :G1)
        g2_targets = Tuple(x for x in g3.binding.feedback if x.target_layer === :G2)
        length(g1_targets) == 1 && length(g2_targets) == 1 || return false
        target_refs = (G1=only(g1_targets).target_contract_ref,
            G2=only(g2_targets).target_contract_ref)
        expected = G3AuthoredSourceDesignAggregateV1(payload, target_refs)
        canonical_hash(semantic_view(expected)) == canonical_hash(semantic_view(g3))
    catch
        false
    end
end

"""Revalidate a deserialized source-aware descriptor from its retained T1/T2 proof."""
function g3_authored_source_design_payload_valid_v1(g3)
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa G3AuthoredSourceDesignAggregateV1 || return false
    payload = g3.authored_payload
    proof = payload.source_proof
    proof isa NamedTuple || return false
    if propertynames(proof) == (:record, :children, :rebuilt_child, :frozen_context)
        return g3_authored_source_design_payload_valid_v1(g3, proof.record,
            proof.children, proof.rebuilt_child; frozen_context=proof.frozen_context)
    end
    propertynames(proof) == (:record, :children, :rebuilt_child, :frozen_context,
        :g3_factory_invocation) || return false
    g3_authored_source_design_payload_valid_v1(g3, proof.record, proof.children,
        proof.rebuilt_child; frozen_context=proof.frozen_context,
        g3_factory_invocation=proof.g3_factory_invocation)
end

function _g3_replay_authored_payload_candidate_v1(payload)
    payload isa G3AuthoredRealizationPayloadV1 ||
        throw(ArgumentError("source-only G3 binding requires G3AuthoredRealizationPayloadV1"))
    proof = payload.source_proof
    proof isa NamedTuple || throw(ArgumentError(
        "source-only G3 binding requires the retained exact T1/T2 proof"))
    if propertynames(proof) == (:record, :children, :rebuilt_child, :frozen_context)
        rebuilt = g3_authored_realization_payload_v1(proof.record, proof.children,
            proof.rebuilt_child; frozen_context=proof.frozen_context)
    elseif propertynames(proof) == (:record, :children, :rebuilt_child,
            :frozen_context, :g3_factory_invocation)
        rebuilt = g3_authored_realization_payload_v1(proof.record, proof.children,
            proof.rebuilt_child; frozen_context=proof.frozen_context,
            g3_factory_invocation=proof.g3_factory_invocation)
    else
        throw(ArgumentError("source-only G3 binding requires the retained exact T1/T2 proof"))
    end
    canonical_hash(semantic_view(rebuilt)) == canonical_hash(semantic_view(payload)) ||
        throw(ArgumentError("source-only G3 binding payload differs from replayed T1/T2 source"))
    candidate_ref = payload.candidate_ref
    prefix = "fusionconceptai://candidate-design/"
    candidate_ref.version == "v5" && startswith(candidate_ref.id, prefix) ||
        throw(ArgumentError("authored G3 candidate ref is outside the exact candidate-design namespace"))
    candidate_id = candidate_ref.id[length(prefix)+1:end]
    !isempty(candidate_id) && payload.candidate_id == candidate_id &&
        proof.record.candidate_ref == candidate_ref &&
        proof.rebuilt_child.candidate_id == candidate_id &&
        proof.rebuilt_child.scenario_id == payload.scenario_id &&
        proof.rebuilt_child.source_path == payload.source_path &&
        proof.record.source_ref == payload.builder_source_ref &&
        proof.record.source_bytes.sha256 == payload.builder_source_sha256 &&
        only(Tuple(child for child in proof.children if child.kind === :binding)).source_ref ==
            payload.source_ref &&
        only(Tuple(child for child in proof.children if child.kind === :binding)).source_bytes.sha256 ==
            payload.source_sha256 ||
        throw(ArgumentError("source-only G3 candidate, scenario, builder and child source refs do not join"))
    candidate_ref
end

function _g3_authored_candidate_from_binding_proof_v1(proof)
    proof isa _G3AuthoredCandidateBindingProofV1 ||
        throw(ArgumentError("G3 candidate binding requires QualifiedRefV1"))
    proof.payload.candidate_ref == proof.candidate_ref &&
        canonical_hash(semantic_view(proof.payload)) == proof.payload_hash ||
        throw(ArgumentError("source-only G3 candidate proof does not bind its payload"))
    proof.candidate_ref
end

function G3ContractBindingV2(contract_ref::Any,
        payload::G3AuthoredRealizationPayloadV1, version_axes::Any)
    proof = _G3AuthoredCandidateBindingProofV1(payload)
    G3ContractBindingV2(contract_ref, proof, version_axes)
end

export G3AuthoredPowerLawV1, G3ControlResourceLinkV2,
       G3AuthoredRealizationPayloadV1, G3AuthoredSourceDesignBindingV1,
       G3AuthoredSourceDesignAggregateV1, g3_authored_realization_payload_v1,
       g3_authored_v5_children_v1, g3_authored_source_design_contract_ref_v1,
       g3_authored_source_design_axes_v1, g3_authored_source_design_aggregate_v1,
       g3_authored_source_design_payload_valid_v1
