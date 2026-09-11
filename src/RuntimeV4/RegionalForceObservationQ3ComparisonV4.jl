using FusionConceptAI
using SHA
using LinearAlgebra
const _RFQ3_REVISION="regional-force-observation-q3-comparison-v2"
const _RFQ3_SOURCE=abspath(@__FILE__)
_rfq3_sha(p)=Digest256(bytes2hex(SHA.sha256(read(p))))

struct RegionalForceQ3RequestV4
    revision::String; candidate_hash::Digest256; context_hash::Digest256
    partition_request_hash::Digest256; partition_result_hash::Digest256
    execution_request_hash::Digest256; execution_result_hash::Digest256; execution_receipt_hash::Digest256
    physical_support_hash::Digest256; partition_region_ids::Tuple; partition_region_hashes::Tuple
    partition_support_hashes::Tuple; partition_interface_hashes::Tuple; nfp::Int
    nodes::Tuple; quadrature::Symbol; field_request_hash::Digest256
    basis_request_hash::Digest256; source_path::String; source_sha256::Digest256
    request_hash::Digest256
end
struct RegionalForceQ3ReceiptV4
    request_hash::Digest256; field_request_hash::Digest256; field_result_hash::Digest256
    field_receipt_hash::Digest256; basis_request_hash::Digest256; basis_result_hash::Digest256
    basis_receipt_hash::Digest256; output_path::String; output_sha256::Digest256
    source_path::String; source_sha256::Digest256; runtime_path::String
    runtime_sha256::Digest256; receipt_hash::Digest256
end
struct RegionalForceQ3ResultV4
    request_hash::Digest256; receipt_hash::Digest256; region_force::Tuple
    total_force::NTuple{3,Float64}; result_hash::Digest256
end
for T in (:RegionalForceQ3RequestV4,:RegionalForceQ3ReceiptV4,:RegionalForceQ3ResultV4)
    @eval semantic_view(x::$T)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
end
canonical_hash(x::RegionalForceQ3RequestV4)=begin
    ids=Tuple(n.region_id for n in x.nodes)
    region_groups=Dict{String,Vector{Any}}()
    for n in x.nodes
        hasproperty(n,:region_id) && push!(get!(region_groups,n.region_id,Any[]), n)
    end
    valid_nodes=!isempty(x.nodes) && all(n -> n isa NamedTuple &&
        hasproperty(n,:region_id) && hasproperty(n,:point) && hasproperty(n,:weight) &&
        hasproperty(n,:region_hash) && hasproperty(n,:region_support_hash) &&
        hasproperty(n,:local_index) && length(n.local_index)==3 &&
        all(i -> i in 1:3, n.local_index) &&
        n.point isa DESCFieldSamplePointV4 && isfinite(n.weight) && n.weight > 0.0 &&
        canonical_hash(n.point) == n.point.point_hash, x.nodes)
    unique_indices=all(length(group) == 27 &&
        length(unique(Tuple(n.local_index for n in group))) == 27
        for group in values(region_groups))
    region_hashes=Tuple(first(group).region_hash for group in values(region_groups)
        if hasproperty(first(group),:region_hash))
    support_hashes=Tuple(first(group).region_support_hash for group in values(region_groups)
        if hasproperty(first(group),:region_support_hash))
    region_map=Dict(id=>(first(group).region_hash,first(group).region_support_hash)
        for (id,group) in region_groups)
    partition_match=length(region_groups)==length(x.partition_region_ids) &&
        Set(keys(region_groups)) == Set(x.partition_region_ids) &&
        Set(region_hashes) == Set(x.partition_region_hashes) &&
        Set(support_hashes) == Set(x.partition_support_hashes) &&
        all(haskey(region_map,id) && region_map[id] ==
            (x.partition_region_hashes[i],x.partition_support_hashes[i])
            for (i,id) in enumerate(x.partition_region_ids))
    x.revision==_RFQ3_REVISION &&
        x.quadrature===:rho_gauss3_theta_midpoint3_zeta_midpoint3 &&
        x.nfp > 0 && length(x.nodes) == 27 * length(region_groups) && valid_nodes && unique_indices && partition_match && isfile(x.source_path) &&
        _rfq3_sha(x.source_path)==x.source_sha256 ||
        throw(ArgumentError("invalid q3 request"))
    h=canonical_hash(semantic_view(x)); h==x.request_hash ||
        throw(ArgumentError("q3 request hash mismatch")); h
