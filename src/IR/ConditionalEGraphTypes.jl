"""Typed, closed declarations for bounded conditional whole-program rewriting."""

struct EqualityConditionRequirementV1
    condition_ref::QualifiedRefV1
    condition_contract_hash::Digest256
end

function _ceg_conditions(values::Tuple; allow_empty=false)
    n=fieldcount(typeof(values)); !allow_empty && n===0 && throw(ArgumentError("required_conditions cannot be empty"))
    ordered=Vector{EqualityConditionRequirementV1}(undef,n); i=1
    while i<=n
        value=getfield(values,i); typeof(value)===EqualityConditionRequirementV1 || throw(ArgumentError("conditions must be typed requirements"))
        Core.arrayset(true,ordered,value,i); i+=1
    end
    ordered=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},ordered, x -> invoke(_ceg_condition_bytes,Tuple{Tuple},(x,)))
    condition_keys=Vector{String}(undef,n); ref_keys=Vector{String}(undef,n); condition_count=0; ref_count=0; i=1
    while i<=n
        condition=Core.arrayref(true,ordered,i); key=invoke(_ceg_condition_bytes,Tuple{Tuple},(condition,)); j=1
        while j<=condition_count
            invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,condition_keys,j),key) && throw(ArgumentError("conditions contain duplicates")); j+=1
        end
        ref_key=invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},getfield(condition,:condition_ref)); j=1
        while j<=ref_count
            invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,ref_keys,j),ref_key) && throw(ArgumentError("condition reference has conflicting requirements")); j+=1
        end
        condition_count+=1; ref_count+=1; Core.arrayset(true,condition_keys,key,condition_count); Core.arrayset(true,ref_keys,ref_key,ref_count); i+=1
    end
    ntuple(i->Core.arrayref(true,ordered,i),n)
end

struct WholeProgramConditionalRewriteV1
    rule_ref::QualifiedRefV1
    lhs_program::TypedASTProgramV1
    rhs_program::TypedASTProgramV1
    lhs_hash::Digest256
    rhs_hash::Digest256
    required_conditions::Tuple{Vararg{EqualityConditionRequirementV1}}
    checker_ref::QualifiedRefV1
    checker_contract_hash::Digest256
    function WholeProgramConditionalRewriteV1(rule_ref::QualifiedRefV1, lhs_program::TypedASTProgramV1, rhs_program::TypedASTProgramV1,
            required_conditions, checker_ref::QualifiedRefV1, checker_contract_hash::Digest256, registry::OperatorRegistryV1)
        required_conditions isa Tuple || throw(ArgumentError("required_conditions must be a Tuple"))
        fieldcount(typeof(required_conditions)) <= 16 || throw(ArgumentError("rewrite rule exceeds 16 conditions"))
        invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},lhs_program,registry); invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1},rhs_program,registry)
        invoke(_ceg_same_interface,Tuple{TypedASTProgramV1,TypedASTProgramV1},lhs_program,rhs_program) || throw(ArgumentError("rewrite sides have different interfaces"))
        lhs_bytes = invoke(_typed_ast_program_json, Tuple{TypedASTProgramV1}, lhs_program); rhs_bytes = invoke(_typed_ast_program_json, Tuple{TypedASTProgramV1}, rhs_program)
        invoke(_ceg_sealed_equal,Tuple{String,String},lhs_bytes,rhs_bytes) && throw(ArgumentError("rewrite sides must have different sealed identities"))
        conditions = invoke(_ceg_conditions,Tuple{Tuple},required_conditions)
        lh, rh = invoke(_ceg_hash_text,Tuple{String},lhs_bytes), invoke(_ceg_hash_text,Tuple{String},rhs_bytes)
        new(rule_ref, lhs_program, rhs_program, lh, rh, conditions, checker_ref, checker_contract_hash)
    end
end
WholeProgramConditionalRewriteV1(rule_ref::QualifiedRefV1, lhs::TypedASTProgramV1, rhs::TypedASTProgramV1, conditions,
    checker::QualifiedRefV1, contract_hash::Digest256; registry::OperatorRegistryV1) = WholeProgramConditionalRewriteV1(rule_ref, lhs, rhs, conditions, checker, contract_hash, registry)

