#= Candidate-bound numerical diagnostics and deterministic discrepancy propagation.

This module executes no new DESC process. It consumes revalidated field/basis
receipts, diagnoses periodic Cartesian-vector integration, and propagates the
observed formulation spread. That spread is neither a certified discretization
bound nor a probability distribution. Physical validation and parametric UQ
remain unsupported until candidate-applicable data and distributions exist.
=#
using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: canonical_hash, semantic_view

const _CVP_REVISION = "candidate-validation-propagation-v1"
const _CVP_SOURCE = abspath(@__FILE__)
_cvp_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_cvp_sum(xs) = ntuple(k -> sum(x[k] for x in xs), 3)
_cvp_norm(x) = sqrt(sum(abs2, x))

"Rotate an already laboratory-Cartesian vector into each physical field period."
function periodic_cartesian_sum_v4(v, nfp::Integer)
    nfp > 0 && length(v) == 3 && all(isfinite, v) ||
        throw(ArgumentError("finite three-vector and positive NFP required"))
    ntuple(k -> sum(begin
        a = 2pi * p / nfp
        k == 1 ? cos(a)*v[1]-sin(a)*v[2] :
        k == 2 ? sin(a)*v[1]+cos(a)*v[2] : v[3]
    end for p in 0:nfp-1), 3)
end

"A deterministic box propagated from executed formulation differences."
struct CandidateForceSpreadV4
    region_ids::Tuple
    center_N::Tuple
    radius_N::Tuple
    total_lower_N::NTuple{3,Float64}
    total_upper_N::NTuple{3,Float64}
    resultant_norm_interval_N::Tuple{Float64,Float64}
    interpretation::Symbol
    certified_error_bound::Bool
    probability_model::Bool
end
semantic_view(x::CandidateForceSpreadV4) = NamedTuple{fieldnames(typeof(x))}(
    ntuple(i -> getfield(x,i), fieldcount(typeof(x))))

function propagate_force_formulation_spread_v4(ids, center, alternatives)
    !isempty(ids) && length(unique(ids)) == length(ids) &&
        length(ids) == length(center) && !isempty(alternatives) &&
        all(v -> length(v)==3 && all(isfinite,v), center) &&
        all(a -> length(a)==length(center) &&
            all(v -> length(v)==3 && all(isfinite,v),a), alternatives) ||
        throw(ArgumentError("invalid regional formulation ensemble"))
    radii = Tuple(ntuple(k -> maximum(abs(a[i][k]-center[i][k])
        for a in alternatives),3) for i in eachindex(ids))
    lower = ntuple(k -> sum(center[i][k]-radii[i][k] for i in eachindex(ids)),3)
    upper = ntuple(k -> sum(center[i][k]+radii[i][k] for i in eachindex(ids)),3)
    near = ntuple(k -> lower[k] <= 0 <= upper[k] ? 0.0 : min(abs(lower[k]),abs(upper[k])),3)
    far = ntuple(k -> max(abs(lower[k]),abs(upper[k])),3)
    CandidateForceSpreadV4(Tuple(ids),Tuple(center),radii,lower,upper,
        (_cvp_norm(near),_cvp_norm(far)),:observed_formulation_spread,false,false)
end

