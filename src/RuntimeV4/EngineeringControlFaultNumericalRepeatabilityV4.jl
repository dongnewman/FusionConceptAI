"""Fresh-process repeatability observation for the manufactured G3 ECF screen.

This slice consumes the trusted operational receipt and the explicit ECF/VVUQ
non-bridge.  It only checks deterministic trace observables in two isolated
Julia processes; it is not generic VVUQ evidence or whole-device validation.
"""

using SHA
import FusionConceptAI: Digest256, ClaimCeiling, canonical_hash, semantic_view

const _ECF_NR_REVISION = "ecf-operational-numerical-repeatability-v1"
const _ECF_NR_SCHEMA = "fusionconceptai:ecf-operational-numerical-repeatability"
const _ECF_NR_SOURCE = abspath(@__FILE__)
_ecf_nr_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))

struct EngineeringControlFaultNumericalRepeatabilityObservationV4
    execution_id::Int
    process_id::Int
    julia_executable::String
    julia_executable_sha256::Digest256
    julia_version::String
    project_manifest_sha256::Digest256
    child_source_sha256::Digest256
    context_hash::Digest256
    request_hash::Digest256
    receipt_hash::Digest256
    result_hash::Digest256
    trace_hash::Digest256
    sample_count::Int
    transport_release_count::Int
    dropout_sample_count::Int
    declared_fault_sample_count::Int
    actuator_bound_violation_count::Int
    observation_hash::Digest256
end

semantic_view(x::EngineeringControlFaultNumericalRepeatabilityObservationV4) =
    (revision=_ECF_NR_REVISION, execution_id=x.execution_id, process_id=x.process_id,
     julia_executable=x.julia_executable, julia_executable_sha256=x.julia_executable_sha256,
     julia_version=x.julia_version, project_manifest_sha256=x.project_manifest_sha256,
     child_source_sha256=x.child_source_sha256,
     context_hash=x.context_hash, request_hash=x.request_hash,
     receipt_hash=x.receipt_hash, result_hash=x.result_hash,
     trace_hash=x.trace_hash, sample_count=x.sample_count,
     transport_release_count=x.transport_release_count,
     dropout_sample_count=x.dropout_sample_count,
     declared_fault_sample_count=x.declared_fault_sample_count,
      actuator_bound_violation_count=x.actuator_bound_violation_count)
_ecf_nr_observation_hash(body) = canonical_hash((revision=_ECF_NR_REVISION, body...))

function canonical_hash(x::EngineeringControlFaultNumericalRepeatabilityObservationV4)
    x.execution_id > 0 && x.process_id > 0 && isfile(x.julia_executable) &&
        _ecf_nr_sha(x.julia_executable) == x.julia_executable_sha256 &&
        all(>=(0), (x.sample_count,
        x.transport_release_count, x.dropout_sample_count,
        x.declared_fault_sample_count, x.actuator_bound_violation_count)) ||
        throw(ArgumentError("invalid ECF repeatability observation"))
    h = canonical_hash(semantic_view(x)); h == x.observation_hash ||
        throw(ArgumentError("ECF repeatability observation hash mismatch")); h
end

struct EngineeringControlFaultNumericalRepeatabilityRequestV4
    revision::String
    schema::String
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    registry_hash::Digest256
    ecf_request_hash::Digest256
    ecf_receipt_hash::Digest256
    nonbridge_hash::Digest256
    execution_count::Int
    child_source_path::String
    child_source_sha256::Digest256
    project_manifest_sha256::Digest256
    julia_executable::String
    julia_executable_sha256::Digest256
    julia_version::String
    source_path::String
    source_sha256::Digest256
    claim_ceiling::ClaimCeiling
    manufactured_operational_screen::Bool
    physical_validation::Bool
    validation_uq::Bool
    whole_device_closure::Bool
    emits_evidence::Bool
    promotion_authority::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    request_hash::Digest256
end

semantic_view(x::EngineeringControlFaultNumericalRepeatabilityRequestV4) =
    (revision=x.revision, schema=x.schema, context_hash=x.context_hash,
     subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
     registry_hash=x.registry_hash, ecf_request_hash=x.ecf_request_hash,
     ecf_receipt_hash=x.ecf_receipt_hash, nonbridge_hash=x.nonbridge_hash,
     execution_count=x.execution_count, source_path=x.source_path,
     source_sha256=x.source_sha256, child_source_path=x.child_source_path,
     child_source_sha256=x.child_source_sha256, project_manifest_sha256=x.project_manifest_sha256,
     julia_executable=x.julia_executable, julia_executable_sha256=x.julia_executable_sha256,
     julia_version=x.julia_version, claim_ceiling=x.claim_ceiling,
     manufactured_operational_screen=x.manufactured_operational_screen,
     physical_validation=x.physical_validation, validation_uq=x.validation_uq,
     whole_device_closure=x.whole_device_closure, emits_evidence=x.emits_evidence,
     promotion_authority=x.promotion_authority, terminal_authority=x.terminal_authority,
     credible_physical_device_count=x.credible_physical_device_count)

