# Strict candidate-local typed weak-integral accounting (screen only).
using FusionConceptAI
import FusionConceptAI: Digest256, PhysicalType, UnitSignature, canonical_hash, semantic_view, screen_only
const _RMWR_SCHEMA="fusionconceptai:runtime-v4-regional-mhd-weak-residual"
const _RMWR_ZERO=(0.0,0.0,0.0)
const _RMWR_MISSING=(:desc_test_function_weak_integral,:regional_residual_jacobian,:boundary_limit_trace)
const _RMWR_TOKEN=Val(:regional_mhd_weak_residual_private)
_rmwr_vec(v)=(length(v)==3 && all(x->x isa Real && isfinite(Float64(x)),v)) ? (Float64(v[1]),Float64(v[2]),Float64(v[3])) : throw(ArgumentError("weak term must be finite 3-vector"))
_rmwr_add(a,b)=ntuple(i->a[i]+b[i],3)
_rmwr_sum(xs)=foldl(_rmwr_add,xs;init=_RMWR_ZERO)
_rmwr_id(x)=x isa Digest256 ? x : canonical_hash(x)

struct RegionalMHDTestFunctionV4
 id::String; region_id::String; support_id::String; component::Symbol; field_type::PhysicalType; source_hash::Digest256; manufactured::Bool
end

"""Independent replay of all derived weak ledgers."""
function replay_regional_mhd_weak_residual(x)
    validate_regional_mhd_weak_residual(x)
    for t in x.test_functions
        r=_rmwr_add(_rmwr_sum(s.volume_integral for s in x.source_terms if s.region_id==t.region_id&&s.support_id==t.support_id&&s.component==t.component),_rmwr_sum(b.oriented_flux for b in x.boundary_terms if b.minus_region==t.region_id&&b.support_id==t.support_id&&b.component==t.component))
        only(filter(z->z.test_id==t.id,x.test_function_residuals)).residual==r || throw(ArgumentError("independent replay mismatch"))
    end
    x
end

struct RegionalMHDWeakExecutionRequestV4
    candidate_identity::Digest256; context_identity::Digest256; residual_identity::Digest256
    provider_id::Symbol; integration_nodes::Tuple; status::Symbol
    claim_ceiling::typeof(screen_only); request_hash::Digest256
    function RegionalMHDWeakExecutionRequestV4(token::Val{:regional_mhd_weak_residual_private},fields...)
        token===_RMWR_TOKEN||throw(ArgumentError("private execution request constructor")); new(fields...)
    end
