using SHA
using Serialization
using JSON3
using FusionConceptAI

const FORMAL_T2_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const FORMAL_T2_SCENARIO = "vnext-t2-native-source-formal-t1-actual-r1"
const FORMAL_T2_SOFTWARE_MANIFEST_SCHEMA =
    "vnext-t1-software-acceptance-manifest-r1"
const FORMAL_T2_SOFTWARE_VERIFICATION_SCHEMA =
    "vnext-t1-software-acceptance-verification-r1"
const FORMAL_T2_EXPECTED_HEAD =
    "63792ca22958ffca8c3fa8e642256eb9f7240724"
const FORMAL_T2_DRIVER_VERSION = "formal-candidate-driver-r5"
const FORMAL_T2_OWNED_ARTIFACTS = (
    "candidate_package.jls",
    "candidate_t1_admission_receipt.json",
    "t2_result.jls",
    "run_receipt.json",
    "replay_uncommitted_attempt.json",
)

_formal_t2_sha256(bytes) = bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes))))

function _formal_t2_canonical_artifact(value)
    bytes = Vector{UInt8}(codeunits(FusionConceptAI.canonical_json(value) * "\n"))
    (bytes=bytes, sha256=_formal_t2_sha256(bytes))
end

function _formal_t2_serialized_artifact(value)
    io = IOBuffer()
    Serialization.serialize(io, value)
    bytes = take!(io)
    (bytes=bytes, sha256=_formal_t2_sha256(bytes),
        value=Serialization.deserialize(IOBuffer(copy(bytes))))
end

function _formal_t2_loaded_serialized_artifact(bytes)
    owned = copy(Vector{UInt8}(bytes))
    (bytes=owned, sha256=_formal_t2_sha256(owned),
        value=Serialization.deserialize(IOBuffer(copy(owned))))
end

_formal_t2_path_occupied(path::String) = ispath(path) || islink(path)

function _formal_t2_require_output_leaf_available(output::String)
    islink(output) && error((:formal_t2_output_directory_symlink, output))
    isdir(output) || mkpath(output)
    for name in FORMAL_T2_OWNED_ARTIFACTS
        path = joinpath(output, name)
        _formal_t2_path_occupied(path) && error(
            (:formal_t2_output_artifact_already_exists, name))
    end
    nothing
end

function _formal_t2_publish_artifact(path::String, artifact)
    _formal_t2_path_occupied(path) && error(
        (:formal_t2_publication_target_already_exists, path))
    parent = dirname(path)
    isdir(parent) || error((:formal_t2_publication_parent_absent, parent))
    temp_path, stream = mktemp(parent; cleanup=false)
    try
        write(stream, artifact.bytes)
        flush(stream)
        close(stream)
        _formal_t2_path_occupied(path) && error(
            (:formal_t2_publication_target_already_exists, path))
        mv(temp_path, path; force=false)
    finally
        isopen(stream) && close(stream)
        ispath(temp_path) && rm(temp_path; force=true)
    end
    islink(path) && error((:formal_t2_publication_target_symlink, path))
    published = read(path)
    published == artifact.bytes || error((:formal_t2_publication_bytes_mismatch,
        path))
    _formal_t2_sha256(published) == artifact.sha256 ||
        error((:formal_t2_publication_hash_mismatch, path))
    artifact
end

function _formal_t2_file_receipt(relative::String)
    path = joinpath(FORMAL_T2_ROOT, split(relative, '/')...)
    isfile(path) || error((:formal_t2_source_absent, relative))
    bytes = read(path)
    (path=relative, bytes=length(bytes), sha256=_formal_t2_sha256(bytes))
end

function _formal_t2_write_canonical(path::String, value)
    artifact = _formal_t2_canonical_artifact(value)
    _formal_t2_publish_artifact(path, artifact)
end

function _formal_t2_write_serialized(path::String, value)
    artifact = _formal_t2_serialized_artifact(value)
    _formal_t2_publish_artifact(path, artifact)
end

function _formal_t2_write_raw(path::String, bytes::Vector{UInt8})
    artifact = _formal_t2_loaded_serialized_artifact(bytes)
    _formal_t2_publish_artifact(path, artifact)
end

function _formal_t2_verify_raw(path::String, expected_sha256::String, label)
    bytes = read(path)
    actual = _formal_t2_sha256(bytes)
    actual == lowercase(expected_sha256) ||
        error((label, :raw_sha256_mismatch, expected_sha256, actual))
    (bytes=bytes, sha256=actual)
