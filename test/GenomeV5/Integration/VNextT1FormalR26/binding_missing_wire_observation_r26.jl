using SHA, JSON3
using FusionConceptAI

const R26_BIND_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_BIND_G = FusionConceptAI
Base.include(R26_BIND_G, joinpath(R26_BIND_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))
Base.include(R26_BIND_G, joinpath(R26_BIND_ROOT, "src", "Contracts",
    "VNextT1CandidateBindingV2.jl"))

function r26_bind_out(relative)
    isabspath(relative) && error("absolute output path forbidden")
    ".." in splitpath(relative) && error("output traversal forbidden")
    path = normpath(joinpath(R26_BIND_ROOT, relative))
    allowed = normpath(joinpath(R26_BIND_ROOT, "docs", "implementation",
        "UP1-04A-VNEXT-T1", "independent_formal_r26_20260922"))
    (path == allowed || startswith(path,
        allowed * string(Base.Filesystem.path_separator))) ||
        error("output is outside the R26 evidence root")
    isdir(path) || error("controller must create the fresh output directory")
    path
end

r26_bind_digest(label) = R26_BIND_G.digest256_text("r26-binding-" * label)

function r26_bind_capture(name, expected, observations)
    try
        receipt = R26_BIND_G.vnext_t1_candidate_binding_v2(expected, observations)
        recomputed = R26_BIND_G._vnext_t1_binding_receipt_hash(receipt.status,
            receipt.reason, receipt.candidate_ref, receipt.candidate_digest,
            receipt.source_package_hash, receipt.wire_hash,
            receipt.duplicate_count)
        return (name=name, outcome=:returned, exception_type=:none,
            status=receipt.status, reason=receipt.reason,
            duplicate_count=receipt.duplicate_count,
            wire_hash_present=receipt.wire_hash !== nothing,
            accepted=receipt.accepted, claim_ceiling=receipt.claim_ceiling,
            receipt_hash=receipt.receipt_hash.value,
            recomputed_receipt_hash=recomputed.value,
            receipt_hash_matches=recomputed == receipt.receipt_hash)
    catch err
        return (name=name, outcome=:caught,
            exception_type=nameof(typeof(err)), status=nothing, reason=nothing,
            duplicate_count=length(observations), wire_hash_present=false,
            accepted=nothing, claim_ceiling=nothing, receipt_hash=nothing,
            recomputed_receipt_hash=nothing, receipt_hash_matches=false)
    end
end

length(ARGS) == 1 || error("usage: <fresh-relative-evidence-directory>")
directory = r26_bind_out(ARGS[1])
output = joinpath(directory, "binding_missing_wire_actual.json")
ispath(output) && error("observation output already exists")

candidate = R26_BIND_G.QualifiedRefV1("local://r26-binding-candidate", "v5")
foreign = R26_BIND_G.QualifiedRefV1("local://r26-binding-foreign", "v5")
candidate_digest = r26_bind_digest("candidate")
package_hash = r26_bind_digest("package")
wire = R26_BIND_G.VNextT1CanonicalBytesV2(UInt8[0x52, 0x32, 0x36])
expected = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, nothing)
matching_absent = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, nothing)
matching_present = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, wire)
foreign_observation = R26_BIND_G.VNextT1CandidateBindingInputV2(foreign,
    candidate_digest, package_hash, nothing)
candidate_digest_mismatch = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    r26_bind_digest("foreign-candidate-digest"), package_hash, nothing)
package_hash_mismatch = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, r26_bind_digest("foreign-package"), nothing)

cases = (
    ("zero_observations", ()),
    ("duplicate_matching_absent", (matching_absent, matching_absent)),
    ("duplicate_differing", (matching_absent, matching_present)),
    ("foreign_candidate", (foreign_observation,)),
    ("candidate_digest_mismatch", (candidate_digest_mismatch,)),
    ("source_package_hash_mismatch", (package_hash_mismatch,)),
    ("matching_observed_wire_present", (matching_present,)),
    ("matching_observed_wire_absent", (matching_absent,)),
)
results = [r26_bind_capture(name, expected, observations)
    for (name, observations) in cases]

open(output, "w") do io
    JSON3.write(io, (schema="vnext_t1_binding_missing_wire_observation_r26",
        diagnostic_only=true, formal_T1=false, product_source_mutated=false,
        expected_wire_present=false, case_count=length(results), results=results,
        pid=getpid(), actual_model_attestation="unavailable"))
    flush(io)
end
println("R26_BINDING_MISSING_WIRE_OBSERVATION=COMPLETE cases=", length(results),
    " caught=", count(x -> x.outcome === :caught, results),
    " returned=", count(x -> x.outcome === :returned, results))
flush(stdout)