struct ConditionalRewriteSetV1
    rules::Tuple{Vararg{WholeProgramConditionalRewriteV1}}
    function ConditionalRewriteSetV1(rules)
        rules isa Tuple || throw(ArgumentError("rules must be a Tuple"))
        values = rules
        n=fieldcount(typeof(values)); n <= 32 || throw(ArgumentError("rewrite set exceeds 32 rules"))
        checked=Vector{WholeProgramConditionalRewriteV1}(undef,n); i=1
        while i<=n
            rule=getfield(values,i); typeof(rule) === WholeProgramConditionalRewriteV1 || throw(ArgumentError("rules must be typed declarations"))
            fieldcount(typeof(getfield(rule,:required_conditions))) <= 16 || throw(ArgumentError("rewrite rule exceeds 16 conditions"))
            Core.arrayset(true,checked,rule,i); i+=1
        end
        ordered = invoke(_ceg_insertion_sorted,Tuple{Vector,Function},checked, x -> invoke(_ceg_rule_bytes, Tuple{WholeProgramConditionalRewriteV1}, x))
        ref_keys = Vector{String}(undef,n); ref_count=0; i=1
        while i<=n
            rule=Core.arrayref(true,ordered,i); key = invoke(_ceg_ref_bytes,Tuple{QualifiedRefV1},getfield(rule,:rule_ref)); j=1
            while j<ref_count+1
                invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,ref_keys,j),key) && throw(ArgumentError("rewrite rule references must be unique")); j+=1
            end
            ref_count+=1; Core.arrayset(true,ref_keys,key,ref_count); i+=1
        end
        new(ntuple(i -> Core.arrayref(true,ordered,i),n))
    end
end

struct ConditionalEGraphBudgetV1
    max_programs::Int; max_rewrite_attempts::Int; max_rounds::Int; max_trace_steps::Int
    function ConditionalEGraphBudgetV1(max_programs::Integer, max_rewrite_attempts::Integer, max_rounds::Integer, max_trace_steps::Integer)
        vals = (invoke(_ceg_safe_budget_int,Tuple{Any,Any,Int,Int},max_programs, "max_programs", 1, 64), invoke(_ceg_safe_budget_int,Tuple{Any,Any,Int,Int},max_rewrite_attempts, "max_rewrite_attempts", 0, 4096), invoke(_ceg_safe_budget_int,Tuple{Any,Any,Int,Int},max_rounds, "max_rounds", 0, 32), invoke(_ceg_safe_budget_int,Tuple{Any,Any,Int,Int},max_trace_steps, "max_trace_steps", 0, 256)); new(vals...)
    end
end
ConditionalEGraphBudgetV1(; max_programs=64, max_rewrite_attempts=4096, max_rounds=32, max_trace_steps=256) = ConditionalEGraphBudgetV1(max_programs, max_rewrite_attempts, max_rounds, max_trace_steps)

@enum RewriteOrientationV1 rewrite_forward rewrite_reverse
@enum ConditionalEGraphStopReasonV1 conditional_fixed_point conditional_budget_programs conditional_budget_rewrite_attempts conditional_budget_rounds conditional_budget_trace_steps
@enum ConditionalEqualityStatusV1 reflexive_equal conditional_equal equality_unknown
@enum ConditionalEGraphSaturationStateV1 saturation_complete saturation_incomplete
@enum ConditionalEGraphDerivationReasonV1 conditional_egraph_derived saturation_budget_exhausted manifest_or_contract_incompatible source_out_of_profile exact_canonicalization_deferred