end
canonical_hash(x::RegionalForceQ3ReceiptV4)=begin h=canonical_hash(semantic_view(x)); h==x.receipt_hash || throw(ArgumentError("q3 receipt hash mismatch")); h end
_rfq3_output_text(vals,total)=join(("REGION|$(i)|$(v[1])|$(v[2])|$(v[3])" for (i,v) in enumerate(vals)),"\n") *
    "\nTOTAL|$(total[1])|$(total[2])|$(total[3])\n"
function validate_regional_force_q3_receipt(receipt, request, fq, fr, bq, br,
        vals, total)
    canonical_hash(receipt); canonical_hash(request); canonical_hash(fq)
    canonical_hash(fr); canonical_hash(bq); canonical_hash(br)
    receipt.request_hash == request.request_hash &&
        receipt.field_request_hash == canonical_hash(fq) &&
        receipt.field_result_hash == canonical_hash(fr) &&
        receipt.field_receipt_hash == canonical_hash(fr.receipt) &&
        receipt.basis_request_hash == canonical_hash(bq) &&
        receipt.basis_result_hash == canonical_hash(br) &&
        receipt.basis_receipt_hash == canonical_hash(br.receipt) &&
        isfile(receipt.output_path) && _rfq3_sha(receipt.output_path) == receipt.output_sha256 &&
        read(receipt.output_path,String) == _rfq3_output_text(vals,total) &&
        receipt.source_path == _RFQ3_SOURCE && isfile(receipt.source_path) &&
        _rfq3_sha(receipt.source_path) == receipt.source_sha256 &&
        isfile(receipt.runtime_path) && _rfq3_sha(receipt.runtime_path) == receipt.runtime_sha256 ||
        throw(ArgumentError("q3 receipt artifact or upstream identity mismatch"))
    receipt.receipt_hash
end
_rfq3_sum(v)=ntuple(k->sum(r[k] for r in v),3)
_rfq3_vectors_isapprox(a,b;rtol,atol)=length(a)==length(b) &&
    all(length(x)==length(y) && all(isapprox(x[i],y[i];rtol=rtol,atol=atol)
        for i in eachindex(x)) for (x,y) in zip(a,b))
canonical_hash(x::RegionalForceQ3ResultV4)=begin
    all(r->length(r)==3 && all(isfinite,r),x.region_force) &&
        all(isfinite,x.total_force) && _rfq3_sum(x.region_force)==x.total_force ||
        throw(ArgumentError("invalid q3 force values"))
    h=canonical_hash(semantic_view(x)); h==x.result_hash ||
        throw(ArgumentError("q3 result hash mismatch")); h
end

struct RegionalForceQ3ComparisonV4
    candidate_hash::Digest256; context_hash::Digest256; q2_request_hash::Digest256; q2_result_hash::Digest256; q2_receipt_hash::Digest256
    q3_request::RegionalForceQ3RequestV4; q3_result::RegionalForceQ3ResultV4; q3_receipt::RegionalForceQ3ReceiptV4
    q2_region_force::Tuple; q3_region_force::Tuple; q2_total_force::NTuple{3,Float64}; q3_total_force::NTuple{3,Float64}
    absolute_difference_N::Float64; relative_difference::Float64; fresh_q3_executed::Bool; independent_replay_required::Bool
    convergence_validated::Bool; evidence_credit::Int; claim_ceiling::ClaimCeiling; source_path::String; source_sha256::Digest256; comparison_hash::Digest256
