# Candidate-bound fresh DESC static-MHD force-balance sample.
using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _DSMB_REVISION = "runtime-v4-desc-static-mhd-balance-v1"
const _DSMB_SCHEMA = "fusionconceptai:runtime-v4-desc-static-mhd-balance"
const _DSMB_TOKEN = Val(:desc_static_mhd_balance_private)
const _DSMB_SOURCE_PATH = abspath(@__FILE__)
const _DSMB_ADAPTER = raw"""
import sys
from pathlib import Path
import numpy as np
import desc
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load
REQ="fusionconceptai:runtime-v4-desc-static-mhd-balance-request"
OUT="fusionconceptai:runtime-v4-desc-static-mhd-balance-output"
KEY="desc.equilibrium.equilibrium.Equilibrium"
EXPECTED={"B":("T",3,"rtz"),"J":("A \\cdot m^{-2}",3,"rtz"),
 "grad(p)":("N \\cdot m^{-3}",3,"rtz"),"F":("N \\cdot m^{-3}",3,"rtz")}
lines=[x.rstrip("\n").split("\t") for x in open(sys.argv[2],encoding="utf-8")]
if lines[0] != ["SCHEMA",REQ] or lines[-1] != ["END","1"]: raise ValueError("framing")
n=int(lines[1][1]); pts=[(float(x[2]),float(x[3]),float(x[4])) for x in lines[2:-1]]
if len(pts)!=n or any(len(x)!=5 or x[0]!="POINT" or int(x[1])!=i+1 for i,x in enumerate(lines[2:-1])): raise ValueError("points")
for k,v in EXPECTED.items():
 a=data_index[KEY][k]
 if (a["units"],int(a["dim"]),a["coordinates"]) != v: raise ValueError("metadata "+k)
if Path(desc.__file__).resolve()!=Path(sys.argv[4]).resolve(): raise ValueError("module path")
eq=load(sys.argv[1])
grid=Grid(np.asarray(pts),coordinates="rtz",NFP=int(eq.NFP),sort=False)
d=eq.compute(["B","J","grad(p)","F"],grid=grid)
for k in ("B","J","grad(p)","F"):
 v=d[k]
 if np.asarray(v).shape != (n,3) or not np.all(np.isfinite(v)): raise ValueError("shape/nonfinite "+k)
rows=["SCHEMA\t"+OUT,"DESC_VERSION\t"+desc.__version__,"NFP\t"+str(int(eq.NFP)),"COUNT\t"+str(n)]
for i,p in enumerate(pts): rows.append("\t".join(["POINT",str(i+1),*(repr(x) for x in p),*(repr(float(x)) for k in ("B","J","grad(p)","F") for x in d[k][i])]))
rows.append("END\t1")
open(sys.argv[3],"w",encoding="utf-8",newline="\n").write("\n".join(rows)+"\n")
"""
const _DSMB_ADAPTER_SHA256 = Digest256(bytes2hex(SHA.sha256(codeunits(_DSMB_ADAPTER))))
_dsmb_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_dsmb_cart(v, pos) = begin
    ph = atan(pos[2],pos[1]); r,t,z=v; (r*cos(ph)-t*sin(ph),r*sin(ph)+t*cos(ph),z)
end
_dsmb_cross(a,b) = (a[2]*b[3]-a[3]*b[2],
    a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1])

struct DESCStaticMHDBalanceSampleV4
    point_hash::Digest256; rho::Float64; theta_rad::Float64; zeta_rad::Float64
    B_xyz_T::NTuple{3,Float64}; J_xyz_A_m2::NTuple{3,Float64}
    grad_p_xyz_N_m3::NTuple{3,Float64}; F_desc_xyz_N_m3::NTuple{3,Float64}
    JxB_minus_gradp_xyz_N_m3::NTuple{3,Float64}; force_balance_error_norm_N_m3::Float64
    F_discrepancy_xyz_N_m3::NTuple{3,Float64}; F_discrepancy_norm_N_m3::Float64
    F_crosscheck_abs_tol_N_m3::Float64; F_crosscheck_rel_tol::Float64; F_crosschecked::Bool
    sample_hash::Digest256