"Independent cylindrical reconstruction; existing weights already include NFP."
function candidate_periodic_force_diagnostic_v4(nodes, samples, ids, nfp)
    nfp > 0 && !isempty(nodes) && length(nodes)==length(samples) &&
        !isempty(ids) && length(unique(ids))==length(ids) ||
        throw(ArgumentError("invalid periodic cubature inputs"))
    all(n -> n.region_id in ids && isfinite(n.weight) && n.weight>0,nodes) ||
        throw(ArgumentError("invalid periodic cubature region or weight"))
    all(i -> nodes[i].point.point_hash == samples[i].point_hash &&
        samples[i].sqrt_g_m3 > 0 && isfinite(samples[i].sqrt_g_m3) &&
        all(isfinite,samples[i].F_cylindrical_R_phi_Z_N_m3),eachindex(nodes)) ||
        throw(ArgumentError("periodic cubature sample identity mismatch"))
    records = Tuple(begin
        indices = findall(n -> n.region_id==id,nodes)
        isempty(indices) && throw(ArgumentError("empty periodic region"))
        full = ntuple(k -> sum(begin
            s = samples[i]; fr,ft,fz = s.F_cylindrical_R_phi_Z_N_m3
            phi = s.cylindrical_position_R_phi_Z[2]
            angle = phi + 2pi*p/nfp
            component = k==1 ? fr*cos(angle)-ft*sin(angle) :
                k==2 ? fr*sin(angle)+ft*cos(angle) : fz
            component*s.sqrt_g_m3*nodes[i].weight/nfp
        end for i in indices for p in 0:nfp-1),3)
        proxy = ntuple(k -> sum(samples[i].F_cartesian_xyz_N_m3[k]*
            samples[i].sqrt_g_m3*nodes[i].weight for i in indices),3)
        l1 = sum(_cvp_norm(samples[i].F_cylindrical_R_phi_Z_N_m3)*
            samples[i].sqrt_g_m3*nodes[i].weight for i in indices)
        volume = sum(samples[i].sqrt_g_m3*nodes[i].weight for i in indices)
        (region_id=id,periodic_full_torus_force_N=full,
            sector_replicated_cartesian_proxy_N=proxy,
            local_force_magnitude_integral_N=l1,volume_m3=volume)
    end for id in ids)
    (regions=records,periodic_full_torus_force_N=_cvp_sum(Tuple(r.periodic_full_torus_force_N for r in records)),
        sector_replicated_cartesian_proxy_N=_cvp_sum(Tuple(r.sector_replicated_cartesian_proxy_N for r in records)),
        local_force_magnitude_integral_N=sum(r.local_force_magnitude_integral_N for r in records),
        volume_m3=sum(r.volume_m3 for r in records),
        max_phi_minus_zeta_rad=maximum(abs(s.cylindrical_position_R_phi_Z[2]-s.zeta_rad) for s in samples),
        scope=:desc_periodic_model_inference,
        explicit_all_periods_provider_execution=false)
end

"Analytic vector/scalar integration benchmark; exclusively code verification."
function execute_periodic_force_benchmark_v4()
    nfp=3; count=24; width=2pi/(nfp*count)
    angles=Tuple((i-.5)*width for i in 1:count)
    sector=ntuple(k -> sum((k==1 ? cos(a) : k==2 ? sin(a) : 1.0)*width for a in angles),3)
    computed=periodic_cartesian_sum_v4(sector,nfp)
    exact=(0.0,0.0,2pi)
    error=_cvp_norm(ntuple(k -> computed[k]-exact[k],3))
    proxy=ntuple(k -> nfp*sector[k],3)
    # Integral rho^2 on [0,1] gives 1/3. Separate midpoint implementation.
    coarse=sum(((i-.5)/4)^2/4 for i in 1:4)
    fine=sum(((i-.5)/8)^2/8 for i in 1:8)
    (benchmark=:analytic_periodic_vector_and_radial_polynomial,
        source_kind=:analytic_code_verification,computed= computed,exact=exact,
        vector_absolute_error=error,unrotated_proxy_error=_cvp_norm(ntuple(k->proxy[k]-exact[k],3)),
        midpoint_coarse_error=abs(coarse-1/3),midpoint_fine_error=abs(fine-1/3),
        observed_error_ratio=abs(coarse-1/3)/abs(fine-1/3),
        status=error<1e-12 && abs(fine-1/3)<abs(coarse-1/3) ? :pass : :fail,
        physical_validation_credit=0)
end

