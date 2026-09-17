"""Deterministic, bounded, exact whole-program conditional exploration."""

struct _CEGProposal
    source::ConditionalProgramENodeV1; target::TypedASTProgramV1; conditions::Tuple{Vararg{EqualityConditionRequirementV1}}
    rule::WholeProgramConditionalRewriteV1; orientation::RewriteOrientationV1; source_bytes::String; target_bytes::String
end

function _ceg_cached_program_bytes(cache::_CEGDerivationCacheV1,
        program::TypedASTProgramV1)::String
    invoke(_tac_cached_program_bytes,
        Tuple{_TACDerivationCanonicalCacheV1,TypedASTProgramV1}, cache.canonical, program)
end

function _ceg_cached_program_hash(cache::_CEGDerivationCacheV1,
        program::TypedASTProgramV1)::Digest256
    invoke(_tac_cached_program_hash,
        Tuple{_TACDerivationCanonicalCacheV1,TypedASTProgramV1}, cache.canonical, program)
end

function _ceg_current_program_bytes(cache::_CEGDerivationCacheV1,
        program::TypedASTProgramV1)::String
    invoke(_tac_authoritative_program_bytes,
        Tuple{_TACDerivationCanonicalCacheV1,TypedASTProgramV1},cache.canonical,program)
end
_ceg_current_program_hash(cache::_CEGDerivationCacheV1, program::TypedASTProgramV1)::Digest256 =
    invoke(_ceg_hash_text,Tuple{String},invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,program))

function _ceg_cached_condition_bytes(cache::_CEGDerivationCacheV1, conditions::Tuple)::String
    if haskey(cache.condition_bytes, conditions)
        cached=cache.condition_bytes[conditions]
        current=invoke(_ceg_condition_bytes,Tuple{Tuple},conditions)
        invoke(_ceg_sealed_equal,Tuple{String,String},cached,current) ||
            throw(ArgumentError("mutated conditional cache condition bytes"))
        return cached
    end
    bytes = invoke(_ceg_condition_bytes, Tuple{Tuple}, conditions)
    cache.condition_bytes[conditions] = bytes
    bytes
end

function _ceg_rule_fingerprint(rule::WholeProgramConditionalRewriteV1)::String
    io=invoke(_ccbw_new,Tuple{});
    _ccbw_utf8!(io,invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},getfield(rule,:rule_ref)))
    _ccbw_utf8!(io,invoke(_tac_program_fingerprint,Tuple{TypedASTProgramV1},getfield(rule,:lhs_program)))
    _ccbw_utf8!(io,invoke(_tac_program_fingerprint,Tuple{TypedASTProgramV1},getfield(rule,:rhs_program)))
    _ccbw_utf8!(io,invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(rule,:required_conditions)))
    _ccbw_utf8!(io,invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},getfield(rule,:checker_ref)))
    _ccbw_utf8!(io,getfield(getfield(rule,:checker_contract_hash),:value))
    invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end

function _ceg_cached_rule_bytes(cache::_CEGDerivationCacheV1,
        rule::WholeProgramConditionalRewriteV1)::String
    current=invoke(_ceg_rule_bytes,
        Tuple{WholeProgramConditionalRewriteV1,_CEGDerivationCacheV1},rule,cache)
    if haskey(cache.rule_bytes, rule)
        entry=cache.rule_bytes[rule]
        entry isa _CEGRuleCacheEntryV1 || throw(ArgumentError("invalid conditional rule cache entry"))
        getfield(entry,:owner_token) === getfield(cache,:owner_token) ||
            throw(ArgumentError("cross-derivation conditional rule cache entry"))
        entry_rule=getfield(entry,:rule)
        entry_rule === rule || throw(ArgumentError("conditional rule cache entry belongs to another rule"))
        invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},
            getfield(entry_rule,:rule_ref),getfield(rule,:rule_ref)) ||
            throw(ArgumentError("conditional rule cache rule reference mismatch"))
        invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},
            getfield(entry_rule,:lhs_hash),getfield(rule,:lhs_hash)) &&
            invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},
                getfield(entry_rule,:rhs_hash),getfield(rule,:rhs_hash)) ||
            throw(ArgumentError("conditional rule cache side hash mismatch"))
        invoke(_ceg_sealed_equal,Tuple{String,String},getfield(entry,:fingerprint),
            invoke(_ceg_rule_fingerprint,Tuple{WholeProgramConditionalRewriteV1},rule)) ||
            throw(ArgumentError("mutated conditional rule cache entry"))
        invoke(_ceg_sealed_equal,Tuple{String,String},getfield(entry,:bytes),current) ||
            throw(ArgumentError("conditional rule cache differs from current canonical bytes"))
        invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},
            invoke(_ceg_hash_text,Tuple{String},getfield(entry,:bytes)),
            invoke(_ceg_hash_text,Tuple{String},current)) ||
            throw(ArgumentError("conditional rule cache canonical hash mismatch"))
        return current
    end
    bytes = current
    cache.rule_bytes[rule] = _CEGRuleCacheEntryV1(getfield(cache,:owner_token),rule,
        bytes,invoke(_ceg_rule_fingerprint,Tuple{WholeProgramConditionalRewriteV1},rule))
    bytes
end

