using SHA
using Serialization
using FusionConceptAI

FusionConceptAI.load_vnext_t2_components_v2!()
const T2_ARTIFACT_ZERO_COUNTS = FusionConceptAI.VNextT2InvocationCountsV2()

_t2_artifact_sha256(bytes) =
    bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes))))

function main(args)
length(args) == 5 || error(
    "expected mode, original producer artifact, attacked artifact, expected SHA-256, receipt path")
mode = Symbol(args[1])
mode in (:raw_hash_mismatch, :recomputed_corrupt, :zero_malformed) ||
    error((:artifact_negative_mode_invalid, mode))
original_path = abspath(args[2])
attacked_path = abspath(args[3])
expected_sha256 = lowercase(args[4])
receipt_path = abspath(args[5])
ispath(receipt_path) && error(:artifact_negative_receipt_exists)

original_before = read(original_path)
original_before_sha256 = _t2_artifact_sha256(original_before)
attacked = read(attacked_path)
attacked_sha256 = _t2_artifact_sha256(attacked)
hash_verified = attacked_sha256 == expected_sha256
deserialize_attempted = false
deserialized_type = nothing
rejection = nothing
error_type = nothing
error_text = nothing

if !hash_verified
    rejection = :producer_candidate_package_raw_sha256_mismatch
else
    deserialize_attempted = true
    try
        value = Serialization.deserialize(IOBuffer(copy(attacked)))
        deserialized_type = string(typeof(value))
        if !(value isa FusionConceptAI.CandidateStatePackageV5NextV2)
            rejection = :producer_candidate_package_type_invalid
        elseif FusionConceptAI.vnext_t1_package_v2_validate(value) !== nothing
            rejection = :producer_candidate_package_content_invalid
        else
            rejection = :unexpected_artifact_acceptance
        end
    catch error
        rejection = :producer_candidate_package_deserialize_failed
        error_type = string(typeof(error))
        error_text = sprint(showerror, error)
    end
end

expected_rejection = mode === :raw_hash_mismatch ?
    :producer_candidate_package_raw_sha256_mismatch :
    :producer_candidate_package_deserialize_failed
original_after = read(original_path)
original_after_sha256 = _t2_artifact_sha256(original_after)

receipt = (schema="vnext-t2-independent-artifact-preflight-negative-r1",
    mode=mode, expected_rejection=expected_rejection,
    actual_rejection=rejection, hash_verified=hash_verified,
    deserialize_attempted=deserialize_attempted,
    deserialized_type=deserialized_type,
    original_artifact_path=original_path,
    original_artifact_sha256_before=original_before_sha256,
    original_artifact_sha256_after=original_after_sha256,
    original_artifact_unchanged=original_before == original_after,
    attacked_artifact_path=attacked_path,
    attacked_artifact_bytes=length(attacked),
    attacked_artifact_expected_sha256=expected_sha256,
    attacked_artifact_actual_sha256=attacked_sha256,
    consumer_attempted_counts=FusionConceptAI.semantic_view(
        T2_ARTIFACT_ZERO_COUNTS),
    committed_counts=FusionConceptAI.semantic_view(T2_ARTIFACT_ZERO_COUNTS),
    publication_committed=false, published_artifacts=(),
    error_type=error_type, error_text=error_text,
    formal_t2_accepted=false, physical_acceptance=false,
    scientific_acceptance=false, actual_model_attestation="unavailable")
line = FusionConceptAI.canonical_json(receipt)
println("VNEXT_T2_ARTIFACT_PREFLIGHT_ACTUAL=" * line)
flush(stdout)
open(receipt_path, "w") do io
    write(io, line * "\n")
    flush(io)
end

rejection === expected_rejection || error((:artifact_rejection_mismatch,
    expected_rejection, rejection))
original_before == original_after || error(:producer_artifact_changed)
mode === :raw_hash_mismatch && deserialize_attempted &&
    error(:raw_hash_mismatch_reached_deserializer)
mode !== :raw_hash_mismatch && !deserialize_attempted &&
    error(:corrupt_artifact_did_not_reach_deserializer)
println("VNEXT_T2_ARTIFACT_PREFLIGHT_NEGATIVE=PASS")
flush(stdout)
end

main(ARGS)