struct CandidateValidationPropagationResultV4
    revision::String
    candidate_hash::Digest256
    context_hash::Digest256
    upstream_hashes::Tuple
    nfp::Int
    region_ids::Tuple
    quadrature_diagnostics::Tuple
    force_spread::CandidateForceSpreadV4
    benchmark::NamedTuple
    local_force_integral_relative_spread::Float64
    numerical_status::Symbol
    numerical_diagnostic_executed::Bool
    error_propagation_executed::Bool
    physical_validation_executed::Bool
    parametric_uq_executed::Bool
    gaps::Tuple
    claim_ceiling::ClaimCeiling
    physical_validation_credit::Int
    source_path::String
    source_sha256::Digest256
    output_path::String
    output_sha256::Digest256
    result_hash::Digest256
end
semantic_view(x::CandidateValidationPropagationResultV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(
    ntuple(i -> getfield(x,i),fieldcount(typeof(x))-1))

function _cvp_report_text(candidate,nfp,diagnostics,spread,benchmark,status,gaps)
    lines=String["candidate_hash=$(candidate)","nfp=$(nfp)","numerical_status=$(status)",
        "benchmark_status=$(benchmark.status)","benchmark_vector_error=$(benchmark.vector_absolute_error)",
        "error_interpretation=observed formulation spread; not certified or probabilistic"]
    for d in diagnostics
        push!(lines,"$(d.label)_periodic_full_torus_force_N=$(d.value.periodic_full_torus_force_N)")
        push!(lines,"$(d.label)_sector_replicated_cartesian_proxy_N=$(d.value.sector_replicated_cartesian_proxy_N)")
        push!(lines,"$(d.label)_local_force_magnitude_integral_N=$(d.value.local_force_magnitude_integral_N)")
        push!(lines,"$(d.label)_volume_m3=$(d.value.volume_m3)")
    end
    push!(lines,"resultant_norm_spread_interval_N=$(spread.resultant_norm_interval_N)")
    append!(lines,["gap=$(g.kind)|$(g.status)|$(g.detail)" for g in gaps])
    join(lines,"\n")*"\n"
end

function canonical_hash(x::CandidateValidationPropagationResultV4)
    x.revision==_CVP_REVISION && x.nfp>0 && !isempty(x.region_ids) &&
        x.claim_ceiling==screen_only && x.physical_validation_credit==0 &&
        x.numerical_diagnostic_executed && x.error_propagation_executed &&
        !x.physical_validation_executed && !x.parametric_uq_executed &&
        !x.force_spread.certified_error_bound && !x.force_spread.probability_model &&
        isfile(x.source_path) && _cvp_sha(x.source_path)==x.source_sha256 &&
        isfile(x.output_path) && _cvp_sha(x.output_path)==x.output_sha256 ||
        throw(ArgumentError("invalid validation diagnostic evidence or authority"))
    read(x.output_path,String)==_cvp_report_text(x.candidate_hash,x.nfp,
        x.quadrature_diagnostics,x.force_spread,x.benchmark,x.numerical_status,x.gaps) ||
        throw(ArgumentError("validation diagnostic output differs from result"))
    expected=canonical_hash(semantic_view(x))
    x.result_hash==expected || throw(ArgumentError("validation diagnostic hash mismatch"))
    expected
end

function _cvp_owner_call(object,name,args...)
    owner=parentmodule(typeof(object))
    isdefined(owner,name) || throw(ArgumentError("missing upstream validator $name"))
    getfield(owner,name)(args...)
end

function execute_candidate_validation_propagation(upstream,traction_request,
        traction_result,q2_request,q2_result,q2_execution,q3_execution,
        q4_execution,independent_execution;run_dir)
    _cvp_owner_call(q4_execution.comparison,:validate_regional_force_q4_execution,
        upstream,traction_request,traction_result,q2_request,q2_result,q2_execution,
        q3_execution,q4_execution)
    _cvp_owner_call(independent_execution.request,:validate_regional_force_independent_execution,
        upstream,traction_request,traction_result,q2_request,q2_result,q2_execution,
        q3_execution,q4_execution,independent_execution)
    context=upstream[1]; nfp=Int(upstream[5].runner_payload.nfp)
    ids=Tuple(r.region_id for r in upstream[12].regions)
    q3=q3_execution.comparison; q4=q4_execution.comparison
    inputs=((:gauss3,q3.q3_request.nodes,q3_execution.br.samples),
        (:gauss4,q4.q4_request.nodes,q4_execution.br.samples),
        (:midpoint_independent,independent_execution.request.nodes,independent_execution.basis_result.samples))
    diagnostics=Tuple((label=label,value=candidate_periodic_force_diagnostic_v4(nodes,samples,ids,nfp))
        for (label,nodes,samples) in inputs)
    center=Tuple(r.periodic_full_torus_force_N for r in diagnostics[2].value.regions)
    alternatives=Tuple(Tuple(r.periodic_full_torus_force_N for r in d.value.regions)
        for d in (diagnostics[1],diagnostics[3]))
    spread=propagate_force_formulation_spread_v4(ids,center,alternatives)
    l1=Tuple(d.value.local_force_magnitude_integral_N for d in diagnostics)
    relative_spread=(maximum(l1)-minimum(l1))/max(maximum(l1),eps())
    status=relative_spread>independent_execution.request.relative_tolerance ? :fail : :deferred
    benchmark=execute_periodic_force_benchmark_v4()
    gaps=(
        (kind=:solution_verification,status=status,recoverable=true,executed=true,
            detail="periodic reconstruction and local residual integral executed; no asymptotic convergence or certified error bound"),
        (kind=:independent_physics_code,status=:unsupported,recoverable=true,executed=false,
            detail="quadrature implementations differ but DESC and geometry provider are shared"),
        (kind=:physical_validation,status=:unsupported,recoverable=true,executed=false,
            detail="no candidate-applicable held-out experimental data with measurement uncertainty"),
        (kind=:parameter_uq,status=:unsupported,recoverable=true,executed=false,
            detail="no candidate input distributions, covariance, or sampled provider reruns"),
        (kind=:model_form_uq,status=:unsupported,recoverable=true,executed=false,
            detail="no validated model discrepancy or transfer uncertainty model"))
    output=joinpath(mkpath(run_dir),"candidate_validation_propagation.txt")
    write(output,_cvp_report_text(context.candidate_hash,nfp,diagnostics,spread,benchmark,status,gaps))
    hashes=(canonical_hash(upstream[5]),canonical_hash(upstream[6]),canonical_hash(upstream[7]),
        canonical_hash(upstream[12]),canonical_hash(upstream[13]),canonical_hash(q2_result),
        canonical_hash(q3),canonical_hash(q4),canonical_hash(independent_execution.result))
    body=(revision=_CVP_REVISION,candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        upstream_hashes=hashes,nfp=nfp,region_ids=ids,quadrature_diagnostics=diagnostics,
        force_spread=spread,benchmark=benchmark,local_force_integral_relative_spread=relative_spread,
        numerical_status=status,numerical_diagnostic_executed=true,error_propagation_executed=true,
        physical_validation_executed=false,parametric_uq_executed=false,gaps=gaps,claim_ceiling=screen_only,
        physical_validation_credit=0,source_path=_CVP_SOURCE,source_sha256=_cvp_sha(_CVP_SOURCE),
        output_path=output,output_sha256=_cvp_sha(output))
    result=CandidateValidationPropagationResultV4(values(body)...,canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_candidate_validation_propagation(result,upstream,traction_request,
        traction_result,q2_request,q2_result,q2_execution,q3_execution,q4_execution,independent_execution)
    canonical_hash(result)
    fresh=execute_candidate_validation_propagation(upstream,traction_request,traction_result,
        q2_request,q2_result,q2_execution,q3_execution,q4_execution,independent_execution;
        run_dir=mktempdir(prefix="validation_propagation_replay_"))
    for key in (:candidate_hash,:context_hash,:upstream_hashes,:nfp,:region_ids,
            :quadrature_diagnostics,:force_spread,:benchmark,:local_force_integral_relative_spread,
            :numerical_status,:gaps)
        canonical_hash(getfield(result,key))==canonical_hash(getfield(fresh,key)) ||
            throw(ArgumentError("validation diagnostic replay mismatch: $key"))
    end
    result.result_hash
end
