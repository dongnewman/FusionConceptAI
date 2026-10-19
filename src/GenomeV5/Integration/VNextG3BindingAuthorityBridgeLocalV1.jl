"""Local-only bridge from T0 authority recheck to G3 binding V2.

The bridge is deliberately not installed in FusionConceptAI.jl or the default
registry. It accepts the native V1 or V2 checked-present recheck result,
compares its own declaration identity to a separately supplied upstream
commitment, then checks the current-source-backed realization/control states.
`self_consistency` is a structural check only; `authority_verified` requires
the independent expected commitment as well.
"""

struct VNextG3BindingChildExpectedCommitmentV1
    child_kind::Symbol; candidate_ref::QualifiedRefV1
    parent_g3_declaration_ref::QualifiedRefV1; parent_g3_declaration_hash::Digest256
    child_ref::QualifiedRefV1; contract_ref::GenomeContractRef
    source_record_ref::QualifiedRefV1; source_record_hash::Digest256
    source_content_hash::Digest256; child_identity_hash::Digest256; state_hash::Digest256
    function VNextG3BindingChildExpectedCommitmentV1(k,c,p,ph,cr,contract,sr,srh,sch,ih,sth)
        k in (:realization,:control) || throw(ArgumentError("invalid expected child kind"))
        c isa QualifiedRefV1 && c.version=="v5" || throw(ArgumentError("expected child candidate invalid"))
        p isa QualifiedRefV1 && p.version=="v1" || throw(ArgumentError("expected child parent ref invalid"))
        cr isa QualifiedRefV1 || throw(ArgumentError("expected child ref invalid")); contract isa GenomeContractRef || throw(ArgumentError("expected child contract invalid")); sr isa QualifiedRefV1 || throw(ArgumentError("expected child source ref invalid"))
        new(k,c,p,ph,cr,contract,sr,srh,sch,ih,sth)
    end
end

struct VNextG3BindingAuthorityExpectedCommitmentV1
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    g3_declaration_ref::QualifiedRefV1
    g3_declaration_identity_hash::Digest256
    realization::VNextG3BindingChildExpectedCommitmentV1
    control::VNextG3BindingChildExpectedCommitmentV1
    commitment_hash::Digest256
    function VNextG3BindingAuthorityExpectedCommitmentV1(c,b,r,h,realization,control,commitment_hash)
        c isa QualifiedRefV1 && c.version=="v5" || throw(ArgumentError("expected candidate must be v5 ref"))
        r isa QualifiedRefV1 && r.version=="v1" || throw(ArgumentError("expected declaration ref must be v1 ref"))
        realization.child_kind===:realization || throw(ArgumentError("expected realization child kind mismatch"))
        control.child_kind===:control || throw(ArgumentError("expected control child kind mismatch"))
        realization.candidate_ref==c && control.candidate_ref==c || throw(ArgumentError("expected child candidate mismatch"))
        realization.parent_g3_declaration_ref==r && control.parent_g3_declaration_ref==r || throw(ArgumentError("expected child parent ref mismatch"))
        realization.parent_g3_declaration_hash==h && control.parent_g3_declaration_hash==h || throw(ArgumentError("expected child parent hash mismatch"))
        x=new(c,b,r,h,realization,control,commitment_hash)
        x.commitment_hash==vnext_g3_binding_expected_commitment_hash_v1(x) || throw(ArgumentError("expected commitment hash mismatch"))
        x
    end
end
function vnext_g3_binding_expected_commitment_v1(c,b,r,h,realization,control)
    body=(domain="vnext-g3-binding-authority-commitment-v1",candidate_ref=c,bundle_hash=b,g3_declaration_ref=r,g3_declaration_identity_hash=h,realization=realization,control=control)
    VNextG3BindingAuthorityExpectedCommitmentV1(c,b,r,h,realization,control,canonical_hash(body))
end

struct VNextG3BindingAuthorityBridgeLocalResultV1
    status::Symbol
    resolution::Symbol
    self_consistency::Bool
    authority_verified::Bool
    binding_state::Union{Nothing,G3BindingStateV2}
    errors::Tuple{Vararg{Symbol}}
    reasons::Tuple{Vararg{Symbol}}
