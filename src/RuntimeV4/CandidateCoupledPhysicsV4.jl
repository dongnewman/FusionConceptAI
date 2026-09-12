#= Real candidate-bound static-MHD weak-volume execution.

The constitutive stress is T=(p+B.B/(2mu0))I-BB'/mu0. This module executes
integrals of T grad(phi) and phi F for phi=(1,x/L,y/L,z/L), with a Jacobian
with respect to sampled p/B. It does NOT fill absent source/boundary terms,
differentiate the DESC solution, or call a coupled PDE solver. The result is
therefore deliberately deferred, even when its numerical kernel passes.
=#
using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: Digest256, canonical_hash, semantic_view, screen_only

const _CCP_REVISION = "candidate-coupled-physics-weak-volume-v1"
const _CCP_SOURCE = abspath(@__FILE__)
const _CCP_MU0 = 1.25663706127e-6
const _CCP_TOKEN = Val(:candidate_coupled_physics_private)
const _CCP_UNITS=(position="m",pressure="Pa",magnetic_field="T",force_density="N m^-3",measure="m^3",test="1",gradient="m^-1",weak_volume="N",strong_moment="N",jacobian_pressure_column="N Pa^-1",jacobian_magnetic_column="N T^-1")
const _CCP_DIMENSIONS=(position=UnitSignature((0,1,0,0,0,0,0)),pressure=UnitSignature((1,-1,-2,0,0,0,0)),
    magnetic_field=UnitSignature((1,0,-2,-1,0,0,0)),force_density=UnitSignature((1,-2,-2,0,0,0,0)),
    measure=UnitSignature((0,3,0,0,0,0,0)),test=UnitSignature((0,0,0,0,0,0,0)),
    gradient=UnitSignature((0,-1,0,0,0,0,0)),weak_volume=UnitSignature((1,1,-2,0,0,0,0)),
    strong_moment=UnitSignature((1,1,-2,0,0,0,0)),jacobian_pressure_column=UnitSignature((0,2,0,0,0,0,0)),
    jacobian_magnetic_column=UnitSignature((0,1,0,1,0,0,0)))
const _CCP_TESTS=(:constant,:cartesian_x_over_reference_length,:cartesian_y_over_reference_length,:cartesian_z_over_reference_length)
const _CCP_GAPS = (
    :candidate_owned_regional_test_space_and_full_state_dof_map,
    :candidate_owned_external_body_source_declaration,
    :rho_boundary_surface_quadrature_and_boundary_limit_provider,
    :complete_regional_volume_source_boundary_residual,
    :full_state_regional_and_interface_coupled_jacobian,
    :global_conservation_with_exterior_flux_and_sources,
    :actual_candidate_multiregion_nonlinear_solve)
_ccp_sha(p) = Digest256(bytes2hex(SHA.sha256(read(p))))
_ccp_tuple(A) = Tuple(Tuple(A[i,j] for j in axes(A,2)) for i in axes(A,1))
_ccp_rotation(a) = [cos(a) -sin(a) 0.0; sin(a) cos(a) 0.0; 0.0 0.0 1.0]

function _ccp_stress(p, B)
    (p + dot(B,B)/(2*_CCP_MU0))*Matrix{Float64}(I,3,3) - B*B'/_CCP_MU0
end