struct ConditionalRewriteTraceStepV1
    round::Int; rule_ref::QualifiedRefV1; rule_hash::Digest256; orientation::RewriteOrientationV1; source_hash::Digest256; target_hash::Digest256; step::Int
    required_conditions::Tuple{Vararg{EqualityConditionRequirementV1}}; cumulative_conditions::Tuple{Vararg{EqualityConditionRequirementV1}}
    function ConditionalRewriteTraceStepV1(round::Int, rule::WholeProgramConditionalRewriteV1,
            orientation::RewriteOrientationV1, source::TypedASTProgramV1, target::TypedASTProgramV1,
            step::Int, cumulative)
        cumulative isa Tuple || throw(ArgumentError("cumulative conditions must be a Tuple"))
        round in 1:32 && step in 1:256 && round===step || throw(ArgumentError("invalid trace coordinates"))
        source_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},source)
        target_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},target)
        expected_source=orientation===rewrite_forward ? getfield(rule,:lhs_program) : getfield(rule,:rhs_program)
        expected_target=orientation===rewrite_forward ? getfield(rule,:rhs_program) : getfield(rule,:lhs_program)
        invoke(_ceg_sealed_equal,Tuple{String,String},source_bytes,invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},expected_source)) &&
            invoke(_ceg_sealed_equal,Tuple{String,String},target_bytes,invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},expected_target)) ||
            throw(ArgumentError("trace programs do not match rewrite orientation"))
        source_hash = invoke(_ceg_hash_text,Tuple{String},source_bytes)
        target_hash = invoke(_ceg_hash_text,Tuple{String},target_bytes)
        rule_hash = invoke(_ceg_hash_text,Tuple{String},invoke(_ceg_rule_bytes,Tuple{WholeProgramConditionalRewriteV1},rule))
        new(round,getfield(rule,:rule_ref),rule_hash,orientation,source_hash,target_hash,step,
            getfield(rule,:required_conditions),invoke(_ceg_conditions,Tuple{Tuple},cumulative;allow_empty=true))
    end
end
struct ConditionalEqualityProvenanceV1
    source_hash::Digest256; target_hash::Digest256; conditions::Tuple{Vararg{EqualityConditionRequirementV1}}; trace::Tuple{Vararg{ConditionalRewriteTraceStepV1}}
    function ConditionalEqualityProvenanceV1(source::TypedASTProgramV1, target::TypedASTProgramV1, conditions, trace)
        conditions isa Tuple || throw(ArgumentError("provenance conditions must be a Tuple"))
        trace isa Tuple || throw(ArgumentError("provenance trace must be a Tuple"))
        ts=trace; fieldcount(typeof(ts))===0 && throw(ArgumentError("provenance trace cannot be empty"))
        i=1; nt=fieldcount(typeof(ts)); while i<=nt; typeof(getfield(ts,i))===ConditionalRewriteTraceStepV1 || throw(ArgumentError("invalid provenance trace")); i+=1; end
        source_hash = invoke(_ceg_hash_text,Tuple{String},invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},source))
        target_hash = invoke(_ceg_hash_text,Tuple{String},invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},target))
        conds = invoke(_ceg_conditions,Tuple{Tuple},conditions;allow_empty=true)
        prior_hash=source_hash; prior_conditions=()
        i=1
        nt=fieldcount(typeof(ts)); while i<=nt
            step=getfield(ts,i)
            invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(step,:source_hash),prior_hash) || throw(ArgumentError("provenance source chain mismatch"))
            getfield(step,:step)===i && getfield(step,:round)===i || throw(ArgumentError("provenance coordinates are not path-local"))
            prior_conditions=invoke(_ceg_merge_conditions,Tuple{Tuple,Tuple},prior_conditions,getfield(step,:required_conditions))
            invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_condition_bytes,Tuple{Tuple},prior_conditions),invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(step,:cumulative_conditions))) || throw(ArgumentError("provenance condition chain mismatch"))
            prior_hash=getfield(step,:target_hash); i+=1
        end
        invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},prior_hash,target_hash) || throw(ArgumentError("provenance target chain mismatch"))
        invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_condition_bytes,Tuple{Tuple},conds),invoke(_ceg_condition_bytes,Tuple{Tuple},prior_conditions)) || throw(ArgumentError("provenance conditions mismatch"))
        new(source_hash,target_hash,conds,ts)
    end
end
struct ConditionalProgramENodeV1
    program::TypedASTProgramV1; program_hash::Digest256; cumulative_conditions::Tuple{Vararg{EqualityConditionRequirementV1}}; provenance::Union{Nothing,ConditionalEqualityProvenanceV1}
    function ConditionalProgramENodeV1(program::TypedASTProgramV1, cumulative, provenance=nothing)
        cumulative isa Tuple || throw(ArgumentError("cumulative conditions must be a Tuple"))
        conditions=invoke(_ceg_conditions,Tuple{Tuple},cumulative;allow_empty=true)
        program_hash=invoke(_ceg_hash_text,Tuple{String},invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},program))
        if provenance !== nothing
            provenance isa ConditionalEqualityProvenanceV1 || throw(ArgumentError("invalid program provenance"))
            invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(provenance,:target_hash),program_hash) || throw(ArgumentError("provenance target does not match member"))
            invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(provenance,:conditions)),invoke(_ceg_condition_bytes,Tuple{Tuple},conditions)) || throw(ArgumentError("provenance conditions do not match member"))
        end
        new(program,program_hash,conditions,provenance)
    end
