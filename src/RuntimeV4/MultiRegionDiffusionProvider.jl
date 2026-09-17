# Standalone numerical-kernel/model-control contract. Not candidate-bound evidence.
using LinearAlgebra
using SparseArrays
import FusionConceptAI: Digest256, canonical_hash, semantic_view, is_canonical_value, UnitSignature

"""Candidate/context integration status for the real 3-D downstream edge.

This record is deliberately not a diffusion result.  It makes absence of a
real constitutive provider explicit and recoverable instead of running the
manufactured 1-D kernel against a 3-D context.
"""
struct MultiRegionContextIntegrationV4
    context_hash::Digest256
    candidate_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    composition_hash::Union{Nothing,Digest256}
    composition_status::Symbol
    status::Symbol
    gaps::Tuple{Vararg{String}}
    claim_ceiling::Symbol
    integration_hash::Digest256
end
semantic_view(x::MultiRegionContextIntegrationV4) =
    (context_hash=x.context_hash,candidate_hash=x.candidate_hash,
     subject_hash=x.subject_hash,scenario_hash=x.scenario_hash,
     composition_hash=x.composition_hash,composition_status=x.composition_status,
     status=x.status,gaps=x.gaps,claim_ceiling=x.claim_ceiling)
function canonical_hash(x::MultiRegionContextIntegrationV4)
    x.status === :deferred && x.composition_status in (:absent, :recoverable_gap, :input_complete) &&
        x.claim_ceiling === :screen_only ||
        throw(ArgumentError("invalid multi-region context integration status"))
    expected=canonical_hash(semantic_view(x)); x.integration_hash==expected ||
        throw(ArgumentError("multi-region context integration hash mismatch")); expected
end

function _multiregion_context_api(context, name::Symbol)
    # ForwardChainContext is intentionally included in several RuntimeV4
    # fixture modules. Resolve the API next to the concrete type rather than
    # accidentally validating a context against another module's types.
    owner = parentmodule(typeof(context))
    isdefined(owner, name) ? getfield(owner, name) : nothing
end

"""Join one validated ForwardChainContext to the exact 3-D input composition.

This is an admission/status operation only. It never invokes the manufactured
1-D diffusion kernel and never selects a provider. A complete structural
composition therefore still returns `:deferred` with the explicit missing
real-provider capability gap.
"""
function integrate_multiregion_context(context; composition_resolver=nothing)
    validator = _multiregion_context_api(context, :validate_forward_chain_context)
    validator === nothing && throw(ArgumentError("ForwardChainContextV4 API is not loaded for context type"))
    validator(context)
    gaps=String[]; composition_hash=nothing; composition_status=:absent
    resolver = composition_resolver === nothing ?
        _multiregion_context_api(context, :compose_three_d_physical_inputs) : composition_resolver
    if resolver === nothing
        push!(gaps,"required_three_d_input_composition_api")
    else
        composition=resolver(context)
        composition_status = hasproperty(composition, :status) ? composition.status : :absent
        composition_hash=try canonical_hash(composition) catch; nothing end
        composition_status === :input_complete ||
            (composition_status === :recoverable_gap ?
                append!(gaps, String["three_d_input_composition:" * String(g)
                    for g in composition.recoverable_gaps]) :
                push!(gaps,"three_d_input_composition_not_complete"))
    end
    # No real constitutive/field provider is currently registered for this edge.
    push!(gaps,"required_real_multiregion_constitutive_provider")
    body=(context_hash=context.context_hash,candidate_hash=context.candidate_hash,
        subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,composition_hash=composition_hash,
        composition_status=composition_status,status=:deferred,gaps=Tuple(gaps),
        claim_ceiling=:screen_only)
    result=MultiRegionContextIntegrationV4(body.context_hash,body.candidate_hash,
        body.subject_hash,body.scenario_hash,body.composition_hash,
        body.composition_status,body.status,body.gaps,
        body.claim_ceiling,canonical_hash(body))
    canonical_hash(result); result
end