end
semantic_view(x::RegionalMHDWeakExecutionRequestV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
struct RegionalMHDWeakExecutionReceiptV4
    request_hash::Digest256; result_hash::Digest256; provider_id::Symbol; integration_nodes::Tuple
    exit_code::Int; replay_hash::Digest256; receipt_hash::Digest256
end
semantic_view(x::RegionalMHDWeakExecutionReceiptV4)=(request_hash=x.request_hash,result_hash=x.result_hash,provider_id=x.provider_id,integration_nodes=x.integration_nodes,exit_code=x.exit_code,replay_hash=x.replay_hash)
struct RegionalMHDWeakExecutionResultV4
    request_hash::Digest256; result_hash::Digest256; receipt_hash::Digest256; status::Symbol
    provider_executed::Bool; result_schema_validated::Bool; claim_ceiling::typeof(screen_only)
end
semantic_view(x::RegionalMHDWeakExecutionResultV4)=(request_hash=x.request_hash,result_hash=x.result_hash,receipt_hash=x.receipt_hash,status=x.status,provider_executed=x.provider_executed,result_schema_validated=x.result_schema_validated,claim_ceiling=x.claim_ceiling)
function execute_regional_mhd_weak_residual(x;provider_id::Symbol=:desc_weak_form,integration_nodes=())
    replay=replay_regional_mhd_weak_residual(x); nodes=Tuple(Symbol(n) for n in integration_nodes)
    rb=(candidate_identity=x.candidate_identity,context_identity=x.context_identity,residual_identity=x.residual_hash,provider_id=provider_id,integration_nodes=nodes,status=:deferred,claim_ceiling=screen_only)
    request=RegionalMHDWeakExecutionRequestV4(_RMWR_TOKEN,values(rb)...,canonical_hash(rb))
    cb=(request_hash=request.request_hash,result_hash=x.residual_hash,provider_id=provider_id,integration_nodes=nodes,exit_code=0,replay_hash=replay.residual_hash)
    receipt=RegionalMHDWeakExecutionReceiptV4(values(cb)...,canonical_hash(cb)); body=(request_hash=request.request_hash,result_hash=x.residual_hash,receipt_hash=receipt.receipt_hash,status=:deferred,provider_executed=false,result_schema_validated=true,claim_ceiling=screen_only)
    request,RegionalMHDWeakExecutionResultV4(values(body)...),receipt
end
function validate_regional_mhd_weak_execution(request::RegionalMHDWeakExecutionRequestV4,result::RegionalMHDWeakExecutionResultV4,receipt::RegionalMHDWeakExecutionReceiptV4)
    canonical_hash(semantic_view(request))==request.request_hash||throw(ArgumentError("weak request tamper")); canonical_hash(semantic_view(receipt))==receipt.receipt_hash||throw(ArgumentError("weak receipt tamper"))
    result.request_hash==request.request_hash&&result.receipt_hash==receipt.receipt_hash&&receipt.request_hash==request.request_hash&&result.status===:deferred&&!result.provider_executed&&result.claim_ceiling===screen_only||throw(ArgumentError("weak execution identity or authority mismatch")); canonical_hash(semantic_view(result))
end

function RegionalMHDTestFunctionV4(id,region,support,component,field_type,source_hash;manufactured=false)
 field_type isa PhysicalType && field_type.tensor_rank==1 && field_type.spatial_dimension==3 || throw(ArgumentError("test function must be typed vector-valued 3D"))
 !isempty(String(id))&&!isempty(String(region))&&!isempty(String(support))||throw(ArgumentError("test ownership incomplete"))
 RegionalMHDTestFunctionV4(String(id),String(region),String(support),Symbol(component),field_type,_rmwr_id(source_hash),manufactured)
end
semantic_view(x::RegionalMHDTestFunctionV4)=(id=x.id,region_id=x.region_id,support_id=x.support_id,component=x.component,field_type=x.field_type,source_hash=x.source_hash,manufactured=x.manufactured)

struct RegionalMHDSourceTermV4
 region_id::String; support_id::String; component::Symbol; units::UnitSignature; volume_integral::NTuple{3,Float64}; source_hash::Digest256
end
function RegionalMHDSourceTermV4(region,support,component,units,value,source_hash)
 !isempty(String(region))&&!isempty(String(support))||throw(ArgumentError("source ownership incomplete"))
 RegionalMHDSourceTermV4(String(region),String(support),Symbol(component),units,_rmwr_vec(value),_rmwr_id(source_hash))
end
semantic_view(x::RegionalMHDSourceTermV4)=(region_id=x.region_id,support_id=x.support_id,component=x.component,units=x.units,volume_integral=x.volume_integral,source_hash=x.source_hash)

struct RegionalMHDBoundaryTermV4
 boundary_id::String; minus_region::String; plus_region::Union{Nothing,String}; support_id::String; component::Symbol; units::UnitSignature; oriented_flux::NTuple{3,Float64}; source_hash::Digest256
end
function RegionalMHDBoundaryTermV4(id,minus,plus,support,component,units,value,source_hash)
 !isempty(String(id))&&!isempty(String(minus))&&(plus===nothing||String(plus)!=String(minus))||throw(ArgumentError("boundary ownership invalid"))
 RegionalMHDBoundaryTermV4(String(id),String(minus),plus===nothing ? nothing : String(plus),String(support),Symbol(component),units,_rmwr_vec(value),_rmwr_id(source_hash))
end
semantic_view(x::RegionalMHDBoundaryTermV4)=(boundary_id=x.boundary_id,minus_region=x.minus_region,plus_region=x.plus_region,support_id=x.support_id,component=x.component,units=x.units,oriented_flux=x.oriented_flux,source_hash=x.source_hash)

struct RegionalMHDUpstreamBindingV4
 provider::Symbol; object_type::Symbol; object_hash::Digest256; candidate_identity::Digest256; context_identity::Digest256; request_identity::Digest256; result_identity::Digest256; receipt_identity::Digest256; partition_identity::Digest256; interface_identity::Digest256; status::Symbol; manufactured::Bool
end
semantic_view(x::RegionalMHDUpstreamBindingV4)=NamedTuple{fieldnames(typeof(x))}(ntuple(i->getfield(x,i),fieldcount(typeof(x))))
function _rmwr_upstream(provider,object,candidate,context;request=nothing,result=nothing,receipt=nothing,partition=nothing,interface=nothing,status=:bound,manufactured=false,validator=nothing)
 provider in (:desc_regional_observation,:static_mhd_interface_ledger)||throw(ArgumentError("unknown DESC upstream")); status in (:bound,:deferred,:unsupported)||throw(ArgumentError("invalid upstream status")); status==:bound&&object===nothing&&throw(ArgumentError("bound DESC upstream missing")); status==:bound&&!manufactured&&throw(ArgumentError("generic binder is test-only"))
 validator===nothing||try validator(object) catch e;throw(ArgumentError("DESC upstream validation failed: $(e)")) end
 RegionalMHDUpstreamBindingV4(provider,Symbol(nameof(typeof(object))),_rmwr_id(object),_rmwr_id(candidate),_rmwr_id(context),_rmwr_id(request),_rmwr_id(result),_rmwr_id(receipt),_rmwr_id(partition),_rmwr_id(interface),status,manufactured)
end
test_only_desc_regional_observation_binding(object,candidate,context;kwargs...)=_rmwr_upstream(:desc_regional_observation,object,candidate,context;kwargs...)
test_only_static_mhd_interface_ledger_binding(object,candidate,context;kwargs...)=_rmwr_upstream(:static_mhd_interface_ledger,object,candidate,context;kwargs...)

struct RegionalMHDWeakResidualV4
 candidate_identity::Digest256; context_identity::Digest256; ast_hash::Digest256; hypergraph_hash::Digest256; test_functions::Tuple; source_terms::Tuple; boundary_terms::Tuple; upstream::Tuple; missing_capabilities::Tuple; test_function_residuals::Tuple; regional_ledger::Tuple; global_ledger::NamedTuple; status::Symbol; manufactured_control::Bool; claim_ceiling::typeof(screen_only); residual_hash::Digest256
 function RegionalMHDWeakResidualV4(token::Val{:regional_mhd_weak_residual_private},fields...)
  token===_RMWR_TOKEN||throw(ArgumentError("private residual constructor"));new(fields...)
 end
end
semantic_view(x::RegionalMHDWeakResidualV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))

