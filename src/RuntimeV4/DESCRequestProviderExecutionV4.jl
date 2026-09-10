# Candidate-bound DESC 0.17 provider execution with replayable receipts.
using FusionConceptAI
using SHA
import FusionConceptAI: canonical_hash, semantic_view

const _DGRPE_REVISION = "runtime-v4-desc-request-provider-execution-v3"
const _DGRPE_SCHEMA = "fusionconceptai:runtime-v4-desc-request-provider-execution"
mutable struct _DGRPEPrivateToken end
const _DGRPE_TOKEN = _DGRPEPrivateToken()

struct DESCExecutionControlsV4
    L::Int; M::Int; N::Int; L_grid::Int; M_grid::Int; N_grid::Int
    maxiter::Int; ftol::Float64; xtol::Float64; gtol::Float64
end
function DESCExecutionControlsV4(L, M, N, L_grid, M_grid, N_grid, maxiter, ftol, xtol, gtol)
    integers = (L, M, N, L_grid, M_grid, N_grid, maxiter)
    all(x -> x isa Integer && x >= 1, integers) || throw(ArgumentError("DESC controls must be positive integers"))
    tolerances = (ftol, xtol, gtol)
    all(x -> x isa Real && isfinite(Float64(x)) && Float64(x) > 0, tolerances) || throw(ArgumentError("DESC tolerances must be finite and positive"))
    DESCExecutionControlsV4(Int.(integers)..., Float64.(tolerances)...)
end

struct DESCExecutionPayloadV4
    nfp::Int; psi::Float64
    L::Int; M::Int; N::Int; L_grid::Int; M_grid::Int; N_grid::Int
    optimizer::String; maxiter::Int; ftol::Float64; xtol::Float64; gtol::Float64
    R_modes::Tuple{Vararg{Tuple{Int,Int,Int,Float64}}}
    Z_modes::Tuple{Vararg{Tuple{Int,Int,Int,Float64}}}
    pressure::Tuple{Vararg{Tuple{Int,Float64}}}
    iota::Tuple{Vararg{Tuple{Int,Float64}}}
    payload_hash::Digest256
    function DESCExecutionPayloadV4(token::_DGRPEPrivateToken, fields...)
        token === _DGRPE_TOKEN || throw(ArgumentError("private DESC payload constructor"))
        new(fields...)
    end
end
_dgrpe_payload_body(nfp, psi, c, R, Z, pressure, iota) = (nfp=nfp, psi=psi,
    L=c.L, M=c.M, N=c.N, L_grid=c.L_grid, M_grid=c.M_grid, N_grid=c.N_grid,
    optimizer="lsq-exact", maxiter=c.maxiter, ftol=c.ftol, xtol=c.xtol, gtol=c.gtol,
    R_modes=R, Z_modes=Z, pressure=pressure, iota=iota)
semantic_view(x::DESCExecutionPayloadV4) = (nfp=x.nfp, psi=x.psi, L=x.L, M=x.M,
    N=x.N, L_grid=x.L_grid, M_grid=x.M_grid, N_grid=x.N_grid,
    optimizer=x.optimizer, maxiter=x.maxiter, ftol=x.ftol, xtol=x.xtol, gtol=x.gtol,
    R_modes=x.R_modes, Z_modes=x.Z_modes, pressure=x.pressure, iota=x.iota)