end

semantic_view(x::VNextG3BindingChildExpectedCommitmentV1)=(child_kind=x.child_kind,candidate_ref=x.candidate_ref,parent_g3_declaration_ref=x.parent_g3_declaration_ref,parent_g3_declaration_hash=x.parent_g3_declaration_hash,child_ref=x.child_ref,contract_ref=x.contract_ref,source_record_ref=x.source_record_ref,source_record_hash=x.source_record_hash,source_content_hash=x.source_content_hash,child_identity_hash=x.child_identity_hash,state_hash=x.state_hash)
_vnext_g3_binding_expected_body(x)=(domain="vnext-g3-binding-authority-commitment-v1",candidate_ref=x.candidate_ref,bundle_hash=x.bundle_hash,g3_declaration_ref=x.g3_declaration_ref,g3_declaration_identity_hash=x.g3_declaration_identity_hash,realization=x.realization,control=x.control)
semantic_view(x::VNextG3BindingAuthorityExpectedCommitmentV1)=merge(_vnext_g3_binding_expected_body(x),(commitment_hash=x.commitment_hash,))
canonical_json(x::VNextG3BindingChildExpectedCommitmentV1)=canonical_json(semantic_view(x))
semantic_view(x::VNextG3BindingAuthorityBridgeLocalResultV1)=(status=x.status,resolution=x.resolution,self_consistency=x.self_consistency,authority_verified=x.authority_verified,binding_state=x.binding_state,errors=x.errors,reasons=x.reasons)
vnext_g3_binding_expected_commitment_hash_v1(x::VNextG3BindingAuthorityExpectedCommitmentV1)=canonical_hash(_vnext_g3_binding_expected_body(x))
canonical_json(x::VNextG3BindingAuthorityExpectedCommitmentV1)=canonical_json(semantic_view(x))
canonical_json(x::VNextG3BindingAuthorityBridgeLocalResultV1)=canonical_json(semantic_view(x))

function vnext_g3_binding_self_consistency_v1(result)
    # V2 is loaded after this bridge by the explicit T2 loader, so resolve its
    # concrete types at call time.  Do not coerce its checked output into the
    # V1 `g1/g2/g3` carrier shape.
    if isdefined(@__MODULE__, :VNextAuthorityRecheckLocalV2Result) &&
            typeof(result) === getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2Result)
        return _vnext_g3_binding_v2_self_consistency(result)
    end
    errors=Symbol[]
    hasproperty(result,:status) && hasproperty(result,:resolution) && hasproperty(result,:output) || return (ok=false,errors=(:result_shape_invalid,))
    result.status===:local_checked_present && result.resolution===:resolved || push!(errors,:t0_not_checked_present)
    out=result.output
    out===nothing && push!(errors,:t0_output_missing)
    if out!==nothing
        for f in (:candidate_ref,:g1,:g2,:g3,:bundle_hash)
            hasproperty(out,f) || push!(errors,Symbol("t0_output_missing_" * String(f)))
        end
        if hasproperty(result,:prior_bundle_sha256) && hasproperty(out,:bundle_hash)
            result.prior_bundle_sha256==out.bundle_hash || push!(errors,:t0_bundle_hash_not_result_hash)
        end
        for layer in (:g1,:g2,:g3)
            hasproperty(out,layer) || continue
            item=getproperty(out,layer)
            hasproperty(item,:candidate_ref) && item.candidate_ref==out.candidate_ref || push!(errors,Symbol("t0_"*String(layer)*"_candidate_mismatch"))
            hasproperty(item,:declaration_ref) || push!(errors,Symbol("t0_"*String(layer)*"_declaration_ref_missing"))
            hasproperty(item,:declaration_identity_hash) || push!(errors,Symbol("t0_"*String(layer)*"_identity_hash_missing"))
        end
    end
    unique!(errors); (ok=isempty(errors),errors=Tuple(errors))
end

