using Test

include(joinpath(@__DIR__, "..", "..", "..", "src", "FusionConceptAI.jl"))
const _BINDING_G3_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_BINDING_G3_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_BINDING_G3_ROOT, "G3BindingChildEditabilityV1.jl"))
using .FusionConceptAI
const G = FusionConceptAI

const BUNIT = UnitSignature()
const BCAND = QualifiedRefV1("fusionconceptai://candidate/binding-1", "v5")
const BPARENT = digest256_text("binding-parent")

function b_auth(layer; status=:missing, candidate=BCAND)
    G.G3SFAuthorityV1(layer, candidate, nothing, nothing, status)
end
function b_link(id="link-g1"; layer=:G1, auth=b_auth(layer))
    G.G3BindingLinkV1(id, layer, "genome/$(layer)/target", :residual, BUNIT,
        :in, 1, "source-1", "owner-1", auth)
end
function b_key()
    G.G3BindingChildKeyV1(BCAND, BPARENT, :binding, "binding-child-1")
end
function b_payload(links=(b_link(), b_link("link-g2"; layer=:G2)))
    G.g3_binding_source_payload_v1(b_key(), links)
end
function assert_b_unchanged(state, result)
    @test result.status == :terminal_deferred
    @test result.state === state
    before = G.g3_binding_canonical_bytes_v1(state)
    @test G.g3_binding_canonical_bytes_v1(result.state) == before
    @test result.state.operation_history === state.operation_history
    @test result.state.state_hash == state.state_hash
    @test result.state.body_hash == state.body_hash
    @test result.state.operation_hash == state.operation_hash
end