function canonical_hash(x::DESCExecutionPayloadV4)
    x.nfp >= 1 && isfinite(x.psi) && x.psi > 0 || throw(ArgumentError("invalid DESC field period or flux"))
    x.optimizer == "lsq-exact" || throw(ArgumentError("unsupported DESC optimizer"))
    c = DESCExecutionControlsV4(x.L, x.M, x.N, x.L_grid, x.M_grid, x.N_grid, x.maxiter, x.ftol, x.xtol, x.gtol)
    !isempty(x.R_modes) && !isempty(x.Z_modes) && !isempty(x.pressure) && !isempty(x.iota) || throw(ArgumentError("DESC payload arrays must be nonempty"))
    all(m -> m[1] == 0 && isfinite(m[4]), x.R_modes) && all(m -> m[1] == 0 && isfinite(m[4]), x.Z_modes) || throw(ArgumentError("invalid DESC Fourier mode"))
    all(v -> v[1] >= 0 && isfinite(v[2]), x.pressure) && all(v -> v[1] >= 0 && isfinite(v[2]), x.iota) || throw(ArgumentError("invalid DESC profile coefficient"))
    length(unique((m[2],m[3]) for m in x.R_modes)) == length(x.R_modes) && length(unique((m[2],m[3]) for m in x.Z_modes)) == length(x.Z_modes) || throw(ArgumentError("duplicate DESC Fourier mode"))
    first.(x.pressure) == Tuple(0:length(x.pressure)-1) && first.(x.iota) == Tuple(0:length(x.iota)-1) || throw(ArgumentError("DESC profile powers must be contiguous from zero"))
    expected = canonical_hash(_dgrpe_payload_body(x.nfp, x.psi, c, x.R_modes, x.Z_modes, x.pressure, x.iota))
    expected == x.payload_hash || throw(ArgumentError("DESC payload hash mismatch"))
    expected
end

struct DESCEnvironmentProbeV4
    executable::Union{Nothing,String}; provider_executable::Union{Nothing,String}
    python_version::Union{Nothing,String}; desc_importable::Bool
    desc_version::Union{Nothing,String}; probe_command::String
    stdout::String; stderr::String; probe_hash::Digest256
end
semantic_view(x::DESCEnvironmentProbeV4) = (executable=x.executable,
    provider_executable=x.provider_executable, python_version=x.python_version,
    desc_importable=x.desc_importable, desc_version=x.desc_version,
    probe_command=x.probe_command, stdout=x.stdout, stderr=x.stderr)
function canonical_hash(x::DESCEnvironmentProbeV4)
    canonical_hash(semantic_view(x)) == x.probe_hash ? x.probe_hash : throw(ArgumentError("DESC probe hash mismatch"))
end
function probe_desc_environment(; python=nothing)
    candidates = python === nothing ? String[get(ENV,"DESC_PYTHON",""), joinpath(pwd(),".venv-desc","Scripts","python.exe"), joinpath(dirname(pwd()),"outputs","fusion_concept_ai",".venv-desc","Scripts","python.exe"), Sys.which("python") === nothing ? "" : String(Sys.which("python"))] : [String(python)]
    ix=findfirst(isfile,candidates); exe=ix===nothing ? nothing : candidates[ix]
    cmd="import sys,importlib.util; import desc; print(sys.version); print('DESC_IMPORTABLE=' + str(importlib.util.find_spec('desc') is not None)); print('DESC_VERSION=' + str(getattr(desc,'__version__','unknown')))"
    if exe===nothing
        body=(executable=nothing,provider_executable=nothing,python_version=nothing,desc_importable=false,desc_version=nothing,probe_command=cmd,stdout="",stderr="python executable not found")
        return DESCEnvironmentProbeV4(body...,canonical_hash(body))
    end
    out=try read(`$exe -c $cmd`,String) catch e; sprint(showerror,e) end
    ok=occursin("DESC_IMPORTABLE=True",out); lines=split(out,'\n'); version=isempty(lines) ? nothing : String(first(lines))
    vm=match(r"DESC_VERSION=([^\r\n]+)",out); dv=vm===nothing ? nothing : String(vm.captures[1]); provider=joinpath(dirname(exe),"desc.exe")
    body=(executable=String(exe),provider_executable=isfile(provider) ? provider : nothing,python_version=version,desc_importable=ok,desc_version=dv,probe_command=cmd,stdout=out,stderr="")
    DESCEnvironmentProbeV4(body...,canonical_hash(body))
end