end

function _formal_t2_prepare_material()
    t1 = t2_t1_admission_fixture()
    admission = t1.admission
    admission.status === :prepared_not_executed ||
        error((:formal_t1_admission_status_invalid, admission.status))
    admission.resolution === :terminal_deferred ||
        error((:formal_t1_admission_resolution_invalid, admission.resolution))
    admission.accepted === false || error(:formal_t1_admission_accepted_invalid)
    admission.claim_ceiling === :contract_only ||
        error(:formal_t1_admission_claim_ceiling_invalid)
    isempty(admission.errors) ||
        error((:formal_t1_admission_errors_present, admission.errors))
    admission.package isa FusionConceptAI.CandidateStatePackageV5NextV2 ||
        error(:formal_t1_admission_package_absent)
    package_serialized = if FORMAL_T2_MODE === :produce
        _formal_t2_serialized_artifact(admission.package)
    else
        producer_path = abspath(ARGS[9])
        producer_expected_sha256 = lowercase(ARGS[10])
        producer_bytes = read(producer_path)
        producer_actual_sha256 = _formal_t2_sha256(producer_bytes)
        if producer_actual_sha256 != producer_expected_sha256
            _formal_t2_pre_material_uncommitted_attempt(
                :producer_artifact_hash_precondition,
                :raw_sha256_mismatch, producer_path,
                producer_expected_sha256, producer_actual_sha256,
                length(producer_bytes), nothing, nothing)
            error((:producer_candidate_package, :raw_sha256_mismatch,
                producer_expected_sha256, producer_actual_sha256))
        end
        reloaded = try
            Serialization.deserialize(IOBuffer(copy(producer_bytes)))
        catch deserialize_error
            _formal_t2_pre_material_uncommitted_attempt(
                :producer_artifact_deserialize_precondition,
                :deserialize_error, producer_path,
                producer_expected_sha256, producer_actual_sha256,
                length(producer_bytes), string(typeof(deserialize_error)),
                sprint(showerror, deserialize_error))
            rethrow()
        end
        if !(reloaded isa FusionConceptAI.CandidateStatePackageV5NextV2)
            _formal_t2_pre_material_uncommitted_attempt(
                :producer_artifact_deserialize_precondition,
                :type_invalid, producer_path,
                producer_expected_sha256, producer_actual_sha256,
                length(producer_bytes), string(typeof(reloaded)),
                "producer candidate package type is invalid")
            error(:producer_candidate_package_type_invalid)
        end
        if !FusionConceptAI._vnext_t2_t1_package_content_equal_v2(
                admission.package, reloaded)
            _formal_t2_pre_material_uncommitted_attempt(
                :producer_artifact_deserialize_precondition,
                :expected_admission_mismatch, producer_path,
                producer_expected_sha256, producer_actual_sha256,
                length(producer_bytes), nothing,
                "producer candidate package differs from rebuilt admission")
            error(:producer_candidate_package_expected_admission_mismatch)
        end
        (bytes=copy(producer_bytes), sha256=producer_actual_sha256,
            value=reloaded)
    end
    package = package_serialized.value
    FusionConceptAI.vnext_t1_package_v2_validate(package) === nothing ||
        error(:formal_t1_reloaded_package_invalid)
    base_adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package)
    base_adapter.input === nothing &&
        error((:formal_t1_reload_adapter_input_absent, base_adapter.reason))
    adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package,
        (base_adapter.input,))
    adapter.binding === nothing &&
        error((:formal_t1_reload_binding_absent, adapter.reason))
    (t1=t1, admission=admission, package=package,
        package_serialized=package_serialized, adapter=adapter,
        package_artifact_origin=FORMAL_T2_MODE === :produce ?
            :local_producer : :producer_artifact,
        independent_expected_admission_rebuilt=true)
end

