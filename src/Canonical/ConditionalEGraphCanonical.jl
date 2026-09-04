"""Closed byte writers for P1 values; no semantic_view/canonical_json recursion."""
const _CEG_DOMAIN="fusionconceptai:v4:p1"
_ceg_ref(io::Base.GenericIOBuffer,r::QualifiedRefV1)=(_ccbw_ascii!(io,"{\"id\":");_ccbw_quote!(io,getfield(r,:id));_ccbw_ascii!(io,",\"version\":");_ccbw_quote!(io,getfield(r,:version));_ccbw_byte!(io,UInt8('}')))
function _ceg_ref_bytes(r::QualifiedRefV1)
    io=invoke(_ccbw_new,Tuple{}); invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,r); invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
_ceg_digest(io::Base.GenericIOBuffer,d::Digest256)=(_ccbw_ascii!(io,"{\"value\":");_ccbw_quote!(io,getfield(d,:value));_ccbw_byte!(io,UInt8('}')))
_ceg_ast(io::Base.GenericIOBuffer,p::TypedASTProgramV1)=_ccbw_utf8!(io,invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},p))
function _ceg_write_conditions!(io::Base.GenericIOBuffer,cs::Tuple)
    _ccbw_byte!(io,UInt8('['));i=1; n=fieldcount(typeof(cs))
    while i<=n
        c=getfield(cs,i)
        i>1&&_ccbw_byte!(io,UInt8(','));_ccbw_ascii!(io,"{\"condition_contract_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(c,:condition_contract_hash));_ccbw_ascii!(io,",\"condition_ref\":");invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(c,:condition_ref));_ccbw_byte!(io,UInt8('}'));i+=1
    end
    _ccbw_byte!(io,UInt8(']'))