end
semantic_view(x::RegionalForceQ3ComparisonV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::RegionalForceQ3ComparisonV4)
    canonical_hash(x.q3_request); canonical_hash(x.q3_result); canonical_hash(x.q3_receipt)
    x.q3_result.request_hash == x.q3_request.request_hash &&
        x.q3_result.receipt_hash == x.q3_receipt.receipt_hash ||
        throw(ArgumentError("q3 request/result/receipt identity mismatch"))
    all(r->length(r)==3 && all(isfinite,r), x.q2_region_force) &&
        all(r->length(r)==3 && all(isfinite,r), x.q3_region_force) &&
        all(isfinite,x.q2_total_force) && all(isfinite,x.q3_total_force) &&
        _rfq3_sum(x.q2_region_force)==x.q2_total_force &&
        _rfq3_sum(x.q3_region_force)==x.q3_total_force &&
        x.q3_region_force == x.q3_result.region_force &&
        x.q3_total_force == x.q3_result.total_force ||
        throw(ArgumentError("q3 comparison force copy mismatch"))
    expected_difference=norm(collect(ntuple(k->
        x.q3_total_force[k]-x.q2_total_force[k],3)))
    expected_relative=expected_difference/max(norm(collect(x.q2_total_force)),eps())
    isfinite(x.absolute_difference_N) && isfinite(x.relative_difference) &&
        x.absolute_difference_N == expected_difference &&
        x.relative_difference == expected_relative ||
        throw(ArgumentError("q3 comparison difference mismatch"))
    x.fresh_q3_executed && x.independent_replay_required && !x.convergence_validated && x.evidence_credit==0 && x.claim_ceiling==screen_only && isfile(x.source_path) && _rfq3_sha(x.source_path)==x.source_sha256 || throw(ArgumentError("q3 comparison authority exceeded"))
    h=canonical_hash(semantic_view(x)); h==x.comparison_hash || throw(ArgumentError("comparison hash mismatch")); h
end

function _rfq3_nodes(partition_request,nfp)
    xi=(-sqrt(3/5),0.0,sqrt(3/5)); rw=(5/9,8/9,5/9); tw=2pi/3; zw=2pi/(3nfp); out=NamedTuple[]
    for region in partition_request.regions
        mid=(region.rho_lower+region.rho_upper)/2; half=(region.rho_upper-region.rho_lower)/2
        for ir in 1:3,it in 1:3,iz in 1:3
            point=DESCFieldSamplePointV4(mid+half*xi[ir],(it-.5)*tw,(iz-.5)*zw)
            push!(out,(region_id=region.region_id,region_hash=region.region_hash,
                region_support_hash=region.region_support_hash,
                local_index=(ir,it,iz),point=point,
                weight=half*rw[ir]*tw*zw*nfp))
        end
    end
    Tuple(out)
end