function assemble_regional_mhd_weak_residual(candidate,context,ast,hypergraph,tests,sources,boundaries,upstream;manufactured_control=false)
 ts,ss,bs,us=Tuple(tests),Tuple(sources),Tuple(boundaries),Tuple(upstream)
 all(x->x isa RegionalMHDTestFunctionV4,ts)||throw(ArgumentError("typed test ownership required")); all(x->x isa RegionalMHDSourceTermV4,ss)||throw(ArgumentError("typed vector source required")); all(x->x isa RegionalMHDBoundaryTermV4,bs)||throw(ArgumentError("typed boundary ownership required")); all(x->x isa RegionalMHDUpstreamBindingV4,us)||throw(ArgumentError("typed DESC upstream required"))
 isempty(ts)&&throw(ArgumentError("test functions cannot be empty")); isempty(us)&&throw(ArgumentError("DESC upstream cannot be empty")); manufactured_control||all(!x.manufactured for x in us)||throw(ArgumentError("manufactured path requires explicit control"))
 regions=unique(vcat([x.region_id for x in ts],[x.region_id for x in ss],[x.minus_region for x in bs],[x.plus_region for x in bs if x.plus_region!==nothing])); all(x->x.minus_region in regions&&(x.plus_region===nothing||x.plus_region in regions),bs)||throw(ArgumentError("unknown boundary region"));
 all(s->any(t->s.region_id==t.region_id&&s.support_id==t.support_id&&s.component==t.component&&s.units==t.field_type.units,ts),ss)||throw(ArgumentError("source has no test owner")); all(b->any(t->b.minus_region==t.region_id&&b.support_id==t.support_id&&b.component==t.component&&b.units==t.field_type.units,ts),bs)||throw(ArgumentError("boundary has no test owner"))
 for id in unique(x.boundary_id for x in bs)
  xs=filter(x->x.boundary_id==id,bs); any(x->x.plus_region===nothing,xs)&&length(xs)>1&&throw(ArgumentError("duplicate exterior boundary id"))
  if any(x->x.plus_region!==nothing,xs)
   length(xs)==2&&xs[1].minus_region==xs[2].plus_region&&xs[2].minus_region==xs[1].plus_region&&xs[1].source_hash==xs[2].source_hash&&_rmwr_add(xs[1].oriented_flux,xs[2].oriented_flux)==_RMWR_ZERO||throw(ArgumentError("interface terms must be paired and opposite"))
  end
 end
 ah,gh=canonical_hash(ast),canonical_hash(hypergraph)
 tf_res=Tuple((test_id=t.id,region_id=t.region_id,units=t.field_type.units,residual=_rmwr_add(_rmwr_sum(s.volume_integral for s in ss if s.region_id==t.region_id&&s.support_id==t.support_id&&s.component==t.component),_rmwr_sum(b.oriented_flux for b in bs if b.minus_region==t.region_id&&b.support_id==t.support_id&&b.component==t.component))) for t in ts)
 led=Tuple((region_id=r,volume=_rmwr_sum(s.volume_integral for s in ss if s.region_id==r),boundary=_rmwr_sum(b.oriented_flux for b in bs if b.minus_region==r)) for r in regions)
 totalv=_rmwr_sum(x.volume for x in led);totalb=_rmwr_sum(x.boundary for x in led);missing=true;missing_caps=_RMWR_MISSING;status=:deferred
 body=(candidate_identity=_rmwr_id(candidate),context_identity=_rmwr_id(context),ast_hash=ah,hypergraph_hash=gh,test_functions=ts,source_terms=ss,boundary_terms=bs,upstream=us,missing_capabilities=missing_caps,test_function_residuals=tf_res,regional_ledger=led,global_ledger=(volume=totalv,boundary=totalb,residual=_rmwr_add(totalv,totalb),balanced=false),status=status,manufactured_control=manufactured_control,claim_ceiling=screen_only)
 RegionalMHDWeakResidualV4(_RMWR_TOKEN,values(body)...,canonical_hash(body))