function _formal_t2_candidate_receipt(material, software_manifest_hash,
        software_verification_hash)
    t1 = material.t1
    package = material.package
    adapter = material.adapter
    admission_material_hash = FusionConceptAI.canonical_hash(
        FusionConceptAI._vnext_t2_t1_admission_handoff_body_v2(
            t1.source.witness, t1.admission_input, material.admission,
            package, adapter, nothing, FORMAL_T2_SCENARIO,
            FusionConceptAI.VNEXT_T2_UP2_PROFILE_V2))
    (schema="vnext-t2-candidate-t1-admission-receipt-r1",
        evidence_kind=:formal_t1_actual,
        producer_version=FORMAL_T2_DRIVER_VERSION,
        software_acceptance_manifest_sha256=software_manifest_hash,
        software_acceptance_verification_sha256=software_verification_hash,
        candidate_ref=package.candidate_ref,
        witness_hash=t1.source.witness.witness_hash,
        source_manifest_hash=t1.source.witness.manifest.manifest_hash,
        t0_bundle_hash=package.bundle_hash,
        t1_parent_commitments=t1.t1_parents,
        g3_expected_commitment=t1.source.expected.commitment_hash,
        t1_admission_status=material.admission.status,
        t1_admission_resolution=material.admission.resolution,
        t1_admission_accepted=material.admission.accepted,
        t1_admission_claim_ceiling=material.admission.claim_ceiling,
        producer_t1_admission_invocation_count=1,
        handoff_revalidation_required=true,
        admission_material_hash=admission_material_hash,
        package_hash=package.package_hash,
        package_content_hash=
            FusionConceptAI._vnext_t2_t1_package_content_hash_v2(package),
        semantic_identity=package.semantic_identity,
        wire_hash=package.wire.sha256,
        serialized_package_bytes=length(material.package_serialized.bytes),
        serialized_package_sha256=material.package_serialized.sha256,
        reload_adapter_receipt_hash=
            FusionConceptAI.canonical_hash(FusionConceptAI.semantic_view(adapter)),
        binding_receipt_hash=adapter.binding.receipt_hash,
        scenario=FORMAL_T2_SCENARIO)
end