@testset "G3 binding child editability V1 typed absence" begin
    @test G.g3_binding_child_edit_schema_hash_v1() isa Digest256
    @test G.g3_binding_child_edit_canonicalization_hash_v1() isa Digest256
    @test G.g3_binding_child_edit_profile_hash_v1() isa Digest256
    payload = b_payload()
    @test payload.initial_links isa Tuple
    @test payload.realization_slot isa G.AbsentChildBindingV1
    @test payload.control_slot isa G.AbsentChildBindingV1
    @test payload.source_content_hash == canonical_hash((domain="g3-binding-source-content-v1", key=payload.key,
        child_contract_ref=payload.child_contract_ref, source_uri=payload.source_uri,
        source_version=payload.source_version, source_record=payload.source_record,
        immutable_binding_schema=payload.immutable_binding_schema, initial_links=payload.initial_links,
        realization_slot=payload.realization_slot, control_slot=payload.control_slot))

    state = G.g3_binding_initial_state_v1(payload)
    @test state.state_status == :typed_absent
    @test state.contract_admission == :terminal_deferred
    @test state.physical_resolution == :unknown
    @test isempty(state.operation_history)
    @test state.body_hash == canonical_hash(state.editable_body)
    @test state.initial_body_hash == canonical_hash(state.editable_body)
    @test state.state_hash isa Digest256
    @test G.g3_binding_canonical_bytes_v1(state) == Vector{UInt8}(codeunits(canonical_json(semantic_view(state))))
    @test canonical_hash(state) == digest256_text(String(G.g3_binding_canonical_bytes_v1(state)))
    @test state.initial_body_hash == canonical_hash(G.G3BindingEditableBodyV1(payload.key, payload.initial_links))

    # Hash layers are independent: changing the editable body changes body/state,
    # while source and child identities remain bound to the immutable payload.
    @test state.source_content_hash == payload.source_content_hash
    @test state.binding_child_identity_hash != state.source_content_hash
    @test state.initial_source_state_hash != state.initial_body_hash

    op_insert = G.g3_binding_insert_operation_v1("op-insert", state.source_payload.key, b_link("new"; layer=:G1),
        state.state_hash, state.body_hash, digest256_text("future-body"))
    op_replace = G.g3_binding_replace_operation_v1("op-replace", state.source_payload.key, "link-g1",
        payload.initial_links[1], b_link("link-g1-replacement"; layer=:G1), state.state_hash,
        state.body_hash, digest256_text("future-body-2"))
    op_delete = G.g3_binding_delete_operation_v1("op-delete", state.source_payload.key, payload.initial_links[1],
        state.state_hash, state.body_hash, digest256_text("future-body-3"))
    assert_b_unchanged(state, G.insert_link(state, op_insert))
    assert_b_unchanged(state, G.replace_link(state, op_replace))
    assert_b_unchanged(state, G.delete_link(state, op_delete))
    @test op_insert.operation_hash == canonical_hash((domain="g3-binding-operation-v1", operation_id=op_insert.operation_id,
        operation=op_insert.operation, key=op_insert.key, link_id=op_insert.link_id,
        expected_prior_state_hash=op_insert.expected_prior_state_hash, before_link=op_insert.before_link,
        after_link=op_insert.after_link, prior_body_hash=op_insert.prior_body_hash,
        resulting_body_hash=op_insert.resulting_body_hash))

    # Pairing: exact one G1/G2 upstream and exact legacy target projection gives
    # a typed absence; equality never promotes actual authority.
    target1 = G.G3SFFeedbackTargetV1("target-1", :G1, "genome/G1/target", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", b_auth(:G1))
    target2 = G.G3SFFeedbackTargetV1("target-2", :G2, "genome/G2/target", :loss,
        BUNIT, :out, -1, "source-1", "owner-1", b_auth(:G2))
    paired = G.g3_binding_pairing_v1(BCAND, (target1, target2), (b_auth(:G1), b_auth(:G2)))
    @test paired.status == :typed_absent
    @test paired.resolution == :terminal_deferred
    @test paired.legacy_actual == :typed_absent
    @test paired.reason == "legacy_missing_authority"
    @test length(paired.links) == 2
    @test isempty(paired.errors)

    actual_contract = GenomeContractRef("urn:actual", "v5", digest256_text("actual-schema"),
        digest256_text("actual-canonical"), "actual-profile")
    actual_g1 = G.G3SFAuthorityV1(:G1, BCAND, actual_contract,
        digest256_text("actual-contract"), :actual; attestation=:trusted_receipt)
    actual_g2 = G.G3SFAuthorityV1(:G2, BCAND, actual_contract,
        digest256_text("actual-contract-2"), :actual; attestation=:trusted_receipt)
    actual_target1 = G.G3SFFeedbackTargetV1("actual-1", :G1, "actual/g1", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", actual_g1)
    actual_target2 = G.G3SFFeedbackTargetV1("actual-2", :G2, "actual/g2", :loss,
        BUNIT, :out, -1, "source-1", "owner-1", actual_g2)
    actual_pair = G.g3_binding_pairing_v1(BCAND, (actual_target1, actual_target2),
        (actual_g1, actual_g2))
    @test actual_pair.status == :typed_absent
    @test actual_pair.legacy_actual == :typed_absent
    @test actual_pair.resolution == :terminal_deferred
    @test actual_pair.reason == "legacy_actual_without_declaration_authority"

    # No caller can inject a synthetic present child before checked-present T0.
    present_contract = GenomeContractRef("urn:binding-present", "v5",
        digest256_text("present-schema"), digest256_text("present-canonical"), "present-profile")
    present_error = try
        G.PresentChildBindingV1(:realization,
            QualifiedRefV1("fusionconceptai://child/realization", "v1"), present_contract,
            digest256_text("present-identity"), digest256_text("present-state"))
        "no-error"
    catch err
        sprint(showerror, err)
    end
    @test occursin("binding_authority_typed_absent", present_error)
    @test_throws ArgumentError G.g3_binding_source_payload_v1(b_key(),
        (b_link(), b_link("link-g2"; layer=:G2)); realization_slot=(status=:present,))
    complete_compat = G.g3_binding_source_payload_v1(b_key(),
        (b_link(), b_link("link-g2"; layer=:G2)); complete=true)
    @test complete_compat.realization_slot isa G.AbsentChildBindingV1
    @test complete_compat.control_slot isa G.AbsentChildBindingV1
    @test complete_compat.source_record.schema.status == :typed_absent
    @test_throws ArgumentError G.G3BindingSourcePayloadV1(complete_compat.key,
        complete_compat.child_contract_ref, complete_compat.source_uri,
        complete_compat.source_version, complete_compat.source_record,
        complete_compat.immutable_binding_schema, complete_compat.initial_links,
        (status=:present,), complete_compat.control_slot, complete_compat.source_content_hash)

    stale_g1 = b_auth(:G1; status=:stale)
    stale_g2 = b_auth(:G2; status=:stale)
    stale_t1 = G.G3SFFeedbackTargetV1("stale-1", :G1, "stale/g1", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", stale_g1)
    stale_t2 = G.G3SFFeedbackTargetV1("stale-2", :G2, "stale/g2", :loss,
        BUNIT, :out, -1, "source-1", "owner-1", stale_g2)
    stale_pair = G.g3_binding_pairing_v1(BCAND, (stale_t1, stale_t2),
        (stale_g1, stale_g2))
    @test stale_pair.status == :fail_closed
    @test stale_pair.errors == ("legacy_stale_authority",)
    contradictory_g1 = b_auth(:G1; status=:contradictory)
    contradictory_g2 = b_auth(:G2; status=:contradictory)
    contradictory_t1 = G.G3SFFeedbackTargetV1("contradictory-1", :G1, "contradictory/g1", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", contradictory_g1)
    contradictory_t2 = G.G3SFFeedbackTargetV1("contradictory-2", :G2, "contradictory/g2", :loss,
        BUNIT, :out, -1, "source-1", "owner-1", contradictory_g2)
    contradictory_pair = G.g3_binding_pairing_v1(BCAND, (contradictory_t1, contradictory_t2),
        (contradictory_g1, contradictory_g2))
    @test contradictory_pair.status == :fail_closed
    @test contradictory_pair.errors == ("legacy_contradictory_authority",)

    unknown_upstream = (b_auth(:G1), b_auth(:G2),
        (layer=:G3, candidate_ref=BCAND, contract_ref=nothing,
         contract_hash=nothing, status=:missing, attestation=:unattested))
    @test "unknown_upstream_authority_layer" in G.g3_binding_pairing_v1(BCAND,
        (target1, target2), unknown_upstream).errors
    unknown_target = (target_layer=:G3, target_path="bad", quantity=:loss,
        unit=BUNIT, direction=:in, sign=Int8(1), source_id="source-1",
        owner_scope="owner-1", target_id="unknown", authority=b_auth(:G1))
    @test "unknown_target_layer" in G.g3_binding_pairing_v1(BCAND,
        (unknown_target, target2), (b_auth(:G1), b_auth(:G2))).errors

    for (upstream, code) in (((b_auth(:G1),), "missing_upstream_authority_layer"),
            ((b_auth(:G1), b_auth(:G1), b_auth(:G2)), "duplicate_upstream_authority_layer"),
            ((b_auth(:G1; candidate=QualifiedRefV1("foreign", "v5")), b_auth(:G2)), "upstream_authority_candidate_mismatch"))
        @test code in G.g3_binding_pairing_v1(BCAND, (target1, target2), upstream).errors
    end
    bad_projection = G.G3SFFeedbackTargetV1("target-bad", :G1, "genome/G1/bad", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", G.G3SFAuthorityV1(:G1, BCAND,
        GenomeContractRef("urn:bad", "v5", digest256_text("bad-ref"), digest256_text("bad-can"), "bad"),
        digest256_text("bad-hash"), :actual; attestation=:trusted_receipt))
    @test "legacy_target_upstream_projection_mismatch" in G.g3_binding_pairing_v1(BCAND,
        (bad_projection, target2), (b_auth(:G1), b_auth(:G2))).errors
    duplicate_id = G.G3SFFeedbackTargetV1("target-1", :G2, "other", :loss, BUNIT,
        :out, -1, "source-1", "owner-1", b_auth(:G2))
    @test "duplicate_feedback_target_id" in G.g3_binding_pairing_v1(BCAND,
        (target1, duplicate_id), (b_auth(:G1), b_auth(:G2))).errors
    duplicate_key = G.G3SFFeedbackTargetV1("target-3", :G1, "genome/G1/target", :residual,
        BUNIT, :in, 1, "source-1", "owner-1", b_auth(:G1))
    @test "duplicate_or_ambiguous_feedback_target" in G.g3_binding_pairing_v1(BCAND,
        (target1, duplicate_key), (b_auth(:G1), b_auth(:G2))).errors
end
