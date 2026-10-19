using Test
using FusionConceptAI

const _ROOT = joinpath(@__DIR__, "..", "..", "..")
const _TRANSPORT_TEST_HELPERS = joinpath(@__DIR__,
    "vnext_declaration_transport_local_v1_tests.jl")

# The transport helper owns the complete local fixture load order: it defines
# Main.G and loads G1/G2/G3 plus LocalV1 before this additive adapter.
Base.include(Main, _TRANSPORT_TEST_HELPERS)
Base.include(G, joinpath(_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))

function _local_fixture()
    g1 = Main._t0l_g1(); g2 = Main._t0l_g2(); g3 = Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2;
            path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3;
            path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control),
        Main._t0l_child(:binding))
    feedback = (Main._t0l_feedback("g1-residual", declarations[1].declaration_ref),
        Main._t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    admission = G.vnext_declaration_transport_local_v1(Main._T0L_CANDIDATE,
        declarations, children, feedback)
    admission.status === :valid || error("fixture transport is not valid")
    admission.transport, declarations, children, feedback
end

_local_input(bundle, records) =
    G.VNextAuthorityRecheckLocalInputV1(Main._T0L_CANDIDATE, bundle, records)

function _rebuild_bundle(bundle; candidate=bundle.candidate_ref,
        declarations=bundle.declarations, children=bundle.children,
        feedback=bundle.feedback, bundle_hash=nothing, status=bundle.status,
        errors=bundle.errors, gaps=bundle.gaps)
    body_hash = G.canonical_hash(G._vnl_t0_bundle_body_v1(candidate,
        declarations, children, feedback))
    G.VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children),
        Tuple(feedback), something(bundle_hash, body_hash), status, errors, gaps)
end

function _record_with(x::G.VNextT0LocalPresentDeclarationV1;
        candidate=x.candidate_ref, source_ref=x.source_ref,
        declaration_ref=x.declaration_ref, source_bytes=x.source_bytes,
        declaration_bytes=x.declaration_bytes, source_locator=x.source_locator,
        factory_receipt=x.factory_receipt,
        declaration_receipt=x.declaration_receipt)
    G.VNextT0LocalPresentDeclarationV1(x.layer, candidate, source_ref,
        declaration_ref, x.source_identity_hash, x.declaration_identity_hash,
        x.axes, source_bytes, declaration_bytes, x.semantic_body, source_locator,
        factory_receipt, declaration_receipt)
end

function _bad_locator(x)
    G.VNextT0LocalSourceLocatorV1(x.repository_root,
        "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl", x.source_uri,
        x.source_ref, x.source_size, x.source_sha256, x.observed_head,
        x.head_path_status, x.working_tree_path_status, x.working_tree_status,
        x.head_blob_sha256, x.provenance)
end

function _bad_receipt(x, ::Type{T}) where {T}
    bad_axes = (G.QualifiedRefV1("local://bad-axis", "v1"), x.axes[2],
        x.axes[3], x.axes[4])
    T(x.candidate_ref, x.layer, x.source_ref, x.declaration_ref, bad_axes,
        x.status, x.factory_result)
end

"""Closed comparison of test values with a bounded product-value walk.

The comparator must not introspect Julia runtime structs: String, Function,
Type, and similar values can expose implementation objects with recursive
internal graphs.  Product structs owned by FusionConceptAI are the only
structs opened; mutable byte arrays remain recursively checked so nested
mutation cannot be hidden.  The explicit depth bound makes a malformed
self-referential fixture fail closed instead of exhausting the Windows stack.
"""
const _CLOSED_EQUAL_MAX_DEPTH = 256
const _CLOSED_EQUAL_PRODUCT_MODULE = parentmodule(G.VNextT0LocalTransportV1)