end
semantic_view(x::DESCStaticMHDBalanceSampleV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::DESCStaticMHDBalanceSampleV4)
    all(isfinite,(x.rho,x.theta_rad,x.zeta_rad,x.force_balance_error_norm_N_m3,x.F_discrepancy_norm_N_m3,x.F_crosscheck_abs_tol_N_m3,x.F_crosscheck_rel_tol)) && x.F_crosschecked || throw(ArgumentError("invalid balance sample"))
    vs=(x.B_xyz_T,x.J_xyz_A_m2,x.grad_p_xyz_N_m3,x.F_desc_xyz_N_m3,x.JxB_minus_gradp_xyz_N_m3,x.F_discrepancy_xyz_N_m3)
    all(v->all(isfinite,v),vs) || throw(ArgumentError("nonfinite balance vector"))
    e=canonical_hash(semantic_view(x)); e==x.sample_hash || throw(ArgumentError("balance sample hash mismatch")); e
end

struct DESCStaticMHDBalanceReceiptV4
    command::String; input_path::String; output_path::String; adapter_path::String; upstream_hdf5_path::String; python_executable::String; desc_module_path::String
    input_sha256::Digest256; output_sha256::Union{Nothing,Digest256}; adapter_sha256::Digest256; upstream_hdf5_sha256::Digest256; python_sha256::Digest256; desc_module_sha256::Digest256
    exit_code::Int; output_schema_validated::Bool; process_hash::Digest256; receipt_hash::Digest256
end
semantic_view(x::DESCStaticMHDBalanceReceiptV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::DESCStaticMHDBalanceReceiptV4); e=canonical_hash(semantic_view(x)); e==x.receipt_hash||throw(ArgumentError("balance receipt hash mismatch"));e end
function validate_desc_static_mhd_balance_receipt(x::DESCStaticMHDBalanceReceiptV4)
    canonical_hash(x); names=fieldnames(typeof(x))[1:end-2]; body=NamedTuple{names}(ntuple(i->getfield(x,i),length(names))); canonical_hash(body)==x.process_hash||throw(ArgumentError("balance process hash mismatch"))
    x.adapter_sha256==_DSMB_ADAPTER_SHA256 || throw(ArgumentError("untrusted balance adapter"))
    x.command==string(Cmd([x.python_executable,x.adapter_path,x.upstream_hdf5_path,
        x.input_path,x.output_path,x.desc_module_path])) ||
        throw(ArgumentError("balance command mismatch"))
    for (p,h) in ((x.input_path,x.input_sha256),(x.adapter_path,x.adapter_sha256),(x.upstream_hdf5_path,x.upstream_hdf5_sha256),(x.python_executable,x.python_sha256),(x.desc_module_path,x.desc_module_sha256))
        isfile(p)&&_dsmb_sha(p)==h||throw(ArgumentError("balance artifact tampered"))
    end
    x.output_sha256!==nothing&&isfile(x.output_path)&&_dsmb_sha(x.output_path)==x.output_sha256||throw(ArgumentError("balance output missing/tampered"))
    x.exit_code==0&&x.output_schema_validated||throw(ArgumentError("balance process unsuccessful")); true
end

struct DESCStaticMHDBalanceRequestV4
    context_hash::Digest256; candidate_hash::Digest256; surface_result_hash::Digest256
    traction_request_hash::Digest256; traction_result_hash::Digest256; pressure_result_hash::Digest256
    desc_version::String; nfp::Int; points::Tuple; positions_xyz_m::Tuple
    source_path::String; source_sha256::Digest256; claim_ceiling::ClaimCeiling; regional_force_balance_sampled::Bool; cross_checked::Bool; request_hash::Digest256
end
semantic_view(x::DESCStaticMHDBalanceRequestV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::DESCStaticMHDBalanceRequestV4)
    x.claim_ceiling==screen_only&&x.regional_force_balance_sampled&&x.cross_checked&&
        !isempty(x.desc_version)&&x.nfp>0&&length(x.points)==length(x.positions_xyz_m)&&
        all(p->length(p)==3&&all(isfinite,p),x.positions_xyz_m)&&
        isfile(x.source_path)&&_dsmb_sha(x.source_path)==x.source_sha256||throw(ArgumentError("balance authority/source mismatch")); e=canonical_hash(semantic_view(x));e==x.request_hash||throw(ArgumentError("balance request hash mismatch"));e