function _formal_t2_source_receipts()
    paths = (
        "src/Contracts/CandidateStatePackageV5Next.jl",
        "src/Contracts/CandidateStatePackageV5NextV2.jl",
        "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
        "src/Contracts/VNextT1CandidateBindingV2.jl",
        "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
        "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
        "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
        "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl",
        "src/GenomeV5/UP2/VNextT2UP2AdapterV2.jl",
        "src/GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl",
        "src/GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl",
        "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl",
        "src/FusionConceptAI.jl",
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/fixture_helpers.jl",
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/formal_candidate_driver.jl")
    Tuple(_formal_t2_file_receipt(path) for path in paths)
end

const FORMAL_T2_UNCOMMITTED_ATTEMPT_SCHEMA =
    "vnext-t2-formal-replay-uncommitted-attempt-r2"
const FORMAL_T2_UNCOMMITTED_ATTEMPT_NAME =
    "formal-t2-replay-uncommitted-attempt"
const FORMAL_T2_UNCOMMITTED_ATTEMPT_VERSION = "r2"
const FORMAL_T2_UNCOMMITTED_ATTEMPT_PROFILE =
    "producer-artifact-candidate-and-output-preconditions-v2"

function _formal_t2_package_state_sha256(package)
    FusionConceptAI._vnext_t2_t1_package_content_hash_v2(package).value
end

function _formal_t2_producer_artifact_receipt(path::String)
    bytes = read(path)
    (bytes=length(bytes), sha256=_formal_t2_sha256(bytes))
end

function _formal_t2_write_uncommitted_attempt(body)
    body_artifact = _formal_t2_canonical_artifact(body)
    envelope = merge(body, (
        canonical_body_bytes=length(body_artifact.bytes),
        canonical_body_sha256=body_artifact.sha256))
    _formal_t2_write_canonical(joinpath(FORMAL_T2_OUTPUT,
        "replay_uncommitted_attempt.json"), envelope)
end

function _formal_t2_pre_material_uncommitted_attempt(stage::Symbol,
        precondition_failure::Symbol, producer_path::String,
        producer_expected_sha256::String,
        producer_actual_sha256::String, producer_bytes::Int,
        failure_type, failure_message)
    zero_counts = FusionConceptAI.VNextT2InvocationCountsV2()
    after = _formal_t2_producer_artifact_receipt(producer_path)
    body = (
        schema=FORMAL_T2_UNCOMMITTED_ATTEMPT_SCHEMA,
        name=FORMAL_T2_UNCOMMITTED_ATTEMPT_NAME,
        version=FORMAL_T2_UNCOMMITTED_ATTEMPT_VERSION,
        profile=FORMAL_T2_UNCOMMITTED_ATTEMPT_PROFILE,
        mode=:replay,
        stage=stage,
        precondition_failure=precondition_failure,
        failure_type=failure_type,
        failure_message=failure_message,
        authority_input_accepted=false,
        consumers_attempted=(),
        attempted_trace=nothing,
        attempted_counts=FusionConceptAI.semantic_view(zero_counts),
        committed_counts=FusionConceptAI.semantic_view(zero_counts),
        result_status=nothing,
        result_resolution=nothing,
        result_reason=nothing,
        result_committed_in_process=false,
        publication_committed=false,
        published_artifacts=(),
        caller_package_sha256_before=nothing,
        caller_package_sha256_after=nothing,
        prior_ledger_sha256_before=nothing,
        prior_ledger_sha256_after=nothing,
        candidate_receipt_expected_sha256=nothing,
        candidate_receipt_actual_sha256=nothing,
        result_reload_identity_expected_sha256=nothing,
        result_reload_identity_actual_sha256=nothing,
        stable_projection_expected_sha256=nothing,
        stable_projection_actual_sha256=nothing,
        formal_manifest_sha256=FORMAL_T2_MANIFEST_SHA256,
        producer_artifact_path=producer_path,
        producer_artifact_expected_sha256=producer_expected_sha256,
        producer_artifact_sha256=producer_actual_sha256,
        producer_artifact_sha256_before=producer_actual_sha256,
        producer_artifact_sha256_after=after.sha256,
        producer_artifact_bytes_before=producer_bytes,
        producer_artifact_bytes_after=after.bytes,
        producer_artifact_unchanged=
            producer_actual_sha256 == after.sha256 &&
            producer_bytes == after.bytes,
        producer_artifact_origin=:producer_artifact,
        formal_t2_accepted=false,
        physical_acceptance=false,
        scientific_acceptance=false,
        actual_model_attestation="unavailable")
    _formal_t2_write_uncommitted_attempt(body)
end

function _formal_t2_uncommitted_attempt(stage::Symbol, material,
        candidate_receipt_expected_sha256,
        candidate_receipt_actual_sha256,
        result_reload_identity_expected_sha256,
        result_reload_identity_actual_sha256,
        stable_projection_expected_sha256,
        stable_projection_actual_sha256;
        authority_input_accepted::Bool,
        result=nothing,
        caller_package_sha256_before::String)
    zero_counts = FusionConceptAI.VNextT2InvocationCountsV2()
    attempted_trace = result === nothing ? nothing :
        FusionConceptAI.semantic_view(result.attempted_trace)
    attempted_counts = result === nothing ? zero_counts :
        result.attempted_trace.counts
    committed_counts = result === nothing ? zero_counts :
        result.committed_counts
    consumers_attempted = result === nothing ? () :
        Tuple(event.consumer_id for event in result.attempted_trace.events)
    caller_package_sha256_after =
        _formal_t2_package_state_sha256(material.package)
    producer_path = abspath(ARGS[9])
    producer_after = _formal_t2_producer_artifact_receipt(producer_path)
    body = (
        schema=FORMAL_T2_UNCOMMITTED_ATTEMPT_SCHEMA,
        name=FORMAL_T2_UNCOMMITTED_ATTEMPT_NAME,
        version=FORMAL_T2_UNCOMMITTED_ATTEMPT_VERSION,
        profile=FORMAL_T2_UNCOMMITTED_ATTEMPT_PROFILE,
        mode=:replay,
        stage=stage,
        precondition_failure=nothing,
        failure_type=nothing,
        failure_message=nothing,
        authority_input_accepted=authority_input_accepted,
        consumers_attempted=consumers_attempted,
        attempted_trace=attempted_trace,
        attempted_counts=FusionConceptAI.semantic_view(attempted_counts),
        committed_counts=FusionConceptAI.semantic_view(committed_counts),
        result_status=result === nothing ? nothing : result.status,
        result_resolution=result === nothing ? nothing : result.resolution,
        result_reason=result === nothing ? nothing : result.reason,
        result_committed_in_process=
            result === nothing ? false : result.committed,
        publication_committed=false,
        published_artifacts=(),
        caller_package_sha256_before=caller_package_sha256_before,
        caller_package_sha256_after=caller_package_sha256_after,
        prior_ledger_sha256_before=nothing,
        prior_ledger_sha256_after=nothing,
        candidate_receipt_expected_sha256=
            candidate_receipt_expected_sha256,
        candidate_receipt_actual_sha256=
            candidate_receipt_actual_sha256,
        result_reload_identity_expected_sha256=
            result_reload_identity_expected_sha256,
        result_reload_identity_actual_sha256=
            result_reload_identity_actual_sha256,
        stable_projection_expected_sha256=
            stable_projection_expected_sha256,
        stable_projection_actual_sha256=
            stable_projection_actual_sha256,
        formal_manifest_sha256=FORMAL_T2_MANIFEST_SHA256,
        producer_artifact_path=producer_path,
        producer_artifact_expected_sha256=lowercase(ARGS[10]),
        producer_artifact_sha256=material.package_serialized.sha256,
        producer_artifact_sha256_before=material.package_serialized.sha256,
        producer_artifact_sha256_after=producer_after.sha256,
        producer_artifact_bytes_before=length(material.package_serialized.bytes),
        producer_artifact_bytes_after=producer_after.bytes,
        producer_artifact_unchanged=
            material.package_serialized.sha256 == producer_after.sha256 &&
            length(material.package_serialized.bytes) == producer_after.bytes,
        producer_artifact_origin=:producer_artifact,
        formal_t2_accepted=false,
        physical_acceptance=false,
        scientific_acceptance=false,
        actual_model_attestation="unavailable")
    _formal_t2_write_uncommitted_attempt(body)
end

function _formal_t2_method_receipt(consumer_id::Symbol, function_name::String,
        method::Method, relative::String)
    method_file, method_line = Base.functionloc(method)
    expected = realpath(joinpath(FORMAL_T2_ROOT, split(relative, '/')...))
    actual = realpath(abspath(String(method_file)))
    actual == expected || error((:formal_t2_method_source_mismatch,
        consumer_id, relative, actual))
    source = _formal_t2_file_receipt(relative)
    body = (domain="vnext-t2-consumer-method-receipt-r1",
        consumer_id=consumer_id, function_name=function_name,
        method_signature=string(method.sig), source=source,
        method_line=method_line)
    merge(body, (method_identity_hash=FusionConceptAI.canonical_hash(body),))
end

function _formal_t2_method_receipts()
    bound = FusionConceptAI.VNextT2UP2BoundInputV2
    e0 = FusionConceptAI.VNextT2E0PhysicalBindingV2
    context = FusionConceptAI.VNextT2GI1AuthorityContextV2
    adapter_source = "src/GenomeV5/UP2/VNextT2UP2AdapterV2.jl"
    (
        _formal_t2_method_receipt(:E0,
            "up2_candidate_physical_binding_from_a",
            which(FusionConceptAI.up2_candidate_physical_binding_from_a,
                Tuple{bound}), adapter_source),
        _formal_t2_method_receipt(:GI1A,
            "gi1_authority_context_from_a",
            which(FusionConceptAI.gi1_authority_context_from_a,
                Tuple{bound,e0}), adapter_source),
        _formal_t2_method_receipt(:E1,
            "e1_authority_slot_from_a",
            which(FusionConceptAI.e1_authority_slot_from_a,
                Tuple{bound,context}), adapter_source),
        _formal_t2_method_receipt(:E2,
            "e2_authority_slot_from_a",
            which(FusionConceptAI.e2_authority_slot_from_a,
                Tuple{bound,context}), adapter_source),
        _formal_t2_method_receipt(:UP2_N10,
            "n10_identity_projection_from_a",
            which(FusionConceptAI.n10_identity_projection_from_a,
                Tuple{bound}),
            "src/GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl"),
        _formal_t2_method_receipt(:ATOMIC_INTEGRATION,
            "vnext_t2_rebind_identity_receipts_v2",
            which(FusionConceptAI.vnext_t2_rebind_identity_receipts_v2,
                Tuple{bound}),
            "src/GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl"),
    )
end

function _formal_t2_require_execution(build, result)
    build.status === :prepared_not_executed ||
        error((:formal_t2_build_not_prepared, build.status, build.reason))
    build.resolution === :terminal_deferred ||
        error((:formal_t2_build_resolution_invalid, build.resolution))
    result.status === :complete_contract_receipts ||
        error((:formal_t2_result_status_invalid, result.status, result.reason))
    result.resolution === :terminal_deferred ||
        error((:formal_t2_result_resolution_invalid, result.resolution))
    result.reason === :none || error((:formal_t2_result_reason, result.reason))
    result.committed || error(:formal_t2_receipts_not_committed)
    result.ledger isa FusionConceptAI.VNextT2ReceiptLedgerV2 ||
        error(:formal_t2_ledger_absent)
    order = Tuple(event.consumer_id for event in result.attempted_trace.events)
    order == FusionConceptAI.VNEXT_T2_CONSUMER_ORDER_V2 ||
        error((:formal_t2_consumer_order_invalid, order))
    result.attempted_trace.counts ==
        FusionConceptAI.VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0) ||
        error((:formal_t2_consumer_counts_invalid,
            result.attempted_trace.counts))
    nothing