end
function _ceg_bindings_bytes(bs::Tuple)
    io=invoke(_ccbw_new,Tuple{}); _ccbw_byte!(io,UInt8('[')); i=1
    n=fieldcount(typeof(bs)); while i<=n
        b=getfield(bs,i)
        i>1&&_ccbw_byte!(io,UInt8(',')); _ccbw_ascii!(io,"{\"hash\":"); invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(b,2)); _ccbw_ascii!(io,",\"ref\":"); invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(getfield(b,1),:qualified)); _ccbw_byte!(io,UInt8('}')); i+=1
    end
    _ccbw_byte!(io,UInt8(']')); invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_wrap(kind::String,body::String)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"canonicalization_version\":\"1\",\"domain\":");_ccbw_quote!(io,_CEG_DOMAIN*":"*kind*":v1");_ccbw_ascii!(io,",\"kind\":");_ccbw_quote!(io,kind);_ccbw_ascii!(io,",\"payload\":");_ccbw_utf8!(io,body);_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_rule_body(r::WholeProgramConditionalRewriteV1)
    _ceg_digest_equal(invoke(_ceg_program_hash,Tuple{TypedASTProgramV1},getfield(r,:lhs_program)),getfield(r,:lhs_hash)) || throw(ArgumentError("spoofed lhs hash")); _ceg_digest_equal(invoke(_ceg_program_hash,Tuple{TypedASTProgramV1},getfield(r,:rhs_program)),getfield(r,:rhs_hash)) || throw(ArgumentError("spoofed rhs hash"))
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"checker_contract_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(r,:checker_contract_hash));_ccbw_ascii!(io,",\"checker_ref\":");invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(r,:checker_ref));_ccbw_ascii!(io,",\"lhs_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(r,:lhs_hash));_ccbw_ascii!(io,",\"lhs_program\":");invoke(_ceg_ast,Tuple{Base.GenericIOBuffer,TypedASTProgramV1},io,getfield(r,:lhs_program));_ccbw_ascii!(io,",\"required_conditions\":");invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,getfield(r,:required_conditions));_ccbw_ascii!(io,",\"rhs_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(r,:rhs_hash));_ccbw_ascii!(io,",\"rhs_program\":");invoke(_ceg_ast,Tuple{Base.GenericIOBuffer,TypedASTProgramV1},io,getfield(r,:rhs_program));_ccbw_ascii!(io,",\"rule_ref\":");invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(r,:rule_ref));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
_ceg_rule_bytes(r::WholeProgramConditionalRewriteV1)=invoke(_ceg_wrap,Tuple{String,String},"whole_program_conditional_rewrite",invoke(_ceg_rule_body,Tuple{WholeProgramConditionalRewriteV1},r))
function _ceg_set_body(s::ConditionalRewriteSetV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"rules\":[");i=1;rules=getfield(s,:rules);n=fieldcount(typeof(rules));while i<=n;r=getfield(rules,i);i>1&&_ccbw_byte!(io,UInt8(','));_ccbw_utf8!(io,invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},r));i+=1;end;_ccbw_ascii!(io,"]}");invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
_ceg_rule_set_bytes(s::ConditionalRewriteSetV1)=invoke(_ceg_wrap,Tuple{String,String},"conditional_rewrite_set",invoke(_ceg_set_body,Tuple{ConditionalRewriteSetV1},s))
function _ceg_member_body(m::ConditionalProgramENodeV1)
    _ceg_digest_equal(invoke(_ceg_program_hash,Tuple{TypedASTProgramV1},getfield(m,:program)),getfield(m,:program_hash)) || throw(ArgumentError("spoofed program hash"))
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"cumulative_conditions\":");invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,getfield(m,:cumulative_conditions));_ccbw_ascii!(io,",\"program\":");invoke(_ceg_ast,Tuple{Base.GenericIOBuffer,TypedASTProgramV1},io,getfield(m,:program));_ccbw_ascii!(io,",\"program_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(m,:program_hash));_ccbw_ascii!(io,",\"provenance\":");getfield(m,:provenance)===nothing ? _ccbw_ascii!(io,"null") : _ccbw_utf8!(io,invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},getfield(m,:provenance)));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
_ceg_member_bytes(m::ConditionalProgramENodeV1)=invoke(_ceg_wrap,Tuple{String,String},"conditional_program_enode",invoke(_ceg_member_body,Tuple{ConditionalProgramENodeV1},m))
function _ceg_trace_body(t::ConditionalRewriteTraceStepV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"cumulative_conditions\":");invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,getfield(t,:cumulative_conditions));_ccbw_ascii!(io,",\"orientation\":");_ccbw_quote!(io,getfield(t,:orientation)===rewrite_forward ? "rewrite_forward" : "rewrite_reverse");_ccbw_ascii!(io,",\"required_conditions\":");invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,getfield(t,:required_conditions));_ccbw_ascii!(io,",\"round\":");_ccbw_integer!(io,Int64(getfield(t,:round)));_ccbw_ascii!(io,",\"rule_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(t,:rule_hash));_ccbw_ascii!(io,",\"rule_ref\":");invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(t,:rule_ref));_ccbw_ascii!(io,",\"source_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(t,:source_hash));_ccbw_ascii!(io,",\"step\":");_ccbw_integer!(io,Int64(getfield(t,:step)));_ccbw_ascii!(io,",\"target_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(t,:target_hash));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
_ceg_trace_bytes(t::ConditionalRewriteTraceStepV1)=invoke(_ceg_wrap,Tuple{String,String},"conditional_rewrite_trace_step",invoke(_ceg_trace_body,Tuple{ConditionalRewriteTraceStepV1},t))
function _ceg_provenance_bytes(p::ConditionalEqualityProvenanceV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"conditions\":");invoke(_ceg_write_conditions!,Tuple{Base.GenericIOBuffer,Tuple},io,getfield(p,:conditions));_ccbw_ascii!(io,",\"source_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(p,:source_hash));_ccbw_ascii!(io,",\"target_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(p,:target_hash));_ccbw_ascii!(io,",\"trace\":[");i=1;trace=getfield(p,:trace);n=fieldcount(typeof(trace));while i<=n;t=getfield(trace,i);i>1&&_ccbw_byte!(io,UInt8(','));_ccbw_utf8!(io,invoke(_ceg_trace_bytes,Tuple{ConditionalRewriteTraceStepV1},t));i+=1;end;_ccbw_ascii!(io,"]}"); body=invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io);invoke(_ceg_wrap,Tuple{String,String},"conditional_equality_provenance",body)
end
function _ceg_budget_bytes(b::ConditionalEGraphBudgetV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"max_programs\":");_ccbw_integer!(io,Int64(getfield(b,:max_programs)));_ccbw_ascii!(io,",\"max_rewrite_attempts\":");_ccbw_integer!(io,Int64(getfield(b,:max_rewrite_attempts)));_ccbw_ascii!(io,",\"max_rounds\":");_ccbw_integer!(io,Int64(getfield(b,:max_rounds)));_ccbw_ascii!(io,",\"max_trace_steps\":");_ccbw_integer!(io,Int64(getfield(b,:max_trace_steps)));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_profile_bytes(p::CanonicalizationProfileV1)
    b=getfield(p,:budget); io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"budget\":{");_ccbw_ascii!(io,"\"max_bytes\":");_ccbw_integer!(io,Int64(getfield(b,:max_bytes)));_ccbw_ascii!(io,",\"max_refinement_rounds\":");_ccbw_integer!(io,Int64(getfield(b,:max_refinement_rounds)));_ccbw_ascii!(io,",\"max_search_nodes\":");_ccbw_integer!(io,Int64(getfield(b,:max_search_nodes)));_ccbw_ascii!(io,",\"max_vertices\":");_ccbw_integer!(io,Int64(getfield(b,:max_vertices)));_ccbw_ascii!(io,"},\"profile_id\":");_ccbw_quote!(io,getfield(p,:profile_id));_ccbw_ascii!(io,",\"version\":");_ccbw_quote!(io,getfield(p,:version));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_usage_bytes(u::ConditionalEGraphUsageV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"programs\":");_ccbw_integer!(io,Int64(getfield(u,:programs)));_ccbw_ascii!(io,",\"rewrite_attempts\":");_ccbw_integer!(io,Int64(getfield(u,:rewrite_attempts)));_ccbw_ascii!(io,",\"rounds\":");_ccbw_integer!(io,Int64(getfield(u,:rounds)));_ccbw_ascii!(io,",\"trace_steps\":");_ccbw_integer!(io,Int64(getfield(u,:trace_steps)));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_members_bytes(ms::Tuple)
    io=invoke(_ccbw_new,Tuple{});_ccbw_byte!(io,UInt8('['));i=1;n=fieldcount(typeof(ms));while i<=n;m=getfield(ms,i);i>1&&_ccbw_byte!(io,UInt8(','));_ccbw_utf8!(io,invoke(_ceg_member_bytes,Tuple{ConditionalProgramENodeV1},m));i+=1;end;_ccbw_byte!(io,UInt8(']'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function _ceg_equivalence_bytes(g::DerivedConditionalEGraphV1)
    _ceg_digest_equal(invoke(_ceg_program_hash,Tuple{TypedASTProgramV1},getfield(g,:source_program)),getfield(g,:source_hash)) || throw(ArgumentError("spoofed source hash"))
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"canonicalization_profile\":");_ccbw_utf8!(io,invoke(_ceg_profile_bytes,Tuple{CanonicalizationProfileV1},getfield(g,:canonicalization_profile)));_ccbw_ascii!(io,",\"manifest_bindings\":");_ccbw_utf8!(io,invoke(_ceg_bindings_bytes,Tuple{Tuple},getfield(g,:used_manifest_bindings)));_ccbw_ascii!(io,",\"members\":");_ccbw_utf8!(io,invoke(_ceg_members_bytes,Tuple{Tuple},getfield(getfield(g,:eclass),:members)));_ccbw_ascii!(io,",\"rewrite_set\":");_ccbw_utf8!(io,invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1},getfield(g,:rewrite_set)));_ccbw_ascii!(io,",\"saturation_state\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(g,:saturation_state))));_ccbw_ascii!(io,",\"source_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(g,:source_hash));_ccbw_ascii!(io,",\"source_program\":");invoke(_ceg_ast,Tuple{Base.GenericIOBuffer,TypedASTProgramV1},io,getfield(g,:source_program));_ccbw_byte!(io,UInt8('}'));invoke(_ceg_wrap,Tuple{String,String},"conditional_equivalence",invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io))
end
function _ceg_attempt_bytes(g::DerivedConditionalEGraphV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"budget\":");_ccbw_utf8!(io,invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},getfield(g,:saturation_budget)));_ccbw_ascii!(io,",\"complete\":");_ccbw_ascii!(io, getfield(g,:complete) ? "true" : "false");_ccbw_ascii!(io,",\"equivalence\":");_ccbw_utf8!(io,invoke(_ceg_equivalence_bytes,Tuple{DerivedConditionalEGraphV1},g));_ccbw_ascii!(io,",\"saturation_state\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(g,:saturation_state))));_ccbw_ascii!(io,",\"stop_reason\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(g,:stop_reason))));_ccbw_ascii!(io,",\"usage\":");_ccbw_utf8!(io,invoke(_ceg_usage_bytes,Tuple{ConditionalEGraphUsageV1},getfield(g,:usage)));_ccbw_byte!(io,UInt8('}'));invoke(_ceg_wrap,Tuple{String,String},"conditional_saturation_attempt",invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io))
end
function _ceg_condition_top_bytes(x::EqualityConditionRequirementV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"condition_contract_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(x,:condition_contract_hash));_ccbw_ascii!(io,",\"condition_ref\":");invoke(_ceg_ref,Tuple{Base.GenericIOBuffer,QualifiedRefV1},io,getfield(x,:condition_ref));_ccbw_byte!(io,UInt8('}'));invoke(_ceg_wrap,Tuple{String,String},"equality_condition_requirement",invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io))
end
canonical_json(x::EqualityConditionRequirementV1)=invoke(_ceg_condition_top_bytes,Tuple{EqualityConditionRequirementV1},x)
canonical_json(x::WholeProgramConditionalRewriteV1)=invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},x);canonical_json(x::ConditionalRewriteSetV1)=invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1},x);canonical_json(x::ConditionalEGraphBudgetV1)=invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_budget",invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},x));canonical_json(x::ConditionalProgramENodeV1)=invoke(_ceg_member_bytes,Tuple{ConditionalProgramENodeV1},x);canonical_json(x::ConditionalRewriteTraceStepV1)=invoke(_ceg_trace_bytes,Tuple{ConditionalRewriteTraceStepV1},x);canonical_json(x::DerivedConditionalEGraphV1)=invoke(_ceg_attempt_bytes,Tuple{DerivedConditionalEGraphV1},x)
canonical_hash(x::EqualityConditionRequirementV1)=_ceg_hash_text(invoke(_ceg_condition_top_bytes,Tuple{EqualityConditionRequirementV1},x));canonical_hash(x::WholeProgramConditionalRewriteV1)=_ceg_hash_text(invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},x));canonical_hash(x::ConditionalRewriteSetV1)=_ceg_hash_text(invoke(_ceg_rule_set_bytes,Tuple{ConditionalRewriteSetV1},x));canonical_hash(x::ConditionalEGraphBudgetV1)=_ceg_hash_text(invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_budget",invoke(_ceg_budget_bytes,Tuple{ConditionalEGraphBudgetV1},x)));canonical_hash(x::ConditionalProgramENodeV1)=_ceg_hash_text(invoke(_ceg_member_bytes,Tuple{ConditionalProgramENodeV1},x));canonical_hash(x::ConditionalRewriteTraceStepV1)=_ceg_hash_text(invoke(_ceg_trace_bytes,Tuple{ConditionalRewriteTraceStepV1},x));canonical_hash(x::DerivedConditionalEGraphV1)=_ceg_hash_text(invoke(_ceg_attempt_bytes,Tuple{DerivedConditionalEGraphV1},x))

conditional_equivalence_hash(g::DerivedConditionalEGraphV1) = getfield(g,:complete) ? _ceg_hash_text(invoke(_ceg_equivalence_bytes,Tuple{DerivedConditionalEGraphV1},g)) : throw(ArgumentError("conditional equivalence hash requires a complete graph"))
saturation_attempt_hash(g::DerivedConditionalEGraphV1) = _ceg_hash_text(invoke(_ceg_attempt_bytes,Tuple{DerivedConditionalEGraphV1},g))
canonical_json(x::ConditionalEqualityProvenanceV1)=invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},x); canonical_hash(x::ConditionalEqualityProvenanceV1)=_ceg_hash_text(invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},x))
canonical_json(x::ConditionalEGraphUsageV1)=invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_usage",invoke(_ceg_usage_bytes,Tuple{ConditionalEGraphUsageV1},x)); canonical_hash(x::ConditionalEGraphUsageV1)=_ceg_hash_text(invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_usage",invoke(_ceg_usage_bytes,Tuple{ConditionalEGraphUsageV1},x)))
function _ceg_eclass_top_bytes(x::ConditionalEClassV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"members\":");_ccbw_utf8!(io,invoke(_ceg_members_bytes,Tuple{Tuple},getfield(x,:members)));_ccbw_ascii!(io,",\"source_program_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(x,:source_program_hash));_ccbw_byte!(io,UInt8('}'));invoke(_ceg_wrap,Tuple{String,String},"conditional_eclass",invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io))
end
canonical_json(x::ConditionalEClassV1)=invoke(_ceg_eclass_top_bytes,Tuple{ConditionalEClassV1},x); canonical_hash(x::ConditionalEClassV1)=_ceg_hash_text(invoke(_ceg_eclass_top_bytes,Tuple{ConditionalEClassV1},x))
function _ceg_query_result_top_bytes(x::ConditionalEqualityQueryResultV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"provenance\":");getfield(x,:provenance)===nothing ? _ccbw_ascii!(io,"null") : _ccbw_utf8!(io,invoke(_ceg_provenance_bytes,Tuple{ConditionalEqualityProvenanceV1},getfield(x,:provenance)));_ccbw_ascii!(io,",\"status\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(x,:status))));_ccbw_byte!(io,UInt8('}'));invoke(_ceg_wrap,Tuple{String,String},"conditional_equality_query_result",invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io))
end
canonical_json(x::ConditionalEqualityQueryResultV1)=invoke(_ceg_query_result_top_bytes,Tuple{ConditionalEqualityQueryResultV1},x)
canonical_hash(x::ConditionalEqualityQueryResultV1)=_ceg_hash_text(invoke(_ceg_query_result_top_bytes,Tuple{ConditionalEqualityQueryResultV1},x))
function _ceg_derivation_result_body(x::ConditionalEGraphDerivationResultV1)
    io=invoke(_ccbw_new,Tuple{});_ccbw_ascii!(io,"{\"artifact\":");getfield(x,:artifact)===nothing ? _ccbw_ascii!(io,"null") : _ccbw_utf8!(io,invoke(_ceg_attempt_bytes,Tuple{DerivedConditionalEGraphV1},getfield(x,:artifact)));_ccbw_ascii!(io,",\"derivation_request_hash\":");invoke(_ceg_digest,Tuple{Base.GenericIOBuffer,Digest256},io,getfield(x,:derivation_request_hash));_ccbw_ascii!(io,",\"reason\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(x,:reason))));_ccbw_ascii!(io,",\"status\":");_ccbw_quote!(io,invoke(String,Tuple{Symbol},invoke(Symbol,Tuple{Enum},getfield(x,:status))));_ccbw_byte!(io,UInt8('}'));invoke(_ccbw_finish,Tuple{Base.GenericIOBuffer},io)
end
function canonical_json(x::ConditionalEGraphDerivationResultV1)
    invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_derivation_result",invoke(_ceg_derivation_result_body,Tuple{ConditionalEGraphDerivationResultV1},x))
end
canonical_hash(x::ConditionalEGraphDerivationResultV1)=_ceg_hash_text(invoke(_ceg_wrap,Tuple{String,String},"conditional_egraph_derivation_result",invoke(_ceg_derivation_result_body,Tuple{ConditionalEGraphDerivationResultV1},x)))