end

struct DESCStaticMHDBalanceResultV4
    status::Symbol; context_hash::Digest256; candidate_hash::Digest256; request_hash::Digest256; samples::Tuple; regional_force_balance_sampled::Bool; cross_checked::Bool; interface_flux_executed::Bool; regional_residual_assembled::Bool; jacobian_executed::Bool; solver_convergence_validated::Bool; multiregion_closure::Bool; physical_validation::Bool; emits_evidence::Bool; grants_pass::Bool; promotion_authority::Bool; p5_ready::Bool; terminal_authority::Bool; credible_physical_device_count::Int; claim_ceiling::ClaimCeiling; receipt::DESCStaticMHDBalanceReceiptV4; result_hash::Digest256
end
semantic_view(x::DESCStaticMHDBalanceResultV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::DESCStaticMHDBalanceResultV4)
    foreach(canonical_hash,x.samples); x.status==:desc_static_mhd_balance_sampled&&x.regional_force_balance_sampled&&x.cross_checked&&!x.interface_flux_executed&&!x.regional_residual_assembled&&!x.jacobian_executed&&!x.solver_convergence_validated&&!x.multiregion_closure&&!x.physical_validation&&!x.emits_evidence&&!x.grants_pass&&!x.promotion_authority&&!x.p5_ready&&!x.terminal_authority&&x.credible_physical_device_count==0&&x.claim_ceiling==screen_only||throw(ArgumentError("balance authority exceeded"));e=canonical_hash(semantic_view(x));e==x.result_hash||throw(ArgumentError("balance result hash mismatch"));e
end

function _dsmb_request(context, surface_result, traction_request, traction_result, pressure_result)
    pts=Tuple(s.point for s in pressure_result.samples)
    positions=Tuple(p for s in surface_result.samples for p in
        (s.minus_position_xyz_m,s.plus_position_xyz_m))
    length(pts)==length(positions)||throw(ArgumentError("balance point/position coverage mismatch"))
    body=(context_hash=context.context_hash,candidate_hash=context.candidate_hash,surface_result_hash=canonical_hash(surface_result),traction_request_hash=canonical_hash(traction_request),traction_result_hash=canonical_hash(traction_result),pressure_result_hash=canonical_hash(pressure_result),desc_version=surface_result.desc_version,nfp=surface_result.nfp,points=pts,positions_xyz_m=positions,source_path=_DSMB_SOURCE_PATH,source_sha256=_dsmb_sha(_DSMB_SOURCE_PATH),claim_ceiling=screen_only,regional_force_balance_sampled=true,cross_checked=true); DESCStaticMHDBalanceRequestV4(values(body)...,canonical_hash(body))
end
function _dsmb_text(req)
    join(["SCHEMA\tfusionconceptai:runtime-v4-desc-static-mhd-balance-request","COUNT\t$(length(req.points))",["POINT\t$i\t$(repr(p.rho))\t$(repr(p.theta_rad))\t$(repr(p.zeta_rad))" for (i,p) in enumerate(req.points)]...,"END\t1"],"\n")*"\n"
end
function _dsmb_parse(path,req)
    l=[split(chomp(x),'\t';keepempty=true) for x in readlines(path)]
    length(l)==length(req.points)+5&&l[1]==["SCHEMA","fusionconceptai:runtime-v4-desc-static-mhd-balance-output"]&&
        l[2]==["DESC_VERSION",req.desc_version]&&l[3]==["NFP",string(req.nfp)]&&
        l[4]==["COUNT",string(length(req.points))]&&l[end]==["END","1"]||
        throw(ArgumentError("balance output framing/metadata")); out=[]
    for (i,p) in enumerate(req.points); r=l[i+4]; length(r)==17&&r[1]=="POINT"&&tryparse(Int,r[2])==i||throw(ArgumentError("balance point row")); vals=parse.(Float64,r[3:end]); all(isfinite,vals)||throw(ArgumentError("balance nonfinite")); Tuple(vals[1:3])==(p.rho,p.theta_rad,p.zeta_rad)||throw(ArgumentError("balance output point coordinates mismatch")); push!(out,(p=p,b=Tuple(vals[4:6]),j=Tuple(vals[7:9]),gp=Tuple(vals[10:12]),f=Tuple(vals[13:15]))) end; out