"""Sample-level weak-volume constitutive kernel, independently FD checked.

weight is the full-torus scalar measure: divide by NFP, rotate physical
vectors, positions and tensors for each field period, THEN sum. Multiplying
one-sector Cartesian components by NFP would be wrong.
"""
function _ccp_sample(p, B, x, F, measure, nfp, length_m)
    nfp isa Integer && nfp > 0 || throw(ArgumentError("invalid NFP"))
    all(isfinite, (p, B..., x..., F..., measure, length_m)) &&
        measure > 0 && length_m > 0 || throw(ArgumentError("invalid weak-volume sample"))
    Bv=collect(B); xv=collect(x); Fv=collect(F)
    weak=zeros(4,3); strong=zeros(4,3); jac=zeros(12,4)
    stress=_ccp_stress(p,Bv)
    dT=Matrix{Float64}[Matrix{Float64}(I,3,3)]
    for j in 1:3
        e=zeros(3); e[j]=1
        push!(dT,(Bv[j]*Matrix{Float64}(I,3,3)-e*Bv'-Bv*e')/_CCP_MU0)
    end
    for period in 0:nfp-1
        R=_ccp_rotation(2pi*period/nfp); xp=R*xv; fp=R*Fv
        Tp=R*stress*R'; w=measure/nfp
        phi=(1.0,xp[1]/length_m,xp[2]/length_m,xp[3]/length_m)
        for t in 1:4, c in 1:3
            strong[t,c] += w*phi[t]*fp[c]
            if t>1
                weak[t,c] += w*Tp[c,t-1]/length_m
                for s in 1:4
                    jac[3*(t-1)+c,s] += w*(R*dT[s]*R')[c,t-1]/length_m
                end
            end
        end
    end
    (weak=weak,strong=strong,jacobian=jac)
end

function _ccp_sample_fd(p,B,x,F,measure,nfp,length_m)
    state=[p;collect(B)]; fd=zeros(12,4)
    for j in 1:4
        # Stress is exactly degree <= 2 in these sampled variables. A central
        # difference therefore has zero truncation error; stress-scaled finite
        # steps avoid subtractive cancellation of the rotated off-diagonal sum.
        scale=j==1 ? max(abs(p),dot(B,B)/(2*_CCP_MU0),1.0) : max(norm(B),1.0)
        h=1e-3*scale
        plus=copy(state); minus=copy(state); plus[j]+=h; minus[j]-=h
        wp=_ccp_sample(plus[1],plus[2:4],x,F,measure,nfp,length_m).weak
        wm=_ccp_sample(minus[1],minus[2:4],x,F,measure,nfp,length_m).weak
        for t in 1:4,c in 1:3
            fd[3*(t-1)+c,j]=(wp[t,c]-wm[t,c])/(2h)
        end
    end
    fd
end

struct CandidateCoupledPhysicsResultV4
    revision::String
    candidate_hash::Digest256
    context_hash::Digest256
    genome_binding_hashes::NTuple{3,Digest256}
    graph_binding_hashes::Tuple
    upstream_hashes::NamedTuple
    region_ids::Tuple
    region_support_hashes::Tuple
    reference_length_m::Float64
    nfp::Int
    units::NamedTuple
    physical_unit_signatures::NamedTuple
    test_functions::Tuple
    region_weak_volume_N::Tuple
    region_strong_moments_N::Tuple
    region_force_magnitude_integral_N::Tuple
    region_volume_m3::Tuple
    region_peak_force_density_N_m3::Tuple
    jacobian_row_ownership::Tuple
    jacobian_column_ownership::Tuple
    weak_volume_sample_jacobian::Tuple
    jacobian_fd_max_scaled_error::Float64
    sampled_constitutive_jacobian_verified::Bool
    execution::NamedTuple
    status::Symbol
    missing_capabilities::Tuple
    evidence_credit::Int
    claim_ceiling::typeof(screen_only)
    source_path::String
    source_sha256::Digest256
    output_path::String
    output_sha256::Digest256
    result_hash::Digest256
    function CandidateCoupledPhysicsResultV4(t::Val{:candidate_coupled_physics_private},f...)
        t===_CCP_TOKEN || throw(ArgumentError("private constructor")); new(f...)
    end
end
semantic_view(x::CandidateCoupledPhysicsResultV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))

function _ccp_artifacts(e)
    if hasproperty(e,:comparison) && hasproperty(e.comparison,:q3_request)
        return (request=e.comparison.q3_request,fq=e.fq,fr=e.fr,bq=e.bq,br=e.br)
    elseif hasproperty(e,:request) && nameof(typeof(e.request))===:RegionalForceIndependentRequestV4
        return (request=e.request,fq=e.field_request,fr=e.field_result,bq=e.basis_request,br=e.basis_result)
    end
    throw(ArgumentError("expected concrete q3 or independent-cubature execution"))
end