function canonical_hash(x::EngineeringControlFaultNumericalRepeatabilityRequestV4)
    x.revision == _ECF_NR_REVISION && x.schema == _ECF_NR_SCHEMA &&
        x.execution_count == 2 && !isempty(x.julia_version) && isfile(x.source_path) && isfile(x.child_source_path) &&
        _ecf_nr_sha(x.source_path) == x.source_sha256 &&
        _ecf_nr_sha(x.child_source_path) == x.child_source_sha256 &&
        x.project_manifest_sha256 == Digest256(bytes2hex(SHA.sha256(vcat(
            read(joinpath(dirname(x.source_path),"..","..","Project.toml")),
            read(joinpath(dirname(x.source_path),"..","..","Manifest.toml")))))) &&
        x.julia_version == string(VERSION) &&
        isfile(x.julia_executable) && _ecf_nr_sha(x.julia_executable) == x.julia_executable_sha256 &&
        x.claim_ceiling == screen_only && x.manufactured_operational_screen &&
        !x.physical_validation && !x.validation_uq && !x.whole_device_closure &&
        !x.emits_evidence && !x.promotion_authority && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("invalid ECF repeatability request"))
    h=canonical_hash(semantic_view(x)); h == x.request_hash ||
        throw(ArgumentError("ECF repeatability request hash mismatch")); h
end

struct EngineeringControlFaultNumericalRepeatabilityResultV4
    status::Symbol
    context_hash::Digest256
    request_hash::Digest256
    ecf_receipt_hash::Digest256
    nonbridge_hash::Digest256
    observations::Tuple{Vararg{EngineeringControlFaultNumericalRepeatabilityObservationV4}}
    trace_observables_validated::Bool
    registry_identity_validated::Bool
    request_identity_validated::Bool
    receipt_identity_validated::Bool
    nonbridge_identity_validated::Bool
    repeatability_passed::Bool
    manufactured_operational_screen::Bool
    physical_validation::Bool
    validation_uq::Bool
    whole_device_closure::Bool
    emits_evidence::Bool
    promotion_authority::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    claim_ceiling::ClaimCeiling
    result_hash::Digest256
end

semantic_view(x::EngineeringControlFaultNumericalRepeatabilityResultV4) =
    (revision=_ECF_NR_REVISION, status=x.status, context_hash=x.context_hash,
     request_hash=x.request_hash, ecf_receipt_hash=x.ecf_receipt_hash,
     nonbridge_hash=x.nonbridge_hash, observations=x.observations,
     trace_observables_validated=x.trace_observables_validated,
     registry_identity_validated=x.registry_identity_validated,
     request_identity_validated=x.request_identity_validated,
     receipt_identity_validated=x.receipt_identity_validated,
     nonbridge_identity_validated=x.nonbridge_identity_validated,
     repeatability_passed=x.repeatability_passed,
     manufactured_operational_screen=x.manufactured_operational_screen,
     physical_validation=x.physical_validation, validation_uq=x.validation_uq,
     whole_device_closure=x.whole_device_closure, emits_evidence=x.emits_evidence,
     promotion_authority=x.promotion_authority, terminal_authority=x.terminal_authority,
     credible_physical_device_count=x.credible_physical_device_count,
     claim_ceiling=x.claim_ceiling)
_ecf_nr_result_hash(body) = canonical_hash((revision=_ECF_NR_REVISION, body...))

function canonical_hash(x::EngineeringControlFaultNumericalRepeatabilityResultV4)
    length(x.observations) == 2 &&
        Tuple(o.execution_id for o in x.observations) == (1,2) &&
        all(o -> canonical_hash(o) == o.observation_hash, x.observations) &&
        x.observations[1].process_id != x.observations[2].process_id &&
        _ecf_nr_observable_key(x.observations[1]) == _ecf_nr_observable_key(x.observations[2]) &&
        x.status === :repeatable_operational_screen && x.trace_observables_validated &&
        x.registry_identity_validated && x.request_identity_validated &&
        x.receipt_identity_validated && x.nonbridge_identity_validated &&
        x.repeatability_passed && x.manufactured_operational_screen &&
        !x.physical_validation && !x.validation_uq && !x.whole_device_closure &&
        !x.emits_evidence && !x.promotion_authority && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("ECF repeatability result exceeds screen authority"))
    h=canonical_hash(semantic_view(x)); h == x.result_hash ||
        throw(ArgumentError("ECF repeatability result hash mismatch")); h