_ceg_ast_bytes(p::TypedASTProgramV1)=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},p)
_ceg_hash_text(s::String)=invoke(_tac_hash_json,Tuple{String},s)
_ceg_program_hash(p::TypedASTProgramV1)=invoke(_ceg_hash_text,Tuple{String},invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},p))
function _ceg_condition_bytes(c::Tuple)
    io=invoke(_ccbw_new,Tuple{})
    invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,c)
    invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_request_program_bytes(p::TypedASTProgramV1)
    try
        return invoke(_ceg_ast_bytes,Tuple{TypedASTProgramV1},p)
    catch e
        e isa CanonicalizationDeferred || rethrow()
        # Request identity remains closed when exact graph permutation is deferred:
        # encode the actual stored fields in their raw tuple order.
        io=_ccbw_new(); _ccbw_ascii!(io,"{\"input_ports\":")
        _ccbw_utf8!(io,invoke(_tac_value_string,Tuple{Any},getfield(p,:input_ports)))
        _ccbw_ascii!(io,",\"nodes\":["); i=1; nodes=getfield(p,:nodes); n=fieldcount(typeof(nodes))
        while i<=n
            node=getfield(nodes,i)
            i>1 && _ccbw_byte!(io,UInt8(',')); _ccbw_ascii!(io,"{\"type\":"); _ccbw_quote!(io,string(nameof(typeof(node))))
            j=1; nf=fieldcount(typeof(node)); while j<=nf
                _ccbw_ascii!(io,",\"field"*string(j)*"\":"); _ccbw_utf8!(io,invoke(_tac_value_string,Tuple{Any},getfield(node,j)))
                j+=1
            end
            _ccbw_byte!(io,UInt8('}')); i+=1
        end
        _ccbw_ascii!(io,"],\"roots\":")
        _ccbw_utf8!(io,invoke(_tac_value_string,Tuple{Any},getfield(p,:roots)))
        _ccbw_ascii!(io,",\"used_manifest_bindings\":")
        _ccbw_utf8!(io,invoke(_tac_value_string,Tuple{Any},getfield(p,:used_manifest_bindings)))
        _ccbw_byte!(io,UInt8('}')); _ccbw_finish(io)
    end
end
function _ceg_request_rules_bytes(rs::ConditionalRewriteSetV1)
    try
        return invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1},rs)
    catch e
        e isa CanonicalizationDeferred || rethrow()
        io=_ccbw_new(); _ccbw_byte!(io,UInt8('[')); i=1
        rules=getfield(rs,:rules); n=fieldcount(typeof(rules)); while i<=n
            r=getfield(rules,i)
            i>1&&_ccbw_byte!(io,UInt8(',')); _ccbw_utf8!(io,invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},getfield(r,:rule_ref))); _ccbw_utf8!(io,invoke(_ceg_request_program_bytes,Tuple{TypedASTProgramV1},getfield(r,:lhs_program))); _ccbw_utf8!(io,invoke(_ceg_request_program_bytes,Tuple{TypedASTProgramV1},getfield(r,:rhs_program))); _ccbw_utf8!(io,invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(r,:required_conditions))); i+=1
        end
        _ccbw_byte!(io,UInt8(']')); _ccbw_finish(io)
    end
end
function _ceg_registry_projection(source::TypedASTProgramV1,rs::ConditionalRewriteSetV1,registry::OperatorRegistryV1)
    rules=getfield(rs,:rules); nr=fieldcount(typeof(rules)); np=1+2*nr
    programs=Vector{TypedASTProgramV1}(undef,np); Core.arrayset(true,programs,source,1); pi=2; ri=1
    while ri<=nr
        r=getfield(rules,ri); Core.arrayset(true,programs,getfield(r,:lhs_program),pi); Core.arrayset(true,programs,getfield(r,:rhs_program),pi+1); pi+=2;ri+=1
    end
    ref_count=0; pi=1
    while pi<=np
        program=Core.arrayref(true,programs,pi); bindings=getfield(program,:used_manifest_bindings); ref_count+=fieldcount(typeof(bindings)); nodes=getfield(program,:nodes); ni=1; nn=fieldcount(typeof(nodes)); while ni<=nn; typeof(getfield(nodes,ni))===ASTApplyV1 && (ref_count+=1); ni+=1; end; pi+=1
    end
    refs=Vector{QualifiedRefV1}(undef,ref_count); ref_i=1; pi=1
    while pi<=np
        program=Core.arrayref(true,programs,pi); bindings=getfield(program,:used_manifest_bindings); bi=1; bn=fieldcount(typeof(bindings)); while bi<=bn; Core.arrayset(true,refs,getfield(getfield(getfield(bindings,bi),1),:qualified),ref_i); ref_i+=1;bi+=1;end
        nodes=getfield(program,:nodes); ni=1; nn=fieldcount(typeof(nodes)); while ni<=nn; node=getfield(nodes,ni); if typeof(node)===ASTApplyV1; Core.arrayset(true,refs,getfield(getfield(node,:operator_ref),:qualified),ref_i); ref_i+=1; end; ni+=1; end; pi+=1
    end
    refs=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},refs,x -> invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},x)); out=Vector{String}(undef,ref_count); out_count=0; i=1; n=Core.arraysize(refs,1)
    while i<=n
        ref=Core.arrayref(true,refs,i)
        refkey=invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},ref); duplicate=false; oi=1
        while oi<=out_count; invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,out,oi),refkey) && (duplicate=true; break); oi+=1; end
        if duplicate
            i+=1
            continue
        end
        match_count=0; matched=nothing
        manifests=getfield(registry,:operators); mi=1; mn=fieldcount(typeof(manifests)); while mi<=mn
            manifest=getfield(manifests,mi)
            candidate=getfield(getfield(manifest,:operator_ref),:qualified)
            if invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},candidate,ref)
                match_count+=1; matched=manifest
            end
            mi+=1
        end
        match_count===0 && (entry=refkey*"\0<missing>")
        match_count===1 && (entry=refkey*"\0"*getfield(getfield(matched,:manifest_hash),:value))
        match_count>1 && throw(ArgumentError("registry contains ambiguous operator reference"))
        out_count+=1; Core.arrayset(true,out,entry,out_count)
        i+=1
    end
    io=_ccbw_new(); i=1; while i<=out_count; i>1&&_ccbw_byte!(io,UInt8(0)); _ccbw_utf8!(io,Core.arrayref(true,out,i)); i+=1; end; _ccbw_finish(io)