function _ccp_validate_upstream(upstream, e)
    length(upstream)==17 || throw(ArgumentError("complete 17-object DESC chain required"))
    context,gb,ge,gp,er,es,ee=upstream[1:7]
    canonical_hash(context); pr,ps=upstream[12:13]; canonical_hash(pr); canonical_hash(ps)
    a=_ccp_artifacts(e); r=a.request
    for obj in (r,a.fq,a.fr,a.bq,a.br); canonical_hash(obj); end
    owner=parentmodule(typeof(a.fr))
    getfield(owner,:validate_desc_field_provider_result)(context,er,es,ee,a.fq,a.fr)
    getfield(parentmodule(typeof(a.br)),:validate_desc_field_basis_bridge_result)(context,gb,ge,gp,er,es,ee,a.fq,a.fr,a.bq,a.br)
    r.candidate_hash==context.candidate_hash && r.context_hash==context.context_hash &&
        r.partition_request_hash==canonical_hash(pr) && r.partition_result_hash==canonical_hash(ps) &&
        r.execution_request_hash==canonical_hash(er) && r.execution_result_hash==canonical_hash(es) &&
        r.execution_receipt_hash==canonical_hash(ee) && r.field_request_hash==canonical_hash(a.fq) &&
        r.basis_request_hash==canonical_hash(a.bq) && r.nfp==Int(er.runner_payload.nfp) ||
        throw(ArgumentError("candidate or provider lineage mismatch"))
    ids=Tuple(z.region_id for z in pr.regions); supports=Tuple(z.region_support_hash for z in pr.regions)
    r.partition_region_ids==ids && r.partition_support_hashes==supports || throw(ArgumentError("region ownership mismatch"))
    if nameof(typeof(r))===:RegionalForceQ3RequestV4
        r.nodes==getfield(parentmodule(typeof(r)),:_rfq3_nodes)(pr,r.nfp) ||
            throw(ArgumentError("quadrature nodes or weights differ from sealed rule"))
    elseif nameof(typeof(r))!==:RegionalForceIndependentRequestV4
        throw(ArgumentError("unsupported regional quadrature producer"))
    end
    length(r.nodes)==length(a.fr.samples)==length(a.br.samples) || throw(ArgumentError("sample count mismatch"))
    for (n,f,b) in zip(r.nodes,a.fr.samples,a.br.samples)
        canonical_hash(n.point)==canonical_hash(f.point)==b.point_hash || throw(ArgumentError("sample order mismatch"))
        index=findfirst(==(n.region_id),ids)
        index!==nothing && n.region_support_hash==supports[index] && n.region_hash==canonical_hash(pr.regions[index]) ||
            throw(ArgumentError("sample region ownership mismatch"))
    end
    a
end

function _ccp_integrate(a,length_m)
    req=a.request; ids=req.partition_region_ids; nr=length(ids); ns=length(req.nodes)
    weak=[zeros(4,3) for _ in ids]; strong=[zeros(4,3) for _ in ids]
    magnitude=zeros(nr); volume=zeros(nr); peak=zeros(nr)
    jac=zeros(12nr,4ns); maxerr=0.0
    for i in 1:ns
        node=req.nodes[i]; field=a.fr.samples[i]; basis=a.br.samples[i]
        region=only(findall(==(node.region_id),ids))
        args=(field.pressure_Pa,basis.B_cartesian_xyz_T,basis.cartesian_position_xyz_m,
            basis.F_cartesian_xyz_N_m3,basis.sqrt_g_m3*node.weight,req.nfp,length_m)
        sample=_ccp_sample(args...); fd=_ccp_sample_fd(args...)
        weak[region].+=sample.weak; strong[region].+=sample.strong
        dv=basis.sqrt_g_m3*node.weight; fm=norm(basis.F_cartesian_xyz_N_m3)
        magnitude[region]+=fm*dv; volume[region]+=dv; peak[region]=max(peak[region],fm)
        jac[12(region-1)+1:12region,4(i-1)+1:4i].=sample.jacobian
        maxerr=max(maxerr,maximum(abs.(sample.jacobian-fd)./max.(1.0,abs.(sample.jacobian))))
    end
    (weak=Tuple(_ccp_tuple(w) for w in weak),strong=Tuple(_ccp_tuple(w) for w in strong),
        magnitude=Tuple(magnitude),volume=Tuple(volume),peak=Tuple(peak),jacobian=_ccp_tuple(jac),maxerr=maxerr)
