using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: canonical_hash, semantic_view

"""Independent deterministic cubature (5x5x5 midpoint cells) for the regional force.

This deliberately does not call q2/q3/q4 node generation or summation code.  It
reuses only the typed DESC provider and candidate-bound basis bridge objects.
"""
const _RFIC_REVISION = "regional-force-independent-cubature-v1"
const _RFIC_SOURCE = abspath(@__FILE__)
const _RFIC_TOKEN = Val(:regional_force_independent_cubature_private)
_rfic_sha(p) = Digest256(bytes2hex(SHA.sha256(read(p))))
_rfic_sum(v) = ntuple(k -> sum(x[k] for x in v), 3)
_rfic_norm(a) = norm(collect(a))
_rfic_diff(a,b) = _rfic_norm(ntuple(k -> b[k]-a[k], 3))

function _rfic_nodes(ids, rhs, shs, bounds, nfp)
    length(ids)==length(rhs)==length(shs)==length(bounds) || throw(ArgumentError("cubature partition length mismatch"))
    nfp > 0 || throw(ArgumentError("cubature nfp must be positive"))
    nodes = NamedTuple[]
    for j in eachindex(ids)
        lo, hi = Float64(bounds[j].rho_lower), Float64(bounds[j].rho_upper)
        isfinite(lo) && isfinite(hi) && 0 <= lo < hi <= 1 || throw(ArgumentError("invalid cubature bounds"))
        dr = (hi-lo)/5
        for ir in 1:5, it in 1:5, iz in 1:5
            p = DESCFieldSamplePointV4(lo+(ir-.5)*dr, (it-.5)*2pi/5, (iz-.5)*2pi/(5*nfp))
            push!(nodes, (region_id=ids[j], region_hash=rhs[j], region_support_hash=shs[j],
                local_index=(ir,it,iz), point=p, weight=dr*4pi^2/25))
        end
    end
    Tuple(nodes)
end

struct RegionalForceIndependentRequestV4
    revision::String; candidate_hash::Digest256; context_hash::Digest256
    partition_request_hash::Digest256; partition_result_hash::Digest256
    execution_request_hash::Digest256; execution_result_hash::Digest256; execution_receipt_hash::Digest256
    traction_request_hash::Digest256; traction_result_hash::Digest256; q2_request_hash::Digest256; q2_result_hash::Digest256; q2_receipt_hash::Digest256; q3_comparison_hash::Digest256; q4_comparison_hash::Digest256
    physical_support_hash::Digest256; partition_region_ids::Tuple; partition_region_hashes::Tuple
    partition_support_hashes::Tuple; partition_region_bounds::Tuple; partition_interface_hashes::Tuple; nfp::Int
    nodes::Tuple; quadrature::Symbol; field_request_hash::Digest256; basis_request_hash::Digest256
    relative_tolerance::Float64; absolute_tolerance_N::Float64; source_path::String; source_sha256::Digest256; request_hash::Digest256
    function RegionalForceIndependentRequestV4(t::Val{:regional_force_independent_cubature_private}, f...)
        t===_RFIC_TOKEN || throw(ArgumentError("private constructor")); new(f...)
    end
end
struct RegionalForceIndependentReceiptV4
    request_hash::Digest256; field_request_hash::Digest256; field_result_hash::Digest256; field_receipt_hash::Digest256
    basis_request_hash::Digest256; basis_result_hash::Digest256; basis_receipt_hash::Digest256
    output_path::String; output_sha256::Digest256; source_path::String; source_sha256::Digest256
    runtime_path::String; runtime_sha256::Digest256; receipt_hash::Digest256
    function RegionalForceIndependentReceiptV4(t::Val{:regional_force_independent_cubature_private}, f...)
        t===_RFIC_TOKEN || throw(ArgumentError("private constructor")); new(f...)
    end
end
struct RegionalForceIndependentResultV4
    request_hash::Digest256; receipt_hash::Digest256; region_force::Tuple; total_force::NTuple{3,Float64}; result_hash::Digest256
    function RegionalForceIndependentResultV4(t::Val{:regional_force_independent_cubature_private}, f...)
        t===_RFIC_TOKEN || throw(ArgumentError("private constructor")); new(f...)
    end
end
for T in (:RegionalForceIndependentRequestV4,:RegionalForceIndependentReceiptV4,:RegionalForceIndependentResultV4)
    @eval semantic_view(x::$T)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