end
_ceg_member_key(p::TypedASTProgramV1,c)=invoke(_ceg_ast_bytes,Tuple{TypedASTProgramV1},p)*"\0"*invoke(_ceg_condition_bytes,Tuple{Tuple},c)
_ceg_member_key(m::ConditionalProgramENodeV1)=invoke(_ceg_member_key,Tuple{TypedASTProgramV1,Tuple},getfield(m,:program),getfield(m,:cumulative_conditions))
function _ceg_member_identity(cache::_CEGDerivationCacheV1,
        program::TypedASTProgramV1, conditions::Tuple)
    key = _CEGMemberKeyV1(invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1}, cache, program),
        invoke(_ceg_cached_condition_bytes, Tuple{_CEGDerivationCacheV1,Tuple}, cache, conditions))
    key
end
function _ceg_cached_member_identity(cache::_CEGDerivationCacheV1,
        member::ConditionalProgramENodeV1)
    if haskey(cache.member_keys, member)
        cached=cache.member_keys[member]
        cached isa _CEGMemberKeyV1 || throw(ArgumentError("invalid conditional member cache entry"))
        expected=_ceg_member_identity(cache,getfield(member,:program),getfield(member,:cumulative_conditions))
        isequal(cached,expected) || throw(ArgumentError("mutated conditional member cache entry"))
        return cached
    end
    key = _ceg_member_identity(cache, getfield(member,:program), getfield(member,:cumulative_conditions))
    cache.member_keys[member] = key
    key
end
function _ceg_merge_conditions(a::Tuple,b::Tuple)
    na=fieldcount(typeof(a)); nb=fieldcount(typeof(b)); n=na+nb
    n===0 && return ()
    vals=Vector{EqualityConditionRequirementV1}(undef,n); i=1
    while i<=na
        Core.arrayset(true,vals,getfield(a,i),i); i+=1
    end
    j=1
    while j<=nb
        Core.arrayset(true,vals,getfield(b,j),i); i+=1; j+=1
    end
    ordered=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},vals,x -> invoke(_ceg_condition_bytes,Tuple{Tuple},(x,)))
    out=Vector{EqualityConditionRequirementV1}(undef,n); keys=Vector{String}(undef,n); count=0; i=1
    while i<=n
        value=Core.arrayref(true,ordered,i); key=invoke(_ceg_condition_bytes,Tuple{Tuple},(value,)); j=1; duplicate=false
        while j<=count
            invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,keys,j),key) && (duplicate=true; break)
            j+=1
        end
        if !duplicate
            count+=1; Core.arrayset(true,out,value,count); Core.arrayset(true,keys,key,count)
        end
        i+=1
    end
    ntuple(i -> Core.arrayref(true,out,i),count)
end
function _ceg_merge_conditions(a::Tuple,b::Tuple,cache::_CEGDerivationCacheV1)
    na=fieldcount(typeof(a)); nb=fieldcount(typeof(b)); n=na+nb
    n===0 && return ()
    vals=Vector{EqualityConditionRequirementV1}(undef,n); i=1
    while i<=na; Core.arrayset(true,vals,getfield(a,i),i); i+=1; end
    j=1
    while j<=nb; Core.arrayset(true,vals,getfield(b,j),i); i+=1; j+=1; end
    ordered=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},vals,
        x -> invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,(x,)))
    out=Vector{EqualityConditionRequirementV1}(undef,n); keys=Vector{String}(undef,n); count=0; i=1
    while i<=n
        value=Core.arrayref(true,ordered,i); key=invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,(value,)); j=1; duplicate=false
        while j<=count; invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,keys,j),key) && (duplicate=true; break); j+=1; end
        if !duplicate; count+=1; Core.arrayset(true,out,value,count); Core.arrayset(true,keys,key,count); end
        i+=1
    end
    ntuple(i -> Core.arrayref(true,out,i),count)