function execute_regional_force_q3(upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution; run_dir)
    length(upstream)==17 || throw(ArgumentError("full chain tuple must have 17 typed entries"))
    (context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,field_request,field_result,basis_request,basis_result,partition_request,partition_result,surface_request,surface_result,pressure_request,pressure_result)=upstream
    validate_desc_regional_integrated_force_observation_request(upstream...,
        traction_request, traction_result, q2_request)
    q2_execution.observation === q2_result ||
        throw(ArgumentError("q2 execution/result identity mismatch"))
    validate_desc_regional_integrated_force_observation_result(upstream...,
        traction_request, traction_result, q2_request,
        q2_execution.field_request, q2_execution.field_result,
        q2_execution.basis_request, q2_execution.basis_result, q2_result)
    canonical_hash(q2_result); canonical_hash(partition_request); canonical_hash(partition_result)
    q2_result.context_hash==context.context_hash && q2_result.candidate_hash==context.candidate_hash || throw(ArgumentError("q2 chain identity mismatch"))
    nfp=Int(execution_request.runner_payload.nfp); nodes=_rfq3_nodes(partition_request,nfp); points=Tuple(n.point for n in nodes)
    fq=make_desc_field_provider_request(context,execution_request,execution_result,execution_receipt,points)
    fr=execute_desc_field_provider(context,execution_request,execution_result,execution_receipt,fq;run_dir=joinpath(String(run_dir),"field"))
    bq=make_desc_field_basis_bridge_request(context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,fq,fr)
    br=execute_desc_field_basis_bridge(context,geometry_bridge,geometry_evaluation,geometry_proof,execution_request,execution_result,execution_receipt,fq,fr,bq;run_dir=joinpath(String(run_dir),"basis"))
    reqbody=(revision=_RFQ3_REVISION,candidate_hash=context.candidate_hash,context_hash=context.context_hash,partition_request_hash=canonical_hash(partition_request),partition_result_hash=canonical_hash(partition_result),execution_request_hash=canonical_hash(execution_request),execution_result_hash=canonical_hash(execution_result),execution_receipt_hash=canonical_hash(execution_receipt),physical_support_hash=partition_request.physical_support_hash,partition_region_ids=Tuple(r.region_id for r in partition_request.regions),partition_region_hashes=Tuple(r.region_hash for r in partition_request.regions),partition_support_hashes=Tuple(r.region_support_hash for r in partition_request.regions),partition_interface_hashes=Tuple(canonical_hash(i) for i in partition_request.interfaces),nfp=nfp,nodes=nodes,quadrature=:rho_gauss3_theta_midpoint3_zeta_midpoint3,field_request_hash=canonical_hash(fq),basis_request_hash=canonical_hash(bq),source_path=_RFQ3_SOURCE,source_sha256=_rfq3_sha(_RFQ3_SOURCE))
    q3req=RegionalForceQ3RequestV4(values(reqbody)...,canonical_hash(reqbody))
    vals=Tuple(ntuple(k->sum(br.samples[i].F_cartesian_xyz_N_m3[k]*br.samples[i].sqrt_g_m3*nodes[i].weight for i in findall(n->n.region_id==reg.region_id,nodes)),3) for reg in partition_request.regions)
    total=ntuple(k->sum(v[k] for v in vals),3); q2tot=q2_result.observed_total_force_xyz_N; ad=norm(collect(ntuple(k->total[k]-q2tot[k],3))); rd=ad/max(norm(collect(q2tot)),eps())
    output_path=joinpath(String(run_dir),"regional_force_q3_result.tsv"); mkpath(dirname(output_path))
    write(output_path,_rfq3_output_text(vals,total))
    recbody=(request_hash=q3req.request_hash,field_request_hash=canonical_hash(fq),field_result_hash=canonical_hash(fr),field_receipt_hash=canonical_hash(fr.receipt),basis_request_hash=canonical_hash(bq),basis_result_hash=canonical_hash(br),basis_receipt_hash=canonical_hash(br.receipt),output_path=output_path,output_sha256=_rfq3_sha(output_path),source_path=_RFQ3_SOURCE,source_sha256=_rfq3_sha(_RFQ3_SOURCE),runtime_path=execution_receipt.python_executable,runtime_sha256=_rfq3_sha(execution_receipt.python_executable))
    rec=RegionalForceQ3ReceiptV4(values(recbody)...,canonical_hash(recbody)); resbody=(request_hash=q3req.request_hash,receipt_hash=rec.receipt_hash,region_force=vals,total_force=total); q3res=RegionalForceQ3ResultV4(values(resbody)...,canonical_hash(resbody))
    validate_regional_force_q3_receipt(rec,q3req,fq,fr,bq,br,vals,total)
    compbody=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,q2_request_hash=canonical_hash(q2_request),q2_result_hash=canonical_hash(q2_result),q2_receipt_hash=canonical_hash(q2_result.receipt),q3_request=q3req,q3_result=q3res,q3_receipt=rec,q2_region_force=Tuple(r.integrated_force_xyz_N for r in q2_result.region_observations),q3_region_force=vals,q2_total_force=q2tot,q3_total_force=total,absolute_difference_N=ad,relative_difference=rd,fresh_q3_executed=true,independent_replay_required=true,convergence_validated=false,evidence_credit=0,claim_ceiling=screen_only,source_path=_RFQ3_SOURCE,source_sha256=_rfq3_sha(_RFQ3_SOURCE))
    comparison=RegionalForceQ3ComparisonV4(values(compbody)...,canonical_hash(compbody))
    (comparison=comparison, fq=fq, fr=fr, bq=bq, br=br)