end

_ecf_nr_observable_key(o::EngineeringControlFaultNumericalRepeatabilityObservationV4) =
    (o.context_hash,o.request_hash,o.receipt_hash,o.result_hash,o.trace_hash,o.sample_count,
     o.transport_release_count,o.dropout_sample_count,o.declared_fault_sample_count,
     o.actuator_bound_violation_count)

function _ecf_nr_parse(line)
    startswith(line, "ECF_NUMERICAL_REPEATABILITY_V1|") ||
        throw(ArgumentError("fresh ECF process emitted no typed observation"))
    d=Dict{String,String}()
    for item in split(chomp(line), '|')[2:end]
        kv=split(item, '=', limit=2); length(kv)==2 && (d[kv[1]]=kv[2])
    end
    d
end
_ecf_nr_value(d,k) = haskey(d,k) ? d[k] : throw(ArgumentError("missing $k"))
_ecf_nr_int(d,k)=parse(Int,_ecf_nr_value(d,k))
_ecf_nr_digest(d,k)=Digest256(_ecf_nr_value(d,k))

function _ecf_nr_fresh(root, expected_context, expected_request, expected_receipt, expected_nonbridge)
    helper=joinpath(root,"scripts","run_v4_ecf_numerical_repeatability_child.jl")
    cmd=`$(Base.julia_cmd()) --startup-file=no --project=$(root) $(helper) $(expected_context) $(expected_request) $(expected_receipt) $(expected_nonbridge)`
    output=read(cmd,String)
    lines=filter(s->startswith(s,"ECF_NUMERICAL_REPEATABILITY_V1|"),split(output,'\n'))
    length(lines)==1 || throw(ArgumentError("fresh ECF process framing is invalid"))
    line=only(lines)
    _ecf_nr_parse(line)
end

function build_ecf_numerical_repeatability_request(registry, context, request, receipt, nonbridge)
    validate_trusted_engineering_control_fault_operational_receipt(receipt,request,registry,context)
    validate_engineering_control_fault_vuq_bridge(registry,context,request,receipt,nonbridge)
    root=normpath(abspath(joinpath(@__DIR__,"..","..")))
    child=joinpath(root,"scripts","run_v4_ecf_numerical_repeatability_child.jl")
    project=joinpath(root,"Project.toml"); manifest=joinpath(root,"Manifest.toml")
    ex=abspath(String(Base.julia_cmd().exec[1]))
    body=(revision=_ECF_NR_REVISION,schema=_ECF_NR_SCHEMA,
      context_hash=context.context_hash,subject_hash=context.subject.physical_subject_hash,
      scenario_hash=context.scenario_hash,registry_hash=registry.registry_hash,
      ecf_request_hash=request.request_hash,ecf_receipt_hash=receipt.receipt_hash,
      nonbridge_hash=nonbridge.bridge_hash,execution_count=2,
      child_source_path=child,child_source_sha256=_ecf_nr_sha(child),
      project_manifest_sha256=Digest256(bytes2hex(SHA.sha256(vcat(read(project),read(manifest))))),
      julia_executable=ex,julia_executable_sha256=_ecf_nr_sha(ex),julia_version=string(VERSION),
      source_path=_ECF_NR_SOURCE,source_sha256=_ecf_nr_sha(_ECF_NR_SOURCE),claim_ceiling=screen_only,
      manufactured_operational_screen=true,physical_validation=false,validation_uq=false,
      whole_device_closure=false,emits_evidence=false,promotion_authority=false,
      terminal_authority=false,credible_physical_device_count=0)
    x=EngineeringControlFaultNumericalRepeatabilityRequestV4(values(body)...,canonical_hash(body)); canonical_hash(x); x
end