end

length(ARGS) in (6, 11) || error(
    "expected mode, software manifest path/hash, verification path/hash, output dir, replay hashes, producer package artifact/hash, and result-reload identity")
const FORMAL_T2_MODE = Symbol(ARGS[1])
FORMAL_T2_MODE in (:produce, :replay) || error("mode must be produce or replay")
FORMAL_T2_MODE === :produce && length(ARGS) != 6 &&
    error("produce mode requires exactly six arguments")
FORMAL_T2_MODE === :replay && length(ARGS) != 11 &&
    error("replay mode requires exactly eleven arguments")
const FORMAL_T2_MANIFEST_PATH = abspath(ARGS[2])
const FORMAL_T2_MANIFEST_SHA256 = lowercase(ARGS[3])
const FORMAL_T2_VERIFICATION_PATH = abspath(ARGS[4])
const FORMAL_T2_VERIFICATION_SHA256 = lowercase(ARGS[5])
const FORMAL_T2_OUTPUT = abspath(ARGS[6])
_formal_t2_require_output_leaf_available(FORMAL_T2_OUTPUT)

manifest_raw = _formal_t2_verify_raw(FORMAL_T2_MANIFEST_PATH,
    FORMAL_T2_MANIFEST_SHA256, :software_manifest)
verification_raw = _formal_t2_verify_raw(FORMAL_T2_VERIFICATION_PATH,
    FORMAL_T2_VERIFICATION_SHA256, :software_manifest_verification)