end
struct ConditionalEClassV1
    source_program_hash::Digest256; members::Tuple{Vararg{ConditionalProgramENodeV1}}
    function ConditionalEClassV1(source_program::TypedASTProgramV1, members)
        members isa Tuple || throw(ArgumentError("conditional e-class members must be a Tuple"))
        ms=members; nm=fieldcount(typeof(ms)); nm===0 && throw(ArgumentError("conditional e-class cannot be empty"))
        i=1; while i<=nm; typeof(getfield(ms,i))===ConditionalProgramENodeV1 || throw(ArgumentError("conditional e-class members are not typed")); i+=1; end
        source_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},source_program); source_hash=invoke(_ceg_hash_text,Tuple{String},source_bytes)
        source_count=0; member_keys=Vector{String}(undef,nm); key_count=0; i=1
        while i<=nm
            m=getfield(ms,i)
            key=invoke(_ceg_member_key,Tuple{ConditionalProgramENodeV1},m)
            j=1; while j<=key_count; invoke(_ceg_sealed_equal,Tuple{String,String},Core.arrayref(true,member_keys,j),key) && throw(ArgumentError("conditional e-class members are duplicated")); j+=1; end
            key_count+=1; Core.arrayset(true,member_keys,key,key_count)
            if invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},getfield(m,:program)),source_bytes) &&
                    fieldcount(typeof(getfield(m,:cumulative_conditions)))===0 && getfield(m,:provenance)===nothing
                source_count+=1
            end
            i+=1
        end
        source_count===1 || throw(ArgumentError("conditional e-class requires one identity source member"))
        values=Vector{ConditionalProgramENodeV1}(undef,nm); i=1; while i<=nm; Core.arrayset(true,values,getfield(ms,i),i); i+=1; end
        ordered=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},values, m -> invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},getfield(m,:program))*"\0"*invoke(_ceg_condition_bytes,Tuple{Tuple},getfield(m,:cumulative_conditions)))
        new(source_hash,ntuple(i -> Core.arrayref(true,ordered,i),nm))
    end
end
struct ConditionalEGraphUsageV1
    programs::Int; rewrite_attempts::Int; rounds::Int; trace_steps::Int
    function ConditionalEGraphUsageV1(programs::Int,rewrite_attempts::Int,rounds::Int,trace_steps::Int)
        programs>=1&&rewrite_attempts>=0&&rounds>=0&&trace_steps>=0||throw(ArgumentError("invalid saturation usage")); new(programs,rewrite_attempts,rounds,trace_steps)
    end
end
struct _ConditionalTraceReplayResultV1
    valid::Bool; final_program::TypedASTProgramV1; final_conditions::Tuple{Vararg{EqualityConditionRequirementV1}}; checked_steps::Int
end
struct DerivedConditionalEGraphV1
    source_program::TypedASTProgramV1; source_hash::Digest256; used_manifest_bindings::Tuple{Vararg{Tuple{OperatorRefV1,Digest256}}}; rewrite_set::ConditionalRewriteSetV1
    eclass::ConditionalEClassV1; saturation_state::ConditionalEGraphSaturationStateV1
    saturation_budget::ConditionalEGraphBudgetV1; usage::ConditionalEGraphUsageV1; canonicalization_profile::CanonicalizationProfileV1; complete::Bool
    stop_reason::ConditionalEGraphStopReasonV1
    function DerivedConditionalEGraphV1(source_program::TypedASTProgramV1, rewrite_set::ConditionalRewriteSetV1, registry::OperatorRegistryV1, budget::ConditionalEGraphBudgetV1, profile::CanonicalizationProfileV1)
        computed=invoke(_ceg_saturate_components,Tuple{TypedASTProgramV1,ConditionalRewriteSetV1,OperatorRegistryV1,ConditionalEGraphBudgetV1,CanonicalizationProfileV1},source_program,rewrite_set,registry,budget,profile)
        computed isa Tuple || throw(ArgumentError("conditional derivation did not resolve to an artifact"))
        source_hash,eclass,state,usage,complete,reason=computed
        new(source_program,source_hash,getfield(source_program,:used_manifest_bindings),rewrite_set,eclass,state,budget,usage,profile,complete,reason)
    end