function execute_ecf_numerical_repeatability(registry,context,request,receipt,nonbridge)
    nr=build_ecf_numerical_repeatability_request(registry,context,request,receipt,nonbridge)
    root=normpath(abspath(joinpath(@__DIR__,"..","..")))
    rows=(_ecf_nr_fresh(root,context.context_hash,request.request_hash,receipt.receipt_hash,nonbridge.bridge_hash),
          _ecf_nr_fresh(root,context.context_hash,request.request_hash,receipt.receipt_hash,nonbridge.bridge_hash))
    obs=map(enumerate(rows)) do (i,d)
        body=(execution_id=i,process_id=_ecf_nr_int(d,"pid"),julia_executable=d["julia"],
          julia_executable_sha256=_ecf_nr_digest(d,"julia_sha"),julia_version=d["julia_version"],
          project_manifest_sha256=_ecf_nr_digest(d,"project_manifest"),child_source_sha256=_ecf_nr_digest(d,"child_source"),
          context_hash=_ecf_nr_digest(d,"context"),request_hash=_ecf_nr_digest(d,"request"),
          receipt_hash=_ecf_nr_digest(d,"receipt"),result_hash=_ecf_nr_digest(d,"result"),trace_hash=_ecf_nr_digest(d,"trace"),
          sample_count=_ecf_nr_int(d,"samples"),transport_release_count=_ecf_nr_int(d,"releases"),
          dropout_sample_count=_ecf_nr_int(d,"dropouts"),declared_fault_sample_count=_ecf_nr_int(d,"faults"),
          actuator_bound_violation_count=_ecf_nr_int(d,"violations"))
        EngineeringControlFaultNumericalRepeatabilityObservationV4(values(body)...,_ecf_nr_observation_hash(body))
    end |> Tuple
    all(o->o.context_hash==context.context_hash && o.request_hash==request.request_hash &&
        o.receipt_hash==receipt.receipt_hash && o.julia_executable==nr.julia_executable &&
        o.julia_executable_sha256==nr.julia_executable_sha256 &&
        o.julia_version==nr.julia_version &&
        o.project_manifest_sha256==nr.project_manifest_sha256 &&
        o.child_source_sha256==nr.child_source_sha256,obs) || throw(ArgumentError("fresh ECF identity mismatch"))
    a,b=obs
    comparable=_ecf_nr_observable_key(a) == _ecf_nr_observable_key(b) &&
      a.process_id != b.process_id
    body=(status=:repeatable_operational_screen,context_hash=context.context_hash,request_hash=nr.request_hash,
      ecf_receipt_hash=receipt.receipt_hash,nonbridge_hash=nonbridge.bridge_hash,observations=obs,
      trace_observables_validated=true,registry_identity_validated=true,request_identity_validated=true,
      receipt_identity_validated=true,nonbridge_identity_validated=true,repeatability_passed=comparable,
      manufactured_operational_screen=true,physical_validation=false,validation_uq=false,whole_device_closure=false,
      emits_evidence=false,promotion_authority=false,terminal_authority=false,credible_physical_device_count=0,claim_ceiling=screen_only)
    result=EngineeringControlFaultNumericalRepeatabilityResultV4(values(body)...,_ecf_nr_result_hash(body)); canonical_hash(result)
    validate_ecf_numerical_repeatability(registry,context,request,receipt,nonbridge,nr,result)
    (request=nr,result=result)
end

function validate_ecf_numerical_repeatability(registry,context,request,receipt,nonbridge,nr,result)
    expected=build_ecf_numerical_repeatability_request(registry,context,request,receipt,nonbridge)
    semantic_view(expected)==semantic_view(nr) || throw(ArgumentError("repeatability request identity mismatch"))
    canonical_hash(result)
    result.context_hash == context.context_hash && result.request_hash == nr.request_hash &&
        result.ecf_receipt_hash == receipt.receipt_hash && result.nonbridge_hash == nonbridge.bridge_hash ||
        throw(ArgumentError("repeatability result chain identity mismatch"))
    rr=receipt.result
    all(o->o.context_hash==context.context_hash && o.request_hash==request.request_hash &&
        o.receipt_hash==receipt.receipt_hash && o.julia_executable==nr.julia_executable &&
        o.julia_executable_sha256==nr.julia_executable_sha256 &&
        o.julia_version==nr.julia_version &&
        o.project_manifest_sha256==nr.project_manifest_sha256 &&
        o.child_source_sha256==nr.child_source_sha256, result.observations) ||
        throw(ArgumentError("repeatability observation identity mismatch"))
    all(o->o.result_hash==receipt.result_hash && o.trace_hash==rr.trace_hash &&
        o.sample_count==rr.sample_count && o.transport_release_count==rr.transport_release_count &&
        o.dropout_sample_count==rr.scheduled_dropout_sample_count &&
        o.declared_fault_sample_count==rr.declared_fault_sample_count &&
        o.actuator_bound_violation_count==rr.actuator_bound_violation_count,
        result.observations) || throw(ArgumentError("repeatability observables differ from receipt result"))
    result.result_hash
end

engineering_control_fault_numerical_repeatability_manifest()=(revision=_ECF_NR_REVISION,execution_count=2,
  isolation=:fresh_julia_process,operational_screen=true,physical_validation=false,validation_uq=false,
  whole_device_closure=false,emits_evidence=false,claim_ceiling=screen_only)