end
function execute_desc_static_mhd_balance(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        traction_request, traction_result, pressure_request, pressure_result; run_dir)
    validate_ideal_mhd_interface_traction_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result, traction_request, traction_result)
    canonical_hash(traction_request); canonical_hash(traction_result); canonical_hash(pressure_result); req=_dsmb_request(context,surface_result,traction_request,traction_result,pressure_result); canonical_hash(req); dir=String(run_dir);mkpath(dir); ip=joinpath(dir,"balance_request.tsv");op=joinpath(dir,"balance_result.tsv");ap=joinpath(dir,"balance_adapter.py");write(ip,_dsmb_text(req));write(ap,_DSMB_ADAPTER); exe=String(pressure_result.receipt.python_executable); h5=String(pressure_result.receipt.upstream_hdf5_path); mod=String(pressure_result.receipt.desc_module_path); cmd=`$exe $ap $h5 $ip $op $mod`; ob,eb=IOBuffer(),IOBuffer(); pr=run(pipeline(ignorestatus(cmd),stdout=ob,stderr=eb)); proc=(command=string(cmd),input_path=ip,output_path=op,adapter_path=ap,upstream_hdf5_path=h5,python_executable=exe,desc_module_path=mod,input_sha256=_dsmb_sha(ip),output_sha256 = isfile(op) ? _dsmb_sha(op) : nothing,adapter_sha256=_dsmb_sha(ap),upstream_hdf5_sha256=_dsmb_sha(h5),python_sha256=_dsmb_sha(exe),desc_module_sha256=_dsmb_sha(mod),exit_code=pr.exitcode,output_schema_validated=false); parsed=pr.exitcode == 0 ? _dsmb_parse(op,req) : throw(ArgumentError("balance process exit $(pr.exitcode): $(String(take!(eb)))")); receipt_body=merge(proc,(output_schema_validated=true,)); receipt=DESCStaticMHDBalanceReceiptV4(values(merge(receipt_body,(process_hash=canonical_hash(receipt_body),)))...,canonical_hash(merge(receipt_body,(process_hash=canonical_hash(receipt_body),)))); validate_desc_static_mhd_balance_receipt(receipt); samples=[]; for (i,q) in enumerate(parsed); pos=req.positions_xyz_m[i]; B=_dsmb_cart(q.b,pos); J=_dsmb_cart(q.j,pos); gp=_dsmb_cart(q.gp,pos); F=_dsmb_cart(q.f,pos); JxB=_dsmb_cross(J,B); res=ntuple(k->JxB[k]-gp[k],3); discrepancy=ntuple(k->F[k]-res[k],3); abs_tol=1.0e-8; rel_tol=1.0e-8; all(abs(discrepancy[k]) <= abs_tol + rel_tol*max(abs(F[k]),abs(res[k])) for k in 1:3) || throw(ArgumentError("DESC F disagrees with JxB-grad(p)")); body=(point_hash=canonical_hash(q.p),rho=q.p.rho,theta_rad=q.p.theta_rad,zeta_rad=q.p.zeta_rad,B_xyz_T=B,J_xyz_A_m2=J,grad_p_xyz_N_m3=gp,F_desc_xyz_N_m3=F,JxB_minus_gradp_xyz_N_m3=res,force_balance_error_norm_N_m3=norm(collect(res)),F_discrepancy_xyz_N_m3=discrepancy,F_discrepancy_norm_N_m3=norm(collect(discrepancy)),F_crosscheck_abs_tol_N_m3=abs_tol,F_crosscheck_rel_tol=rel_tol,F_crosschecked=true); push!(samples,DESCStaticMHDBalanceSampleV4(values(body)...,canonical_hash(body))) end; body=(status=:desc_static_mhd_balance_sampled,context_hash=context.context_hash,candidate_hash=context.candidate_hash,request_hash=req.request_hash,samples=Tuple(samples),regional_force_balance_sampled=true,cross_checked=true,interface_flux_executed=false,regional_residual_assembled=false,jacobian_executed=false,solver_convergence_validated=false,multiregion_closure=false,physical_validation=false,emits_evidence=false,grants_pass=false,promotion_authority=false,p5_ready=false,terminal_authority=false,credible_physical_device_count=0,claim_ceiling=screen_only,receipt=receipt); result=DESCStaticMHDBalanceResultV4(values(body)...,canonical_hash(body)); validate_desc_static_mhd_balance_result(context,surface_result,traction_request,traction_result,pressure_result,req,result); result