function _vnext_g3_binding_v2_self_consistency(result)
    errors=Symbol[]
    checked_type = getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2Checked)
    present_declaration_type = getfield(@__MODULE__, :VNextT0LocalPresentDeclarationV1)
    present_child_type = getfield(@__MODULE__, :VNextT0LocalChildPresentV1)
    result.status===:local_checked_present && result.resolution===:resolved ||
        push!(errors,:t0_not_checked_present)
    result.accepted === false || push!(errors,:t0_v2_authority_claim_invalid)
    result.claim_ceiling === :contract_only || push!(errors,:t0_v2_claim_ceiling_invalid)
    out=result.output
    out isa checked_type || push!(errors,:t0_v2_checked_output_missing)
    if out isa checked_type
        out.candidate_ref isa QualifiedRefV1 || push!(errors,:t0_v2_candidate_invalid)
        out.bundle_hash isa Digest256 || push!(errors,:t0_v2_bundle_hash_invalid)
        result.prior_bundle_sha256==out.bundle_hash || push!(errors,:t0_bundle_hash_not_result_hash)
        if isdefined(@__MODULE__, :_vnext_ar_v2_sha) && isdefined(@__MODULE__, :copy_bytes)
            wire_hash=getfield(@__MODULE__, :_vnext_ar_v2_sha)(
                getfield(@__MODULE__, :copy_bytes)(result.prior_bundle_bytes))
            result.prior_bundle_bytes.sha256==wire_hash ||
                push!(errors,:t0_prior_bundle_bytes_hash_mismatch)
        else
            push!(errors,:t0_prior_bundle_wire_validator_missing)
        end
        Tuple(d.layer for d in out.declarations)==(:G1,:G2,:G3) ||
            push!(errors,:t0_v2_declaration_layer_order_invalid)
        for (i,d) in enumerate(out.declarations)
            d isa present_declaration_type || (push!(errors,Symbol("t0_v2_declaration_not_present_",string(i))); continue)
            d.candidate_ref==out.candidate_ref || push!(errors,Symbol("t0_v2_declaration_candidate_mismatch_",string(i)))
            if isdefined(@__MODULE__, :_vnext_ar_v2_validate_declaration)
                validation=getfield(@__MODULE__, :_vnext_ar_v2_validate_declaration)(d,out.candidate_ref,i)
                isempty(validation) || push!(errors,Symbol("t0_v2_declaration_invalid_",string(i)))
            else
                push!(errors,:t0_v2_declaration_validator_missing)
            end
        end
        Tuple(c.kind for c in out.children)==(:realization,:control,:binding) ||
            push!(errors,:t0_v2_child_kind_order_invalid)
        out.g3_children_deferred === false || push!(errors,:t0_v2_g3_children_deferred)
        for (i,c) in enumerate(out.children)
            c isa present_child_type || (push!(errors,Symbol("t0_v2_child_not_present_",string(i))); continue)
            c.candidate_ref==out.candidate_ref || push!(errors,Symbol("t0_v2_child_candidate_mismatch_",string(i)))
            c.layer===:G3 || push!(errors,Symbol("t0_v2_child_layer_invalid_",string(i)))
            if isdefined(@__MODULE__, :_vnext_ar_v2_validate_child)
                validation=getfield(@__MODULE__, :_vnext_ar_v2_validate_child)(c,out.candidate_ref,i)
                isempty(validation) || push!(errors,Symbol("t0_v2_child_invalid_",string(i)))
            else
                push!(errors,:t0_v2_child_validator_missing)
            end
        end
        seen=Set{String}()
        for f in out.feedback
            f isa VNextT0LocalFeedbackV1 || (push!(errors,:t0_v2_feedback_type_invalid); continue)
            f.candidate_ref==out.candidate_ref || push!(errors,:t0_v2_feedback_candidate_mismatch)
            f.body_hash==canonical_hash(f.body) || push!(errors,:t0_v2_feedback_hash_mismatch)
            f.target_id in seen && push!(errors,:t0_v2_feedback_duplicate)
            push!(seen,f.target_id)
        end
    end
    unique!(errors); (ok=isempty(errors),errors=Tuple(errors))