end
struct ConditionalEqualityQueryResultV1
    status::ConditionalEqualityStatusV1; provenance::Union{Nothing,ConditionalEqualityProvenanceV1}
    function ConditionalEqualityQueryResultV1(graph::DerivedConditionalEGraphV1, target::TypedASTProgramV1)
        target_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},target)
        source_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},getfield(graph,:source_program))
        if invoke(_ceg_sealed_equal,Tuple{String,String},source_bytes,target_bytes)
            return new(reflexive_equal,nothing)
        end
        members=getfield(getfield(graph,:eclass),:members); i=1; nm=fieldcount(typeof(members)); while i<=nm
            member=getfield(members,i)
            member_bytes=invoke(_typed_ast_program_json,Tuple{TypedASTProgramV1},getfield(member,:program))
            if !invoke(_ceg_sealed_equal,Tuple{String,String},member_bytes,target_bytes)
                i+=1
                continue
            end
            provenance=getfield(member,:provenance)
            provenance isa ConditionalEqualityProvenanceV1 || return new(equality_unknown,nothing)
            fieldcount(typeof(getfield(provenance,:trace)))>0 && fieldcount(typeof(getfield(provenance,:conditions)))>0 || return new(equality_unknown,nothing)
            i+=1
            return new(conditional_equal,provenance)
        end
        new(equality_unknown,nothing)
    end
end
struct ConditionalEGraphDerivationResultV1
    status::ResolutionStatus; artifact::Union{Nothing,DerivedConditionalEGraphV1}; reason::ConditionalEGraphDerivationReasonV1; derivation_request_hash::Digest256
    function ConditionalEGraphDerivationResultV1(source::TypedASTProgramV1, rules::ConditionalRewriteSetV1,
            registry::OperatorRegistryV1, budget::ConditionalEGraphBudgetV1, profile::CanonicalizationProfileV1)
        request_hash = invoke(_ceg_request_hash,Tuple{TypedASTProgramV1,ConditionalRewriteSetV1,OperatorRegistryV1,ConditionalEGraphBudgetV1,CanonicalizationProfileV1},source,rules,registry,budget,profile)
        if !(fieldcount(typeof(getfield(source,:nodes))) in 1:32 && fieldcount(typeof(getfield(source,:roots))) in 1:8)
            return new(terminal_deferred,nothing,source_out_of_profile,request_hash)
        end
        try
            artifact = DerivedConditionalEGraphV1(source,rules,registry,budget,profile)
            max_bytes = getfield(getfield(profile,:budget),:max_bytes)
            ncodeunits(invoke(_ceg_equivalence_bytes,Tuple{DerivedConditionalEGraphV1},artifact)) <= max_bytes || return new(terminal_deferred,nothing,exact_canonicalization_deferred,request_hash)
            ncodeunits(invoke(_ceg_attempt_bytes,Tuple{DerivedConditionalEGraphV1},artifact)) <= max_bytes || return new(terminal_deferred,nothing,exact_canonicalization_deferred,request_hash)
            complete = getfield(artifact,:complete)
            reason = complete ? conditional_egraph_derived : saturation_budget_exhausted
            new(resolved,artifact,reason,request_hash)
        catch e
            e isa CanonicalizationDeferred && return new(terminal_deferred,nothing,exact_canonicalization_deferred,request_hash)
            e isa ArgumentError && return new(terminal_deferred,nothing,manifest_or_contract_incompatible,request_hash)
            rethrow()
        end
    end
end

function _ceg_safe_budget_int(x, field, lo, hi)
    typeof(x) in _P0_SAFE_INTEGER_TYPES && !(x isa Bool) && typemin(Int) <= x <= typemax(Int) && lo <= x <= hi || throw(ArgumentError("$field must be a safe integer in range")); Int(x)
end
function _ceg_registry_manifest(registry::OperatorRegistryV1, ref::QualifiedRefV1)
    count=0; matched=nothing
    manifests=getfield(registry,:operators); i=1; n=fieldcount(typeof(manifests)); while i<=n
        manifest=getfield(manifests,i)
        candidate=getfield(getfield(manifest,:operator_ref),:qualified)
        if invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},candidate,ref)
            count+=1; matched=manifest
        end
        i+=1
    end
    count===1 || throw(ArgumentError(count===0 ? "operator reference is unknown" : "operator reference is ambiguous"))
    matched
