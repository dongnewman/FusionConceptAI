using Test
using SHA
using FusionConceptAI

const G = FusionConceptAI
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5",
    "Integration", "VNextParentBaselineBindingLocalV1.jl"))

_h(text::AbstractString) = G.digest256_text(text)
_blob(text::AbstractString) = begin
    bytes = Vector{UInt8}(codeunits(text))
    G.LocalDigestBytesV1(bytes, G.Digest256(bytes2hex(SHA.sha256(bytes))))
end

const _CANDIDATE = G.LocalCandidateIdentityV1("local-r2-candidate", "v1",
    _h("candidate/local-r2"))
const _AXES = (
    G.LocalQualifiedRefV1("axis/payload", "v1", _h("axis/payload")),
    G.LocalQualifiedRefV1("axis/canonical", "v1", _h("axis/canonical")),
    G.LocalQualifiedRefV1("axis/applicability", "v1", _h("axis/applicability")),
    G.LocalQualifiedRefV1("axis/receipt", "v1", _h("axis/receipt")))

function _child(layer::Symbol)
    kind = layer === :G1 ? :mechanism : :geometry
    id = layer === :G1 ? "g1-local-child" : "g2-local-child"
    G.LocalChildRequestV1(layer, kind, id,
        G.LocalQualifiedRefV1("child/$id", "v1", _h("child-contract/$id")),
        _h("child-contract/$id"))
end

function _record(layer::Symbol; candidate=_CANDIDATE,
        receipt_status=:source_backed_present, review_fresh=true,
        authority_origin=:runtime_local, source_text=nothing,
        declaration_text=nothing, semantic_text=nothing, receipt_text=nothing,
        source_claim=nothing, declaration_claim=nothing, semantic_claim=nothing,
        receipt_claim=nothing, receipt_candidate=candidate, receipt_layer=layer,
        factory_version=G.VNEXT_LOCAL_PBB_FACTORY_VERSION_V1,
        receipt_source_ref=nothing, receipt_declaration_ref=nothing,
        receipt_axes=_AXES, review_candidate=candidate, review_layer=layer,
        review_source_ref=nothing, review_declaration_ref=nothing,
        review_axes=_AXES, review_claim=nothing, review_version="v1",
        review_status=nothing)
    prefix = layer === :G1 ? "g1" : "g2"
    source_blob = _blob(source_text === nothing ? "actual source bytes $prefix" : source_text)
    declaration_blob = _blob(declaration_text === nothing ? "actual declaration bytes $prefix" : declaration_text)
    semantic_blob = _blob(semantic_text === nothing ? "actual semantic body $prefix" : semantic_text)
    receipt_blob = _blob(receipt_text === nothing ? "actual factory receipt bytes $prefix" : receipt_text)
    source_blob = source_claim === nothing ? source_blob : G.LocalDigestBytesV1(source_blob.bytes, source_claim)
    declaration_blob = declaration_claim === nothing ? declaration_blob : G.LocalDigestBytesV1(declaration_blob.bytes, declaration_claim)
    semantic_blob = semantic_claim === nothing ? semantic_blob : G.LocalDigestBytesV1(semantic_blob.bytes, semantic_claim)
    receipt_blob = receipt_claim === nothing ? receipt_blob : G.LocalDigestBytesV1(receipt_blob.bytes, receipt_claim)
    source_ref = G.LocalQualifiedRefV1("source/$prefix", "v1", G._vnl_sha256(source_blob.bytes))
    declaration_ref = G.LocalQualifiedRefV1("declaration/$prefix", "v1", G._vnl_sha256(declaration_blob.bytes))
    review_blob = _blob("actual candidate review bytes $prefix")
    review_blob = review_claim === nothing ? review_blob : G.LocalDigestBytesV1(review_blob.bytes, review_claim)
    review_status_value = review_status === nothing ?
        (review_fresh ? :fresh_reviewed : :unavailable) : review_status
    review_receipt = G.LocalCandidateIdentityReviewReceiptV1(review_blob,
        G._vnl_sha256(review_blob.bytes), review_status_value,
        review_version === "v1" ? G.VNEXT_LOCAL_PBB_REVIEW_VERSION_V1 : review_version,
        G.LocalQualifiedRefV1("reviewer/$prefix", "v1", _h("reviewer/$prefix")),
        review_candidate, review_layer,
        review_source_ref === nothing ? source_ref : review_source_ref,
        review_declaration_ref === nothing ? declaration_ref : review_declaration_ref,
        review_axes)
    locator = G.LocalSourceLocatorV1("runtime-repository", "src/GenomeV5/$prefix/DeclarationV1.jl",
        "GenomeV5.$prefix.DeclarationV1", "$(prefix)DeclarationV1", "$(prefix)FactoryV1",
        "runtime-input/$prefix", length(source_blob.bytes), source_blob.claimed_sha256)
    child_contract_ref = G.LocalQualifiedRefV1("child/$prefix-local-child", "v1",
        _h("child-contract/$prefix-local-child"))
    child_contract_hash = _h("child-contract/$prefix-local-child")
    receipt = G.LocalFactoryReceiptV1("$(prefix)FactoryV1", factory_version, receipt_status,
        receipt_blob, G._vnl_sha256(receipt_blob.bytes), receipt_candidate, receipt_layer,
        receipt_source_ref === nothing ? source_ref : receipt_source_ref,
        receipt_declaration_ref === nothing ? declaration_ref : receipt_declaration_ref,
        receipt_axes, review_receipt)
    kind = layer === :G1 ? :mechanism : :geometry
    G.LocalDeclarationRecordV1(layer, kind, layer === :G1 ? "g1-local-child" : "g2-local-child",
        child_contract_ref, child_contract_hash, candidate, _AXES, source_ref, declaration_ref, source_blob, declaration_blob,
        semantic_blob, G._vnl_sha256(declaration_blob.bytes), G._vnl_sha256(semantic_blob.bytes),
        locator, receipt, authority_origin)