struct DESCProviderReceiptV4
    command::String; inspection_command::String
    input_path::String; output_path::String; adapter_path::String; inspector_path::String
    python_executable::String; desc_module_path::String
    input_sha256::Digest256; output_sha256::Union{Nothing,Digest256}
    adapter_source_sha256::Digest256; inspector_source_sha256::Digest256
    python_executable_sha256::Digest256; desc_module_sha256::Digest256
    exit_code::Int; inspection_exit_code::Union{Nothing,Int}
    stdout::String; stderr::String; inspection_stdout::String; inspection_stderr::String
    output_schema_validated::Bool; process_hash::Digest256; receipt_hash::Digest256
end
semantic_view(x::DESCProviderReceiptV4) = (command=x.command,
    inspection_command=x.inspection_command, input_path=x.input_path,
    output_path=x.output_path, adapter_path=x.adapter_path,
    inspector_path=x.inspector_path, python_executable=x.python_executable,
    desc_module_path=x.desc_module_path, input_sha256=x.input_sha256,
    output_sha256=x.output_sha256, adapter_source_sha256=x.adapter_source_sha256,
    inspector_source_sha256=x.inspector_source_sha256,
    python_executable_sha256=x.python_executable_sha256,
    desc_module_sha256=x.desc_module_sha256, exit_code=x.exit_code,
    inspection_exit_code=x.inspection_exit_code, stdout=x.stdout, stderr=x.stderr,
    inspection_stdout=x.inspection_stdout, inspection_stderr=x.inspection_stderr,
    output_schema_validated=x.output_schema_validated, process_hash=x.process_hash)
function canonical_hash(x::DESCProviderReceiptV4)
    canonical_hash(semantic_view(x))==x.receipt_hash ? x.receipt_hash : throw(ArgumentError("DESC provider receipt hash mismatch"))
end
_dgrpe_sha256(path::AbstractString) = Digest256(bytes2hex(SHA.sha256(read(path))))
function validate_desc_provider_receipt(r::DESCProviderReceiptV4)
    canonical_hash(r)
    for (path, expected, label) in ((r.input_path,r.input_sha256,"input"), (r.adapter_path,r.adapter_source_sha256,"adapter"), (r.inspector_path,r.inspector_source_sha256,"inspector"), (r.python_executable,r.python_executable_sha256,"Python"), (r.desc_module_path,r.desc_module_sha256,"DESC module"))
        isfile(path) && _dgrpe_sha256(path)==expected || throw(ArgumentError("DESC $(label) receipt was tampered"))
    end
    r.output_sha256 === nothing || (isfile(r.output_path) && _dgrpe_sha256(r.output_path)==r.output_sha256) || throw(ArgumentError("DESC output receipt was tampered"))
    r.exit_code==0 && r.inspection_exit_code==0 && r.output_schema_validated || throw(ArgumentError("DESC receipt does not contain a validated output"))
    true
end

struct DESCExecutionRequestV4
    context_hash::Digest256; candidate_hash::Digest256
    compatibility_certificate_hash::Digest256
    runner_payload::DESCExecutionPayloadV4; request_hash::Digest256
    function DESCExecutionRequestV4(token::_DGRPEPrivateToken, context_hash, candidate_hash, certificate_hash, payload)
        token === _DGRPE_TOKEN || throw(ArgumentError("private DESC request constructor")); canonical_hash(payload)
        body=(context_hash=context_hash,candidate_hash=candidate_hash,compatibility_certificate_hash=certificate_hash,runner_payload=payload)
        new(context_hash,candidate_hash,certificate_hash,payload,canonical_hash(body))
    end
end
semantic_view(x::DESCExecutionRequestV4)=(context_hash=x.context_hash,candidate_hash=x.candidate_hash,compatibility_certificate_hash=x.compatibility_certificate_hash,runner_payload=x.runner_payload)
function canonical_hash(x::DESCExecutionRequestV4)
    canonical_hash(x.runner_payload)
    canonical_hash(semantic_view(x))==x.request_hash ? x.request_hash : throw(ArgumentError("DESC request hash mismatch"))
end