end

function _vnext_g3_binding_authority_identity(result)
    if isdefined(@__MODULE__, :VNextAuthorityRecheckLocalV2Result) &&
            typeof(result) === getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2Result)
        out=result.output
        g3=out.declarations[3]
        return (candidate_ref=out.candidate_ref,bundle_hash=out.bundle_hash,
            g3_declaration_ref=g3.declaration_ref,
            g3_declaration_identity_hash=g3.declaration_identity_hash)
    end
    out=result.output
    (candidate_ref=out.candidate_ref,bundle_hash=out.bundle_hash,
        g3_declaration_ref=out.g3.declaration_ref,
        g3_declaration_identity_hash=out.g3.declaration_identity_hash)
end

function _vnext_g3_state_info(state, kind, candidate, parent_ref, parent_hash)
    required=(:key,:state_status)
    all(hasproperty(state,f) for f in required) || return nothing,:child_state_shape_invalid
    state.state_status===:present || return nothing,:child_state_not_present
    state.key.candidate_ref==candidate || return nothing,:child_candidate_mismatch
    state.key.parent_g3_declaration_hash==parent_hash || return nothing,:child_parent_hash_mismatch
    src = if hasproperty(state,:source_payload_ref)
        state.source_payload_ref
    elseif hasproperty(state,:payload)
        state.payload
    else
        nothing
    end
    src===nothing && return nothing,:child_source_ref_missing
    for f in (:child_contract_ref,:child_contract_identity_hash,:source_content_hash)
        hasproperty(src,f) || return nothing,Symbol("child_source_"*String(f)*"_missing")
    end
    (hasproperty(src,:source_record_ref) || hasproperty(src,:source_record)) ||
        return nothing,:child_source_record_missing
    hasproperty(state,:initial_source_content_hash) && state.initial_source_content_hash==src.source_content_hash || return nothing,:child_source_hash_mismatch
    state_hash = hasproperty(state,:current_state_hash) ? state.current_state_hash :
        (hasproperty(state,:state_hash) ? state.state_hash : nothing)
    state_hash isa Digest256 || return nothing,:child_state_hash_missing
    child_parent_ref = if hasproperty(state.key,:parent_g3_declaration_ref)
        state.key.parent_g3_declaration_ref
    elseif hasproperty(src,:parent_g3_declaration_ref)
        src.parent_g3_declaration_ref
    else
        nothing
    end
    child_parent_ref===nothing && return nothing,:child_parent_ref_missing
    child_parent_ref==parent_ref || return nothing,:child_parent_ref_mismatch
    child_id=String(kind)*":"*String(state.key.child_id)
    child_ref=QualifiedRefV1("local://GenomeV5/G3/"*child_id,"v1")
    sr = if hasproperty(src,:source_record_ref)
        src.source_record_ref
    elseif hasproperty(src,:source_record)
        src.source_record
    else
        nothing
    end
    sr===nothing && return nothing,:child_source_record_missing
    record_uri = hasproperty(sr,:record_uri) ? sr.record_uri : sr.source_uri
    record_version = hasproperty(sr,:record_version) ? sr.record_version : sr.source_version
    source_ref=QualifiedRefV1(record_uri, record_version)
    source_record_hash = hasproperty(sr,:source_record_hash) ? sr.source_record_hash : sr.record_hash
    info=(child_kind=kind,candidate_ref=candidate,parent_g3_declaration_ref=parent_ref,parent_g3_declaration_hash=parent_hash,child_ref=child_ref,contract_ref=src.child_contract_ref,source_record_ref=source_ref,source_record_hash=source_record_hash,source_content_hash=src.source_content_hash,child_identity_hash=src.child_contract_identity_hash,state_hash=state_hash)
    info,nothing
end

function _vnext_g3binding_present_slot(info)
    G3BindingChildPresentV2(info.child_kind,info.candidate_ref,info.parent_g3_declaration_ref,info.parent_g3_declaration_hash,info.child_ref,info.contract_ref,info.source_record_ref,info.source_record_hash,info.source_content_hash,info.child_identity_hash,info.state_hash)