end
function _ceg_validate_program_for_rewrite(program::TypedASTProgramV1, registry::OperatorRegistryV1, allow_impure::Bool)
    fieldcount(typeof(getfield(program,:nodes)))<=32 || throw(ArgumentError("rewrite program has too many nodes")); fieldcount(typeof(getfield(program,:roots)))<=8 || throw(ArgumentError("rewrite program has too many roots"))
    bindings=getfield(program,:used_manifest_bindings); bi=1; bn=fieldcount(typeof(bindings)); while bi<=bn
        binding=getfield(bindings,bi)
        manifest = invoke(_ceg_registry_manifest,Tuple{OperatorRegistryV1,QualifiedRefV1},registry,getfield(getfield(binding,1),:qualified))
        invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(binding,2),getfield(manifest,:manifest_hash)) || throw(ArgumentError("AST manifest binding digest mismatch"))
        bi+=1
    end
    nodes=getfield(program,:nodes); ni=1; nn=fieldcount(typeof(nodes)); while ni<=nn
        n=getfield(nodes,ni)
        if typeof(n) !== ASTApplyV1
            ni+=1
            continue
        end
        manifest=invoke(_ceg_registry_manifest,Tuple{OperatorRegistryV1,QualifiedRefV1},registry,getfield(getfield(n,:operator_ref),:qualified))
        allow_impure || (getfield(manifest,:pure) && getfield(manifest,:cse_allowed) && !getfield(manifest,:stateful) && !getfield(manifest,:stochastic) && !getfield(manifest,:event) || throw(ArgumentError("rewrite requires pure CSE-safe manifests")))
        allow_impure || (getfield(n,:pure) && getfield(n,:cse_allowed) || throw(ArgumentError("rewrite AST metadata is not manifest-derived")))
        !allow_impure && typeof(getfield(manifest,:input_type_rule)) in (DelayRuleV1,SamplingRuleV1,EventTransitionRuleV1) && throw(ArgumentError("delay/event rules cannot be rewritten"))
        found=false
        bi=1; while bi<=bn
            b=getfield(bindings,bi)
            if invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},getfield(getfield(b,1),:qualified),getfield(getfield(n,:operator_ref),:qualified)); invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(b,2),getfield(manifest,:manifest_hash)) || throw(ArgumentError("AST manifest binding digest mismatch")); found=true; end
            bi+=1
        end
        found || throw(ArgumentError("AST operator has no exact manifest binding"))
        ni+=1
    end
    nothing
end
_ceg_validate_program_for_rewrite(program::TypedASTProgramV1, registry::OperatorRegistryV1; allow_impure=false) =
    invoke(_ceg_validate_program_for_rewrite,Tuple{TypedASTProgramV1,OperatorRegistryV1,Bool},program,registry,allow_impure)
function _ceg_input_abi(p::TypedASTProgramV1)
    nodes=getfield(p,:nodes); ports=getfield(p,:input_ports); n=fieldcount(typeof(ports)); vals=Vector{Any}(undef,n); i=1
    while i<=n
        port=getfield(ports,i); node=getfield(nodes,port)
        Core.arrayset(true,vals,(getfield(node,:port),getfield(node,:output_type),getfield(node,:parameters)),i); i+=1
    end
    ordered=invoke(_ceg_insertion_sorted,Tuple{Vector,Function},vals,x->invoke(_tac_value_string,Tuple{Any},getfield(x,1)))
    ntuple(i -> Core.arrayref(true,ordered,i),n)
end
function _ceg_root_abi(p::TypedASTProgramV1)
    nodes=getfield(p,:nodes); roots=getfield(p,:roots); n=fieldcount(typeof(roots)); out=Vector{PhysicalType}(undef,n); i=1
    while i<=n; Core.arrayset(true,out,getfield(getfield(nodes,getfield(roots,i)),:output_type),i); i+=1; end
    ntuple(i -> Core.arrayref(true,out,i), n)