end
function canonical_hash(x::RegionalForceIndependentRequestV4)
    expected=_rfic_nodes(x.partition_region_ids,x.partition_region_hashes,x.partition_support_hashes,x.partition_region_bounds,x.nfp)
    x.revision==_RFIC_REVISION && x.quadrature===:rho_midpoint5_theta_midpoint5_zeta_midpoint5 && isfinite(x.relative_tolerance)&&x.relative_tolerance>0&&isfinite(x.absolute_tolerance_N)&&x.absolute_tolerance_N>0 && x.nodes==expected && length(x.nodes)==125*length(x.partition_region_ids) &&
        all(n->isfinite(n.weight)&&n.weight>0&&canonical_hash(n.point)==n.point.point_hash,x.nodes) && isfile(x.source_path)&&_rfic_sha(x.source_path)==x.source_sha256 || throw(ArgumentError("invalid independent cubature request"))
    h=canonical_hash(semantic_view(x)); h==x.request_hash || throw(ArgumentError("independent request hash mismatch")); h
end
function canonical_hash(x::RegionalForceIndependentReceiptV4)
    isfile(x.source_path)&&_rfic_sha(x.source_path)==x.source_sha256&&isfile(x.runtime_path)&&_rfic_sha(x.runtime_path)==x.runtime_sha256 || throw(ArgumentError("invalid independent receipt provenance"))
    h=canonical_hash(semantic_view(x)); h==x.receipt_hash || throw(ArgumentError("independent receipt hash mismatch")); h
end
function canonical_hash(x::RegionalForceIndependentResultV4)
    !isempty(x.region_force)&&all(v->length(v)==3&&all(isfinite,v),x.region_force)&&all(isfinite,x.total_force)&&_rfic_sum(x.region_force)==x.total_force || throw(ArgumentError("invalid independent force"))
    h=canonical_hash(semantic_view(x)); h==x.result_hash || throw(ArgumentError("independent result hash mismatch")); h
end
_rfic_text(ids,v,t)=join(("REGION|$(ids[i])|$(v[i][1])|$(v[i][2])|$(v[i][3])" for i in eachindex(v)),"\n")*"\nTOTAL|$(t[1])|$(t[2])|$(t[3])\n"

function validate_regional_force_independent_receipt(receipt,request,fq,fr,bq,br,values,total)
    canonical_hash(receipt); canonical_hash(request); canonical_hash(fq); canonical_hash(fr); canonical_hash(bq); canonical_hash(br)
    receipt.request_hash==request.request_hash&&receipt.field_request_hash==canonical_hash(fq)&&receipt.field_result_hash==canonical_hash(fr)&&receipt.field_receipt_hash==canonical_hash(fr.receipt)&&receipt.basis_request_hash==canonical_hash(bq)&&receipt.basis_result_hash==canonical_hash(br)&&receipt.basis_receipt_hash==canonical_hash(br.receipt)&&isfile(receipt.output_path)&&_rfic_sha(receipt.output_path)==receipt.output_sha256&&read(receipt.output_path,String)==_rfic_text(request.partition_region_ids,values,total) || throw(ArgumentError("independent receipt chain mismatch"))
    receipt.receipt_hash
end

function _rfic_recompute(nodes, samples, ids)
    vals=Tuple(ntuple(k->sum(samples[i].F_cartesian_xyz_N_m3[k]*samples[i].sqrt_g_m3*nodes[i].weight for i in eachindex(nodes) if nodes[i].region_id==id),3) for id in ids)
    (region_force=vals,total_force=_rfic_sum(vals))
end