end
function _vnext_g3binding_child_matches(info, expected)
    fields=(:child_kind,:candidate_ref,:parent_g3_declaration_ref,:parent_g3_declaration_hash,
        :child_ref,:contract_ref,:source_record_ref,:source_record_hash,:source_content_hash,
        :child_identity_hash,:state_hash)
    all(getproperty(info,f)==getproperty(expected,f) for f in fields)
end

function vnext_g3_binding_authority_bridge_local_v1(result,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state, control_state, key::G3BindingChildKeyV2;
        initial_links=())
    if hasproperty(result,:status) && result.status === :typed_absent
        return VNextG3BindingAuthorityBridgeLocalResultV1(:typed_absent,:terminal_deferred,
            false,false,nothing,(),(:t0_typed_absent,))
    end
    if hasproperty(result,:status) && result.status === :fail_closed
        return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,
            false,false,nothing,(:t0_fail_closed,),())
    end
    sc=vnext_g3_binding_self_consistency_v1(result)
    !sc.ok && return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,false,false,nothing,sc.errors,(:self_consistency_failed,))
    identity=_vnext_g3_binding_authority_identity(result)
    expected.candidate_ref==identity.candidate_ref || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:expected_candidate_mismatch,),())
    expected.bundle_hash==identity.bundle_hash || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:expected_bundle_hash_mismatch,),())
    expected.g3_declaration_ref==identity.g3_declaration_ref || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:expected_g3_declaration_ref_mismatch,),())
    expected.g3_declaration_identity_hash==identity.g3_declaration_identity_hash || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:expected_g3_identity_hash_mismatch,),())
    key.candidate_ref==expected.candidate_ref || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:key_candidate_mismatch,),())
    key.parent_g3_declaration_ref==expected.g3_declaration_ref || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:key_parent_ref_mismatch,),())
    key.parent_g3_declaration_hash==expected.g3_declaration_identity_hash || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:key_parent_hash_mismatch,),())
    ri,re=_vnext_g3_state_info(realization_state,:realization,expected.candidate_ref,expected.g3_declaration_ref,expected.g3_declaration_identity_hash)
    ri===nothing && return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(re,),())
    ci,ce=_vnext_g3_state_info(control_state,:control,expected.candidate_ref,expected.g3_declaration_ref,expected.g3_declaration_identity_hash)
    ci===nothing && return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(ce,),())
    _vnext_g3binding_child_matches(ri,expected.realization) || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:realization_expected_commitment_mismatch,),())
    _vnext_g3binding_child_matches(ci,expected.control) || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:control_expected_commitment_mismatch,),())
    rs=_vnext_g3binding_present_slot(ri); cs=_vnext_g3binding_present_slot(ci)
    payload=g3_binding_v2_source_payload(key,initial_links;realization_slot=rs,control_slot=cs,complete=true,source_hash=expected.commitment_hash)
    state=g3_binding_v2_admit(payload)
    state.state_status===:present || return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,true,false,nothing,(:v2_present_admission_failed,),())
    VNextG3BindingAuthorityBridgeLocalResultV1(:local_checked_present,:resolved,true,true,state,(),())
end

function vnext_g3_binding_authority_bridge_local_v1(result, expected,
        realization_state, control_state, key; initial_links=())
    expected isa VNextG3BindingAuthorityExpectedCommitmentV1 ||
        return VNextG3BindingAuthorityBridgeLocalResultV1(:fail_closed,:none,false,false,nothing,(:expected_commitment_type_invalid,),())
    vnext_g3_binding_authority_bridge_local_v1(result,expected,realization_state,control_state,key;initial_links=initial_links)
end

export VNextG3BindingChildExpectedCommitmentV1,VNextG3BindingAuthorityExpectedCommitmentV1,VNextG3BindingAuthorityBridgeLocalResultV1,vnext_g3_binding_expected_commitment_v1,vnext_g3_binding_expected_commitment_hash_v1,vnext_g3_binding_self_consistency_v1,vnext_g3_binding_authority_bridge_local_v1
