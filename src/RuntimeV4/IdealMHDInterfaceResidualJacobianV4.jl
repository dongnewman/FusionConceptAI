# Candidate-bound static ideal-MHD interface residual/Jacobian slice.
# This is a local interface subset only; it is not a regional or global solve.
using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _IMIRJ_REVISION = "runtime-v4-ideal-mhd-interface-residual-jacobian-v1"
const _IMIRJ_SCHEMA = "fusionconceptai:runtime-v4-ideal-mhd-interface-residual-jacobian"
const _IMIRJ_TOKEN = Val(:ideal_mhd_interface_residual_jacobian_private)
const _IMIRJ_ORDER = :p_minus_Bxyz_minus_p_plus_Bxyz_plus
const _IMIRJ_FORMULA = :static_momentum_traction_plus_common_orientation_Bn_jump
const _IMIRJ_SOURCE_PATH = abspath(@__FILE__)
_imirj_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))

struct IdealMHDInterfaceResidualJacobianRequestV4
    revision::String; schema::String; request_kind::Symbol
    traction_request_hash::Digest256; traction_result_hash::Digest256
    candidate_hash::Digest256; interface_subset::Tuple
    mu0_N_A2::Float64; traction_unit::String; B_unit::String
    state_order::Symbol; residual_units::Tuple; formula::Symbol
    finite_offset_proxy::Bool; fd_steps::NTuple{8,Float64}; fd_abs_tolerance::Float64
    residual_owner::Symbol; jacobian_owner::Symbol; source_path::String
    source_sha256::Digest256; julia_executable::String
    julia_executable_sha256::Digest256; claim_ceiling::ClaimCeiling
    jump_conditions_validated::Bool; regional_residual_assembled::Bool
    global_residual_assembled::Bool; solver_convergence_validated::Bool
    multiregion_closure::Bool; physical_validation::Bool; engineering_validation::Bool
    emits_evidence::Bool; grants_pass::Bool; promotion_authority::Bool
    p5_ready::Bool; terminal_authority::Bool; credible_physical_device_count::Int
    request_hash::Digest256
    function IdealMHDInterfaceResidualJacobianRequestV4(
            ::Val{:ideal_mhd_interface_residual_jacobian_private}, f...); new(f...); end
end
_imirj_body(x) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
semantic_view(x::IdealMHDInterfaceResidualJacobianRequestV4) = _imirj_body(x)

function canonical_hash(x::IdealMHDInterfaceResidualJacobianRequestV4)
    x.revision == _IMIRJ_REVISION && x.schema == _IMIRJ_SCHEMA &&
    x.request_kind === :candidate_bound_static_ideal_mhd_interface_subset &&
    !isempty(x.interface_subset) &&
    x.state_order === _IMIRJ_ORDER && x.formula === _IMIRJ_FORMULA &&
    x.mu0_N_A2 == 1.25663706127e-6 && x.traction_unit == "Pa" && x.B_unit == "T" &&
    x.finite_offset_proxy && all(>(0),x.fd_steps) && x.fd_abs_tolerance > 0 &&
    x.residual_owner === :interface_subset_only && x.jacobian_owner === :interface_subset_only &&
    isfile(x.source_path) && _imirj_sha(x.source_path) == x.source_sha256 &&
    isfile(x.julia_executable) && _imirj_sha(x.julia_executable) == x.julia_executable_sha256 &&
    x.claim_ceiling == screen_only && !x.jump_conditions_validated &&
    !x.regional_residual_assembled && !x.global_residual_assembled &&
    !x.solver_convergence_validated && !x.multiregion_closure && !x.physical_validation &&
    !x.engineering_validation && !x.emits_evidence && !x.grants_pass &&
    !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
    x.credible_physical_device_count == 0 || throw(ArgumentError("invalid residual/Jacobian request"))
    h=canonical_hash(semantic_view(x)); h == x.request_hash || throw(ArgumentError("request hash mismatch")); h
end

struct IdealMHDInterfaceResidualJacobianResultV4
    request_hash::Digest256; traction_request_hash::Digest256; traction_result_hash::Digest256
    states::Tuple; residuals::Tuple; jacobians::Tuple
    analytic_jacobian_hashes::Tuple; fd_jacobians::Tuple
    fd_max_abs_errors::Tuple; fd_validated::Bool; interface_subset_residual::Bool
    jacobian_executed::Bool; jacobian_validated::Bool; central_pair_cancelled::Bool
    jump_conditions_validated::Bool; regional_residual_assembled::Bool; global_residual_assembled::Bool
    solver_convergence_validated::Bool; multiregion_closure::Bool; physical_validation::Bool
    engineering_validation::Bool; emits_evidence::Bool; grants_pass::Bool; promotion_authority::Bool
    p5_ready::Bool; terminal_authority::Bool; claim_ceiling::ClaimCeiling; result_hash::Digest256
    function IdealMHDInterfaceResidualJacobianResultV4(
            ::Val{:ideal_mhd_interface_residual_jacobian_private},f...); new(f...); end