function _dgrpe_candidate_payload(context, bridge, controls::DESCExecutionControlsV4)
    boundary=_dgpi_candidate_program(context,bridge).program.boundary
    declarations=Tuple(x for x in context.candidate.field_geometry_genome_ref.fields if nameof(typeof(x)) === :ThreeDPhysicalProviderInputV4)
    length(declarations)==1 || throw(ArgumentError("DESC request requires exactly one candidate-owned physical declaration"))
    profiles=only(declarations).profiles_flux
    R=Tuple((0,Int(x.poloidal_mode),Int(x.toroidal_mode),Float64(x.coefficient_m)) for x in boundary.radial_coefficients)
    Z=Tuple((0,Int(x.poloidal_mode),Int(x.toroidal_mode),Float64(x.coefficient_m)) for x in boundary.vertical_coefficients)
    pressure=Tuple((i-1,Float64(v)) for (i,v) in enumerate(profiles.pressure.coefficients))
    iota=Tuple((i-1,Float64(v)) for (i,v) in enumerate(profiles.rotational_or_current.coefficients))
    body=_dgrpe_payload_body(Int(boundary.field_periods),
        Float64(profiles.toroidal_flux_wb),controls,R,Z,pressure,iota)
    payload=DESCExecutionPayloadV4(_DGRPE_TOKEN,body...,canonical_hash(body)); canonical_hash(payload); payload
end
function make_desc_execution_request(context,bridge,evaluation,proof,controls::DESCExecutionControlsV4)
    validate_desc_geometry_compatibility(context,bridge,evaluation,proof)
    payload=_dgrpe_candidate_payload(context,bridge,controls)
    DESCExecutionRequestV4(_DGRPE_TOKEN,context.context_hash,context.candidate_hash,canonical_hash(proof.certificate),payload)
end

struct DESCRequestProviderExecutionV4
    status::Symbol; context_hash::Digest256; candidate_hash::Digest256
    compatibility_certificate_hash::Digest256; probe_hash::Digest256; request_hash::Digest256
    provider_selected::Bool; provider_executed::Bool
    solver_execution_attempted::Bool; solver_executed::Bool; result_schema_validated::Bool
    physical_validation::Bool; engineering_validation::Bool; emits_evidence::Bool
    grants_pass::Bool; promotion_authority::Bool; p5_ready::Bool; terminal_authority::Bool
    credible_physical_device_count::Int; request_emitted::Bool
    receipt::Union{Nothing,DESCProviderReceiptV4}; claim_ceiling::ClaimCeiling; result_hash::Digest256
end
semantic_view(x::DESCRequestProviderExecutionV4)=(revision=_DGRPE_REVISION,schema=_DGRPE_SCHEMA,status=x.status,context_hash=x.context_hash,candidate_hash=x.candidate_hash,compatibility_certificate_hash=x.compatibility_certificate_hash,probe_hash=x.probe_hash,request_hash=x.request_hash,provider_selected=x.provider_selected,provider_executed=x.provider_executed,solver_execution_attempted=x.solver_execution_attempted,solver_executed=x.solver_executed,result_schema_validated=x.result_schema_validated,physical_validation=x.physical_validation,engineering_validation=x.engineering_validation,emits_evidence=x.emits_evidence,grants_pass=x.grants_pass,promotion_authority=x.promotion_authority,p5_ready=x.p5_ready,terminal_authority=x.terminal_authority,credible_physical_device_count=x.credible_physical_device_count,request_emitted=x.request_emitted,receipt_hash=x.receipt===nothing ? nothing : canonical_hash(x.receipt),claim_ceiling=x.claim_ceiling)
function canonical_hash(x::DESCRequestProviderExecutionV4)
    x.receipt===nothing || canonical_hash(x.receipt)
    x.claim_ceiling==screen_only && x.provider_selected && !x.physical_validation && !x.engineering_validation && !x.emits_evidence && !x.grants_pass && !x.promotion_authority && !x.p5_ready && !x.terminal_authority && x.credible_physical_device_count==0 || throw(ArgumentError("DESC execution authority ceiling was exceeded"))
    x.provider_executed==x.solver_executed && (!x.result_schema_validated || x.solver_executed) || throw(ArgumentError("DESC execution status fields are inconsistent"))
    canonical_hash(semantic_view(x))==x.result_hash ? x.result_hash : throw(ArgumentError("DESC execution result hash mismatch"))
