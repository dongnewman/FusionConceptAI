using Test, SHA, JSON3, Dates
using FusionConceptAI

include(joinpath(@__DIR__, "path_guard_r26.jl"))

const R26_BIND_ROOT = realpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_BIND_G = FusionConceptAI
const R26_BIND_PROTOCOL_PATH = joinpath(@__DIR__, "protocol_r26_v9.json")
const R26_BIND_PROTOCOL = JSON3.read(read(R26_BIND_PROTOCOL_PATH, String))
Base.include(R26_BIND_G, joinpath(R26_BIND_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))
Base.include(R26_BIND_G, joinpath(R26_BIND_ROOT, "src", "Contracts",
    "VNextT1CandidateBindingV2.jl"))

r26_bind_sha(bytes) = uppercase(bytes2hex(sha256(bytes)))
r26_bind_digest_file(path) = begin
    bytes=read(path); (bytes=length(bytes), sha256=r26_bind_sha(bytes))
end
r26_bind_value(label) = R26_BIND_G.digest256_text("r26-binding-" * label)

function r26_bind_verify_dependencies()
    actual = Dict{String,Any}()
    for row in R26_BIND_PROTOCOL.dependencies
        rel = String(row.path)
        path = r26_guard_existing_repo_file(R26_BIND_ROOT, rel;
            label="frozen dependency")
        got = r26_bind_digest_file(path)
        got.bytes == Int(row.bytes) && got.sha256 == String(row.sha256) ||
            error("frozen dependency drift: $rel")
        actual[rel] = got
    end
    actual
end

function r26_bind_arg(name)
    index = findfirst(==(name), ARGS)
    index === nothing && error("missing argument $name")
    index < length(ARGS) || error("missing value for $name")
    ARGS[index + 1]
end

function r26_bind_ledger_path(value)
    allowed = joinpath(R26_BIND_ROOT,
        "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922")
    r26_guard_new_owned_file(R26_BIND_ROOT, allowed, value; label="ledger")
end

function r26_bind_actual(name, expected, observations, expected_status,
        expected_reason, expected_count, expected_wire_present)
    receipt = R26_BIND_G.vnext_t1_candidate_binding_v2(expected, observations)
    recomputed = R26_BIND_G._vnext_t1_binding_receipt_hash(receipt.status,
        receipt.reason, receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash,
        receipt.duplicate_count)
    (name=name, receipt=receipt, expected_status=expected_status,
        expected_reason=expected_reason, expected_count=expected_count,
        expected_wire_present=expected_wire_present,
        actual=(status=String(receipt.status), reason=String(receipt.reason),
            duplicate_count=receipt.duplicate_count,
            wire_hash_present=receipt.wire_hash !== nothing,
            wire_hash=receipt.wire_hash === nothing ? nothing : receipt.wire_hash.value,
            accepted=receipt.accepted, claim_ceiling=String(receipt.claim_ceiling),
            receipt_hash=receipt.receipt_hash.value,
            recomputed_receipt_hash=recomputed.value,
            receipt_hash_matches=recomputed == receipt.receipt_hash))
end

R26_BIND_PROTOCOL.schema == "vnext_t1_independent_formal_r26_protocol_v9" ||
    error("protocol schema mismatch")
before = r26_bind_verify_dependencies()

candidate = R26_BIND_G.QualifiedRefV1("local://r26-binding-candidate", "v5")
foreign = R26_BIND_G.QualifiedRefV1("local://r26-binding-foreign", "v5")
candidate_digest = r26_bind_value("candidate")
package_hash = r26_bind_value("package")
wire = R26_BIND_G.VNextT1CanonicalBytesV2(UInt8[0x52, 0x32, 0x36])
other_wire = R26_BIND_G.VNextT1CanonicalBytesV2(UInt8[0x52, 0x32, 0x37])
expected_absent = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, nothing)
expected_present = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, wire)
matching_absent = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, nothing)
matching_present = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, wire)
wrong_wire = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, package_hash, other_wire)
foreign_observation = R26_BIND_G.VNextT1CandidateBindingInputV2(foreign,
    candidate_digest, package_hash, nothing)