end
_imirj_result_body(x) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
semantic_view(x::IdealMHDInterfaceResidualJacobianResultV4)=_imirj_result_body(x)
function canonical_hash(x::IdealMHDInterfaceResidualJacobianResultV4)
    all(s->length(s)==8 && all(isfinite,s),x.states) && all(r->length(r)==4 && all(isfinite,r),x.residuals) &&
    all(j->all(isfinite,Iterators.flatten(j)),x.jacobians) && all(j->all(isfinite,Iterators.flatten(j)),x.fd_jacobians) &&
    all(isfinite,x.fd_max_abs_errors) &&
    x.interface_subset_residual && x.jacobian_executed && x.jacobian_validated && x.fd_validated &&
    !x.jump_conditions_validated && !x.regional_residual_assembled && !x.global_residual_assembled &&
    !x.solver_convergence_validated && !x.multiregion_closure && !x.physical_validation &&
    !x.engineering_validation && !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
    !x.p5_ready && !x.terminal_authority && x.claim_ceiling == screen_only ||
        throw(ArgumentError("residual/Jacobian result exceeds authority ceiling"))
    h=canonical_hash(semantic_view(x)); h == x.result_hash || throw(ArgumentError("result hash mismatch")); h
end

function make_ideal_mhd_interface_residual_jacobian_request(traction_request, traction_result)
    canonical_hash(traction_request); canonical_hash(traction_result)
    traction_result.request_hash == traction_request.request_hash &&
        traction_result.context_hash == traction_request.context_hash &&
        traction_result.candidate_hash == traction_request.candidate_hash ||
        throw(ArgumentError("foreign traction request/result identity"))
    !isempty(traction_result.samples) || throw(ArgumentError("traction result has no interface samples"))
    ex=abspath(String(Base.julia_cmd().exec[1])); body=(revision=_IMIRJ_REVISION,schema=_IMIRJ_SCHEMA,
      request_kind=:candidate_bound_static_ideal_mhd_interface_subset,
      traction_request_hash=canonical_hash(traction_request),traction_result_hash=canonical_hash(traction_result),
      candidate_hash=traction_request.candidate_hash,interface_subset=Tuple(s.spec_hash for s in traction_result.samples),
      mu0_N_A2=1.25663706127e-6,traction_unit="Pa",B_unit="T",state_order=_IMIRJ_ORDER,
      residual_units=("Pa","Pa","Pa","T"),formula=_IMIRJ_FORMULA,finite_offset_proxy=true,
      fd_steps=(1e-3,1e-4,1e-4,1e-4,1e-3,1e-4,1e-4,1e-4),fd_abs_tolerance=1e-5,
      residual_owner=:interface_subset_only,jacobian_owner=:interface_subset_only,
      source_path=_IMIRJ_SOURCE_PATH,source_sha256=_imirj_sha(_IMIRJ_SOURCE_PATH),julia_executable=ex,
      julia_executable_sha256=_imirj_sha(ex),claim_ceiling=screen_only,jump_conditions_validated=false,
      regional_residual_assembled=false,global_residual_assembled=false,solver_convergence_validated=false,
      multiregion_closure=false,physical_validation=false,engineering_validation=false,emits_evidence=false,
      grants_pass=false,promotion_authority=false,p5_ready=false,terminal_authority=false,credible_physical_device_count=0)
    request=IdealMHDInterfaceResidualJacobianRequestV4(_IMIRJ_TOKEN,values(body)...,canonical_hash(body))
    canonical_hash(request)
    request
end

function _imirj_eval(s, nm, np, mu)
    pm=s[1]; bm=(s[2],s[3],s[4]); pp=s[5]; bp=(s[6],s[7],s[8])
    function tr(p,b,n)
        bn=dot(b,n); q=p+dot(b,b)/(2mu)
        ntuple(i->q*n[i]-b[i]*bn/mu,3)
    end
    tm=tr(pm,bm,nm); tp=tr(pp,bp,np)
    (ntuple(i->tm[i]+tp[i],3)..., dot(bm,nm)+dot(bp,np))
end

function _imirj_analytic(s,nm,np,mu)
    bm=(s[2],s[3],s[4]); bp=(s[6],s[7],s[8])
    # Columns are p-, B-, p+, B+.
    rows=[zeros(Float64,8) for _ in 1:4]
    for i in 1:3
        rows[i][1]=nm[i]; rows[i][5]=np[i]
        for j in 1:3
            rows[i][1+j]=(nm[i]*bm[j]-(i==j ? dot(bm,nm) : 0.0)-bm[i]*nm[j])/mu
            rows[i][5+j]=(np[i]*bp[j]-(i==j ? dot(bp,np) : 0.0)-bp[i]*np[j])/mu
        end
    end
    rows[4][2]=nm[1]; rows[4][3]=nm[2]; rows[4][4]=nm[3]
    rows[4][6]=np[1]; rows[4][7]=np[2]; rows[4][8]=np[3]
    Tuple(Tuple(row) for row in rows)