end
_ceg_proposal_key(p::_CEGProposal)=invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},getfield(p,:rule))*"\0"*getfield(p,:source_bytes)*"\0"*getfield(p,:target_bytes)*"\0"*(getfield(p,:orientation)===rewrite_forward ? "1" : "2")*"\0"*invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(p,:conditions))
function _ceg_cached_proposal_identity(cache::_CEGDerivationCacheV1, p::_CEGProposal)
    if haskey(cache.proposal_keys, p)
        cached=cache.proposal_keys[p]
        cached isa _CEGProposalKeyV1 || throw(ArgumentError("invalid conditional proposal cache entry"))
        expected = _CEGProposalKeyV1(
            invoke(_ceg_cached_rule_bytes,
                Tuple{_CEGDerivationCacheV1,WholeProgramConditionalRewriteV1},
                cache,getfield(p,:rule)),
            invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(getfield(p,:source),:program)),
            invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(p,:target)),
            getfield(p,:orientation)===rewrite_forward ? UInt8(1) : UInt8(2),
            invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,getfield(p,:conditions)))
        isequal(cached,expected) || throw(ArgumentError("mutated conditional proposal cache entry"))
        return cached
    end
    key = _CEGProposalKeyV1(
        invoke(_ceg_cached_rule_bytes,
            Tuple{_CEGDerivationCacheV1,WholeProgramConditionalRewriteV1},
            cache,getfield(p,:rule)),
        invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(getfield(p,:source),:program)),
        invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(p,:target)),
        getfield(p,:orientation)===rewrite_forward ? UInt8(1) : UInt8(2),
        invoke(_ceg_cached_condition_bytes, Tuple{_CEGDerivationCacheV1,Tuple}, cache, getfield(p,:conditions)))
    cache.proposal_keys[p] = key
    key
end
function _ceg_cached_proposal_sort_key(cache::_CEGDerivationCacheV1, p::_CEGProposal)::String
    if haskey(cache.proposal_sort_keys, p)
        cached=cache.proposal_sort_keys[p]
        expected_key=invoke(_ceg_cached_proposal_identity,Tuple{_CEGDerivationCacheV1,_CEGProposal},cache,p)
        expected=expected_key.rule_bytes*"\0"*expected_key.source_bytes*"\0"*expected_key.target_bytes*"\0"*
            (expected_key.orientation===UInt8(1) ? "1" : "2")*"\0"*expected_key.condition_bytes
        invoke(_ceg_sealed_equal,Tuple{String,String},cached,expected) ||
            throw(ArgumentError("mutated conditional proposal sort cache entry"))
        return cached
    end
    key = invoke(_ceg_cached_proposal_identity,
        Tuple{_CEGDerivationCacheV1,_CEGProposal}, cache, p)
    # Preserve the historical bytewise sort order exactly.  The structured
    # key is used for lookup; this legacy projection is only an ordering key.
    text = key.rule_bytes*"\0"*key.source_bytes*"\0"*key.target_bytes*"\0"*
        (key.orientation === UInt8(1) ? "1" : "2")*"\0"*key.condition_bytes
    cache.proposal_sort_keys[p] = text
    text
end
_ceg_new_node(p::TypedASTProgramV1,c::Tuple,provenance=nothing)=ConditionalProgramENodeV1(p,c,provenance)
function _ceg_sealed_program_hash(cache::_CEGDerivationCacheV1,
        p::TypedASTProgramV1)
    invoke(_ceg_cached_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,p)
    invoke(_ceg_cached_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,p)
    entry=getfield(getfield(cache,:canonical),:entries)[p]
    _CEGSealedProgramHashV1(cache.owner_token,entry,_CEG_SEAL_GUARD)
end
function _ceg_validate_sealed_program(cache::_CEGDerivationCacheV1,
        p::TypedASTProgramV1, sealed::_CEGSealedProgramHashV1)
    getfield(sealed,:owner_token) === getfield(cache,:owner_token) ||
        throw(ArgumentError("cross-derivation sealed program hash"))
    getfield(sealed,:program) === p ||
        throw(ArgumentError("sealed program hash belongs to another program"))
    bytes=invoke(_ceg_cached_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,p)
    getfield(sealed,:bytes) === bytes || throw(ArgumentError("stale sealed program bytes"))
    hash=invoke(_ceg_cached_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,p)
    getfield(sealed,:value) == hash || throw(ArgumentError("stale sealed program hash"))
    sealed
end
function _ceg_new_node(cache::_CEGDerivationCacheV1, p::TypedASTProgramV1,
        c::Tuple, provenance=nothing)
    sealed=invoke(_ceg_sealed_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,p)
    invoke(_ceg_validate_sealed_program,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1,_CEGSealedProgramHashV1},
        cache,p,sealed)
    ConditionalProgramENodeV1(p,c,provenance,sealed)
end
_ceg_new_trace(r,rule,orient,source,target,step,conditions::Tuple)=ConditionalRewriteTraceStepV1(r,rule,orient,source,target,step,conditions)
function _ceg_new_trace(cache::_CEGDerivationCacheV1, round::Int,
        rule::WholeProgramConditionalRewriteV1, orient::RewriteOrientationV1,
        source::TypedASTProgramV1, target::TypedASTProgramV1, step::Int,
        conditions::Tuple)
    source_bytes=invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source)
    target_bytes=invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,target)
    expected_source=orient===rewrite_forward ? getfield(rule,:lhs_program) : getfield(rule,:rhs_program)
    expected_target=orient===rewrite_forward ? getfield(rule,:rhs_program) : getfield(rule,:lhs_program)
    expected_source_bytes=invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,expected_source)
    expected_target_bytes=invoke(_ceg_current_program_bytes,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,expected_target)
    rule_bytes=invoke(_ceg_cached_rule_bytes,
        Tuple{_CEGDerivationCacheV1,WholeProgramConditionalRewriteV1},cache,rule)
    source_hash=invoke(_ceg_cached_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source)
    target_hash=invoke(_ceg_cached_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,target)
    fragments=_CEGTraceFragmentsV1(cache.owner_token,source_bytes,target_bytes,
        expected_source_bytes,expected_target_bytes,
        source_hash,target_hash,
        invoke(_ceg_hash_text,Tuple{String},rule_bytes),rule_bytes,
        getfield(rule,:rule_ref),_CEG_SEAL_GUARD)
    ConditionalRewriteTraceStepV1(round,rule,orient,source,target,step,conditions,fragments)