candidate_mismatch = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    r26_bind_value("foreign-candidate-digest"), package_hash, nothing)
package_mismatch = R26_BIND_G.VNextT1CandidateBindingInputV2(candidate,
    candidate_digest, r26_bind_value("foreign-package"), nothing)

cases = (
    ("absent_zero", expected_absent, (), :terminal_deferred, :missing_observation, 0, false),
    ("absent_duplicate_matching", expected_absent, (matching_absent, matching_absent), :fail_closed, :duplicate_conflict, 2, false),
    ("absent_duplicate_differing", expected_absent, (matching_absent, matching_present), :fail_closed, :duplicate_conflict, 2, false),
    ("absent_foreign_candidate", expected_absent, (foreign_observation,), :fail_closed, :foreign_candidate_ref, 1, false),
    ("absent_candidate_digest", expected_absent, (candidate_mismatch,), :fail_closed, :candidate_digest_mismatch, 1, false),
    ("absent_package_hash", expected_absent, (package_mismatch,), :fail_closed, :source_package_hash_mismatch, 1, false),
    ("absent_matching_present", expected_absent, (matching_present,), :terminal_deferred, :missing_expected_wire, 1, false),
    ("absent_matching_absent", expected_absent, (matching_absent,), :terminal_deferred, :missing_expected_wire, 1, false),
    ("present_zero", expected_present, (), :terminal_deferred, :missing_observation, 0, true),
    ("present_duplicate", expected_present, (matching_present, matching_present), :fail_closed, :duplicate_conflict, 2, true),
    ("present_foreign_candidate", expected_present, (foreign_observation,), :fail_closed, :foreign_candidate_ref, 1, true),
    ("present_candidate_digest", expected_present, (candidate_mismatch,), :fail_closed, :candidate_digest_mismatch, 1, true),
    ("present_package_hash", expected_present, (package_mismatch,), :fail_closed, :source_package_hash_mismatch, 1, true),
    ("present_observed_absent", expected_present, (matching_absent,), :terminal_deferred, :missing_observed_wire, 1, true),
    ("present_matching", expected_present, (matching_present,), :bound, :exact_explicit_binding, 1, true),
    ("present_wrong_wire", expected_present, (wrong_wire,), :fail_closed, :wire_hash_mismatch, 1, true),
)
rows = [r26_bind_actual(row...) for row in cases]
println("R26_BINDING_ACTUAL_BEFORE_ASSERT=", JSON3.write((
    schema="vnext_t1_binding_cross_product_actual_r26_v1",
    case_count=length(rows), results=[merge((name=row.name,), row.actual) for row in rows])))
flush(stdout)

@testset "R26 candidate binding absent and present wire cross-product" begin
    @test length(rows) == 16
    for row in rows
        receipt = row.receipt
        @test receipt.status === row.expected_status
        @test receipt.reason === row.expected_reason
        @test receipt.duplicate_count == row.expected_count
        @test (receipt.wire_hash !== nothing) == row.expected_wire_present
        @test receipt.accepted === false
        @test receipt.claim_ceiling === :contract_only
        @test row.actual.receipt_hash_matches
    end
end

after = r26_bind_verify_dependencies()
before == after || error("dependency changed during binding matrix")
ledger_path = r26_bind_ledger_path(r26_bind_arg("--ledger"))
ledger = (schema="vnext_t1_binding_cross_product_r26_ledger_v1",
    protocol_sha256=r26_bind_digest_file(R26_BIND_PROTOCOL_PATH).sha256,
    case_count=length(rows), results=[merge((name=row.name,), row.actual) for row in rows],
    dependencies_before=before, dependencies_after=after,
    dependencies_unchanged=true, pid=getpid(), utc=string(Dates.now(Dates.UTC)),
    formal_T1=false, scientific_acceptance=false,
    actual_model_attestation="unavailable")
open(ledger_path, "w") do io
    JSON3.write(io, ledger); flush(io)
end
println("R26_BINDING_FORMAL_LEDGER=", JSON3.write(ledger)); flush(stdout)