"""A validated DESC execution is an upstream sub-capability, not a
multi-region solve.

The bridge deliberately consumes both the execution result and its receipt.
The receipt validator is resolved from the module owning the concrete receipt
type, so a caller cannot substitute an unvalidated HDF5 path.  DESC's fixed
boundary output does not export the region constitutive laws or oriented
interface fluxes required by `contract`; consequently this function returns a
typed recoverable admission gap and never reads manufactured values or emits
physical evidence.
"""
struct MultiRegionDESCAdmissionV4
    context_hash::Digest256
    candidate_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    contract_hash::Digest256
    desc_execution_hash::Digest256
    desc_receipt_hash::Digest256
    output_hash::Digest256
    output_path::String
    status::Symbol
    provider_selected::Bool
    provider_executed::Bool
    result_schema_validated::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    claim_ceiling::Symbol
    recoverable_gaps::Tuple{Vararg{String}}
    admission_hash::Digest256
end

semantic_view(x::MultiRegionDESCAdmissionV4) = (
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    contract_hash=x.contract_hash, desc_execution_hash=x.desc_execution_hash,
    desc_receipt_hash=x.desc_receipt_hash, output_hash=x.output_hash,
    output_path=x.output_path, status=x.status,
    provider_selected=x.provider_selected, provider_executed=x.provider_executed,
    result_schema_validated=x.result_schema_validated,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation,
    emits_evidence=x.emits_evidence, claim_ceiling=x.claim_ceiling,
    recoverable_gaps=x.recoverable_gaps)

function canonical_hash(x::MultiRegionDESCAdmissionV4)
    x.status === :deferred && !x.provider_selected && x.provider_executed &&
        x.result_schema_validated && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence &&
        x.claim_ceiling === :screen_only && !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("invalid DESC multi-region admission authority"))
    expected = canonical_hash(semantic_view(x))
    x.admission_hash == expected ||
        throw(ArgumentError("DESC multi-region admission hash mismatch"))
    expected
end

function _mr_receipt_validator(receipt)
    owner = parentmodule(typeof(receipt))
    isdefined(owner, :validate_desc_provider_receipt) ||
        throw(ArgumentError("DESC receipt validator is not available for receipt type"))
    getfield(owner, :validate_desc_provider_receipt)
end

function _mr_require_field(value, name::Symbol)
    hasproperty(value, name) ||
        throw(ArgumentError("DESC execution/receipt is missing field $(name)"))
    getproperty(value, name)
end