end
function validate_regional_force_q3_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, execution)
    comparison=execution.comparison
    length(upstream)==17 || throw(ArgumentError("full chain tuple must have 17 typed entries"))
    (context,gb,ge,gp,er,eres,erc,field_request,field_result,basis_request,
        basis_result,partition_request,partition_result,surface_request,
        surface_result,pressure_request,pressure_result)=upstream
    validate_desc_regional_integrated_force_observation_request(upstream...,
        traction_request, traction_result, q2_request)
    q2_execution.observation === q2_result || throw(ArgumentError("q2 execution/result identity mismatch"))
    validate_desc_regional_integrated_force_observation_result(upstream...,
        traction_request, traction_result, q2_request, q2_execution.field_request,
        q2_execution.field_result, q2_execution.basis_request,
        q2_execution.basis_result, q2_result)
    q3req=comparison.q3_request
    q3req.execution_request_hash==canonical_hash(er) &&
        q3req.execution_result_hash==canonical_hash(eres) &&
        q3req.execution_receipt_hash==canonical_hash(erc) &&
        q3req.partition_request_hash==canonical_hash(partition_request) &&
        q3req.partition_result_hash==canonical_hash(partition_result) &&
        q3req.nfp==Int(er.runner_payload.nfp) &&
        q3req.physical_support_hash==partition_request.physical_support_hash &&
        q3req.partition_region_ids==Tuple(r.region_id for r in partition_request.regions) &&
        q3req.partition_region_hashes==Tuple(r.region_hash for r in partition_request.regions) &&
        q3req.partition_support_hashes==Tuple(r.region_support_hash for r in partition_request.regions) &&
        q3req.partition_interface_hashes==Tuple(canonical_hash(i) for i in partition_request.interfaces) ||
        throw(ArgumentError("q3 request upstream identity mismatch"))
    validate_desc_field_provider_result(context,er,eres,erc, execution.fq, execution.fr)
    validate_desc_field_basis_bridge_result(context,gb,ge,gp,er,eres,erc,
        execution.fq,execution.fr,execution.bq,execution.br)
    vals=comparison.q3_result.region_force; total=comparison.q3_result.total_force
    validate_regional_force_q3_receipt(comparison.q3_receipt,q3req,execution.fq,
        execution.fr,execution.bq,execution.br,vals,total)
    canonical_hash(comparison)
end
validate_regional_force_q3_comparison(x::RegionalForceQ3ComparisonV4)=canonical_hash(x)

function validate_regional_force_q3_comparison(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution,
        execution, comparison::RegionalForceQ3ComparisonV4; run_dir)
    canonical_hash(q2_request); canonical_hash(q2_result); canonical_hash(comparison)
    comparison.candidate_hash == q2_result.candidate_hash &&
        comparison.context_hash == q2_result.context_hash &&
        comparison.q2_request_hash == canonical_hash(q2_request) &&
    comparison.q2_result_hash == canonical_hash(q2_result) &&
        comparison.q2_region_force ==
            Tuple(r.integrated_force_xyz_N for r in q2_result.region_observations) &&
        comparison.q2_total_force == q2_result.observed_total_force_xyz_N ||
        throw(ArgumentError("q2 comparison identity mismatch"))
    validate_regional_force_q3_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, execution)
    fresh = execute_regional_force_q3(upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution; run_dir=joinpath(String(run_dir),"replay"))
    fresh.comparison.q3_request.nodes == comparison.q3_request.nodes &&
        _rfq3_vectors_isapprox(fresh.comparison.q3_result.region_force,
            comparison.q3_result.region_force; rtol=1e-8, atol=1e-10) &&
        _rfq3_vectors_isapprox((fresh.comparison.q3_result.total_force,),
            (comparison.q3_result.total_force,); rtol=1e-8, atol=1e-10) &&
        isapprox(fresh.comparison.absolute_difference_N, comparison.absolute_difference_N;
            rtol=1e-8, atol=1e-10) &&
        isapprox(fresh.comparison.relative_difference, comparison.relative_difference;
            rtol=0, atol=1e-14) &&
        fresh.comparison.q3_receipt.output_path != comparison.q3_receipt.output_path ||
        throw(ArgumentError("q3 comparison differs from independent replay"))
    comparison.comparison_hash
end
