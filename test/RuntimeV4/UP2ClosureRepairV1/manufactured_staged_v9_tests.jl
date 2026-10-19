# Two recorded processes consume the same actual production context/result.
module ManufacturedStagedV9Tests
using Test, FusionConceptAI, LinearAlgebra, Serialization, SHA
include(joinpath(@__DIR__,"manufactured_candidate_v1_tests.jl"))
const M=ManufacturedCandidateV1Tests
const S=M.S
const N=M.N
const ROOT=M.REPO

function write_new_json(path,payload)
    ispath(path) && error("preserve existing staged evidence")
    write(path,canonical_json(payload)*"\n")
end

function staged_sources_v9()
    Tuple((path=joinpath(ROOT,p),sha256=M.sha(joinpath(ROOT,p))) for p in (
        "src/RuntimeV4/SpatialMultiRegionV4.jl","src/RuntimeV4/SpatialCandidateV4.jl",
        "src/RuntimeV4/SpatialManufacturedInputV1.jl","src/RuntimeV4/SpatialBoundedLinearStepV1.jl",
        "test/RuntimeV4/UP2ClosureRepairV1/manufactured_candidate_v1_tests.jl",
        "test/RuntimeV4/UP2ClosureRepairV1/manufactured_staged_v9_tests.jl",
        "test/RuntimeV4/UP2ClosureRepairV1/manufactured_quadrature_audit_v9.jl"))
end

function carrier_binding_v9(context,result,path,protocol_sha)
    (schema="mms-actual-carrier-binding-v9",producer_root=realpath(dirname(path)),carrier_path=realpath(path),
        carrier_sha256=M.sha(path),carrier_bytes=filesize(path),julia_version=string(VERSION),
        protocol_sha256=protocol_sha,sources=staged_sources_v9(),candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,result_hash=canonical_hash(result),declaration_hash=canonical_hash(result.declaration),
        case_hashes=Tuple(canonical_hash(c) for c in result.cases),
        scope=:transport_only_no_validation_cache,authority=:no_publish)
end

include(joinpath(@__DIR__,"manufactured_quadrature_audit_v9.jl"))

function producer_v9(out,protocol_sha)
    ispath(out) && error("preserve producer output");mkpath(out)
    x,d=M.phase(out,"stage1_preflight") do;M.stage1_tests(joinpath(out,"preflight"));end
    parent=M.phase(out,"actual_circular_parent") do;M.build_manufactured_parent(x,out);end
    context=M.phase(out,"actual_spatial_candidate") do;M.candidate_preflight(x,d,parent,out);end
    result=M.phase(out,"actual_provider_writer_full_solver_replay") do
        S.execute_spatial_manufactured_numerical_v1(context,joinpath(out,"production"))
    end
    path=joinpath(out,"actual_carrier.bin")
    M.phase(out,"save_actual_context_result_carrier") do
        serialize(path,(schema="mms-actual-carrier-v9",context=context,result=result))
        write_new_json(joinpath(out,"carrier_binding.json"),carrier_binding_v9(context,result,path,protocol_sha))
    end
    endpoint=M.phase(out,"single_endpoint_error_diagnostics") do;M.endpoint_diagnostics(context,result,out);end
    audit=M.phase(out,"fixed_quadrature_test_only_diagnostics") do
        quadrature_audit_v9(context,result,joinpath(out,"quadrature_audit"))
    end
    c=only(result.cases)
    write_new_json(joinpath(out,"producer_complete.json"),(schema="mms-producer-complete-v9",
        software_stage=:passed,producer_tests=:all_original_preflight_parent_candidate,
        candidate_hash=context.candidate_hash,context_hash=context.context_hash,result_hash=canonical_hash(result),
        carrier_binding_sha256=M.sha(joinpath(out,"carrier_binding.json")),
        endpoint_diagnostics_sha256=M.sha(joinpath(out,"endpoint_diagnostics.json")),
        quadrature_audit_sha256=M.sha(joinpath(out,"quadrature_audit","complete.json")),
        nonlinear_solves=1,positive_result_replays=1,solver_exit_code=c.solver_exit_code,
        stopping_reason=c.stopping_reason,numerical_status=c.diagnostics.numerical_status,
        final_scaled_max=c.diagnostics.scaled_max,physical_validation=:unsupported,authority=:no_publish))
    println("MMS_STAGE_COMPLETE stage=producer software=passed numerical=",c.diagnostics.numerical_status);flush(stdout)