end
_ceg_rule_hash(r::WholeProgramConditionalRewriteV1)=invoke(_ceg_hash_text,Tuple{String},invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},r))
function _ceg_request_hash(source::TypedASTProgramV1,rs::ConditionalRewriteSetV1,registry::OperatorRegistryV1,budget::ConditionalEGraphBudgetV1,profile::CanonicalizationProfileV1)
    body=invoke(_ceg_request_program_bytes,Tuple{TypedASTProgramV1},source)*"\0"*
        invoke(_ceg_request_rules_bytes,Tuple{ConditionalRewriteSetV1},rs)*"\0"*
        invoke(_ceg_bindings_bytes,Tuple{Tuple},getfield(source,:used_manifest_bindings))*"\0"*
        invoke(_ceg_registry_projection,Tuple{TypedASTProgramV1,ConditionalRewriteSetV1,OperatorRegistryV1},source,rs,registry)*"\0"*
        invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},budget)*"\0"*
        invoke(_ceg_profile_bytes,Tuple{CanonicalizationProfileV1},profile)
    invoke(_ceg_hash_text,Tuple{String},body)
end
function _ceg_request_hash(source::TypedASTProgramV1,rs::ConditionalRewriteSetV1,
        registry::OperatorRegistryV1,budget::ConditionalEGraphBudgetV1,
        profile::CanonicalizationProfileV1, cache::_CEGDerivationCacheV1)
    body=invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source)*"\0"*
        invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1,_CEGDerivationCacheV1},rs,cache)*"\0"*
        invoke(_ceg_bindings_bytes,Tuple{Tuple},getfield(source,:used_manifest_bindings))*"\0"*
        invoke(_ceg_registry_projection,Tuple{TypedASTProgramV1,ConditionalRewriteSetV1,OperatorRegistryV1},source,rs,registry)*"\0"*
        invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},budget)*"\0"*
        invoke(_ceg_profile_bytes,Tuple{CanonicalizationProfileV1},profile)
    invoke(_ceg_hash_text,Tuple{String},body)
end
function _ceg_deferred_request_hash(source::TypedASTProgramV1,registry::OperatorRegistryV1,budget::ConditionalEGraphBudgetV1,profile::CanonicalizationProfileV1)
    body=invoke(_ceg_request_program_bytes,Tuple{TypedASTProgramV1},source)*"\0[]\0"*
        invoke(_ceg_bindings_bytes,Tuple{Tuple},getfield(source,:used_manifest_bindings))*"\0"*
        invoke(_ceg_registry_projection,Tuple{TypedASTProgramV1,ConditionalRewriteSetV1,OperatorRegistryV1},source,ConditionalRewriteSetV1(()),registry)*"\0"*
        invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},budget)*"\0"*
        invoke(_ceg_profile_bytes,Tuple{CanonicalizationProfileV1},profile)
    invoke(_ceg_hash_text,Tuple{String},body)
end
function _ceg_candidate_provenance(p, round, root_source)
    src=getfield(p,:source); prior=getfield(src,:provenance) isa ConditionalEqualityProvenanceV1 ? getfield(getfield(src,:provenance),:trace) : ()
        step=invoke(_ceg_new_trace,Tuple{Int,WholeProgramConditionalRewriteV1,RewriteOrientationV1,TypedASTProgramV1,TypedASTProgramV1,Int,Tuple},round,getfield(p,:rule),getfield(p,:orientation),getfield(src,:program),getfield(p,:target),fieldcount(typeof(prior))+1,getfield(p,:conditions))
    prov=ConditionalEqualityProvenanceV1(root_source,getfield(p,:target),getfield(p,:conditions),(prior...,step))
    (invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},prov),step,prov)
end
function _ceg_candidate_provenance(cache::_CEGDerivationCacheV1, p::_CEGProposal,
        round::Int, root_source::TypedASTProgramV1)
    src=getfield(p,:source)
    prior=getfield(src,:provenance) isa ConditionalEqualityProvenanceV1 ?
        getfield(getfield(src,:provenance),:trace) : ()
    step=invoke(_ceg_new_trace,
        Tuple{_CEGDerivationCacheV1,Int,WholeProgramConditionalRewriteV1,RewriteOrientationV1,TypedASTProgramV1,TypedASTProgramV1,Int,Tuple},
        cache,round,getfield(p,:rule),getfield(p,:orientation),getfield(src,:program),
        getfield(p,:target),fieldcount(typeof(prior))+1,getfield(p,:conditions))
    source_hash=invoke(_ceg_current_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,root_source)
    target_hash=invoke(_ceg_current_program_hash,
        Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(p,:target))
    fragments=_CEGProvenanceFragmentsV1(cache.owner_token,source_hash,target_hash,_CEG_SEAL_GUARD)
    prov=ConditionalEqualityProvenanceV1(root_source,getfield(p,:target),
        getfield(p,:conditions),(prior...,step),fragments)
    (invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},prov),step,prov)