end

const _CCP_EXECUTION=(real_upstream_fields_consumed=true,weak_volume_executed=true,
    nonconstant_strong_moment_executed=true,sampled_constitutive_jacobian_executed=true,
    periodic_model_reconstruction_executed=true,full_torus_direct_sampling_executed=false,
    external_source_term_executed=false,boundary_term_executed=false,
    complete_weak_residual_executed=false,full_state_jacobian_executed=false,
    global_conservation_executed=false,coupled_solve_attempted=false,
    coupled_solve_converged=false,physical_validation=false,terminal_authority=false)

function _ccp_text(ids,v)
    join(("$(ids[r])\t$(t)\t$(join(v.weak[r][t], '\t'))\t$(join(v.strong[r][t], '\t'))"
        for r in eachindex(ids) for t in 1:4),"\n")*"\n"*
        join(("MAGNITUDE_VOLUME_PEAK\t$(ids[r])\t$(v.magnitude[r])\t$(v.volume[r])\t$(v.peak[r])" for r in eachindex(ids)),"\n")*
        "\nJACOBIAN_FD_MAX_SCALED_ERROR\t$(v.maxerr)\n"
end

function canonical_hash(x::CandidateCoupledPhysicsResultV4)
    nr=length(x.region_ids); nc=length(x.jacobian_column_ownership)
    x.revision==_CCP_REVISION && x.status===:deferred && x.missing_capabilities==_CCP_GAPS &&
        x.execution==_CCP_EXECUTION && x.evidence_credit==0 && x.claim_ceiling===screen_only &&
        x.units==_CCP_UNITS && x.physical_unit_signatures==_CCP_DIMENSIONS && x.test_functions==_CCP_TESTS && nr>0 &&
        length(unique(x.region_ids))==nr && length(x.region_support_hashes)==nr &&
        length(x.region_weak_volume_N)==nr && length(x.region_strong_moments_N)==nr &&
        all(v->length(v)==nr && all(z->isfinite(z)&&z>=0,v),(x.region_force_magnitude_integral_N,x.region_volume_m3,x.region_peak_force_density_N_m3)) &&
        all(region->length(region)==4 && all(row->length(row)==3 && all(isfinite,row),region),x.region_weak_volume_N) &&
        all(region->length(region)==4 && all(row->length(row)==3 && all(isfinite,row),region),x.region_strong_moments_N) &&
        x.jacobian_row_ownership==Tuple((region_id=id,test_index=t,cartesian_component=c) for id in x.region_ids for t in 1:4 for c in 1:3) &&
        nc>0 && nc%4==0 && length(x.weak_volume_sample_jacobian)==12nr &&
        all(row->length(row)==nc && all(isfinite,row),x.weak_volume_sample_jacobian) &&
        x.nfp>0 && isfinite(x.reference_length_m) && x.reference_length_m>0 &&
        isfinite(x.jacobian_fd_max_scaled_error) &&
        x.sampled_constitutive_jacobian_verified==(x.jacobian_fd_max_scaled_error<=1e-6) &&
        x.source_path==_CCP_SOURCE && _ccp_sha(x.source_path)==x.source_sha256 &&
        isfile(x.output_path) && _ccp_sha(x.output_path)==x.output_sha256 ||
        throw(ArgumentError("invalid weak-volume result or authority"))
    h=canonical_hash(semantic_view(x)); h==x.result_hash || throw(ArgumentError("result hash mismatch")); h
end

function _ccp_identity(upstream,a)
    context=upstream[1]
    (candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        genome_binding_hashes=Tuple(canonical_hash(g) for g in context.genome_bindings),
        graph_binding_hashes=Tuple(canonical_hash(g) for genome in context.genome_bindings for g in genome.graph_bindings),
        upstream_hashes=(regional_request=canonical_hash(a.request),field_request=canonical_hash(a.fq),
            field_result=canonical_hash(a.fr),field_receipt=canonical_hash(a.fr.receipt),
            basis_request=canonical_hash(a.bq),basis_result=canonical_hash(a.br),basis_receipt=canonical_hash(a.br.receipt),
            partition_request=canonical_hash(upstream[12]),partition_result=canonical_hash(upstream[13])))