end
function validate_regional_mhd_weak_residual(x::RegionalMHDWeakResidualV4)
 expected=canonical_hash(semantic_view(x));expected==x.residual_hash||throw(ArgumentError("residual hash mismatch"));x.claim_ceiling==screen_only||throw(ArgumentError("authority escalation"));x.missing_capabilities==_RMWR_MISSING||throw(ArgumentError("missing capability ledger mismatch"));x.status==:deferred||throw(ArgumentError("status must remain deferred until capabilities exist"))
 for t in x.test_functions
  actual=only(filter(r->r.test_id==t.id,x.test_function_residuals));recomputed=_rmwr_add(_rmwr_sum(s.volume_integral for s in x.source_terms if s.region_id==t.region_id&&s.support_id==t.support_id&&s.component==t.component),_rmwr_sum(b.oriented_flux for b in x.boundary_terms if b.minus_region==t.region_id&&b.support_id==t.support_id&&b.component==t.component));actual.residual==recomputed||throw(ArgumentError("test residual recomputation mismatch"))
 end
 regions=Tuple(r.region_id for r in x.regional_ledger); rebuilt=Tuple((region_id=r,volume=_rmwr_sum(s.volume_integral for s in x.source_terms if s.region_id==r),boundary=_rmwr_sum(b.oriented_flux for b in x.boundary_terms if b.minus_region==r)) for r in regions); rebuilt==x.regional_ledger||throw(ArgumentError("regional ledger recomputation mismatch"))
 gv=_rmwr_sum(r.volume for r in rebuilt); gb=_rmwr_sum(r.boundary for r in rebuilt); rebuilt_global=(volume=gv,boundary=gb,residual=_rmwr_add(gv,gb),balanced=false); rebuilt_global==x.global_ledger||throw(ArgumentError("global ledger recomputation mismatch"))
 expected
