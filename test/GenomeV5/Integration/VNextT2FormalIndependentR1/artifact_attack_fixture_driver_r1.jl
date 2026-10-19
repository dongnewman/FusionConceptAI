using SHA
using Serialization
using FusionConceptAI

const T2_ATTACK_REGISTRY_BEFORE = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
include(joinpath(@__DIR__, "..", "VNextT2IdentityReceiptV2",
    "fixture_helpers.jl"))
FusionConceptAI.load_vnext_t2_components_v2!()
const T2_ATTACK_REGISTRY_AFTER = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
T2_ATTACK_REGISTRY_BEFORE == T2_ATTACK_REGISTRY_AFTER ||
    error(:artifact_attack_fixture_registry_drift)

_t2_attack_sha256(bytes) =
    bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes))))

function _t2_attack_write_serialized(path, value)
    ispath(path) && error((:artifact_attack_output_exists, path))
    io = IOBuffer()
    Serialization.serialize(io, value)
    bytes = take!(io)
    open(path, "w") do stream
        write(stream, bytes)
        flush(stream)
    end
    (path=path, bytes=length(bytes), sha256=_t2_attack_sha256(bytes))
end

function _t2_attack_write_canonical(path, value)
    ispath(path) && error((:artifact_attack_output_exists, path))
    bytes = Vector{UInt8}(codeunits(FusionConceptAI.canonical_json(value) * "\n"))
    open(path, "w") do stream
        write(stream, bytes)
        flush(stream)
    end
    (path=path, bytes=length(bytes), sha256=_t2_attack_sha256(bytes))
end

function main(args)
    length(args) == 1 || error("expected artifact attack output directory")
    output = abspath(only(args))
    mkpath(output)
    isempty(readdir(output)) || error(:artifact_attack_output_not_empty)

    wrong_type = _t2_attack_write_serialized(
        joinpath(output, "candidate_package_wrong_type.jls"),
        (schema="vnext-t2-intentional-wrong-serialized-type-r1",
         accepted=false))

    foreign_candidate = FusionConceptAI.QualifiedRefV1(
        "fusionconceptai://candidate/vnext-t2-foreign-artifact-negative-r1",
        "v5")
    source = v3_chain(candidate=foreign_candidate)
    source_recheck = FusionConceptAI.vnext_declaration_authority_recheck_local_v2(
        FusionConceptAI.VNextAuthorityRecheckLocalV2Input(
            source.transport.candidate_ref, source.transport))
    t1_parents = ntuple(i -> FusionConceptAI.vnext_t1_parent_commitment_v2(
        source.transport.candidate_ref, source.transport.declarations[i]), 2)
    authority = (status=source.bridge.status,
        resolution=source.bridge.resolution,
        authority_verified=source.bridge.authority_verified,
        expected_commitment=source.expected,
        binding_state=source.bridge.binding_state,
        commitment_hash=source.expected.commitment_hash)
    admission_input = FusionConceptAI.VNextT1AdmissionInputV2(
        source.transport.candidate_ref, source.transport, source_recheck,
        t1_parents, source.expected.commitment_hash, authority)
    admission = FusionConceptAI.vnext_t1_admit_v2(admission_input)

    observation = (
        schema="vnext-t2-independent-artifact-attack-observation-r1",
        candidate_ref=foreign_candidate,
        source_ready=source.built.source_ready,
        source_status=source.built.status,
        source_errors=source.built.errors,
        source_gaps=source.built.gaps,
        recheck_type=string(typeof(source_recheck)),
        recheck_status=source_recheck.status,
        recheck_resolution=source_recheck.resolution,
        recheck_errors=source_recheck.errors,
        admission_type=string(typeof(admission)),
        admission_status=admission.status,
        admission_resolution=admission.resolution,
        admission_errors=admission.errors,
        admission_gaps=admission.gaps,
        package_type=admission.package === nothing ? nothing :
            string(typeof(admission.package)),
        formal_t2_accepted=false,
        physical_acceptance=false,
        scientific_acceptance=false,
        actual_model_attestation="unavailable")
    observation_receipt = _t2_attack_write_canonical(
        joinpath(output, "foreign_package_observation.json"), observation)
    println("VNEXT_T2_FOREIGN_ARTIFACT_ACTUAL=" *
        FusionConceptAI.canonical_json(observation))
    flush(stdout)

    source.built.source_ready || error(:foreign_artifact_source_not_ready)
    source_recheck.status === :local_checked_present ||
        error(:foreign_artifact_recheck_not_present)
    admission.status === :prepared_not_executed ||
        error(:foreign_artifact_admission_not_prepared)
    admission.resolution === :terminal_deferred ||
        error(:foreign_artifact_admission_resolution_invalid)
    admission.package isa FusionConceptAI.CandidateStatePackageV5NextV2 ||
        error(:foreign_artifact_package_absent)
    FusionConceptAI.vnext_t1_package_v2_validate(admission.package) === nothing ||
        error(:foreign_artifact_package_invalid)
    admission.package.candidate_ref == foreign_candidate ||
        error(:foreign_artifact_candidate_mismatch)

    foreign_package = _t2_attack_write_serialized(
        joinpath(output, "candidate_package_foreign_valid.jls"),
        admission.package)
    receipt = (
        schema="vnext-t2-independent-artifact-attack-fixtures-r1",
        wrong_type=wrong_type,
        foreign_package=foreign_package,
        foreign_observation=observation_receipt,
        foreign_candidate_ref=foreign_candidate,
        foreign_package_hash=admission.package.package_hash,
        foreign_semantic_identity=admission.package.semantic_identity,
        foreign_bundle_hash=admission.package.bundle_hash,
        foreign_wire_hash=admission.package.wire.sha256,
        producer_artifacts_immutable=true,
        formal_t2_accepted=false,
        physical_acceptance=false,
        scientific_acceptance=false,
        actual_model_attestation="unavailable")
    receipt_file = _t2_attack_write_canonical(
        joinpath(output, "attack_fixture_receipt.json"), receipt)
    println("VNEXT_T2_ARTIFACT_ATTACK_FIXTURES=" *
        FusionConceptAI.canonical_json(receipt))
    println("VNEXT_T2_ARTIFACT_ATTACK_FIXTURE_RECEIPT_SHA256=" *
        receipt_file.sha256)
    println("VNEXT_T2_ARTIFACT_ATTACK_FIXTURES=PASS")
    flush(stdout)
end

main(ARGS)