end

function execute_candidate_coupled_physics(upstream,regional_execution;run_dir,reference_length_m=1.0)
    isfinite(reference_length_m) && reference_length_m>0 || throw(ArgumentError("reference length must be positive"))
    a=_ccp_validate_upstream(upstream,regional_execution); v=_ccp_integrate(a,Float64(reference_length_m))
    ids=a.request.partition_region_ids; output=joinpath(mkpath(abspath(run_dir)),"candidate_weak_volume.tsv")
    write(output,_ccp_text(ids,v))
    body=merge((revision=_CCP_REVISION,),_ccp_identity(upstream,a),
        (region_ids=ids,region_support_hashes=a.request.partition_support_hashes,
        reference_length_m=Float64(reference_length_m),nfp=a.request.nfp,
        units=_CCP_UNITS,physical_unit_signatures=_CCP_DIMENSIONS,test_functions=_CCP_TESTS,
        region_weak_volume_N=v.weak,region_strong_moments_N=v.strong,
        region_force_magnitude_integral_N=v.magnitude,region_volume_m3=v.volume,region_peak_force_density_N_m3=v.peak,
        jacobian_row_ownership=Tuple((region_id=id,test_index=t,cartesian_component=c) for id in ids for t in 1:4 for c in 1:3),
        jacobian_column_ownership=Tuple((sample_index=i,point_hash=canonical_hash(a.request.nodes[i].point),state=s,unit=s===:pressure ? "Pa" : "T") for i in eachindex(a.request.nodes) for s in (:pressure,:Bx,:By,:Bz)),
        weak_volume_sample_jacobian=v.jacobian,jacobian_fd_max_scaled_error=v.maxerr,
        sampled_constitutive_jacobian_verified=v.maxerr<=1e-6,execution=_CCP_EXECUTION,
        status=:deferred,missing_capabilities=_CCP_GAPS,evidence_credit=0,claim_ceiling=screen_only,
        source_path=_CCP_SOURCE,source_sha256=_ccp_sha(_CCP_SOURCE),output_path=output,output_sha256=_ccp_sha(output)))
    result=CandidateCoupledPhysicsResultV4(_CCP_TOKEN,values(body)...,canonical_hash(body))
    validate_candidate_coupled_physics(upstream,regional_execution,result); result
end

function validate_candidate_coupled_physics(upstream,regional_execution,result::CandidateCoupledPhysicsResultV4)
    canonical_hash(result); a=_ccp_validate_upstream(upstream,regional_execution)
    identity=_ccp_identity(upstream,a)
    all(getproperty(result,k)==getproperty(identity,k) for k in keys(identity)) || throw(ArgumentError("weak-volume identity mismatch"))
    result.region_ids==a.request.partition_region_ids && result.region_support_hashes==a.request.partition_support_hashes &&
        result.nfp==a.request.nfp && result.jacobian_column_ownership==Tuple((sample_index=i,point_hash=canonical_hash(a.request.nodes[i].point),state=s,unit=s===:pressure ? "Pa" : "T") for i in eachindex(a.request.nodes) for s in (:pressure,:Bx,:By,:Bz)) ||
        throw(ArgumentError("weak-volume row or column ownership mismatch"))
    v=_ccp_integrate(a,result.reference_length_m)
    v.weak==result.region_weak_volume_N && v.strong==result.region_strong_moments_N &&
        v.magnitude==result.region_force_magnitude_integral_N && v.volume==result.region_volume_m3 && v.peak==result.region_peak_force_density_N_m3 &&
        v.jacobian==result.weak_volume_sample_jacobian && v.maxerr==result.jacobian_fd_max_scaled_error &&
        read(result.output_path,String)==_ccp_text(result.region_ids,v) || throw(ArgumentError("weak-volume replay mismatch"))
    result.result_hash
end
