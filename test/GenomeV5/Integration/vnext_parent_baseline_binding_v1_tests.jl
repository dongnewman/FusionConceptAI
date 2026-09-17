using Test
using FusionConceptAI

const _ROOT = joinpath(@__DIR__, "..", "..", "..", "src")
Base.include(FusionConceptAI, joinpath(_ROOT, "GenomeV5", "Integration", "VNextParentBaselineBindingV1.jl"))
const G = FusionConceptAI

const _A = G.Digest256(repeat("a", 64))
const _B = G.Digest256(repeat("b", 64))
const _C = G.Digest256(repeat("c", 64))
const _D = G.Digest256(repeat("d", 64))
const _PROFILE = "ad33-vnext-profile-v1"

function _contract(uri, schema, canon, profile=_PROFILE)
    G.GenomeContractRef(uri, "v5", schema, canon, profile)
end

function _child_contract(uri)
    ref = _contract(uri, _A, _B)
    seed = G.ChildContractSchemaIdentityV1(ref, _A, _B, _PROFILE,
        G._child_contract_identity_expected(G.ChildContractSchemaIdentityV1(
            ref, _A, _B, _PROFILE, G.Digest256(repeat("e", 64)))))
    G.ChildContractSchemaIdentityV1(ref, _A, _B, _PROFILE,
        G._child_contract_identity_expected(seed))
end

function _error_text(f)
    try
        f()
        return "no_error"
    catch error
        return sprint(showerror, error)
    end
end

@testset "AD-33 parent-baseline typed-absent scaffold" begin
    g1_candidate = G.G1RequestedCandidateV1(
        G.QualifiedRefV1("fusionconceptai://candidate/g1/scaffold", "v5"))
    g1_public = _contract("fusionconceptai://GenomeV5/G1/edit", _A, _B)
    g1_child = _child_contract("fusionconceptai://GenomeV5/G1/edit-child")
    g1_request = G.G1ParentBaselineRequestV1(g1_candidate, g1_public,
        g1_child, :mechanism)
    g1_state = G.g1_typed_absent_state(g1_request)

    @test g1_state.layer === :G1
    @test g1_state.contract_admission === :terminal_deferred
    @test G.verify_absent_state(g1_state)
    @test G.verify_absent_parent(g1_state.baseline_binding)
    @test G.verify_absent_child(g1_state.child_key)
    @test g1_state.baseline_binding isa G.AbsentParentBaselineBindingV1
    @test g1_state.child_key isa G.AbsentChildKeyV1
    @test !(:actual_parent_ref in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:parent_declaration_hash in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:baseline_raw_source_sha256 in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:source_locator in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:factory_receipt in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:parent_binding_hash in fieldnames(typeof(g1_state.baseline_binding)))
    @test !(:actual_parent_ref in fieldnames(typeof(g1_state.child_key)))
    @test !(:parent_declaration_hash in fieldnames(typeof(g1_state.child_key)))
    @test !(:parent_binding_hash in fieldnames(typeof(g1_state.child_key)))
    @test g1_state.baseline_binding.absence_domain == G.VNEXT_PBB_ABSENT_DOMAIN_G1
    @test g1_state.child_key.child_key_digest != g1_state.baseline_binding.absence_digest

    changed_reason = G._absent_parent_hash(:G1, g1_candidate, g1_public,
        :factory_input_unavailable)
    @test changed_reason != g1_state.baseline_binding.absence_digest
    @test G.child_contract_identity_matches(g1_child)
    @test !G.child_contract_identity_matches(g1_child, _C)

    g2_contract = _contract("fusionconceptai://GenomeV5/G2/edit", _C, _D)
    g2_child_ref = _contract("fusionconceptai://GenomeV5/G2/edit-child", _C, _D)
    g2_child_seed = G.ChildContractSchemaIdentityV1(g2_child_ref, _C, _D,
        _PROFILE, G.Digest256(repeat("f", 64)))
    g2_child = G.ChildContractSchemaIdentityV1(g2_child_ref, _C, _D,
        _PROFILE, G._child_contract_identity_expected(g2_child_seed))
    g2_request = G.G2ParentBaselineRequestV1(
        G.G2RequestedCandidateV1(g2_contract), g2_contract, g2_child, :geometry)
    g2_state = G.g2_typed_absent_state(g2_request)
    @test g2_state.layer === :G2
    @test g2_state.contract_admission === :terminal_deferred
    @test G.verify_absent_state(g2_state)
    @test g2_state.baseline_binding.absence_domain == G.VNEXT_PBB_ABSENT_DOMAIN_G2
    @test g2_state.child_key.child_kind === :geometry

    foreign_request = G.G2ParentBaselineRequestV1(
        G.G2RequestedCandidateV1(g2_contract), g1_public, g2_child, :geometry)
    @test occursin("foreign_candidate", _error_text(() -> G.g2_typed_absent_state(foreign_request)))

    for mode in (:fixture, :ref_only, :synthetic, :foreign)
        @test occursin(mode === :ref_only ? "ref_only_authority" :
            mode === :foreign ? "foreign_candidate" : "synthetic_fixture_authority",
            _error_text(() -> G.admit_present_parent(g1_request, mode)))
        @test occursin(mode === :ref_only ? "ref_only_authority" :
            mode === :foreign ? "foreign_candidate" : "synthetic_fixture_authority",
            _error_text(() -> G.admit_present_parent(g2_request, mode)))
    end
    @test occursin("source_backed_receipt_unavailable",
        _error_text(() -> G.admit_present_parent(g1_request, :source_backed)))

    before_bytes = copy(g1_state.canonical_state.bytes)
    before_sha = g1_state.canonical_state.sha256
    before_state_hash = g1_state.state_hash
    before_history = g1_state.history.digests
    input = G.ReplaceSourcePayloadInputV1("op-g1-absent", g1_state.child_key,
        g1_state.state_hash, g1_state.source_content_hash, _D)
    failure = G.replace_source_payload(g1_state, input)
    @test failure.status === :rejected
    @test failure.error_code === :baseline_authority_absent
    @test !failure.published
    @test !failure.history_advanced
    @test failure.prior_canonical_bytes.bytes == before_bytes
    @test failure.prior_canonical_bytes.sha256 == before_sha
    @test g1_state.canonical_state.bytes == before_bytes
    @test g1_state.state_hash == before_state_hash
    @test g1_state.history.digests == before_history

    @test occursin("absent_to_present_cas_forbidden",
        _error_text(() -> G.promote_absent_to_present(g1_state, :present)))
    @test !(:parent_declaration_hash in fieldnames(typeof(g2_state.baseline_binding)))
    @test !(:baseline_semantic_body_sha256 in fieldnames(typeof(g2_state.baseline_binding)))

    @test all(code isa Symbol for code in G.VNEXT_PBB_ERROR_CODES)
    @test :baseline_authority_absent in G.VNEXT_PBB_ERROR_CODES
    @test :synthetic_fixture_authority in G.VNEXT_PBB_ERROR_CODES
    @test :ref_only_authority in G.VNEXT_PBB_ERROR_CODES
end

println("AD33_PBB_STATUS=typed_absent_scaffold_pass")
println("AD33_PBB_PRESENT_AUTHORITY=false")
println("AD33_PBB_PHYSICAL_CREDIT=false")