end
function _dgrpe_result(status,context,request,certificate,probe;attempted=false,executed=false,schema_validated=false,emitted=false,receipt=nothing)
    body=(status=status,context_hash=canonical_hash(context),candidate_hash=context.candidate_hash,compatibility_certificate_hash=canonical_hash(certificate),probe_hash=probe.probe_hash,request_hash=canonical_hash(request),provider_selected=true,provider_executed=executed,solver_execution_attempted=attempted,solver_executed=executed,result_schema_validated=schema_validated,physical_validation=false,engineering_validation=false,emits_evidence=false,grants_pass=false,promotion_authority=false,p5_ready=false,terminal_authority=false,credible_physical_device_count=0,request_emitted=emitted,receipt=receipt,claim_ceiling=screen_only)
    hash_body=merge((revision=_DGRPE_REVISION,schema=_DGRPE_SCHEMA),Base.structdiff(body,NamedTuple{(:receipt,)}),(receipt_hash=receipt===nothing ? nothing : canonical_hash(receipt),))
    result=DESCRequestProviderExecutionV4(body...,canonical_hash(hash_body)); canonical_hash(result); result
end

function _dgrpe_line_payload(p::DESCExecutionPayloadV4)
    canonical_hash(p); scalar(x)=x isa AbstractString ? "\"$(x)\"" : string(x); array(xs)="["*join(("["*join(scalar.(x),",")*"]" for x in xs),",")*"]"
    "{"*join(("\"nfp\":"*scalar(p.nfp),"\"psi\":"*scalar(p.psi),"\"L\":"*scalar(p.L),"\"M\":"*scalar(p.M),"\"N\":"*scalar(p.N),"\"L_grid\":"*scalar(p.L_grid),"\"M_grid\":"*scalar(p.M_grid),"\"N_grid\":"*scalar(p.N_grid),"\"optimizer\":"*scalar(p.optimizer),"\"maxiter\":"*scalar(p.maxiter),"\"ftol\":"*scalar(p.ftol),"\"xtol\":"*scalar(p.xtol),"\"gtol\":"*scalar(p.gtol),"\"R_modes\":"*array(p.R_modes),"\"Z_modes\":"*array(p.Z_modes),"\"pressure\":"*array(p.pressure),"\"iota\":"*array(p.iota)),",")*"}"
end