end

function _ceg_saturate_components(source::TypedASTProgramV1,rs::ConditionalRewriteSetV1,registry::OperatorRegistryV1,
        saturation_budget::ConditionalEGraphBudgetV1,canonicalization_profile::CanonicalizationProfileV1)
    _ceg_saturate_components(source,rs,registry,saturation_budget,canonicalization_profile,_CEGDerivationCacheV1())
end
function _ceg_saturate_components(source::TypedASTProgramV1,rs::ConditionalRewriteSetV1,registry::OperatorRegistryV1,
        saturation_budget::ConditionalEGraphBudgetV1,canonicalization_profile::CanonicalizationProfileV1,
        cache::_CEGDerivationCacheV1)
    (fieldcount(typeof(getfield(source,:nodes))) in 1:32 && fieldcount(typeof(getfield(source,:roots))) in 1:8) || throw(ArgumentError("source is outside the conditional e-graph profile"))
    try
        invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1,Bool},source,registry,fieldcount(typeof(getfield(rs,:rules)))===0)
        rules=getfield(rs,:rules); ri=1; rn=fieldcount(typeof(rules)); while ri<=rn; r=getfield(rules,ri); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},getfield(r,:lhs_program),registry); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},getfield(r,:rhs_program),registry); ri+=1; end
    catch e
        rethrow()
    end
    max_programs=getfield(saturation_budget,:max_programs); max_trace_steps=getfield(saturation_budget,:max_trace_steps)
    source_hash=source_node=nothing; members=Vector{ConditionalProgramENodeV1}(undef,max_programs); member_count=0
    visited_index=Dict{_CEGMemberKeyV1,Nothing}(); visited_count=0
    try
        source_hash=invoke(_ceg_cached_program_hash,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source)
        source_node=invoke(_ceg_new_node,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1,Tuple},cache,source,())
        member_count=1; Core.arrayset(true,members,source_node,member_count)
        visited_index[invoke(_ceg_cached_member_identity,Tuple{_CEGDerivationCacheV1,ConditionalProgramENodeV1},cache,source_node)]=nothing; visited_count=1
        ncodeunits(invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source)) <= getfield(getfield(canonicalization_profile,:budget),:max_bytes) || throw(CanonicalizationDeferred("conditional source byte budget exhausted"))
        ri=1; rule_values=getfield(rs,:rules); max_bytes=getfield(getfield(canonicalization_profile,:budget),:max_bytes)
        while ri<=fieldcount(typeof(rule_values)); ncodeunits(invoke(_ceg_cached_rule_bytes,Tuple{_CEGDerivationCacheV1,WholeProgramConditionalRewriteV1},cache,getfield(rule_values,ri))) <= max_bytes || throw(CanonicalizationDeferred("conditional rule byte budget exhausted")); ri+=1; end
        ncodeunits(invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1,_CEGDerivationCacheV1},rs,cache)) <= getfield(getfield(canonicalization_profile,:budget),:max_bytes) || throw(CanonicalizationDeferred("conditional rule-set byte budget exhausted"))
    catch
        rethrow()
    end
    active=Vector{ConditionalProgramENodeV1}(undef,1); Core.arrayset(true,active,source_node,1); active_count=1; traces=Vector{ConditionalRewriteTraceStepV1}(undef,max_trace_steps); trace_count=0; attempts=0; rounds=0; complete=false; reason=conditional_fixed_point
    while true
        active_count===0&&(complete=true;break)
        rounds>=getfield(saturation_budget,:max_rounds)&&(reason=conditional_budget_rounds;break)
        checked=2*active_count*fieldcount(typeof(getfield(rs,:rules)))
        attempts+checked>getfield(saturation_budget,:max_rewrite_attempts)&&(reason=conditional_budget_rewrite_attempts;break)
        proposals=Vector{_CEGProposal}(undef,checked); proposal_count=0; proposal_index=Dict{_CEGProposalKeyV1,Nothing}()
        active_sorted=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},active,
            m -> begin
                k=invoke(_ceg_cached_member_identity,Tuple{_CEGDerivationCacheV1,ConditionalProgramENodeV1},cache,m)
                k.program_bytes*"\0"*k.condition_bytes
            end); ai=1; while ai<=active_count
            m=Core.arrayref(true,active_sorted,ai)
            mb=invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(m,:program))
            ri=1; rules=getfield(rs,:rules); rn=fieldcount(typeof(rules)); while ri<=rn
                r=getfield(rules,ri); lhsb=invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(r,:lhs_program)); rhsb=invoke(_ceg_current_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,getfield(r,:rhs_program)); merged=invoke(_ceg_merge_conditions,Tuple{Tuple,Tuple,_CEGDerivationCacheV1},getfield(m,:cumulative_conditions),getfield(r,:required_conditions),cache)
                if invoke(_ceg_sealed_equal,Tuple{String,String},mb,lhsb)
                    candidate=_CEGProposal(m,getfield(r,:rhs_program),merged,r,rewrite_forward,mb,rhsb); key=invoke(_ceg_cached_proposal_identity,Tuple{_CEGDerivationCacheV1,_CEGProposal},cache,candidate)
                    if !haskey(proposal_index,key); proposal_index[key]=nothing; proposal_count+=1; Core.arrayset(true,proposals,candidate,proposal_count); end
                end
                if invoke(_ceg_sealed_equal,Tuple{String,String},mb,rhsb)
                    candidate=_CEGProposal(m,getfield(r,:lhs_program),merged,r,rewrite_reverse,mb,lhsb); key=invoke(_ceg_cached_proposal_identity,Tuple{_CEGDerivationCacheV1,_CEGProposal},cache,candidate)
                    if !haskey(proposal_index,key); proposal_index[key]=nothing; proposal_count+=1; Core.arrayset(true,proposals,candidate,proposal_count); end
                end
                ri+=1
            end
            ai+=1
        end
        attempts+=checked
        proposal_count===0&&(complete=true;break)
        proposals_compact=Vector{_CEGProposal}(undef,proposal_count); pi=1; while pi<=proposal_count; Core.arrayset(true,proposals_compact,Core.arrayref(true,proposals,pi),pi); pi+=1; end
        proposals_sorted=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},proposals_compact,
            p -> invoke(_ceg_cached_proposal_sort_key,Tuple{_CEGDerivationCacheV1,_CEGProposal},cache,p))
        best=Vector{Tuple{String,_CEGProposal,String}}(undef,proposal_count); best_count=0; best_index=Dict{_CEGMemberKeyV1,Int}(); provenance_cache=IdDict{Any,Any}(); pi=1
        while pi<=proposal_count
            p=Core.arrayref(true,proposals_sorted,pi)
            identity=invoke(_ceg_member_identity,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1,Tuple},cache,getfield(p,:target),getfield(p,:conditions))
            k=identity.program_bytes*"\0"*identity.condition_bytes
            candidate_provenance=get(provenance_cache,p,nothing)
            candidate_provenance === nothing && (candidate_provenance=invoke(_ceg_candidate_provenance,Tuple{_CEGDerivationCacheV1,_CEGProposal,Int,TypedASTProgramV1},cache,p,rounds+1,source); provenance_cache[p]=candidate_provenance)
            witness=getfield(candidate_provenance,1)
            found=get(best_index,identity,0)
            if found===0
                best_count+=1; best_index[identity]=best_count; Core.arrayset(true,best,(k,p,witness),best_count)
            else
                prior=Core.arrayref(true,best,found)
                invoke(_ceg_sealed_less,Tuple{String,String},witness,getfield(prior,3)) && Core.arrayset(true,best,(k,p,witness),found)
            end
            pi+=1
        end
        best_compact=Vector{Tuple{String,_CEGProposal,String}}(undef,best_count); fi=1; while fi<=best_count; Core.arrayset(true,best_compact,Core.arrayref(true,best,fi),fi); fi+=1; end
        best_sorted=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},best_compact,x->getfield(x,1)); fresh=Vector{_CEGProposal}(undef,best_count); fresh_count=0; fi=1
        while fi<=best_count
            item=Core.arrayref(true,best_sorted,fi)
            proposal=getfield(item,2)
            identity=invoke(_ceg_member_identity,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1,Tuple},cache,getfield(proposal,:target),getfield(proposal,:conditions))
            seen=haskey(visited_index,identity)
            if !seen; fresh_count+=1; Core.arrayset(true,fresh,getfield(item,2),fresh_count); end; fi+=1
        end
        member_count+fresh_count>max_programs&&(reason=conditional_budget_programs;break)
        trace_count+fresh_count>max_trace_steps&&(reason=conditional_budget_trace_steps;break)
        fresh_count===0&&(complete=true;break);rounds+=1
        next=Vector{ConditionalProgramENodeV1}(undef,fresh_count); next_count=0; fi=1
        while fi<=fresh_count
            p=Core.arrayref(true,fresh,fi)
            candidate_provenance=get(provenance_cache,p,nothing)
            if candidate_provenance === nothing
                candidate_provenance=invoke(_ceg_candidate_provenance,Tuple{_CEGDerivationCacheV1,_CEGProposal,Int,TypedASTProgramV1},cache,p,rounds,source)
            end
            _,step,prov=candidate_provenance
            m=invoke(_ceg_new_node,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1,Tuple,ConditionalEqualityProvenanceV1},cache,getfield(p,:target),getfield(p,:conditions),prov); member_count+=1; Core.arrayset(true,members,m,member_count); next_count+=1; Core.arrayset(true,next,m,next_count); trace_count+=1; Core.arrayset(true,traces,step,trace_count); visited_count+=1; visited_index[invoke(_ceg_cached_member_identity,Tuple{_CEGDerivationCacheV1,ConditionalProgramENodeV1},cache,m)]=nothing; fi+=1
        end
        active=next; active_count=next_count
    end
    members_compact=Vector{ConditionalProgramENodeV1}(undef,member_count); i=1; while i<=member_count; Core.arrayset(true,members_compact,Core.arrayref(true,members,i),i); i+=1; end
    members_sorted=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},members_compact,
        m -> begin
            k=invoke(_ceg_cached_member_identity,Tuple{_CEGDerivationCacheV1,ConditionalProgramENodeV1},cache,m)
            k.program_bytes*"\0"*k.condition_bytes
        end)
    eclass=ConditionalEClassV1(source,ntuple(i -> Core.arrayref(true,members_sorted,i),member_count)); usage=ConditionalEGraphUsageV1(member_count,attempts,rounds,trace_count); state=complete ? saturation_complete : saturation_incomplete
    (source_hash,eclass,state,usage,complete,reason)