function _closed_equal(a, b, depth::Int=0)
    typeof(a) === typeof(b) || return false
    depth <= _CLOSED_EQUAL_MAX_DEPTH || return false
    a === b && return true
    # Runtime/atomic values are opaque; do not recurse through their internal
    # struct representation (which is outside the product value contract).
    if a isa AbstractString || a isa AbstractChar || a isa Symbol ||
            a isa Number || a isa Enum || a isa Function || a isa Type ||
            a isa Module || a isa Ptr || a isa Nothing
        return a == b
    elseif a isa AbstractArray
        size(a) == size(b) || return false
        return all(_closed_equal(x, y, depth + 1) for (x, y) in zip(a, b))
    elseif a isa Tuple
        length(a) == length(b) || return false
        return all(_closed_equal(x, y, depth + 1) for (x, y) in zip(a, b))
    elseif a isa NamedTuple
        keys(a) == keys(b) || return false
        return all(_closed_equal(getproperty(a, k), getproperty(b, k), depth + 1)
            for k in keys(a))
    elseif a isa AbstractDict
        keys(a) == keys(b) || return false
        return all(haskey(b, k) && _closed_equal(v, b[k], depth + 1)
            for (k, v) in a)
    elseif isstructtype(typeof(a))
        # Only recurse into immutable product values defined by this package;
        # unknown runtime structs are compared opaquely and never traversed.
        parentmodule(typeof(a)) === _CLOSED_EQUAL_PRODUCT_MODULE || return a == b
        return all(_closed_equal(getfield(a, i), getfield(b, i), depth + 1)
            for i in 1:fieldcount(typeof(a)))
    end
    a == b
end

function _snapshot_part(x)
    frozen = deepcopy(x)
    canonical = G.canonical_json(frozen)
    bytes = copy(Vector{UInt8}(codeunits(canonical)))
    hash = G._vnl_t0_sha(bytes)
    (frozen=frozen, bytes=bytes, hash=hash)
end

function _freeze_state(bundle, records)
    bundle_state = _snapshot_part(bundle)
    record_state = Tuple(_snapshot_part(x) for x in records)
    (bundle=bundle_state.frozen, records=Tuple(x.frozen for x in record_state),
        bundle_bytes=bundle_state.bytes, bundle_hash=bundle_state.hash,
        record_bytes=Tuple(x.bytes for x in record_state),
        record_hash=Tuple(x.hash for x in record_state))
end

function _assert_frozen_unchanged(snapshot, bundle, records)
    @test _closed_equal(bundle, snapshot.bundle)
    @test _closed_equal(records, snapshot.records)
end

function _expected_present(snapshot)
    G.VNextAuthorityRecheckLocalCheckedPresentV1(Main._T0L_CANDIDATE,
        snapshot.records[1], snapshot.records[2], snapshot.records[3],
        snapshot.bundle.feedback, snapshot.bundle.children,
        snapshot.bundle.bundle_hash)
end

function _expected_typed_absent(snapshot)
    G.VNextAuthorityRecheckLocalTypedAbsentV1(Main._T0L_CANDIDATE,
        (:missing_material, :g3_feedback_material_absent),
        snapshot.bundle.bundle_hash, true)
end

function _assert_negative(name, bundle, records, expected_errors)
    before = _freeze_state(bundle, records)
    result = G.vnext_declaration_authority_recheck_local_v1(
        _local_input(bundle, records))
    @test result.status === :fail_closed
    @test result.resolution === :none
    @test result.accepted === false
    @test result.claim_ceiling === :contract_only
    @test result.errors === expected_errors
    @test result.reasons === expected_errors
    @test result.output === nothing
    _assert_frozen_unchanged(before, bundle, records)
    @test collect(result.prior_bundle_bytes) == before.bundle_bytes
    @test result.prior_bundle_sha256 == bundle.bundle_hash
    result
end