"""Admit only a fresh, replay-validated DESC artifact to the multi-region edge."""
function admit_desc_multiregion_provider(context, contract::MultiRegionCouplingContractV4,
        execution_result, receipt)
    validator = _multiregion_context_api(context, :validate_forward_chain_context)
    validator === nothing && throw(ArgumentError("ForwardChainContextV4 validator is unavailable"))
    validator(context)
    canonical_hash(contract)
    contract.candidate_prefix_hash == context.compiled.prefix_hash ||
        throw(ArgumentError("multi-region contract is foreign to context prefix"))
    contract.candidate_hash == context.candidate.canonical_hashes.genome_bundle_hash ||
        throw(ArgumentError("multi-region contract is foreign to candidate"))
    contract.mission_hash == canonical_hash(context.mission_payload) ||
        throw(ArgumentError("multi-region contract is foreign to mission"))
    contract.bounds_hash == canonical_hash(context.bounds_payload) ||
        throw(ArgumentError("multi-region contract is foreign to bounds"))
    isempty(contract.required_channels) &&
        throw(ArgumentError("multi-region admission requires declared conservation channels"))
    isempty(contract.interfaces) &&
        throw(ArgumentError("multi-region admission requires typed interfaces"))
    validation = validate_multiregion_coupling(contract, context.compiled)
    validation.status === :ready ||
        throw(ArgumentError("multi-region contract is not independently ready for context"))

    # This is intentionally mandatory and happens before consuming output_path.
    _mr_receipt_validator(receipt)(receipt)
    canonical_hash(receipt)
    canonical_hash(execution_result)
    execution_result.receipt === nothing &&
        throw(ArgumentError("DESC execution result has no validated receipt"))
    canonical_hash(execution_result.receipt) == canonical_hash(receipt) ||
        throw(ArgumentError("DESC execution result and receipt differ"))
    _mr_require_field(execution_result, :context_hash) == context.context_hash ||
        throw(ArgumentError("DESC execution result is foreign to context"))
    _mr_require_field(execution_result, :candidate_hash) == context.candidate_hash ||
        throw(ArgumentError("DESC execution result is foreign to candidate"))
    execution_result.provider_executed && execution_result.result_schema_validated ||
        throw(ArgumentError("DESC execution result is not an executed validated result"))
    receipt.exit_code == 0 && receipt.inspection_exit_code == 0 &&
        receipt.output_schema_validated ||
        throw(ArgumentError("DESC receipt is not a successful inspected artifact"))
    output_hash = receipt.output_sha256
    output_hash === nothing && throw(ArgumentError("DESC receipt has no output hash"))
    output_path = String(receipt.output_path)

    gaps = String["desc_fixed_boundary_output_is_not_multiregion_closure"]
    append!(gaps, String["required_multiregion_constitutive_field:" * String(c)
        for c in contract.required_channels])
    append!(gaps, String["required_multiregion_interface_flux:" * String(c)
        for c in contract.required_channels])
    body = (context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        contract_hash=canonical_hash(contract),
        desc_execution_hash=canonical_hash(execution_result),
        desc_receipt_hash=canonical_hash(receipt), output_hash=output_hash,
        output_path=output_path, status=:deferred, provider_selected=false,
        provider_executed=true, result_schema_validated=true,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, claim_ceiling=:screen_only,
        recoverable_gaps=Tuple(gaps))
    result = MultiRegionDESCAdmissionV4(body.context_hash, body.candidate_hash,
        body.subject_hash, body.scenario_hash, body.contract_hash,
        body.desc_execution_hash, body.desc_receipt_hash, body.output_hash,
        body.output_path, body.status, body.provider_selected,
        body.provider_executed, body.result_schema_validated,
        body.physical_validation, body.engineering_validation,
        body.emits_evidence, body.claim_ceiling, body.recoverable_gaps,
        canonical_hash(body))
    canonical_hash(result)
    result
end

struct DiffusionBoundaryV4
    kind::Symbol; value::Float64; units::UnitSignature
    function DiffusionBoundaryV4(k::Symbol,v::Real,u::UnitSignature)
        k in (:dirichlet,:neumann)||throw(ArgumentError("boundary kind")); isfinite(v)||throw(ArgumentError("boundary value")); new(k,Float64(v),u)
    end
end
semantic_view(x::DiffusionBoundaryV4)=(kind=x.kind,value=x.value,units=x.units)

struct DiffusionRegionSpecV4
    region_id::String; coordinates::Tuple{Vararg{Float64}}; conductivity::Float64; source::Float64
    coordinate_units::UnitSignature; state_units::UnitSignature; conductivity_units::UnitSignature; source_units::UnitSignature; flux_units::UnitSignature
    left::DiffusionBoundaryV4; right::DiffusionBoundaryV4
    function DiffusionRegionSpecV4(id::AbstractString,coords,k::Real,s::Real,u::UnitSignature,l::DiffusionBoundaryV4,r::DiffusionBoundaryV4;coordinate_units=UnitSignature(),conductivity_units=UnitSignature(),source_units=u,flux_units=u)
        xs=Tuple(Float64.(coords)); !isempty(id)&&length(xs)>=2&&all(isfinite,xs)&&all(xs[i+1]>xs[i] for i in 1:length(xs)-1)||throw(ArgumentError("invalid region mesh")); kk,ss=Float64(k),Float64(s); isfinite(kk)&&kk>0&&isfinite(ss)||throw(ArgumentError("invalid material/source")); l.units==u&&r.units==u||throw(ArgumentError("boundary state-unit mismatch")); new(String(id),xs,kk,ss,coordinate_units,u,conductivity_units,source_units,flux_units,l,r)
    end