const _DGRPE_ADAPTER_SOURCE="""
import json, sys
from desc.geometry import FourierRZToroidalSurface
from desc.profiles import PowerSeriesProfile
from desc.equilibrium import Equilibrium
with open(sys.argv[1], encoding='utf-8') as stream: req=json.load(stream)
surf=FourierRZToroidalSurface(R_lmn=[x[3] for x in req['R_modes']], Z_lmn=[x[3] for x in req['Z_modes']], modes_R=[[x[1],x[2]] for x in req['R_modes']], modes_Z=[[x[1],x[2]] for x in req['Z_modes']], NFP=req['nfp'], sym=True)
eq=Equilibrium(L=req['L'], M=req['M'], N=req['N'], L_grid=req['L_grid'], M_grid=req['M_grid'], N_grid=req['N_grid'], NFP=req['nfp'], Psi=req['psi'], surface=surf, pressure=PowerSeriesProfile([x[1] for x in req['pressure']], sym=False), iota=PowerSeriesProfile([x[1] for x in req['iota']], sym=False), spectral_indexing='ansi')
eq, _=eq.solve(objective='force', optimizer=req['optimizer'], maxiter=req['maxiter'], ftol=req['ftol'], xtol=req['xtol'], gtol=req['gtol'], verbose=0, copy=True)
eq.save(sys.argv[2])
print('DESC_PROVIDER_EXECUTED=1')
print('DESC_VERSION='+__import__('desc').__version__)
"""
const _DGRPE_INSPECTOR_SOURCE="""
import json, math, sys
import numpy as np
import desc
from desc.io import load
with open(sys.argv[1], encoding='utf-8') as stream: req=json.load(stream)
eq=load(sys.argv[2])
assert type(eq).__name__=='Equilibrium'
assert eq.NFP==req['nfp'] and math.isclose(float(eq.Psi),req['psi'])
assert (eq.L,eq.M,eq.N,eq.L_grid,eq.M_grid,eq.N_grid)==tuple(req[k] for k in ('L','M','N','L_grid','M_grid','N_grid'))
assert eq.spectral_indexing=='ansi' and eq.surface.NFP==req['nfp']
def coefficients(basis,values): return {(int(mode[1]),int(mode[2])):float(value) for mode,value in zip(basis.modes,values)}
radial=coefficients(eq.surface.R_basis,eq.surface.R_lmn); vertical=coefficients(eq.surface.Z_basis,eq.surface.Z_lmn)
for _,m,n,value in req['R_modes']: assert math.isclose(radial[(m,n)],value,rel_tol=1e-12,abs_tol=1e-12)
for _,m,n,value in req['Z_modes']: assert math.isclose(vertical[(m,n)],value,rel_tol=1e-12,abs_tol=1e-12)
assert np.allclose(eq.pressure.params[:len(req['pressure'])],[x[1] for x in req['pressure']],rtol=1e-12,atol=1e-12)
assert np.allclose(eq.iota.params[:len(req['iota'])],[x[1] for x in req['iota']],rtol=1e-12,atol=1e-12)
print('DESC_OUTPUT_INSPECTION_OK=1'); print('DESC_VERSION='+desc.__version__); print('EQUILIBRIUM_TYPE='+type(eq).__name__)
print('NFP='+str(eq.NFP)); print('PSI='+repr(float(eq.Psi))); print('RESOLUTION='+','.join(str(x) for x in (eq.L,eq.M,eq.N,eq.L_grid,eq.M_grid,eq.N_grid)))
"""

function _dgrpe_run(probe,input_path,output_path,adapter_path,inspector_path)
    probe.desc_importable && probe.executable!==nothing || throw(ArgumentError("DESC provider executable is unavailable")); exe=String(probe.executable)
    cmd=`$exe $adapter_path $input_path $output_path`; out=IOBuffer(); err=IOBuffer(); proc=run(pipeline(ignorestatus(cmd),stdout=out,stderr=err)); code=proc.exitcode; stdout=String(take!(out)); stderr=String(take!(err))
    icmd=`$exe $inspector_path $input_path $output_path`; iout=IOBuffer(); ierr=IOBuffer(); icode=nothing
    if code==0 && isfile(output_path); iproc=run(pipeline(ignorestatus(icmd),stdout=iout,stderr=ierr)); icode=iproc.exitcode; end
    istout=String(take!(iout)); ister=String(take!(ierr)); validated=icode==0 && occursin("DESC_OUTPUT_INSPECTION_OK=1",istout)
    module_path=normpath(joinpath(dirname(exe),"..","Lib","site-packages","desc","__init__.py")); paths=(input_path,adapter_path,inspector_path,exe,module_path); all(isfile,paths) || throw(ArgumentError("DESC execution identity file is missing"))
    ih=_dgrpe_sha256(input_path); oh=isfile(output_path) ? _dgrpe_sha256(output_path) : nothing; ah=_dgrpe_sha256(adapter_path); ish=_dgrpe_sha256(inspector_path); pyh=_dgrpe_sha256(exe); mh=_dgrpe_sha256(module_path)
    process_body=(command=string(cmd),inspection_command=string(icmd),exit_code=code,inspection_exit_code=icode,stdout=stdout,stderr=stderr,inspection_stdout=istout,inspection_stderr=ister,input_sha256=ih,output_sha256=oh,adapter_source_sha256=ah,inspector_source_sha256=ish,python_executable_sha256=pyh,desc_module_sha256=mh,output_schema_validated=validated)
    receipt_body=(command=string(cmd),inspection_command=string(icmd),
        input_path=String(input_path),output_path=String(output_path),
        adapter_path=String(adapter_path),inspector_path=String(inspector_path),
        python_executable=exe,desc_module_path=module_path,
        input_sha256=ih,output_sha256=oh,adapter_source_sha256=ah,
        inspector_source_sha256=ish,python_executable_sha256=pyh,
        desc_module_sha256=mh,exit_code=code,inspection_exit_code=icode,
        stdout=stdout,stderr=stderr,inspection_stdout=istout,
        inspection_stderr=ister,output_schema_validated=validated,
        process_hash=canonical_hash(process_body))
    DESCProviderReceiptV4(receipt_body...,canonical_hash(receipt_body))