end
function _ceg_same_interface(a::TypedASTProgramV1,b::TypedASTProgramV1)
    ai,bi=invoke(_ceg_input_abi,Tuple{TypedASTProgramV1},a),invoke(_ceg_input_abi,Tuple{TypedASTProgramV1},b); fieldcount(typeof(ai))===fieldcount(typeof(bi)) || return false
    i=1; while i<=fieldcount(typeof(ai))
        av=getfield(ai,i); bv=getfield(bi,i)
        getfield(av,1)===getfield(bv,1) && invoke(_ceg_physical_equal,Tuple{PhysicalType,PhysicalType},getfield(av,2),getfield(bv,2)) && invoke(_ceg_closed_value_equal,Tuple{Any,Any},getfield(av,3),getfield(bv,3)) || return false
        i+=1
    end
    ar,br=invoke(_ceg_root_abi,Tuple{TypedASTProgramV1},a),invoke(_ceg_root_abi,Tuple{TypedASTProgramV1},b); fieldcount(typeof(ar))===fieldcount(typeof(br)) || return false
    i=1; while i<=fieldcount(typeof(ar)); invoke(_ceg_physical_equal,Tuple{PhysicalType,PhysicalType},getfield(ar,i),getfield(br,i)) || return false; i+=1; end; true
end
_ceg_sealed_equal(a::String,b::String)=invoke(_tac_text_equal,Tuple{String,String},a,b)
_ceg_digest_equal(a::Digest256,b::Digest256)=invoke(_ceg_sealed_equal,Tuple{String,String},getfield(a,:value),getfield(b,:value))
_ceg_ref_equal(a::QualifiedRefV1,b::QualifiedRefV1)=invoke(_ceg_sealed_equal,Tuple{String,String},getfield(a,:id),getfield(b,:id))&&invoke(_ceg_sealed_equal,Tuple{String,String},getfield(a,:version),getfield(b,:version))
_ceg_physical_equal(a::PhysicalType,b::PhysicalType)=getfield(a,:value_kind)===getfield(b,:value_kind)&&getfield(a,:tensor_rank)===getfield(b,:tensor_rank)&&getfield(a,:spatial_dimension)===getfield(b,:spatial_dimension)&&invoke(_ceg_closed_value_equal,Tuple{Any,Any},getfield(a,:temporal_type),getfield(b,:temporal_type))&&invoke(_ceg_closed_value_equal,Tuple{Any,Any},getfield(a,:units),getfield(b,:units))
function _ceg_bindings_equal(a,b)
    a isa Tuple && b isa Tuple || return false
    av,bv=a,b; fieldcount(typeof(av))==fieldcount(typeof(bv)) || return false
    i=1; while i<=fieldcount(typeof(av))
        aa=getfield(av,i); bb=getfield(bv,i)
        invoke(_ceg_ref_equal,Tuple{QualifiedRefV1,QualifiedRefV1},getfield(getfield(aa,1),:qualified),getfield(getfield(bb,1),:qualified))&&invoke(_ceg_digest_equal,Tuple{Digest256,Digest256},getfield(aa,2),getfield(bb,2)) || return false
        i+=1
    end
    true
end
_ceg_closed_value_equal(a,b)=invoke(_ceg_sealed_equal,Tuple{String,String},invoke(_tac_value_string,Tuple{Any},a),invoke(_tac_value_string,Tuple{Any},b))
function _ceg_sealed_less(a::String,b::String)
    na=sizeof(a); nb=sizeof(b); n=min(na,nb); i=1
    while i<=n
        aa=codeunit(a,i); bb=codeunit(b,i); aa<bb&&return true; aa>bb&&return false; i+=1
    end
    na<nb
end
function _ceg_insertion_sorted(values::Vector,key::Function)
    n=Core.arraysize(values,1); out=Vector{eltype(values)}(undef,n); i=1
    while i<=n; Core.arrayset(true,out,Core.arrayref(true,values,i),i); i+=1; end
    i=2
    while i<=Core.arraysize(out,1)
        v=Core.arrayref(true,out,i); vk=key(v); j=i-1
        while j>=1 && invoke(_ceg_sealed_less,Tuple{String,String},key(Core.arrayref(true,out,j)),vk)===false && invoke(_ceg_sealed_equal,Tuple{String,String},key(Core.arrayref(true,out,j)),vk)===false
            Core.arrayset(true,out,Core.arrayref(true,out,j),j+1); j-=1
        end
        Core.arrayset(true,out,v,j+1); i+=1
    end
    out
end