end
function validate_desc_static_mhd_balance_result(context, surface_result, traction_request,
        traction_result, pressure_result, req::DESCStaticMHDBalanceRequestV4,
        result::DESCStaticMHDBalanceResultV4)
    context.context_hash == req.context_hash == result.context_hash &&
        context.candidate_hash == req.candidate_hash == result.candidate_hash ||
        throw(ArgumentError("balance context/candidate mismatch"))
    canonical_hash(surface_result); canonical_hash(traction_request); canonical_hash(traction_result)
    canonical_hash(pressure_result); canonical_hash(req); canonical_hash(result)
    req.surface_result_hash == canonical_hash(surface_result) &&
        req.positions_xyz_m == Tuple(p for s in surface_result.samples for p in
            (s.minus_position_xyz_m,s.plus_position_xyz_m)) &&
        req.traction_request_hash == canonical_hash(traction_request) &&
        req.traction_result_hash == canonical_hash(traction_result) &&
        req.pressure_result_hash == canonical_hash(pressure_result) &&
        req.points == Tuple(s.point for s in pressure_result.samples) &&
        req.desc_version == pressure_result.desc_version && req.nfp == pressure_result.nfp &&
        result.request_hash == req.request_hash &&
        traction_result.request_hash == traction_request.request_hash &&
        traction_result.context_hash == context.context_hash &&
        traction_result.candidate_hash == context.candidate_hash &&
        pressure_result.context_hash == context.context_hash &&
        pressure_result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("balance upstream/request identity mismatch"))
    validate_desc_static_mhd_balance_receipt(result.receipt)
    length(result.samples) == length(pressure_result.samples) ||
        throw(ArgumentError("balance result sample count mismatch"))
    parsed = _dsmb_parse(result.receipt.output_path, req)
    for (index, (s, p)) in enumerate(zip(result.samples, pressure_result.samples))
        s.point_hash == canonical_hash(p.point) || throw(ArgumentError("balance point identity mismatch"))
        raw = parsed[index]; position = req.positions_xyz_m[index]
        raw.b == p.B_desc_native_T &&
            raw.f == p.force_balance_error_desc_native_N_m3 ||
            throw(ArgumentError("balance B/F disagree with sealed pressure trace"))
        replayed = (_dsmb_cart(raw.b,position),_dsmb_cart(raw.j,position),
            _dsmb_cart(raw.gp,position),_dsmb_cart(raw.f,position))
        replayed == (s.B_xyz_T,s.J_xyz_A_m2,s.grad_p_xyz_N_m3,s.F_desc_xyz_N_m3) ||
            throw(ArgumentError("balance sample differs from sealed output replay"))
        b = s.B_xyz_T; j = s.J_xyz_A_m2; gp = s.grad_p_xyz_N_m3
        jxb = _dsmb_cross(j,b)
        computed = ntuple(k -> jxb[k] - gp[k], 3)
        all(isapprox.(computed, s.JxB_minus_gradp_xyz_N_m3; atol=0.0, rtol=0.0)) ||
            throw(ArgumentError("balance residual was not independently recomputed"))
        all(abs(s.F_discrepancy_xyz_N_m3[k] - (s.F_desc_xyz_N_m3[k] - computed[k])) == 0.0 for k in 1:3) ||
            throw(ArgumentError("balance discrepancy mismatch"))
        s.force_balance_error_norm_N_m3 == norm(collect(computed)) &&
            s.F_discrepancy_norm_N_m3 == norm(collect(s.F_discrepancy_xyz_N_m3)) &&
            all(abs(s.F_discrepancy_xyz_N_m3[k]) <= s.F_crosscheck_abs_tol_N_m3 +
                s.F_crosscheck_rel_tol*max(abs(s.F_desc_xyz_N_m3[k]),abs(computed[k])) for k in 1:3) ||
            throw(ArgumentError("balance norm/cross-check mismatch"))
    end
    result.result_hash
end
""" Add only the specified new files; focused integration is supplied by example/test. """