# Fixture/dispatch is one-to-one; static QA checks that closure as well.
# `expected_errors` is the complete public result tuple.  The adapter's
# fail-closed contract intentionally publishes only the first accumulated
# validator error, so each public tuple is exact even when validation would
# collect later diagnostics internally.
const LOCAL_NEGATIVE_DISPATCH = (
    (name=:duplicate_layer, expected_errors=(:duplicate_layer,)),
    (name=:missing_layer, expected_errors=(:missing_layer,)),
    (name=:unknown_layer, expected_errors=(:unknown_layer,)),
    (name=:foreign_candidate, expected_errors=(:record_bundle_canonical_mismatch,)),
    (name=:source_ref_mismatch, expected_errors=(:source_locator_ref_mismatch,)),
    (name=:declaration_ref_mismatch, expected_errors=(:declaration_identity_hash_mismatch,)),
    (name=:source_hash_mismatch, expected_errors=(:source_bytes_hash_mismatch,)),
    (name=:declaration_hash_mismatch, expected_errors=(:declaration_bytes_hash_mismatch,)),
    (name=:source_bytes_mismatch, expected_errors=(:source_bytes_hash_mismatch,)),
    (name=:declaration_bytes_mismatch, expected_errors=(:declaration_bytes_hash_mismatch,)),
    (name=:locator_mismatch, expected_errors=(:source_locator_unreadable_or_escape,)),
    (name=:factory_receipt_mismatch, expected_errors=(:receipt_axes_mismatch,)),
    (name=:declaration_receipt_mismatch, expected_errors=(:receipt_axes_mismatch,)),
    (name=:canonical_equality_mismatch, expected_errors=(:record_bundle_canonical_mismatch,)),
    (name=:feedback_projection_mismatch, expected_errors=(:feedback_target_ref_mismatch,)),
    (name=:duplicate_feedback_target, expected_errors=(:duplicate_feedback,)),
    (name=:unknown_feedback_layer, expected_errors=(:feedback_layer_invalid,)),
    (name=:g3_child_present_forbidden, expected_errors=(:g3_child_present_forbidden,)),
    (name=:stale_bundle, expected_errors=(:bundle_hash_mismatch,)),
    (name=:bundle_hash_mismatch, expected_errors=(:bundle_hash_mismatch,)),
    (name=:bundle_status_invalid, expected_errors=(:bundle_status_invalid,)),
    (name=:bundle_errors_present, expected_errors=(:bundle_errors_present,)),
    (name=:prior_bundle_bytes_unchanged, expected_errors=(:bundle_hash_mismatch,)),
    (name=:prior_bundle_hash_unchanged, expected_errors=(:bundle_hash_mismatch,)),
    (name=:axis_identity_or_order_invalid,
        expected_errors=(:axes_identity_or_order_invalid,)))