end
semantic_view(x::DiffusionRegionSpecV4)=(region_id=x.region_id,coordinates=x.coordinates,conductivity=x.conductivity,source=x.source,coordinate_units=x.coordinate_units,state_units=x.state_units,conductivity_units=x.conductivity_units,source_units=x.source_units,flux_units=x.flux_units,left=x.left,right=x.right)

struct MultiRegionCouplingPlanV4
    contract::MultiRegionCouplingContractV4; validation::MultiRegionCouplingValidationV4; regions::Tuple{DiffusionRegionSpecV4,DiffusionRegionSpecV4}; interface_id::String; interface_units::UnitSignature; tolerance::Float64; protocol_id::String; plan_hash::Digest256
    function MultiRegionCouplingPlanV4(c::MultiRegionCouplingContractV4,v::MultiRegionCouplingValidationV4,regions,iface::AbstractString,u::UnitSignature;tolerance=1e-9,protocol_id="standalone-1d-diffusion-v1")
        v.status===:ready&&v.contract_hash==canonical_hash(c)||throw(ArgumentError("plan requires independently validated contract")); rs=Tuple(regions); length(rs)==2&&all(x->x isa DiffusionRegionSpecV4,rs)||throw(ArgumentError("exactly two typed regions required")); ci=only(i for i in c.interfaces if i.interface_id==String(iface)); Set((ci.minus_region,ci.plus_region))==Set(x.region_id for x in rs)||throw(ArgumentError("interface binding")); all(x->x.flux_units==u,rs)||throw(ArgumentError("interface flux units")); t=Float64(tolerance);isfinite(t)&&t>0||throw(ArgumentError("tolerance")); body=(contract_hash=canonical_hash(c),validation=v,regions=rs,interface_id=String(iface),interface_units=u,tolerance=t,protocol_id=String(protocol_id));is_canonical_value(body)||throw(ArgumentError("noncanonical plan")); new(c,v,(rs[1],rs[2]),String(iface),u,t,String(protocol_id),canonical_hash(body))
    end
end
semantic_view(x::MultiRegionCouplingPlanV4)=(contract=x.contract,validation=x.validation,regions=x.regions,interface_id=x.interface_id,interface_units=x.interface_units,tolerance=x.tolerance,protocol_id=x.protocol_id,plan_hash=x.plan_hash)
canonical_hash(x::MultiRegionCouplingPlanV4)=canonical_hash(semantic_view(x))

struct MultiRegionDiffusionResultV4
    status::Symbol; values::Tuple{Vararg{Float64}}; interface_value_jump::Union{Nothing,Float64}; oriented_flux_minus::Union{Nothing,Float64}; oriented_flux_plus::Union{Nothing,Float64}; residual_norm::Union{Nothing,Float64}; block_residuals::Tuple{Vararg{Float64}}; reason::String; result_hash::Digest256
end
semantic_view(x::MultiRegionDiffusionResultV4)=(status=x.status,values=x.values,interface_value_jump=x.interface_value_jump,oriented_flux_minus=x.oriented_flux_minus,oriented_flux_plus=x.oriented_flux_plus,residual_norm=x.residual_norm,block_residuals=x.block_residuals,reason=x.reason)
struct MultiRegionDiffusionReceiptV4
    plan_hash::Digest256; result::MultiRegionDiffusionResultV4; protocol_id::String; receipt_hash::Digest256
end
semantic_view(x::MultiRegionDiffusionReceiptV4)=(plan_hash=x.plan_hash,result=x.result,protocol_id=x.protocol_id)
function _result(st,vals,j,fm,fp,r,b,why)
    values=Tuple(Float64.(vals)); blocks=Tuple(Float64.(b))
    body=(status=st,values=values,interface_value_jump=j,
        oriented_flux_minus=fm,oriented_flux_plus=fp,residual_norm=r,
        block_residuals=blocks,reason=why)
    MultiRegionDiffusionResultV4(st,values,j,fm,fp,r,blocks,why,canonical_hash(body))