end
regional_mhd_weak_residual_manifest()=(schema=_RMWR_SCHEMA,status=:deferred,vector_components=3,interface_pairing=:strict_opposite_same_source,exterior_boundary_separate=true,claim_ceiling=screen_only)

"""Production request shell: consumes concrete committed DESC artifacts.

It deliberately records a gap-only request.  The old observation and jump
ledger are validated by their canonical hashes here; weak test integration,
boundary traces, and a residual Jacobian remain unavailable capabilities.
"""
struct RegionalMHDProductionGapRequestV4
    candidate_identity::Digest256; context_identity::Digest256
    q3_comparison_identity::Digest256; jump_request_identity::Digest256
    jump_result_identity::Digest256; partition_identity::Digest256
    global_observation_identity::Digest256
    region_ids::Tuple; region_support_hashes::Tuple; missing_capabilities::Tuple
    status::Symbol; claim_ceiling::typeof(screen_only); request_hash::Digest256
    function RegionalMHDProductionGapRequestV4(token::Val{:regional_mhd_weak_residual_private},fields...)
        token===_RMWR_TOKEN||throw(ArgumentError("private production request constructor"));new(fields...)
    end
end
semantic_view(x::RegionalMHDProductionGapRequestV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function make_regional_mhd_production_gap_request(candidate, context,
        q3_comparison, jump_request, jump_result, partition,
        global_observation)
    for (x,label) in ((q3_comparison,:q3_comparison),
            (jump_request,:jump_request),(jump_result,:jump_result),
            (partition,:partition),(global_observation,:global_observation))
        x===nothing&&throw(ArgumentError("missing concrete DESC $label artifact")); canonical_hash(x)
    end
    hasproperty(partition,:regions) ||
        throw(ArgumentError("partition artifact lacks region ownership"))
    regions=Tuple(getproperty(r,:region_id) for r in partition.regions); supports=Tuple(getproperty(r,:region_support_hash) for r in partition.regions)
    isempty(regions)||length(unique(regions))==length(regions)||throw(ArgumentError("duplicate or missing region ownership"))
    body=(candidate_identity=_rmwr_id(candidate),
        context_identity=_rmwr_id(context),
        q3_comparison_identity=canonical_hash(q3_comparison),
        jump_request_identity=canonical_hash(jump_request),
        jump_result_identity=canonical_hash(jump_result),
        partition_identity=canonical_hash(partition),
        global_observation_identity=canonical_hash(global_observation),
        region_ids=regions,region_support_hashes=supports,
        missing_capabilities=_RMWR_MISSING,status=:deferred,
        claim_ceiling=screen_only)
    RegionalMHDProductionGapRequestV4(_RMWR_TOKEN,values(body)...,canonical_hash(body))
end
function validate_regional_mhd_production_gap_request(x::RegionalMHDProductionGapRequestV4)
    canonical_hash(semantic_view(x))==x.request_hash||throw(ArgumentError("production request hash mismatch"));x.status==:deferred&&x.missing_capabilities==_RMWR_MISSING||throw(ArgumentError("production gap status invalid"));x.claim_ceiling==screen_only||throw(ArgumentError("authority escalation"));x.request_hash
end

function _rmwr_owner(object, name::Symbol)
    owner = parentmodule(typeof(object))
    isdefined(owner, name) ||
        throw(ArgumentError("upstream validator unavailable: $name"))
    getfield(owner, name)
end

"""Strict production entry point over committed q3, jump-ledger, and global
conservation artifacts. Missing weak-form capabilities keep the result
deferred; this function never manufactures a proxy residual."""
function bind_regional_mhd_desc_production_gap(candidate, context, q3_upstream,
        traction_request, traction_result, q2_request, q2_result, q2_execution,
        q3_execution, static_full_chain, static_ledger_request,
        static_ledger_result, global_observation)
    length(q3_upstream) == 17 ||
        throw(ArgumentError("q3 upstream must be the complete 17-entry tuple"))
    length(static_full_chain) == 21 ||
        throw(ArgumentError("static ledger chain must contain its complete 21-entry prefix"))
    q3_comparison = q3_execution.comparison
    partition_request = q3_upstream[12]
    _rmwr_owner(q3_comparison, :validate_regional_force_q3_execution)(
        q3_upstream, traction_request, traction_result, q2_request, q2_result,
        q2_execution, q3_execution)
    _rmwr_owner(static_ledger_result,
        :validate_static_mhd_interface_jump_ledger)(static_full_chain...,
        static_ledger_request, static_ledger_result)
    _rmwr_owner(global_observation,
        :validate_regional_mhd_global_conservation_observation)(global_observation)
    candidate_id = _rmwr_id(candidate)
    context_id = _rmwr_id(context)
    q3_comparison.candidate_hash == candidate_id &&
        q3_comparison.context_hash == context_id &&
        static_ledger_result.candidate_hash == candidate_id &&
        static_ledger_result.context_hash == context_id &&
        global_observation.candidate_hash == candidate_id &&
        global_observation.context_hash == context_id ||
        throw(ArgumentError("production artifact candidate/context mismatch"))
    q3_comparison.q3_request.partition_region_ids ==
        Tuple(region.region_id for region in partition_request.regions) &&
        q3_comparison.q3_request.partition_support_hashes ==
        Tuple(region.region_support_hash for region in partition_request.regions) &&
        q3_comparison.q3_request.partition_request_hash ==
        canonical_hash(partition_request) &&
        q3_comparison.q3_request.partition_result_hash ==
        canonical_hash(q3_upstream[13]) ||
        throw(ArgumentError("production artifact partition mismatch"))
    global_observation.q3_request_hash ==
        q3_comparison.q3_request.request_hash &&
        global_observation.q3_result_hash == q3_comparison.q3_result.result_hash &&
        global_observation.q3_receipt_hash == q3_comparison.q3_receipt.receipt_hash &&
        global_observation.ledger_request_hash == static_ledger_request.request_hash &&
        global_observation.ledger_result_hash == static_ledger_result.result_hash &&
        global_observation.partition_request_hash == canonical_hash(partition_request) &&
        global_observation.partition_result_hash == canonical_hash(q3_upstream[13]) ||
        throw(ArgumentError("production artifact cross-identity mismatch"))
    request = make_regional_mhd_production_gap_request(candidate, context,
        q3_comparison, static_ledger_request, static_ledger_result,
        partition_request, global_observation)
    validate_regional_mhd_production_gap_request(request)
    request
end