function validate_regional_force_independent_execution(upstream, traction_request, traction_result, q2_request, q2_result, q2_execution, q3_execution, q4_execution, execution)
    length(upstream)==17 || throw(ArgumentError("full chain tuple must have 17 typed entries"))
    (context,gb,ge,gp,er,es,ee,_,_,_,_,pr,ps,_,_,_,_)=upstream
    validate_regional_force_q4_execution(upstream,traction_request,traction_result,
        q2_request,q2_result,q2_execution,q3_execution,q4_execution)
    canonical_hash(execution.request); canonical_hash(execution.result)
    execution.result.request_hash==canonical_hash(execution.request) &&
        execution.result.receipt_hash==canonical_hash(execution.receipt) &&
        execution.request.context_hash==context.context_hash &&
        execution.request.execution_request_hash==canonical_hash(er) &&
        execution.request.execution_result_hash==canonical_hash(es) &&
        execution.request.execution_receipt_hash==canonical_hash(ee) &&
        execution.request.nfp==Int(er.runner_payload.nfp) &&
        execution.request.field_request_hash==canonical_hash(execution.field_request) &&
        execution.request.basis_request_hash==canonical_hash(execution.basis_request) &&
        execution.request.physical_support_hash==pr.physical_support_hash &&
        execution.request.partition_region_ids==Tuple(r.region_id for r in pr.regions) &&
        execution.request.partition_region_hashes==Tuple(r.region_hash for r in pr.regions) &&
        execution.request.partition_support_hashes==Tuple(r.region_support_hash for r in pr.regions) &&
        execution.request.partition_region_bounds==Tuple((rho_lower=Float64(r.rho_lower),rho_upper=Float64(r.rho_upper)) for r in pr.regions) &&
        execution.request.partition_interface_hashes==Tuple(canonical_hash(i) for i in pr.interfaces) ||
        throw(ArgumentError("independent current execution/partition binding mismatch"))
    canonical_hash(traction_request); canonical_hash(traction_result); canonical_hash(q2_request); canonical_hash(q2_result); canonical_hash(q2_result.receipt); canonical_hash(q3_execution.comparison); canonical_hash(q4_execution.comparison)
    execution.request.traction_request_hash==canonical_hash(traction_request) && execution.request.traction_result_hash==canonical_hash(traction_result) && execution.request.q2_request_hash==canonical_hash(q2_request) && execution.request.q2_result_hash==canonical_hash(q2_result) && execution.request.q2_receipt_hash==canonical_hash(q2_result.receipt) && execution.request.q3_comparison_hash==canonical_hash(q3_execution.comparison) && execution.request.q4_comparison_hash==canonical_hash(q4_execution.comparison) || throw(ArgumentError("independent upstream identity mismatch"))
    canonical_hash(pr); canonical_hash(ps)
    validate_desc_field_provider_result(context,er,es,ee,execution.field_request,execution.field_result)
    validate_desc_field_basis_bridge_result(context,gb,ge,gp,er,es,ee,execution.field_request,execution.field_result,execution.basis_request,execution.basis_result)
    validate_regional_force_independent_receipt(execution.receipt,execution.request,execution.field_request,execution.field_result,execution.basis_request,execution.basis_result,execution.result.region_force,execution.result.total_force)
    replay=_rfic_recompute(execution.request.nodes,execution.basis_result.samples,execution.request.partition_region_ids)
    replay.region_force==execution.result.region_force && replay.total_force==execution.result.total_force || throw(ArgumentError("independent replay mismatch"))
    q4=q4_execution.comparison.q4_total_force; d=_rfic_diff(q4,execution.result.total_force); rel=d/max(_rfic_norm(q4),eps()); expected=(d<=execution.request.absolute_tolerance_N||rel<=execution.request.relative_tolerance) ? :pass : :fail
    execution.q4_total_force==q4 && execution.absolute_difference_N==d && execution.relative_difference==rel && execution.comparison_status===expected || throw(ArgumentError("independent comparison envelope mismatch"))
    execution.request.candidate_hash==context.candidate_hash && execution.request.partition_request_hash==canonical_hash(pr) && execution.request.partition_result_hash==canonical_hash(ps) || throw(ArgumentError("independent request is not current candidate/partition"))
    execution.result.result_hash
end