end

function execute_desc_request_provider(context,request::DESCExecutionRequestV4,bridge,evaluation,proof,probe::DESCEnvironmentProbeV4;run_dir=nothing)
    validate_desc_geometry_compatibility(context,bridge,evaluation,proof); certificate=proof.certificate
    canonical_hash(probe); canonical_hash(context); canonical_hash(certificate); canonical_hash(request)
    request.context_hash==canonical_hash(context) || throw(ArgumentError("DESC request is foreign to context")); request.candidate_hash==context.candidate_hash || throw(ArgumentError("DESC request is foreign to candidate")); request.compatibility_certificate_hash==canonical_hash(certificate) || throw(ArgumentError("DESC request is foreign to compatibility certificate"))
    p=request.runner_payload; controls=DESCExecutionControlsV4(p.L,p.M,p.N,p.L_grid,p.M_grid,p.N_grid,p.maxiter,p.ftol,p.xtol,p.gtol)
    rebuilt=make_desc_execution_request(context,bridge,evaluation,proof,controls)
    canonical_hash(rebuilt)==request.request_hash && semantic_view(rebuilt)==semantic_view(request) || throw(ArgumentError("DESC request payload is not the current candidate-owned reconstruction"))
    probe.desc_importable || return _dgrpe_result(:blocked_environment,context,request,certificate,probe)
    dir=run_dir===nothing ? mktempdir() : String(run_dir); mkpath(dir); input_path=joinpath(dir,"candidate_bound.desc"); output_path=joinpath(dir,"candidate_bound.h5"); adapter_path=joinpath(dir,"desc_provider_adapter.py"); inspector_path=joinpath(dir,"desc_output_inspector.py")
    open(input_path,"w") do io; write(io,_dgrpe_line_payload(p)); end; open(adapter_path,"w") do io; write(io,_DGRPE_ADAPTER_SOURCE); end; open(inspector_path,"w") do io; write(io,_DGRPE_INSPECTOR_SOURCE); end
    receipt=_dgrpe_run(probe,input_path,output_path,adapter_path,inspector_path); success=receipt.exit_code==0 && receipt.inspection_exit_code==0 && receipt.output_schema_validated; success && validate_desc_provider_receipt(receipt)
    _dgrpe_result(success ? :provider_executed : :provider_execution_failed,context,request,certificate,probe;attempted=true,executed=success,schema_validated=success,emitted=true,receipt=receipt)
end

desc_request_provider_execution_manifest()=(schema=_DGRPE_SCHEMA,revision=_DGRPE_REVISION,claim_ceiling=screen_only,requires_candidate_bound_certificate=true,provider_selected=true,provider_executed=true,solver_execution_attempted=true,solver_executed=true,result_schema_validated=true,physical_validation=false,engineering_validation=false,emits_evidence=false,grants_pass=false,promotion_authority=false,p5_ready=false,terminal_authority=false,credible_physical_device_count=0)