@testset "local T0 authority recheck V1" begin
    bundle, records, children, feedback = _local_fixture()
    positive_before = _freeze_state(bundle, records)
    result = G.vnext_declaration_authority_recheck_local_v1(
        _local_input(bundle, records))
    @test result.status === :local_checked_present
    @test result.resolution === :resolved
    @test result.accepted === false
    @test result.claim_ceiling === :contract_only
    @test result.errors === ()
    @test result.reasons === ()
    @test result.output isa G.VNextAuthorityRecheckLocalCheckedPresentV1
    @test result.output.g1.layer === :G1
    @test result.output.g2.layer === :G2
    @test result.output.g3.layer === :G3
    @test all(x -> x isa G.VNextT0LocalChildAbsentV1, result.output.children)
    @test _closed_equal(result.output, _expected_present(positive_before))
    _assert_frozen_unchanged(positive_before, bundle, records)
    @test collect(result.prior_bundle_bytes) == positive_before.bundle_bytes
    @test result.prior_bundle_sha256 == bundle.bundle_hash

    @testset "closed comparator mutation probe" begin
        probe = deepcopy(bundle)
        probe_snapshot = deepcopy(probe)
        @test _closed_equal(probe, probe_snapshot)
        probe.declarations[1].source_bytes.bytes[1] = xor(
            probe.declarations[1].source_bytes.bytes[1], UInt8(0x01))
        @test !_closed_equal(probe, probe_snapshot)
    end

    @testset "typed absence preserves the deferred G3 boundary" begin
        absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3,
            Main._T0L_CANDIDATE, :missing_material, :terminal_deferred)
        absent_bundle = _rebuild_bundle(bundle;
            declarations=(records[1], records[2], absent_g3))
        absent_records = (records[1], records[2], absent_g3)
        absent_before = _freeze_state(absent_bundle, absent_records)
        absent = G.vnext_declaration_authority_recheck_local_v1(
            _local_input(absent_bundle, absent_records))
        @test absent.status === :typed_absent
        @test absent.resolution === :terminal_deferred
        @test absent.accepted === false
        @test absent.claim_ceiling === :contract_only
        @test absent.errors === ()
        @test absent.reasons ===
            (:missing_material, :g3_feedback_material_absent)
        @test absent.output isa G.VNextAuthorityRecheckLocalTypedAbsentV1
        @test absent.output.reasons ===
            (:missing_material, :g3_feedback_material_absent)
        @test absent.output.g3_children_deferred
        @test _closed_equal(absent.output, _expected_typed_absent(absent_before))
        _assert_frozen_unchanged(absent_before, absent_bundle, absent_records)
        @test collect(absent.prior_bundle_bytes) == absent_before.bundle_bytes
        @test absent.prior_bundle_sha256 == absent_bundle.bundle_hash
    end

    g1, g2, g3 = records
    foreign = G.QualifiedRefV1("local://foreign-candidate", "v5")
    bad_source_ref = G.QualifiedRefV1("local://bad/source", "v1")
    bad_declaration_ref = G.QualifiedRefV1("local://bad/declaration", "v1")
    bad_sha = G.digest256_text("local-negative")
    cases = Dict{Symbol,Tuple{Any,Any}}()
    cases[:duplicate_layer] = (bundle, (g1, g1, g3))
    cases[:missing_layer] = (bundle, (g1, g3))
    unknown_layer = G.VNextT0LocalPresentDeclarationV1(:G4, g1.candidate_ref,
        g1.source_ref, g1.declaration_ref, g1.source_identity_hash,
        g1.declaration_identity_hash, g1.axes, g1.source_bytes,
        g1.declaration_bytes, g1.semantic_body, g1.source_locator,
        g1.factory_receipt, g1.declaration_receipt)
    cases[:unknown_layer] = (bundle, (unknown_layer, g2, g3))
    malformed_axis_record = G.VNextT0LocalPresentDeclarationV1(:G1,
        g1.candidate_ref, g1.source_ref, g1.declaration_ref,
        g1.source_identity_hash, g1.declaration_identity_hash,
        (g1.axes[1], G.QualifiedRefV1("foreign-axis", "v1"),
            g1.axes[3], g1.axes[4]), g1.source_bytes, g1.declaration_bytes,
        g1.semantic_body, g1.source_locator, g1.factory_receipt,
        g1.declaration_receipt)
    cases[:axis_identity_or_order_invalid] = (_rebuild_bundle(bundle;
        declarations=(malformed_axis_record, g2, g3)),
        (malformed_axis_record, g2, g3))
    foreign_record = _record_with(g1; candidate=foreign)
    cases[:foreign_candidate] = (bundle, (foreign_record, g2, g3))

    source_ref_record = _record_with(g1; source_ref=bad_source_ref)
    cases[:source_ref_mismatch] = (_rebuild_bundle(bundle;
        declarations=(source_ref_record, g2, g3)),
        (source_ref_record, g2, g3))
    declaration_ref_record = _record_with(g1; declaration_ref=bad_declaration_ref)
    cases[:declaration_ref_mismatch] = (_rebuild_bundle(bundle;
        declarations=(declaration_ref_record, g2, g3)),
        (declaration_ref_record, g2, g3))
    source_hash_record = _record_with(g1;
        source_bytes=G.VNextT0LocalBytesV1(g1.source_bytes.bytes, bad_sha))
    cases[:source_hash_mismatch] = (_rebuild_bundle(bundle;
        declarations=(source_hash_record, g2, g3)),
        (source_hash_record, g2, g3))
    declaration_hash_record = _record_with(g1;
        declaration_bytes=G.VNextT0LocalBytesV1(g1.declaration_bytes.bytes, bad_sha))
    cases[:declaration_hash_mismatch] = (_rebuild_bundle(bundle;
        declarations=(declaration_hash_record, g2, g3)),
        (declaration_hash_record, g2, g3))
    source_bytes_record = _record_with(g1;
        source_bytes=G.VNextT0LocalBytesV1(vcat(g1.source_bytes.bytes, UInt8[0x00]),
            g1.source_bytes.sha256))
    cases[:source_bytes_mismatch] = (_rebuild_bundle(bundle;
        declarations=(source_bytes_record, g2, g3)),
        (source_bytes_record, g2, g3))
    declaration_bytes_record = _record_with(g1;
        declaration_bytes=G.VNextT0LocalBytesV1(vcat(g1.declaration_bytes.bytes,
            UInt8[0x00]), g1.declaration_bytes.sha256))
    cases[:declaration_bytes_mismatch] = (_rebuild_bundle(bundle;
        declarations=(declaration_bytes_record, g2, g3)),
        (declaration_bytes_record, g2, g3))
    locator_record = _record_with(g1; source_locator=_bad_locator(g1.source_locator))
    cases[:locator_mismatch] = (_rebuild_bundle(bundle;
        declarations=(locator_record, g2, g3)), (locator_record, g2, g3))
    factory_receipt_record = _record_with(g1;
        factory_receipt=_bad_receipt(g1.factory_receipt,
            G.VNextT0LocalFactoryReceiptV1))
    cases[:factory_receipt_mismatch] = (_rebuild_bundle(bundle;
        declarations=(factory_receipt_record, g2, g3)),
        (factory_receipt_record, g2, g3))
    declaration_receipt_record = _record_with(g1;
        declaration_receipt=_bad_receipt(g1.declaration_receipt,
            G.VNextT0LocalDeclarationReceiptV1))
    cases[:declaration_receipt_mismatch] = (_rebuild_bundle(bundle;
        declarations=(declaration_receipt_record, g2, g3)),
        (declaration_receipt_record, g2, g3))
    cases[:canonical_equality_mismatch] = (_rebuild_bundle(bundle;
        declarations=(source_ref_record, g2, g3)), records)

    wrong_feedback = G.VNextT0LocalFeedbackV1(feedback[1].target_id,
        feedback[1].target_layer, Main._T0L_CANDIDATE,
        G.QualifiedRefV1("local://unknown-target", "v1"), feedback[1].body,
        feedback[1].body_hash)
    cases[:feedback_projection_mismatch] = (_rebuild_bundle(bundle;
        feedback=(wrong_feedback, feedback[2])), records)
    cases[:duplicate_feedback_target] = (_rebuild_bundle(bundle;
        feedback=(feedback[1], feedback[1], feedback[2])), records)
    unknown_feedback = G.VNextT0LocalFeedbackV1("unknown-layer", :G9,
        Main._T0L_CANDIDATE, feedback[1].target_ref, feedback[1].body,
        feedback[1].body_hash)
    cases[:unknown_feedback_layer] = (_rebuild_bundle(bundle;
        feedback=(unknown_feedback, feedback[2])), records)
    present_child = Main._t0l_child_present(:realization)
    cases[:g3_child_present_forbidden] = (_rebuild_bundle(bundle;
        children=(present_child, children[2], children[3])), records)
    cases[:stale_bundle] = (_rebuild_bundle(bundle;
        bundle_hash=G.digest256_text("stale-bundle")), records)
    changed_feedback_bundle = _rebuild_bundle(bundle;
        feedback=(feedback[2], feedback[1]), bundle_hash=G.digest256_text("stale"))
    cases[:bundle_hash_mismatch] = (changed_feedback_bundle, records)
    cases[:bundle_status_invalid] = (_rebuild_bundle(bundle; status=:invalid), records)
    cases[:bundle_errors_present] = (_rebuild_bundle(bundle;
        errors=(:synthetic_error,)), records)
    cases[:prior_bundle_bytes_unchanged] = (cases[:stale_bundle][1], records)
    cases[:prior_bundle_hash_unchanged] = (cases[:stale_bundle][1], records)

    @test Set(keys(cases)) == Set(x.name for x in LOCAL_NEGATIVE_DISPATCH)
    for dispatch in LOCAL_NEGATIVE_DISPATCH
        case_bundle, case_records = cases[dispatch.name]
        _assert_negative(dispatch.name, case_bundle, case_records,
            dispatch.expected_errors)
    end
end

println("UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_STATUS=local_checked_present_or_typed_absent")
println("UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_ACCEPTED=false")
println("UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_T1_T2_CREDIT=false")
println("UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_NEGATIVE_DISPATCH=25")