end
function canonical_hash(x::MultiRegionDiffusionResultV4)
    expected=canonical_hash(semantic_view(x)); x.result_hash==expected ||
        throw(ArgumentError("diffusion result hash mismatch")); expected
end
function _receipt(p,r)
    body=(plan_hash=p.plan_hash,result=r,protocol_id=p.protocol_id)
    MultiRegionDiffusionReceiptV4(p.plan_hash,r,p.protocol_id,canonical_hash(body))
end
function canonical_hash(x::MultiRegionDiffusionReceiptV4)
    canonical_hash(x.result)
    expected=canonical_hash((plan_hash=x.plan_hash,result=x.result,protocol_id=x.protocol_id))
    x.receipt_hash==expected || throw(ArgumentError("diffusion receipt hash mismatch")); expected
end
_fail(p,st,why)=_receipt(p,_result(st,(),nothing,nothing,nothing,nothing,(),why))

function solve_multiregion_diffusion(p::MultiRegionCouplingPlanV4)
    a,b=p.regions; ci=only(i for i in p.contract.interfaces if i.interface_id==p.interface_id); minus,plus=ci.minus_region==a.region_id ? (a,b) : ci.minus_region==b.region_id ? (b,a) : return _fail(p,:unknown,"interface binding"); n1,n2=length(minus.coordinates),length(plus.coordinates); N=n1+n2; A=zeros(N,N);rhs=zeros(N)
    for (g,o) in ((minus,0),(plus,n1)); h=[g.coordinates[i+1]-g.coordinates[i] for i in 1:length(g.coordinates)-1]; maximum(abs.(h.-h[1]))<=64eps(maximum(abs.(g.coordinates)))+eps()||return _fail(p,:deferred,"nonuniform mesh unsupported"); for j in 2:length(h);i=o+j;q=g.conductivity/h[1]^2;A[i,i-1]=-q;A[i,i]=2q;A[i,i+1]=-q;rhs[i]=g.source;end;end
    function bc!(row,g,idx,side);c=side===:left ? g.left : g.right;h=side===:left ? g.coordinates[2]-g.coordinates[1] : g.coordinates[end]-g.coordinates[end-1];A[row,:].=0;if c.kind===:dirichlet;A[row,idx]=1;else;A[row,idx]=g.conductivity/h;A[row,side===:left ? idx+1 : idx-1]=-g.conductivity/h;end;rhs[row]=c.value;end
    bc!(1,minus,1,:left);bc!(N,plus,N,:right);im=n1;ip=n1+1;hm=minus.coordinates[end]-minus.coordinates[end-1];hp=plus.coordinates[2]-plus.coordinates[1];A[im,im]=1;A[im,ip]=-1;A[ip,im]=minus.conductivity/hm;A[ip,im-1]=-minus.conductivity/hm;A[ip,ip]=plus.conductivity/hp;A[ip,ip+1]=-plus.conductivity/hp;As=sparse(A);x=try As\rhs catch;return _fail(p,:numerical_fail,"singular_or_solver_error") end;all(isfinite,x)||return _fail(p,:numerical_fail,"nonfinite_solution");rr=As*x-rhs;rn=norm(rr,Inf);j=abs(x[im]-x[ip]);fm=minus.conductivity/hm*(x[im]-x[im-1]);fp=plus.conductivity/hp*(x[ip+1]-x[ip]);blocks=(norm(rr[1:n1],Inf),norm(rr[n1+1:end],Inf),j,abs(fm-fp));st=rn<=p.tolerance&&j<=p.tolerance&&abs(fm-fp)<=p.tolerance ? :pass : :numerical_fail;r=_result(st,x,j,fm,fp,rn,blocks,st===:pass ? "bounded_model_solve" : "residual_failure");_receipt(p,r)
end