end

function consumer_v9(out,producer,protocol_sha,expected_carrier_sha,expected_binding_sha)
    ispath(out) && error("preserve consumer output");mkpath(out)
    producer=realpath(producer);path=joinpath(producer,"actual_carrier.bin")
    binding_path=joinpath(producer,"carrier_binding.json")
    observed=(binding_sha256=M.sha(binding_path),carrier_sha256=M.sha(path),carrier_bytes=filesize(path),
        expected_carrier_sha256=expected_carrier_sha,expected_binding_sha256=expected_binding_sha,
        producer_root=producer,sources=staged_sources_v9(),julia_version=string(VERSION),protocol_sha256=protocol_sha)
    write_new_json(joinpath(out,"carrier_before_deserialize.json"),observed)
    # Expected bytes come from the independent controller's post-producer seal,
    # passed as child argv; the carrier cannot self-authorize a rewritten binding.
    observed.carrier_sha256==expected_carrier_sha && observed.binding_sha256==expected_binding_sha ||
        error("carrier/binding bytes differ from independent post-producer seal")
    metadata=S._smr_read_canonical_json_v1(read(binding_path,String))
    metadata.producer_root==producer && metadata.carrier_path==realpath(path) &&
        metadata.carrier_sha256==observed.carrier_sha256 && metadata.carrier_bytes==observed.carrier_bytes &&
        metadata.julia_version==string(VERSION) && metadata.protocol_sha256==protocol_sha || error("foreign carrier transport binding")
    canonical_json(metadata.sources)==canonical_json(observed.sources) || error("carrier source closure changed")
    payload=M.phase(out,"deserialize_actual_producer_carrier") do;deserialize(path);end
    payload.schema=="mms-actual-carrier-v9" || error("foreign carrier schema")
    context=payload.context;result=payload.result
    read(binding_path,String)==canonical_json(carrier_binding_v9(context,result,path,protocol_sha))*"\n" ||
        error("carrier canonical context/result identity differs")
    # Independently re-enter the actual public candidate/provider/artifact/attempt
    # validator via the original explicit consumer suite; no admission is reused.
    M.phase(out,"explicit_consumer_replay_and_scope_negatives") do;M.result_tests(context,result,out);end
    M.sha(path)==observed.carrier_sha256 && M.sha(binding_path)==observed.binding_sha256 || error("consumer altered original carrier")
    c=only(result.cases)
    write_new_json(joinpath(out,"consumer_complete.json"),(schema="mms-consumer-complete-v9",
        software_stage=:passed,consumer_tests=:all_original_result_and_public_scope_cases,
        candidate_hash=context.candidate_hash,context_hash=context.context_hash,result_hash=canonical_hash(result),
        producer_root=producer,carrier_binding_sha256=observed.binding_sha256,carrier_sha256=observed.carrier_sha256,
        nonlinear_solves=0,positive_result_replays=1,solver_exit_code=c.solver_exit_code,
        stopping_reason=c.stopping_reason,numerical_status=c.diagnostics.numerical_status,
        final_scaled_max=c.diagnostics.scaled_max,physical_validation=:unsupported,authority=:no_publish))
    println("MMS_STAGE_COMPLETE stage=consumer software=passed numerical=",c.diagnostics.numerical_status);flush(stdout)
end

function main(args)
    length(args)==6 || error("expected MODE OUTPUT PRODUCER_OUTPUT PROTOCOL_SHA EXPECTED_CARRIER_SHA EXPECTED_BINDING_SHA")
    mode,out,producer,protocol_sha,expected_carrier_sha,expected_binding_sha=args
    occursin(r"^[0-9a-f]{64}$",protocol_sha) || error("protocol SHA required")
    if mode=="consumer"
        all(x->occursin(r"^[0-9a-f]{64}$",x),(expected_carrier_sha,expected_binding_sha)) || error("independent transport hashes required")
    else
        expected_carrier_sha==expected_binding_sha=="not_applicable" || error("producer cannot receive a prior carrier")
    end
    println("MMS_STAGED mode=",mode," julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    mode=="producer" ? producer_v9(abspath(out),protocol_sha) :
        mode=="consumer" ? consumer_v9(abspath(out),abspath(producer),protocol_sha,expected_carrier_sha,expected_binding_sha) : error("unknown staged mode")
end
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    ManufacturedStagedV9Tests.main(ARGS)
end