end
_ceg_normalize_rules(rules)=typeof(rules)===ConditionalRewriteSetV1 ? rules : ConditionalRewriteSetV1(rules)

function derive_conditional_program_egraph(source::TypedASTProgramV1,rules,registry::OperatorRegistryV1;
        saturation_budget::ConditionalEGraphBudgetV1=ConditionalEGraphBudgetV1(),canonicalization_profile=default_canonicalization_profile())
    canonicalization_profile isa CanonicalizationProfileV1 || throw(ArgumentError("canonicalization_profile must be CanonicalizationProfileV1"))
    rs=invoke(_ceg_normalize_rules,Tuple{Any},rules)
    ConditionalEGraphDerivationResultV1(source,rs,registry,saturation_budget,canonicalization_profile)
end

function _ceg_trace_rule(rs,s)
        rules=getfield(rs,:rules); i=1; n=fieldcount(typeof(rules)); while i<=n; r=getfield(rules,i); invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},getfield(r,:rule_ref),getfield(s,:rule_ref))&&invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},invoke(_ceg_rule_hash,Tuple{WholeProgramConditionalRewriteV1},r),getfield(s,:rule_hash))&&return r; i+=1; end; nothing
end
function _ceg_replay_result(source::TypedASTProgramV1,target::TypedASTProgramV1,rules,registry::OperatorRegistryV1,provenance::ConditionalEqualityProvenanceV1)
    rs=invoke(_ceg_normalize_rules,Tuple{Any},rules); cache=_CEGDerivationCacheV1(); current=source; cond=(); checked=0
    try
        invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},source,registry); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},target,registry)
        rules=getfield(rs,:rules); ri=1; rn=fieldcount(typeof(rules)); while ri<=rn; r=getfield(rules,ri); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},getfield(r,:lhs_program),registry); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},getfield(r,:rhs_program),registry); ri+=1; end
    catch e
        (e isa ArgumentError || e isa CanonicalizationDeferred) || rethrow()
        return _ConditionalTraceReplayResultV1(false,current,cond,0)
    end
    invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(provenance,:source_hash),invoke(_ceg_cached_program_hash,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source))&&invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(provenance,:target_hash),invoke(_ceg_cached_program_hash,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,target)) || return _ConditionalTraceReplayResultV1(false,current,cond,0)
    invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,target),invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,source))&&fieldcount(typeof(getfield(provenance,:trace)))===0&&return _ConditionalTraceReplayResultV1(true,current,cond,0)
    trace=getfield(provenance,:trace); ti=1; tn=fieldcount(typeof(trace)); while ti<=tn
        s=getfield(trace,ti)
        r=invoke(_ceg_trace_rule,Tuple{ConditionalRewriteSetV1,ConditionalRewriteTraceStepV1},rs,s); r===nothing&&return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        expected=getfield(s,:orientation)===rewrite_forward ? getfield(r,:lhs_program) : getfield(r,:rhs_program); next=getfield(s,:orientation)===rewrite_forward ? getfield(r,:rhs_program) : getfield(r,:lhs_program)
        invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,current),invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,expected))||return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},invoke(_ceg_cached_program_hash,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,current),getfield(s,:source_hash))&&invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},invoke(_ceg_cached_program_hash,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,next),getfield(s,:target_hash))||return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        cond=invoke(_ceg_merge_conditions,Tuple{Tuple,Tuple,_CEGDerivationCacheV1},cond,getfield(r,:required_conditions),cache); invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,cond),invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,getfield(s,:cumulative_conditions)))||return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,getfield(s,:required_conditions)),invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,getfield(r,:required_conditions))) || return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        getfield(s,:step) === checked + 1 && getfield(s,:round) === checked + 1 || return _ConditionalTraceReplayResultV1(false,current,cond,checked)
        current=next;checked+=1;ti+=1
    end
    invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,getfield(provenance,:conditions)),invoke(_ceg_cached_condition_bytes,Tuple{_CEGDerivationCacheV1,Tuple},cache,cond)) || return _ConditionalTraceReplayResultV1(false,current,cond,checked)
    invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,current),invoke(_ceg_cached_program_bytes,Tuple{_CEGDerivationCacheV1,TypedASTProgramV1},cache,target)) ? _ConditionalTraceReplayResultV1(true,current,cond,checked) : _ConditionalTraceReplayResultV1(false,current,cond,checked)
end
replay_conditional_rewrite_trace(source::TypedASTProgramV1,target::TypedASTProgramV1,rules,registry::OperatorRegistryV1,provenance::ConditionalEqualityProvenanceV1) =
    getfield(invoke(_ceg_replay_result,Tuple{TypedASTProgramV1,TypedASTProgramV1,Any,OperatorRegistryV1,ConditionalEqualityProvenanceV1},source,target,rules,registry,provenance),:valid)

function query_conditional_equality(graph::DerivedConditionalEGraphV1,target::TypedASTProgramV1)
    ConditionalEqualityQueryResultV1(graph,target)
end