manifest_document = JSON3.read(String(copy(manifest_raw.bytes)))
verification_document = JSON3.read(String(copy(verification_raw.bytes)))
String(manifest_document.schema) == FORMAL_T2_SOFTWARE_MANIFEST_SCHEMA ||
    error(:software_manifest_schema_mismatch)
manifest_document.formal_t1_software_accepted === true ||
    error(:software_manifest_not_accepted)
String(manifest_document.acceptance_scope) ==
    "software_capability_multi_candidate" ||
    error(:software_manifest_scope_mismatch)
manifest_document.candidate_specific === false ||
    error(:software_manifest_candidate_scope_invalid)
String(manifest_document.repository_head) == FORMAL_T2_EXPECTED_HEAD ||
    error(:software_manifest_head_mismatch)
String(verification_document.schema) ==
    FORMAL_T2_SOFTWARE_VERIFICATION_SCHEMA ||
    error(:software_verification_schema_mismatch)
verification_document.verified === true ||
    error(:software_verification_not_verified)
String(verification_document.manifest_sha256) ==
    FORMAL_T2_MANIFEST_SHA256 ||
    error(:software_verification_manifest_hash_mismatch)
String(verification_document.repository_head) == FORMAL_T2_EXPECTED_HEAD ||
    error(:software_verification_head_mismatch)
verification_document.candidate_specific === false ||
    error(:software_verification_candidate_scope_invalid)
String(verification_document.actual_model_attestation) == "unavailable" ||
    error(:software_verification_model_attestation_invalid)

registry_before_fixture = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
include(joinpath(@__DIR__, "fixture_helpers.jl"))
registry_after_fixture = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
registry_before_fixture == registry_after_fixture ||
    error(:formal_t2_fixture_changed_default_registry)
isdefined(FusionConceptAI, :load_vnext_t2_components_v2!) ||
    error(:formal_t2_shared_loader_not_connected)
FusionConceptAI.load_vnext_t2_components_v2!()
FusionConceptAI.vnext_t2_module_load_state_v2() === :loaded ||
    error(:formal_t2_module_loader_not_loaded)
FusionConceptAI.load_vnext_t2_components_v2!()
registry_after_loader = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
registry_after_loader == registry_before_fixture ||
    error(:formal_t2_loader_changed_default_registry)

material = _formal_t2_prepare_material()
candidate_body = _formal_t2_candidate_receipt(material,
    FusionConceptAI.Digest256(FORMAL_T2_MANIFEST_SHA256),
    FusionConceptAI.Digest256(FORMAL_T2_VERIFICATION_SHA256))
