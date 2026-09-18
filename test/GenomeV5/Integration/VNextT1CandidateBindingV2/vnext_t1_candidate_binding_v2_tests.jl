using Test
using SHA
using Base64

module _V2_BINDING
using SHA
using Base64
include(joinpath(@__DIR__, "..", "..", "..", "..", "src", "IR", "PhysicalTypes.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "..", "src", "Canonical", "CanonicalJSON.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "..", "src", "Contracts", "VNextT1CanonicalBytesV2.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "..", "src", "Contracts", "VNextT1CandidateBindingV2.jl"))
end

const B = _V2_BINDING
const REF = B.QualifiedRefV1("fusion.candidate/local-explicit", "v1")
const DIGEST = B.Digest256("9f4f2f4631776ddd9ba616e06c69381c5ae40efdfed368b264708ee5014fe236")
const PACKAGE = B.Digest256("5a6c35fe029e862c34fa532a0639c32256f23993748ac108f92fd31ea0f29250")

wire(bytes=UInt8[0x00, 0xff, 0x10, 0x20, 0x7f]) = B.VNextT1CanonicalBytesV2(bytes)
binding(; ref=REF, digest=DIGEST, package=PACKAGE, payload=wire()) =
    B.VNextT1CandidateBindingInputV2(ref, digest, package, payload)

@testset "VNext T1 V2 explicit candidate binding" begin
    expected = binding()
    receipt = B.vnext_t1_candidate_binding_v2(expected, (binding(),))
    @test receipt.status === :bound
    @test receipt.accepted === false
    @test receipt.claim_ceiling === :contract_only
    @test receipt.wire_hash == expected.wire.sha256
    @test receipt.receipt_hash != receipt.wire_hash
    @test receipt.receipt_hash == B._vnext_t1_binding_receipt_hash(
        receipt.status, receipt.reason, receipt.candidate_ref,
        receipt.candidate_digest, receipt.source_package_hash,
        receipt.wire_hash, receipt.duplicate_count)

    @test B.vnext_t1_candidate_binding_v2(expected, ()).status === :terminal_deferred
    @test B.vnext_t1_candidate_binding_v2(binding(payload=nothing),
        (binding(payload=nothing),)).reason === :missing_expected_wire
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(payload=nothing),)).reason === :missing_observed_wire

    foreign_ref = B.QualifiedRefV1("fusion.candidate/foreign", "v1")
    foreign_version = B.QualifiedRefV1(REF.id, "v2")
    case_mismatch = B.QualifiedRefV1("Fusion.candidate/local-explicit", "v1")
    path_expected = binding(ref=B.QualifiedRefV1("fusion.candidate/a/../b", "v1"))
    path_alias = binding(ref=B.QualifiedRefV1("fusion.candidate/b", "v1"))
    cross_splice = B.QualifiedRefV1(foreign_ref.id, foreign_version.version)
    foreign_digest = B.Digest256(repeat("a", 64))
    foreign_package = B.Digest256(repeat("b", 64))
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(ref=foreign_ref),)).reason === :foreign_candidate_ref
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(ref=foreign_version),)).reason === :foreign_candidate_ref
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(ref=case_mismatch),)).reason === :foreign_candidate_ref
    @test B.vnext_t1_candidate_binding_v2(path_expected,
        (path_alias,)).reason === :foreign_candidate_ref
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(ref=cross_splice),)).reason === :foreign_candidate_ref
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(digest=foreign_digest),)).reason === :candidate_digest_mismatch
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(package=foreign_package),)).reason === :source_package_hash_mismatch
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(payload=wire(UInt8[0x00, 0xff, 0x10, 0x20, 0x7e])),)).reason === :wire_hash_mismatch
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(), binding())).reason === :duplicate_conflict
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(), binding(ref=foreign_ref))).reason === :duplicate_conflict
    @test B.vnext_t1_candidate_binding_v2(expected,
        (binding(ref=foreign_ref, digest=foreign_digest, package=foreign_package,
            payload=nothing),)).reason === :foreign_candidate_ref

    body_hash = B._vnext_t1_binding_receipt_hash(receipt.status, receipt.reason,
        receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash, receipt.duplicate_count)
    @test_throws ArgumentError B.VNextT1CandidateBindingReceiptV2(
        "wrong-domain", receipt.schema, receipt.version, receipt.status,
        receipt.reason, receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash, receipt.duplicate_count,
        false, :contract_only, body_hash)
    @test_throws ArgumentError B.VNextT1CandidateBindingReceiptV2(
        receipt.domain, receipt.schema, receipt.version, :bound,
        :wire_hash_mismatch, receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash, receipt.duplicate_count,
        false, :contract_only, body_hash)
    @test_throws ArgumentError B.VNextT1CandidateBindingReceiptV2(
        receipt.domain, receipt.schema, receipt.version, receipt.status,
        receipt.reason, receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash, 2,
        false, :contract_only, body_hash)
    @test_throws ArgumentError B.VNextT1CandidateBindingReceiptV2(
        receipt.domain, receipt.schema, receipt.version, receipt.status,
        receipt.reason, receipt.candidate_ref, receipt.candidate_digest,
        receipt.source_package_hash, receipt.wire_hash, receipt.duplicate_count,
        false, :contract_only, B.Digest256(repeat("0", 64)))

    println("VNEXT_T1_CANDIDATE_BINDING_V2_REPLAY",
        " schema=", receipt.schema,
        " version=", receipt.version,
        " status=", receipt.status,
        " candidate_digest=", receipt.candidate_digest.value,
        " wire_hash=", receipt.wire_hash.value,
        " receipt_hash=", receipt.receipt_hash.value)
end