end

function _batch(g1=_record(:G1), g2=_record(:G2), children=(_child(:G1), _child(:G2)))
    G.LocalParentBaselineBatchInputV1(_CANDIDATE, (g1, g2), children)
end

@testset "local parent-baseline binding V1 R3" begin
    # duplicate layer/child controls and foreign controls must fail closed.
    present = G.bind_local_parent_baseline_v1(_batch())
    @test present.status === :present
    @test present.resolution === :resolved
    @test present.accepted
    @test present.output isa G.PresentLocalParentBaselineBundleV1
    @test G.verify_present_local_binding_v1(present.output.g1)
    @test G.verify_present_local_binding_v1(present.output.g2)
    @test G.recompute_local_bundle_hash_v1(present.output) == present.output.bundle_hash
    receipt = present.output.g1.factory_receipt
    @testset "empty_factory_identity and empty_factory_version fail closed" begin
        @test_throws ArgumentError G.LocalFactoryReceiptV1("", receipt.factory_version,
            receipt.receipt_status, receipt.receipt_bytes, receipt.receipt_sha256,
            receipt.candidate, receipt.layer, receipt.source_ref, receipt.declaration_ref,
            receipt.axes, receipt.candidate_identity_review)
        @test_throws ArgumentError G.LocalFactoryReceiptV1(receipt.factory_identity, "",
            receipt.receipt_status, receipt.receipt_bytes, receipt.receipt_sha256,
            receipt.candidate, receipt.layer, receipt.source_ref, receipt.declaration_ref,
            receipt.axes, receipt.candidate_identity_review)
    end
    cross_candidate = G.LocalCandidateIdentityV1("cross-candidate", "v1", _h("cross-candidate"))
    cross_bundle = G.PresentLocalParentBaselineBundleV1(cross_candidate,
        present.output.g1, present.output.g2,
        G._vnl_bundle_hash(cross_candidate, present.output.g1, present.output.g2))
    cross_source_hash = _h("cross-candidate-source")
    cross_history = ()
    cross_bytes = G._vnl_state_bytes(cross_bundle, cross_source_hash, cross_history)
    cross_state = G.LocalCanonicalStateV1(cross_bundle, cross_source_hash, cross_bytes,
        G._vnl_sha256(cross_bytes),
        G._vnl_state_hash(cross_bundle, cross_source_hash, cross_bytes, cross_history),
        cross_history)
    @test !G.verify_local_state_v1(cross_state)
    tampered_bundle = G.PresentLocalParentBaselineBundleV1(present.output.candidate,
        present.output.g1, present.output.g2, _h("tampered-bundle-hash"))
    tampered_bundle_bytes = G._vnl_state_bytes(tampered_bundle, cross_source_hash, cross_history)
    tampered_bundle_state = G.LocalCanonicalStateV1(tampered_bundle, cross_source_hash,
        tampered_bundle_bytes, G._vnl_sha256(tampered_bundle_bytes),
        G._vnl_state_hash(tampered_bundle, cross_source_hash, tampered_bundle_bytes,
            cross_history), cross_history)
    @test !G.verify_local_state_v1(tampered_bundle_state)

    absent = G.bind_local_parent_baseline_v1(
        G.LocalParentBaselineBatchInputV1(_CANDIDATE, (), (_child(:G1), _child(:G2))))
    @test absent.status === :typed_absent
    @test absent.resolution === :terminal_deferred
    @test absent.output isa G.AbsentLocalParentBaselineBundleV1
    @test G.verify_absent_local_binding_v1(absent.output.g1)
    @test G.verify_absent_local_binding_v1(absent.output.g2)
    malformed_absent = G.AbsentLocalParentBaselineBindingV1(:G3, :other, "",
        _CANDIDATE, :missing_child_record, :terminal_deferred,
        G._vnl_absence_digest(_CANDIDATE, :G3, :other, "", :missing_child_record))
    @test !G.verify_absent_local_binding_v1(malformed_absent)
    malformed_absent_kind = G.AbsentLocalParentBaselineBindingV1(:G1, :geometry,
        "g1-local-child", _CANDIDATE, :missing_child_record, :terminal_deferred,
        G._vnl_absence_digest(_CANDIDATE, :G1, :geometry, "g1-local-child",
            :missing_child_record))
    @test !G.verify_absent_local_binding_v1(malformed_absent_kind)
    malformed_bundle = G.AbsentLocalParentBaselineBundleV1(_CANDIDATE,
        malformed_absent, absent.output.g2,
        G._vnl_bundle_hash(_CANDIDATE, malformed_absent, absent.output.g2))
    malformed_bytes = G._vnl_state_bytes(malformed_bundle, _h("malformed-source"), ())
    malformed_state = G.LocalCanonicalStateV1(malformed_bundle, _h("malformed-source"),
        malformed_bytes, G._vnl_sha256(malformed_bytes),
        G._vnl_state_hash(malformed_bundle, _h("malformed-source"), malformed_bytes, ()), ())
    @test !G.verify_local_state_v1(malformed_state)
    single_record_missing = G.bind_local_parent_baseline_v1(
        G.LocalParentBaselineBatchInputV1(_CANDIDATE, (_record(:G1),),
            (_child(:G1), _child(:G2))))
    @test single_record_missing.status === :typed_absent
    @test single_record_missing.resolution === :terminal_deferred
    @test single_record_missing.output.g1.reason === :missing_declaration_record
    @test single_record_missing.output.g2.reason === :missing_declaration_record
    no_children = G.bind_local_parent_baseline_v1(
        G.LocalParentBaselineBatchInputV1(_CANDIDATE, (_record(:G1), _record(:G2)), ()))
    @test no_children.status === :typed_absent
    @test no_children.output.g1.reason === :missing_child_record
    one_child_missing = G.bind_local_parent_baseline_v1(
        G.LocalParentBaselineBatchInputV1(_CANDIDATE, (_record(:G1), _record(:G2)),
            (_child(:G1),)))
    @test one_child_missing.status === :typed_absent
    @test one_child_missing.output.g1.reason === :missing_child_record

    unavailable = G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; receipt_status=:unavailable), _record(:G2)))
    @test unavailable.status === :typed_absent
    @test unavailable.output.g1.reason === :source_backed_receipt_unavailable ||
        unavailable.output.g2.reason === :source_backed_receipt_unavailable

    unreviewed = G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; review_fresh=false), _record(:G2)))
    @test unreviewed.status === :typed_absent
    @test unreviewed.output isa G.AbsentLocalParentBaselineBundleV1

    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; source_claim=_h("tampered")), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; receipt_claim=_h("tampered")), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; review_claim=_h("tampered")), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; review_candidate=G.LocalCandidateIdentityV1("foreign-review", "v1", _h("foreign-review"))),
        _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; review_status=:stale), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; factory_version="GenomeV5/Integration/VNextParentBaselineBindingLocalV1/factory-v2"),
        _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; review_version="stale-review-v0"), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; candidate=G.LocalCandidateIdentityV1("foreign", "v1", _h("foreign"))),
        _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(G.LocalParentBaselineBatchInputV1(
        _CANDIDATE, (_record(:G1), _record(:G1), _record(:G2)),
        (_child(:G1), _child(:G2)))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(G.LocalParentBaselineBatchInputV1(
        _CANDIDATE, (_record(:G1), _record(:G2)),
        (_child(:G1), _child(:G1), _child(:G2)))).status === :fail_closed
    bad_child = G.LocalChildRequestV1(:G1, :mechanism, "g1-local-child",
        G.LocalQualifiedRefV1("child/g1-local-child", "v1", _h("child/g1-local-child")),
        _h("wrong-child-contract"))
    @test G.bind_local_parent_baseline_v1(G.LocalParentBaselineBatchInputV1(
        _CANDIDATE, (_record(:G1), _record(:G2)),
        (bad_child, _child(:G2)))).status === :fail_closed
    foreign_id_child = G.LocalChildRequestV1(:G1, :mechanism, "foreign-g1-child",
        G.LocalQualifiedRefV1("child/foreign-g1-child", "v1", _h("child-contract/foreign-g1-child")),
        _h("child-contract/foreign-g1-child"))
    @test G.bind_local_parent_baseline_v1(G.LocalParentBaselineBatchInputV1(
        _CANDIDATE, (_record(:G1), _record(:G2)),
        (foreign_id_child, _child(:G2)))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; receipt_layer=:G2), _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; receipt_source_ref=G.LocalQualifiedRefV1("foreign", "v1", _h("foreign"))),
        _record(:G2))).status === :fail_closed
    @test G.bind_local_parent_baseline_v1(_batch(
        _record(:G1; authority_origin=:fixture), _record(:G2))).status === :fail_closed

    original = present.output.g1
    foreign_locator = G.LocalSourceLocatorV1(original.source_locator.repository_root,
        original.source_locator.source_path, original.source_locator.module_identity,
        original.source_locator.declaration_type, "ForeignFactoryV1",
        original.source_locator.input_locator, original.source_locator.source_bytes,
        original.source_locator.source_sha256)
    foreign_present = G.PresentLocalParentBaselineBindingV1(original.layer,
        original.child_kind, original.child_id, original.child_contract_ref,
        original.child_contract_hash, original.candidate, original.axes,
        original.source_ref, original.declaration_ref, original.source_bytes,
        original.declaration_bytes, original.semantic_body_bytes, original.declaration_hash,
        original.semantic_body_hash, foreign_locator, original.factory_receipt,
        original.parent_binding_hash)
    @test !G.verify_present_local_binding_v1(foreign_present)
    reversed_axes = (original.axes[2], original.axes[1], original.axes[3], original.axes[4])
    foreign_axes_receipt = G.LocalFactoryReceiptV1(
        original.factory_receipt.factory_identity, original.factory_receipt.factory_version,
        original.factory_receipt.receipt_status, original.factory_receipt.receipt_bytes,
        original.factory_receipt.receipt_sha256, original.factory_receipt.candidate,
        original.factory_receipt.layer, original.factory_receipt.source_ref,
        original.factory_receipt.declaration_ref, reversed_axes,
        original.factory_receipt.candidate_identity_review)
    foreign_axes_present = G.PresentLocalParentBaselineBindingV1(original.layer,
        original.child_kind, original.child_id, original.child_contract_ref,
        original.child_contract_hash, original.candidate, original.axes,
        original.source_ref, original.declaration_ref, original.source_bytes,
        original.declaration_bytes, original.semantic_body_bytes, original.declaration_hash,
        original.semantic_body_hash, original.source_locator, foreign_axes_receipt,
        original.parent_binding_hash)
    @test !G.verify_present_local_binding_v1(foreign_axes_present)
    foreign_contract_ref = G.LocalQualifiedRefV1("child/foreign-contract", "v1",
        _h("child-contract/foreign-contract"))
    foreign_contract_present = G.PresentLocalParentBaselineBindingV1(original.layer,
        original.child_kind, original.child_id, foreign_contract_ref,
        foreign_contract_ref.content_hash, original.candidate, original.axes,
        original.source_ref, original.declaration_ref, original.source_bytes,
        original.declaration_bytes, original.semantic_body_bytes, original.declaration_hash,
        original.semantic_body_hash, original.source_locator, original.factory_receipt,
        original.parent_binding_hash)
    @test !G.verify_present_local_binding_v1(foreign_contract_present)
    future_factory_receipt = G.LocalFactoryReceiptV1(
        original.factory_receipt.factory_identity, "future-factory-v2",
        original.factory_receipt.receipt_status, original.factory_receipt.receipt_bytes,
        original.factory_receipt.receipt_sha256, original.factory_receipt.candidate,
        original.factory_receipt.layer, original.factory_receipt.source_ref,
        original.factory_receipt.declaration_ref, original.factory_receipt.axes,
        original.factory_receipt.candidate_identity_review)
    future_factory_present = G.PresentLocalParentBaselineBindingV1(original.layer,
        original.child_kind, original.child_id, original.child_contract_ref,
        original.child_contract_hash, original.candidate, original.axes,
        original.source_ref, original.declaration_ref, original.source_bytes,
        original.declaration_bytes, original.semantic_body_bytes, original.declaration_hash,
        original.semantic_body_hash, original.source_locator, future_factory_receipt,
        original.parent_binding_hash)
    @test !G.verify_present_local_binding_v1(future_factory_present)
    stale_review = G.LocalCandidateIdentityReviewReceiptV1(
        original.factory_receipt.candidate_identity_review.review_bytes,
        original.factory_receipt.candidate_identity_review.review_sha256,
        :fresh_reviewed, "stale-review-v0",
        original.factory_receipt.candidate_identity_review.reviewer_ref,
        original.candidate, original.layer, original.source_ref,
        original.declaration_ref, original.axes)
    stale_review_factory = G.LocalFactoryReceiptV1(
        original.factory_receipt.factory_identity, original.factory_receipt.factory_version,
        original.factory_receipt.receipt_status, original.factory_receipt.receipt_bytes,
        original.factory_receipt.receipt_sha256, original.factory_receipt.candidate,
        original.factory_receipt.layer, original.factory_receipt.source_ref,
        original.factory_receipt.declaration_ref, original.factory_receipt.axes,
        stale_review)
    stale_review_present = G.PresentLocalParentBaselineBindingV1(original.layer,
        original.child_kind, original.child_id, original.child_contract_ref,
        original.child_contract_hash, original.candidate, original.axes,
        original.source_ref, original.declaration_ref, original.source_bytes,
        original.declaration_bytes, original.semantic_body_bytes, original.declaration_hash,
        original.semantic_body_hash, original.source_locator, stale_review_factory,
        original.parent_binding_hash)
    @test !G.verify_present_local_binding_v1(stale_review_present)

    state = G.local_state_from_binding_v1(present)
    @test state !== nothing
    @test G.verify_local_state_v1(state)
    before_bytes = copy(state.canonical_bytes)
    before_sha = state.canonical_sha256
    before_state_hash = state.state_hash
    before_source_hash = state.source_content_hash
    before_history = state.history
    replacement = _blob("replacement source payload")
    stale_state = G.LocalReplaceSourcePayloadInputV1("stale-state", _h("stale-state"),
        before_source_hash, before_history, replacement)
    stale_state_receipt = G.replace_local_source_payload_v1(state, stale_state)
    @test stale_state_receipt.error_code === :stale_state_hash
    @test !stale_state_receipt.published && !stale_state_receipt.history_advanced
    @test stale_state_receipt.prior_canonical_bytes == before_bytes
    stale_source = G.LocalReplaceSourcePayloadInputV1("stale-source", before_state_hash,
        _h("stale-source"), before_history, replacement)
    stale_source_receipt = G.replace_local_source_payload_v1(state, stale_source)
    @test stale_source_receipt.error_code === :stale_source_hash
    @test stale_source_receipt.prior_state_hash == before_state_hash

    state.canonical_bytes[1] = state.canonical_bytes[1] == UInt8('x') ? UInt8('y') : UInt8('x')
    tampered_snapshot = copy(state.canonical_bytes)
    tamper_input = G.LocalReplaceSourcePayloadInputV1("tampered-state", before_state_hash,
        before_source_hash, before_history, replacement)
    tamper_receipt = G.replace_local_source_payload_v1(state, tamper_input)
    @test tamper_receipt.error_code === :state_hash_mismatch
    @test tamper_receipt.prior_canonical_bytes == state.canonical_bytes
    @test tamper_receipt.prior_canonical_bytes == tampered_snapshot
    @test state.canonical_sha256 == before_sha
    @test state.state_hash == before_state_hash
    @test state.source_content_hash == before_source_hash
    @test state.history == before_history
    @test !tamper_receipt.published && !tamper_receipt.history_advanced
    @test tamper_receipt.prior_state_hash == before_state_hash
    @test tamper_receipt.prior_source_content_hash == before_source_hash
    @test tamper_receipt.prior_history == before_history

    stale_history = G.LocalReplaceSourcePayloadInputV1("stale-history", before_state_hash,
        before_source_hash, (_h("stale-history"),), replacement)
    stale_history_receipt = G.replace_local_source_payload_v1(state, stale_history)
    @test stale_history_receipt.error_code === :stale_history
    @test stale_history_receipt.prior_canonical_bytes == state.canonical_bytes

    tampered_history_state = G.LocalCanonicalStateV1(state.bundle,
        state.source_content_hash, state.canonical_bytes, state.canonical_sha256,
        state.state_hash, (_h("tampered-history"),))
    tampered_history_input = G.LocalReplaceSourcePayloadInputV1("tampered-history",
        before_state_hash, before_source_hash, tampered_history_state.history, replacement)
    tampered_history_receipt = G.replace_local_source_payload_v1(tampered_history_state,
        tampered_history_input)
    @test tampered_history_receipt.error_code === :state_hash_mismatch
    @test tampered_history_receipt.prior_canonical_bytes == tampered_history_state.canonical_bytes
    @test tampered_history_receipt.prior_state_hash == tampered_history_state.state_hash
    @test tampered_history_receipt.prior_history == tampered_history_state.history

    absent_state = G.local_state_from_binding_v1(absent)
    absent_input = G.LocalReplaceSourcePayloadInputV1("absent", absent_state.state_hash,
        absent_state.source_content_hash, absent_state.history, replacement)
    absent_receipt = G.replace_local_source_payload_v1(absent_state, absent_input)
    @test absent_receipt.error_code === :baseline_authority_absent
    @test absent_receipt.prior_canonical_bytes == absent_state.canonical_bytes
    @test_throws ArgumentError G.promote_absent_local_to_present_v1(absent_state)

    next_state = G.local_state_from_binding_v1(present)
    published = G.replace_local_source_payload_v1(next_state,
        G.LocalReplaceSourcePayloadInputV1("valid-op", next_state.state_hash,
            next_state.source_content_hash, next_state.history, replacement))
    @test published.status === :published
    @test published.published && published.history_advanced
    @test published.state_after !== nothing
    @test G.verify_local_state_v1(published.state_after)
end

println("VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined")
println("VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true")
println("VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false")