function execute_regional_force_independent_cubature(upstream, traction_request, traction_result, q2_request, q2_result, q2_execution, q3_execution, q4_execution; run_dir, relative_tolerance=1e-3, absolute_tolerance_N=1e-6)
    isfinite(relative_tolerance)&&relative_tolerance>0&&isfinite(absolute_tolerance_N)&&absolute_tolerance_N>0 || throw(ArgumentError("invalid tolerances"))
    length(upstream)==17 || throw(ArgumentError("full chain tuple must have 17 typed entries"))
    (context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,_,_,_,_,partition_request,partition_result,_,_,_,_)=upstream
    meta=partition_request
    ids=Tuple(r.region_id for r in meta.regions); rhs=Tuple(r.region_hash for r in meta.regions); shs=Tuple(r.region_support_hash for r in meta.regions)
    bounds=Tuple((rho_lower=Float64(r.rho_lower),rho_upper=Float64(r.rho_upper)) for r in meta.regions); nfp=Int(execution_request.runner_payload.nfp)
    points=Tuple(n.point for n in _rfic_nodes(ids,rhs,shs,bounds,nfp))
    root=mkpath(run_dir); fq=make_desc_field_provider_request(context,execution_request,execution_result,execution_receipt,points)
    fr=execute_desc_field_provider(context,execution_request,execution_result,execution_receipt,fq; run_dir=joinpath(root,"field"))
    # Basis bridge is the typed candidate-owned metric provider; only its samples are consumed here.
    bq=make_desc_field_basis_bridge_request(context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,fq,fr)
    br=execute_desc_field_basis_bridge(context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,fq,fr,bq; run_dir=joinpath(root,"basis"))
    nodes=_rfic_nodes(ids,rhs,shs,bounds,nfp)
    vals=Tuple(ntuple(k->sum(br.samples[i].F_cartesian_xyz_N_m3[k]*br.samples[i].sqrt_g_m3*nodes[i].weight for i in eachindex(nodes) if nodes[i].region_id==id),3) for id in ids); total=_rfic_sum(vals)
    body=(revision=_RFIC_REVISION,candidate_hash=context.candidate_hash,context_hash=context.context_hash,partition_request_hash=canonical_hash(partition_request),partition_result_hash=canonical_hash(partition_result),execution_request_hash=canonical_hash(execution_request),execution_result_hash=canonical_hash(execution_result),execution_receipt_hash=canonical_hash(execution_receipt),traction_request_hash=canonical_hash(traction_request),traction_result_hash=canonical_hash(traction_result),q2_request_hash=canonical_hash(q2_request),q2_result_hash=canonical_hash(q2_result),q2_receipt_hash=canonical_hash(q2_result.receipt),q3_comparison_hash=canonical_hash(q3_execution.comparison),q4_comparison_hash=canonical_hash(q4_execution.comparison),physical_support_hash=partition_request.physical_support_hash,partition_region_ids=ids,partition_region_hashes=rhs,partition_support_hashes=shs,partition_region_bounds=bounds,partition_interface_hashes=Tuple(canonical_hash(i) for i in partition_request.interfaces),nfp=nfp,nodes=nodes,quadrature=:rho_midpoint5_theta_midpoint5_zeta_midpoint5,field_request_hash=canonical_hash(fq),basis_request_hash=canonical_hash(bq),relative_tolerance=relative_tolerance,absolute_tolerance_N=absolute_tolerance_N,source_path=_RFIC_SOURCE,source_sha256=_rfic_sha(_RFIC_SOURCE))
    req=RegionalForceIndependentRequestV4(_RFIC_TOKEN,values(body)...,canonical_hash(body)); out=joinpath(root,"regional_force_independent_result.tsv"); write(out,_rfic_text(ids,vals,total))
    rb=(request_hash=req.request_hash,field_request_hash=canonical_hash(fq),field_result_hash=canonical_hash(fr),field_receipt_hash=canonical_hash(fr.receipt),basis_request_hash=canonical_hash(bq),basis_result_hash=canonical_hash(br),basis_receipt_hash=canonical_hash(br.receipt),output_path=out,output_sha256=_rfic_sha(out),source_path=_RFIC_SOURCE,source_sha256=_rfic_sha(_RFIC_SOURCE),runtime_path=execution_receipt.python_executable,runtime_sha256=_rfic_sha(execution_receipt.python_executable))
    receipt=RegionalForceIndependentReceiptV4(_RFIC_TOKEN,values(rb)...,canonical_hash(rb)); resultbody=(request_hash=req.request_hash,receipt_hash=receipt.receipt_hash,region_force=vals,total_force=total); result=RegionalForceIndependentResultV4(_RFIC_TOKEN,values(resultbody)...,canonical_hash(resultbody)); validate_regional_force_independent_receipt(receipt,req,fq,fr,bq,br,vals,total)
    q4=q4_execution.comparison.q4_total_force; d=_rfic_diff(q4,total); rel=d/max(_rfic_norm(q4),eps()); status=(d<=absolute_tolerance_N||rel<=relative_tolerance) ? :pass : :fail
    execution=(request=req,result=result,receipt=receipt,field_request=fq,field_result=fr,basis_request=bq,basis_result=br,q4_total_force=q4,absolute_difference_N=d,relative_difference=rel,comparison_status=status,independent_replay_required=true,independent_code_validation=false,physical_validation=false,validation_uq=false,promotion_authority=false,terminal_authority=false,credible_device_count=0,evidence_credit=0,claim_ceiling=screen_only)
    validate_regional_force_independent_execution(upstream,traction_request,traction_result,q2_request,q2_result,q2_execution,q3_execution,q4_execution,execution)
    execution
end