end

function execute_ideal_mhd_interface_residual_jacobian(request, traction_request, traction_result,
        state; _validate=true)
    canonical_hash(request); canonical_hash(traction_request); canonical_hash(traction_result)
    request.traction_request_hash==canonical_hash(traction_request) && request.traction_result_hash==canonical_hash(traction_result) ||
        throw(ArgumentError("foreign traction identity"))
    request.candidate_hash == traction_request.candidate_hash &&
        traction_result.request_hash == traction_request.request_hash &&
        traction_result.context_hash == traction_request.context_hash &&
        traction_result.candidate_hash == traction_request.candidate_hash ||
        throw(ArgumentError("foreign traction context/candidate identity"))
    !isempty(traction_result.samples) || throw(ArgumentError("local slice requires interface samples"))
    request.interface_subset == Tuple(s.spec_hash for s in traction_result.samples) ||
        throw(ArgumentError("interface subset identity/coverage mismatch"))
    states = state isa NTuple{8,Float64} ? ntuple(_->state,length(traction_result.samples)) : state
    length(states)==length(traction_result.samples) || throw(ArgumentError("state/sample coverage mismatch"))
    all(s->length(s)==8 && all(isfinite,s),states) || throw(ArgumentError("invalid state vector"))
    samples=traction_result.samples
    rs=Tuple(_imirj_eval(states[k],samples[k].minus_outward_normal_xyz,samples[k].plus_outward_normal_xyz,request.mu0_N_A2) for k in eachindex(samples))
    as=Tuple(_imirj_analytic(states[k],samples[k].minus_outward_normal_xyz,samples[k].plus_outward_normal_xyz,request.mu0_N_A2) for k in eachindex(samples))
    fds=Tuple(ntuple(i->ntuple(j->begin
        h=request.fd_steps[j]; sp=ntuple(k->k==j ? state[k]+h : state[k],8); sm=ntuple(k->k==j ? state[k]-h : state[k],8)
        (_imirj_eval(sp,samples[k].minus_outward_normal_xyz,samples[k].plus_outward_normal_xyz,request.mu0_N_A2)[i]-_imirj_eval(sm,samples[k].minus_outward_normal_xyz,samples[k].plus_outward_normal_xyz,request.mu0_N_A2)[i])/(2h)
    end,8),4) for (k,state) in enumerate(states))
    errs=Tuple(maximum(abs(fds[k][i][j]-as[k][i][j]) for i in 1:4 for j in 1:8) for k in eachindex(samples))
    all(err->err <= request.fd_abs_tolerance,errs) || throw(ArgumentError("analytic Jacobian finite-difference check failed"))
    body=(request_hash=request.request_hash,traction_request_hash=request.traction_request_hash,traction_result_hash=request.traction_result_hash,
      states=states,residuals=rs,jacobians=as,analytic_jacobian_hashes=Tuple(canonical_hash(a) for a in as),fd_jacobians=fds,fd_max_abs_errors=errs,fd_validated=true,
      interface_subset_residual=true,jacobian_executed=true,jacobian_validated=true,central_pair_cancelled=all(s->all(iszero,s.paired_flux_defect_xyz_Pa),samples),
      jump_conditions_validated=false,regional_residual_assembled=false,global_residual_assembled=false,solver_convergence_validated=false,
      multiregion_closure=false,physical_validation=false,engineering_validation=false,emits_evidence=false,grants_pass=false,
      promotion_authority=false,p5_ready=false,terminal_authority=false,claim_ceiling=screen_only)
    result=IdealMHDInterfaceResidualJacobianResultV4(_IMIRJ_TOKEN,values(body)...,canonical_hash(body))
    _validate && validate_ideal_mhd_interface_residual_jacobian_result(request, traction_request, traction_result, result)
    result
end

function validate_ideal_mhd_interface_residual_jacobian_result(r::IdealMHDInterfaceResidualJacobianResultV4)
    canonical_hash(r)
end
function validate_ideal_mhd_interface_residual_jacobian_result(request, traction_request, traction_result,
        r::IdealMHDInterfaceResidualJacobianResultV4)
    canonical_hash(request); canonical_hash(traction_request); canonical_hash(traction_result)
    expected=execute_ideal_mhd_interface_residual_jacobian(request, traction_request, traction_result, r.states; _validate=false)
    semantic_view(expected)==semantic_view(r) || throw(ArgumentError("residual/Jacobian differs from independent recomputation"))
    r.result_hash
end

ideal_mhd_interface_residual_jacobian_manifest()=(schema=_IMIRJ_SCHEMA,revision=_IMIRJ_REVISION,
  interface_subset_residual=true,jacobian_executed=true,jacobian_validated=true,jump_conditions_validated=false,
  regional_residual_assembled=false,global_residual_assembled=false,multiregion_closure=false,claim_ceiling=screen_only)