candidate_artifact = _formal_t2_canonical_artifact(candidate_body)
candidate_receipt_hash = FusionConceptAI.Digest256(candidate_artifact.sha256)
caller_package_sha256_before =
    _formal_t2_package_state_sha256(material.package)

if FORMAL_T2_MODE === :replay &&
        candidate_artifact.sha256 != lowercase(ARGS[7])
    _formal_t2_uncommitted_attempt(:candidate_receipt_precondition,
        material, lowercase(ARGS[7]), candidate_artifact.sha256,
        nothing, nothing, nothing, nothing,
        authority_input_accepted=false,
        caller_package_sha256_before=caller_package_sha256_before)
    error((:formal_t2_candidate_receipt_replay_mismatch,
        ARGS[7], candidate_artifact.sha256))
end

t1 = material.t1
package = material.package
adapter = material.adapter
gate = FusionConceptAI.vnext_t2_formal_gate_identity_v2(
    package.candidate_ref, FORMAL_T2_SCENARIO,
    t1.source.witness.witness_hash, package.package_hash,
    package.semantic_identity, package.bundle_hash, package.wire.sha256,
    FusionConceptAI.canonical_hash(FusionConceptAI.semantic_view(adapter)),
    adapter.binding.receipt_hash, t1.t1_parents,
    t1.source.expected.commitment_hash,
    FusionConceptAI.Digest256(FORMAL_T2_MANIFEST_SHA256),
    candidate_receipt_hash, evidence_kind=:formal_t1_actual,
    formal_t1_accepted=true)
build = FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
    t1.source.witness, t1.admission_input, material.admission, package,
    adapter, gate, scenario=FORMAL_T2_SCENARIO)
result = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(build)
_formal_t2_require_execution(build, result)

result_serialized = _formal_t2_serialized_artifact(result)
FusionConceptAI._vnext_t2_v2_content_equal(
    FusionConceptAI.semantic_view(result_serialized.value),
    FusionConceptAI.semantic_view(result)) ||
    error(:formal_t2_result_reload_mismatch)
result_reload_identity_hash = FusionConceptAI.canonical_hash(
    FusionConceptAI.semantic_view(result_serialized.value))

if FORMAL_T2_MODE === :replay &&
        result_reload_identity_hash.value != lowercase(ARGS[11])
    _formal_t2_uncommitted_attempt(:serialized_result_postcondition,
        material, lowercase(ARGS[7]), candidate_artifact.sha256,
        lowercase(ARGS[11]), result_reload_identity_hash.value,
        lowercase(ARGS[8]), nothing,
        authority_input_accepted=true, result=result,
        caller_package_sha256_before=caller_package_sha256_before)
    error((:formal_t2_serialized_result_replay_mismatch,
        ARGS[11], result_reload_identity_hash.value))
end

source_receipts = _formal_t2_source_receipts()
method_receipts = _formal_t2_method_receipts()
stable_projection = (
    schema="vnext-t2-formal-stable-projection-r1",
    software_acceptance_manifest_sha256=FORMAL_T2_MANIFEST_SHA256,
    software_acceptance_verification_sha256=FORMAL_T2_VERIFICATION_SHA256,
    candidate_t1_admission_receipt_sha256=candidate_artifact.sha256,
    candidate_ref=package.candidate_ref,
    witness_hash=t1.source.witness.witness_hash,
    package_hash=package.package_hash,
    package_content_hash=
        FusionConceptAI._vnext_t2_t1_package_content_hash_v2(package),
    semantic_identity=package.semantic_identity,
    bundle_hash=package.bundle_hash,
    wire_hash=package.wire.sha256,
    adapter_hash=FusionConceptAI.canonical_hash(
        FusionConceptAI.semantic_view(adapter)),
    binding_receipt_hash=adapter.binding.receipt_hash,
    formal_gate_hash=gate.identity_hash,
    input_hash=build.input.input_hash,
    ledger_hash=result.ledger.ledger_hash,
    attempted_trace_hash=result.attempted_trace.trace_hash,
    result_reload_identity_hash=result_reload_identity_hash,
    consumer_order=Tuple(event.consumer_id for event in
        result.attempted_trace.events),
    consumer_counts=FusionConceptAI.semantic_view(
        result.attempted_trace.counts),
    invocation_receipt_hashes=Tuple(receipt.identity_hash for receipt in
        result.ledger.receipts),
    invocation_receipts=Tuple(FusionConceptAI.semantic_view(receipt) for
        receipt in result.ledger.receipts),
    attempt_events=Tuple(FusionConceptAI.semantic_view(event) for event in
        result.attempted_trace.events),
    consumer_method_receipts=method_receipts,
    t1_admission_invocation_count=2,
    source_receipts=source_receipts,
    compiler_executed=false, provider_executed=false, solver_executed=false)
stable_projection_hash = FusionConceptAI.canonical_hash(stable_projection)

if FORMAL_T2_MODE === :replay &&
        stable_projection_hash.value != lowercase(ARGS[8])
    _formal_t2_uncommitted_attempt(:stable_projection_postcondition,
        material, lowercase(ARGS[7]), candidate_artifact.sha256,
        lowercase(ARGS[11]), result_reload_identity_hash.value,
        lowercase(ARGS[8]), stable_projection_hash.value,
        authority_input_accepted=true, result=result,
        caller_package_sha256_before=caller_package_sha256_before)
    error((:formal_t2_stable_projection_replay_mismatch,
        ARGS[8], stable_projection_hash.value))
end

caller_package_sha256_after =
    _formal_t2_package_state_sha256(material.package)
caller_package_sha256_after == caller_package_sha256_before ||
    error(:formal_t2_caller_package_changed_during_execution)

package_file = _formal_t2_publish_artifact(
    joinpath(FORMAL_T2_OUTPUT, "candidate_package.jls"),
    material.package_serialized)
candidate_file = _formal_t2_publish_artifact(
    joinpath(FORMAL_T2_OUTPUT, "candidate_t1_admission_receipt.json"),
    candidate_artifact)
result_serialized = _formal_t2_publish_artifact(
    joinpath(FORMAL_T2_OUTPUT, "t2_result.jls"), result_serialized)

run_receipt = (
    schema="vnext-t2-formal-candidate-execution-receipt-r1",
    driver_version=FORMAL_T2_DRIVER_VERSION,
    mode=FORMAL_T2_MODE,
    process_id=getpid(),
    julia_threads=Threads.nthreads(),
    evidence_kind=:formal_t1_actual,
    formal_gate_verified=true,
    software_manifest_schema=FORMAL_T2_SOFTWARE_MANIFEST_SCHEMA,
    stable_projection=stable_projection,
    stable_projection_hash=stable_projection_hash,
    result_status=result.status,
    result_resolution=result.resolution,
    result_committed=result.committed,
    accepted=result.ledger.accepted,
    claim_ceiling=result.ledger.claim_ceiling,
    result_serialized_bytes=length(result_serialized.bytes),
    result_serialized_sha256=result_serialized.sha256,
    result_reload_identity_hash=result_reload_identity_hash,
    candidate_package_serialized_bytes=length(package_file.bytes),
    candidate_package_serialized_sha256=package_file.sha256,
    caller_package_sha256_before=caller_package_sha256_before,
    caller_package_sha256_after=caller_package_sha256_after,
    package_artifact_origin=material.package_artifact_origin,
    independent_expected_admission_rebuilt=
        material.independent_expected_admission_rebuilt,
    publication_committed=true,
    published_artifacts=("candidate_package.jls",
        "candidate_t1_admission_receipt.json", "t2_result.jls",
        "run_receipt.json"),
    formal_t2_accepted=false,
    physical_acceptance=false,
    scientific_acceptance=false,
    actual_model_attestation="unavailable")
run_file = _formal_t2_write_canonical(
    joinpath(FORMAL_T2_OUTPUT, "run_receipt.json"), run_receipt)

println(FusionConceptAI.canonical_json(run_receipt))
println("VNEXT_T2_FORMAL_CANDIDATE_DRIVER=PASS")
println("VNEXT_T2_FORMAL_MODE=" * String(FORMAL_T2_MODE))
println("VNEXT_T2_FORMAL_EVIDENCE_KIND=formal_t1_actual")
println("VNEXT_T2_FORMAL_GATE_VERIFIED=true")
println("VNEXT_T2_T1_ADMISSION_INVOCATIONS=2")
println("VNEXT_T2_FIVE_CONSUMER_COUNTS=1,1,1,1,1")
println("VNEXT_T2_CANDIDATE_RECEIPT_SHA256=" * candidate_file.sha256)
println("VNEXT_T2_STABLE_PROJECTION_HASH=" * stable_projection_hash.value)
println("VNEXT_T2_RUN_RECEIPT_SHA256=" * run_file.sha256)
println("VNEXT_T2_FORMAL_ACCEPTANCE=false")
