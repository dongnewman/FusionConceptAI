using Test
using SHA
using Serialization
using JSON3
using FusionConceptAI

const T2_NEG_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const T2_NEG_SCENARIO = "vnext-t2-native-source-formal-t1-actual-r1"
const T2_NEG_EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
const T2_NEG_DRIVER_VERSION = "independent-actual-negative-r1"
const T2_NEG_CANDIDATE_DRIVER_VERSION = "formal-candidate-driver-r5"

# Load the versioned T2 definitions before typed constants are constructed and
# before _t2_neg_run is compiled.  The fixture include is definition-only; it
# does not build a candidate or prewarm any consumer.
const T2_NEG_REGISTRY_BEFORE = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
include(joinpath(@__DIR__, "..", "VNextT2IdentityReceiptV2",
    "fixture_helpers.jl"))
FusionConceptAI.load_vnext_t2_components_v2!()
const T2_NEG_REGISTRY_AFTER = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
T2_NEG_REGISTRY_BEFORE == T2_NEG_REGISTRY_AFTER ||
    error(:negative_fixture_registry_drift)

const T2_NEG_ZERO_DIGEST = FusionConceptAI.Digest256(repeat("0", 64))
const T2_NEG_EXPECTED_COUNTS =
    FusionConceptAI.VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0)
const T2_NEG_ZERO_COUNTS = FusionConceptAI.VNextT2InvocationCountsV2()

_t2_neg_sha256(bytes) = bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes))))
_t2_neg_digest(label) = FusionConceptAI.Digest256(
    _t2_neg_sha256(Vector{UInt8}(codeunits("vnext-t2-negative/" * label))))

function _t2_neg_verify_raw(path::String, expected::String, label::Symbol)
    bytes = read(path)
    actual = _t2_neg_sha256(bytes)
    actual == lowercase(expected) || error((label, :raw_sha256_mismatch,
        lowercase(expected), actual))
    (bytes=bytes, sha256=actual)
end

function _t2_neg_canonical_artifact(value)
    bytes = Vector{UInt8}(codeunits(FusionConceptAI.canonical_json(value) * "\n"))
    (bytes=bytes, sha256=_t2_neg_sha256(bytes))
end

function _t2_neg_replace(value, field::Symbol, replacement)
    names = fieldnames(typeof(value))
    index = findfirst(==(field), names)
    index === nothing && error((:unknown_negative_fixture_field, field, names))
    values = ntuple(i -> i == index ? replacement : getfield(value, i),
        fieldcount(typeof(value)))
    typeof(value)(values...)
end

function _t2_neg_candidate_receipt(material, manifest_hash, verification_hash)
    t1 = material.t1
    package = material.package
    adapter = material.adapter
    handoff_hash = FusionConceptAI.canonical_hash(
        FusionConceptAI._vnext_t2_t1_admission_handoff_body_v2(
            t1.source.witness, t1.admission_input, material.admission,
            package, adapter, nothing, T2_NEG_SCENARIO,
            FusionConceptAI.VNEXT_T2_UP2_PROFILE_V2))
    (schema="vnext-t2-candidate-t1-admission-receipt-r1",
        evidence_kind=:formal_t1_actual,
        producer_version=T2_NEG_CANDIDATE_DRIVER_VERSION,
        software_acceptance_manifest_sha256=manifest_hash,
        software_acceptance_verification_sha256=verification_hash,
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
        admission_material_hash=handoff_hash,
        package_hash=package.package_hash,
        package_content_hash=
            FusionConceptAI._vnext_t2_t1_package_content_hash_v2(package),
        semantic_identity=package.semantic_identity,
        wire_hash=package.wire.sha256,
        serialized_package_bytes=length(material.package_bytes),
        serialized_package_sha256=material.package_sha256,
        reload_adapter_receipt_hash=FusionConceptAI.canonical_hash(
            FusionConceptAI.semantic_view(adapter)),
        binding_receipt_hash=adapter.binding.receipt_hash,
        scenario=T2_NEG_SCENARIO)
end

function _t2_neg_gate_with(gate;
        candidate_ref=gate.candidate_ref, scenario=gate.scenario,
        witness_hash=gate.witness_hash, package_hash=gate.package_hash,
        semantic_identity=gate.semantic_identity, bundle_hash=gate.bundle_hash,
        wire_hash=gate.wire_hash,
        reload_adapter_receipt_hash=gate.reload_adapter_receipt_hash,
        binding_receipt_hash=gate.binding_receipt_hash,
        parent_commitments=gate.parent_commitments,
        g3_authority_commitment=gate.g3_authority_commitment,
        software_receipt_hash=gate.formal_t1_software_acceptance_receipt_hash,
        candidate_receipt_hash=gate.candidate_t1_admission_receipt_hash,
        evidence_kind=gate.evidence_kind,
        formal_t1_accepted=gate.formal_t1_accepted,
        profile=gate.profile)
    FusionConceptAI.vnext_t2_formal_gate_identity_v2(candidate_ref, scenario,
        witness_hash, package_hash, semantic_identity, bundle_hash, wire_hash,
        reload_adapter_receipt_hash, binding_receipt_hash,
        parent_commitments, g3_authority_commitment,
        software_receipt_hash, candidate_receipt_hash,
        evidence_kind=evidence_kind, formal_t1_accepted=formal_t1_accepted,
        profile=profile)
end

function _t2_neg_input_with(input;
        witness=input.witness, package=input.package, adapter=input.adapter,
        gate=input.formal_gate, scenario=input.scenario, profile=input.profile)
    draft = FusionConceptAI.VNextT2UP2BoundInputV2(witness, package, adapter,
        gate, scenario, profile, T2_NEG_ZERO_DIGEST)
    hash = FusionConceptAI.canonical_hash(
        FusionConceptAI._vnext_t2_bound_input_body_v2(witness, package,
            adapter, gate, scenario, profile))
    _t2_neg_replace(draft, :input_hash, hash)
end

function _t2_neg_rehash_witness(witness)
    _t2_neg_replace(witness, :witness_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_witness_body(witness)))
end

function _t2_neg_rehash_manifest(manifest)
    _t2_neg_replace(manifest, :manifest_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_manifest_body(manifest)))
end

function _t2_neg_refresh_component_manifest(witness)
    source_bundle = FusionConceptAI.canonical_hash((
        domain="vnext-t2-concrete-source-bundle-v3",
        candidate_ref=witness.candidate_ref,
        g1=witness.g1.identity.identity_hash,
        g2=witness.g2.identity.identity_hash,
        g3=witness.g3.identity.identity_hash,
        children=witness.children.identity_hash,
        feedback=witness.feedback.identity_hash))
    manifest = witness.manifest
    for (field, value) in (
            (:parent_bundle_hash, witness.parent_bundle.bundle_hash),
            (:g3_expected_commitment_hash,
                witness.children.expected_commitment.commitment_hash),
            (:g1_identity_hash, witness.g1.identity.identity_hash),
            (:g2_identity_hash, witness.g2.identity.identity_hash),
            (:g3_identity_hash, witness.g3.identity.identity_hash),
            (:children_identity_hash, witness.children.identity_hash),
            (:feedback_identity_hash, witness.feedback.identity_hash),
            (:source_bundle_hash, source_bundle))
        manifest = _t2_neg_replace(manifest, field, value)
    end
    manifest = _t2_neg_rehash_manifest(manifest)
    _t2_neg_rehash_witness(_t2_neg_replace(witness, :manifest, manifest))
end

function _t2_neg_witness_gate_input(input, witness;
        refresh_manifest::Bool=false)
    refreshed = refresh_manifest ?
        _t2_neg_refresh_component_manifest(witness) :
        _t2_neg_rehash_witness(witness)
    gate = _t2_neg_gate_with(input.formal_gate,
        witness_hash=refreshed.witness_hash)
    _t2_neg_input_with(input, witness=refreshed, gate=gate)
end

function _t2_neg_package_fingerprint(package)
    (type=string(typeof(package)), package_hash=package.package_hash,
        package_content_hash=
            FusionConceptAI._vnext_t2_t1_package_content_hash_v2(package),
        semantic_identity=package.semantic_identity,
        bundle_hash=package.bundle_hash, wire_sha256=package.wire.sha256,
        wire_bytes=FusionConceptAI.byte_length(package.wire),
        status=package.status, resolution=package.resolution,
        accepted=package.accepted, claim_ceiling=package.claim_ceiling)
end

function _t2_neg_ledger_fingerprint(ledger)
    ledger === nothing && return nothing
    (type=string(typeof(ledger)), ledger_hash=ledger.ledger_hash,
        input_hash=ledger.input_hash, package_hash=ledger.package_hash,
        counts=FusionConceptAI.semantic_view(ledger.counts),
        receipt_hashes=Tuple(x.identity_hash for x in ledger.receipts),
        status=ledger.status, resolution=ledger.resolution,
        accepted=ledger.accepted, claim_ceiling=ledger.claim_ceiling)
end

function _t2_neg_state(baseline)
    (package=_t2_neg_package_fingerprint(baseline.input.package),
        package_artifact=hasproperty(baseline, :package_artifact) ?
            baseline.package_artifact : nothing,
        ledger=_t2_neg_ledger_fingerprint(baseline.result.ledger))
end

_t2_neg_prop(value, name, default=nothing) =
    hasproperty(value, name) ? getproperty(value, name) : default

function _t2_neg_first_reason(value)
    reason = _t2_neg_prop(value, :reason, nothing)
    reason !== nothing && return reason
    errors = _t2_neg_prop(value, :errors, ())
    isempty(errors) ? nothing : first(errors)
end

function _t2_neg_observe!(stream, case_id::String, value, before, after;
        attacked_input_hash=nothing, note="")
    attempted_trace = _t2_neg_prop(value, :attempted_trace, nothing)
    attempted_counts = attempted_trace === nothing ? nothing :
        FusionConceptAI.semantic_view(attempted_trace.counts)
    committed_counts = _t2_neg_prop(value, :committed_counts, nothing)
    committed_projection = committed_counts === nothing ? nothing :
        FusionConceptAI.semantic_view(committed_counts)
    row = (schema="vnext-t2-independent-negative-observation-r1",
        case_id=case_id, value_type=string(typeof(value)),
        status=_t2_neg_prop(value, :status, nothing),
        resolution=_t2_neg_prop(value, :resolution, nothing),
        first_reason=_t2_neg_first_reason(value),
        reason=_t2_neg_prop(value, :reason, nothing),
        errors=_t2_neg_prop(value, :errors, ()),
        gaps=_t2_neg_prop(value, :gaps, ()),
        committed=_t2_neg_prop(value, :committed, nothing),
        ledger=_t2_neg_ledger_fingerprint(
            _t2_neg_prop(value, :ledger, nothing)),
        attempted_counts=attempted_counts,
        committed_counts=committed_projection,
        attacked_input_hash=attacked_input_hash,
        package_fingerprint_before=before.package,
        package_fingerprint_after=after.package,
        package_artifact_before=before.package_artifact,
        package_artifact_after=after.package_artifact,
        prior_ledger_fingerprint_before=before.ledger,
        prior_ledger_fingerprint_after=after.ledger,
        note=note)
    line = FusionConceptAI.canonical_json(row)
    println(stream, line)
    flush(stream)
    println("VNEXT_T2_NEGATIVE_ACTUAL=" * line)
    flush(stdout)
    row
end

function _t2_neg_run_zero!(stream, case_id, input, expected_reason, baseline)
    before = _t2_neg_state(baseline)
    actual = try
        FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(input,
            prior_ledger=baseline.result.ledger)
    catch error
        error
    end
    after = _t2_neg_state(baseline)
    _t2_neg_observe!(stream, case_id, actual, before, after,
        attacked_input_hash=input.input_hash)
    @test actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2
    actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2 ||
        return actual
    @test actual.status === :fail_closed
    @test actual.resolution === :none
    @test actual.reason === expected_reason
    @test !actual.committed
    @test actual.ledger === baseline.result.ledger
    @test actual.committed_counts == baseline.result.ledger.counts
    @test isempty(actual.attempted_trace.events)
    @test actual.attempted_trace.counts == T2_NEG_ZERO_COUNTS
    @test before == after
    actual
end

function _t2_neg_run_build_zero!(stream, case_id, build, expected_status,
        expected_resolution, expected_reason, baseline)
    before = _t2_neg_state(baseline)
    actual = try
        FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(build,
            prior_ledger=baseline.result.ledger)
    catch error
        error
    end
    after = _t2_neg_state(baseline)
    _t2_neg_observe!(stream, case_id, actual, before, after,
        attacked_input_hash=build.input_hash,
        note="source-backed T1 admission handoff boundary")
    @test build.status === expected_status
    @test build.resolution === expected_resolution
    @test build.reason === expected_reason
    @test actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2
    actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2 ||
        return actual
    @test actual.status === expected_status
    @test actual.resolution === expected_resolution
    @test actual.reason === expected_reason
    @test !actual.committed
    @test actual.ledger === baseline.result.ledger
    @test actual.committed_counts == baseline.result.ledger.counts
    @test isempty(actual.attempted_trace.events)
    @test actual.attempted_trace.counts == T2_NEG_ZERO_COUNTS
    @test before == after
    actual
end

function _t2_neg_source_carrier_input(input, mode::Symbol)
    witness = input.witness
    record = witness.g1.record
    original = record.source_bytes
    changed = copy(original.bytes)
    !isempty(changed) || error(:source_carrier_fixture_empty)
    changed[1] = xor(changed[1], 0x01)
    carrier = mode === :bytes_only ?
        FusionConceptAI.VNextT0LocalBytesV1(changed, original.sha256) :
        mode === :hash_only ?
        FusionConceptAI.VNextT0LocalBytesV1(original.bytes,
            _t2_neg_digest("source-hash-only")) :
        mode === :bytes_rehashed ?
        FusionConceptAI.VNextT0LocalBytesV1(changed,
            FusionConceptAI.Digest256(_t2_neg_sha256(changed))) :
        mode === :zero ?
        FusionConceptAI.VNextT0LocalBytesV1(UInt8[], T2_NEG_ZERO_DIGEST) :
        error((:unknown_source_carrier_mode, mode))
    attacked_record = _t2_neg_replace(record, :source_bytes, carrier)
    attacked_g1 = _t2_neg_replace(witness.g1, :record, attacked_record)
    attacked_witness = _t2_neg_replace(witness, :g1, attacked_g1)
    _t2_neg_witness_gate_input(input, attacked_witness)
end

function _t2_neg_source_edit_no_rebuild_input(input)
    witness = input.witness
    record = witness.g1.record
    changed = copy(record.source_bytes.bytes)
    changed[end] = xor(changed[end], 0x01)
    carrier = FusionConceptAI.VNextT0LocalBytesV1(changed,
        FusionConceptAI.Digest256(_t2_neg_sha256(changed)))
    attacked_record = _t2_neg_replace(record, :source_bytes, carrier)
    attacked_g1 = _t2_neg_replace(witness.g1, :record, attacked_record)
    stale_witness = _t2_neg_replace(witness, :g1, attacked_g1)
    _t2_neg_input_with(input, witness=stale_witness)
end

function _t2_neg_axis_input(input, label::String)
    witness = input.witness
    identity = witness.g1.identity
    axes = Base.setindex(identity.source_axes,
        FusionConceptAI.QualifiedRefV1("formal-negative://axis/" * label,
            "v5"), 1)
    draft = _t2_neg_replace(identity, :source_axes, axes)
    attacked_identity = _t2_neg_replace(draft, :identity_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_layer_identity_body(draft)))
    attacked_g1 = _t2_neg_replace(witness.g1, :identity, attacked_identity)
    _t2_neg_witness_gate_input(input,
        _t2_neg_replace(witness, :g1, attacked_g1), refresh_manifest=true)
end

function _t2_neg_children_input(input, label::String; foreign::Bool)
    witness = input.witness
    children = witness.children
    t0_children = if foreign
        child = first(children.t0_children)
        changed = _t2_neg_replace(child, :candidate_ref,
            FusionConceptAI.QualifiedRefV1(
                "formal-negative://child/" * label, "v5"))
        Base.setindex(children.t0_children, changed, 1)
    else
        (children.t0_children[2], children.t0_children[1],
            children.t0_children[3])
    end
    draft = _t2_neg_replace(children, :t0_children, t0_children)
    attacked_children = _t2_neg_replace(draft, :identity_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_children_body(draft)))
    _t2_neg_witness_gate_input(input,
        _t2_neg_replace(witness, :children, attacked_children),
        refresh_manifest=true)
end

function _t2_neg_feedback_input(input, label::String; foreign::Bool)
    witness = input.witness
    feedback = witness.feedback
    item = first(feedback.t0_feedback)
    changed = foreign ? _t2_neg_replace(item, :target_ref,
        FusionConceptAI.QualifiedRefV1(
            "formal-negative://feedback/" * label, "v5")) :
        _t2_neg_replace(item, :body_hash,
            _t2_neg_digest("feedback-" * label))
    items = Base.setindex(feedback.t0_feedback, changed, 1)
    draft = _t2_neg_replace(feedback, :t0_feedback, items)
    attacked_feedback = _t2_neg_replace(draft, :identity_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_feedback_body(draft)))
    _t2_neg_witness_gate_input(input,
        _t2_neg_replace(witness, :feedback, attacked_feedback),
        refresh_manifest=true)
end

function _t2_neg_t0_input(input, label::String)
    witness = input.witness
    draft = _t2_neg_replace(witness.manifest, :t0_bundle_hash,
        _t2_neg_digest("t0-" * label))
    manifest = _t2_neg_rehash_manifest(draft)
    _t2_neg_witness_gate_input(input,
        _t2_neg_replace(witness, :manifest, manifest))
end

function _t2_neg_parent_input(input, chain, label::String; foreign::Bool)
    witness = input.witness
    attacked_witness = if foreign
        parent = witness.parent_bundle
        g1 = _t2_neg_replace(parent.g1, :authority_commitment,
            _t2_neg_digest("parent-" * label))
        draft = _t2_neg_replace(parent, :g1, g1)
        parent2 = _t2_neg_replace(draft, :bundle_hash,
            FusionConceptAI.canonical_hash((candidate_ref=draft.candidate_ref,
                g1=draft.g1, g2=draft.g2)))
        _t2_neg_replace(witness, :parent_bundle, parent2)
    else
        t2_witness_with_t1_commitments_as_source_parent(chain)
    end
    _t2_neg_witness_gate_input(input, attacked_witness,
        refresh_manifest=true)
end

function _t2_neg_coupling_input(input)
    witness = input.witness
    coupling = witness.coupling
    draft = typeof(coupling)(:fail_closed, :none,
        (:declared_source_child_contradiction,), coupling.gaps,
        T2_NEG_ZERO_DIGEST)
    attacked_coupling = _t2_neg_replace(draft, :diagnostic_hash,
        FusionConceptAI.canonical_hash(
            FusionConceptAI._vnext_t2_v3_coupling_body(draft)))
    _t2_neg_witness_gate_input(input,
        _t2_neg_replace(witness, :coupling, attacked_coupling))
end

function _t2_neg_require_baseline!(stream, build, result, material,
        package_hash_before)
    candidate = (input=build.input, result=result,
        package_artifact=(bytes=length(material.package_bytes),
            sha256=material.package_sha256))
    before = _t2_neg_state(candidate)
    after = _t2_neg_state(candidate)
    _t2_neg_observe!(stream, "ACTUAL_BASELINE_POSITIVE", result,
        before, after, attacked_input_hash=build.input.input_hash,
        note="actual formal T1 gate and producer package artifact")
    @test build.status === :prepared_not_executed
    @test build.resolution === :terminal_deferred
    @test build.input isa FusionConceptAI.VNextT2UP2BoundInputV2
    input_validation =
        FusionConceptAI.vnext_t2_up2_validate_input_v2(build.input)
    @test input_validation.status === :valid
    @test input_validation.reason === :none
    @test result.status === :complete_contract_receipts
    @test result.resolution === :terminal_deferred
    @test result.reason === :none
    @test result.committed
    @test result.ledger isa FusionConceptAI.VNextT2ReceiptLedgerV2
    @test result.attempted_trace.counts == T2_NEG_EXPECTED_COUNTS
    @test result.ledger.counts == T2_NEG_EXPECTED_COUNTS
    @test result.ledger.input_hash == build.input.input_hash
    @test result.ledger.package_hash == build.input.package.package_hash
    @test Tuple(x.consumer_id for x in result.ledger.receipts) ==
        FusionConceptAI.VNEXT_T2_CONSUMER_ORDER_V2
    @test Tuple(x.invocation_count for x in result.ledger.receipts) ==
        (1, 1, 1, 1, 1)
    @test Tuple(x.consumer_id for x in result.attempted_trace.events) ==
        FusionConceptAI.VNEXT_T2_CONSUMER_ORDER_V2
    @test build.input.formal_gate.evidence_kind === :formal_t1_actual
    @test build.input.formal_gate.formal_t1_accepted
    @test material.package === build.input.package
    @test material.admission.status === :prepared_not_executed
    @test material.admission.resolution === :terminal_deferred
    @test material.admission.accepted === false
    @test material.admission.claim_ceiling === :contract_only
    @test material.admission.package === material.t1.admission.package
    @test material.package.package_hash ==
        material.t1.admission.package.package_hash
    @test material.candidate_receipt.producer_t1_admission_invocation_count == 1
    @test material.candidate_receipt.handoff_revalidation_required
    @test material.candidate_receipt.producer_t1_admission_invocation_count +
        (build.status === :prepared_not_executed ? 1 : 0) == 2
    @test build.input.package.parent_commitments == material.t1.t1_parents ==
        build.input.formal_gate.parent_commitments
    source_parent_commitments = (
        material.t1.source.parent.output.g1.authority_commitment,
        material.t1.source.parent.output.g2.authority_commitment)
    @test source_parent_commitments != material.t1.t1_parents
    @test FusionConceptAI.verify_present_t0_local_parent_bundle_v1(
        build.input.witness.parent_bundle,
        FusionConceptAI.t0_parent_authority_commitment_v1(
            build.input.witness.g1.record),
        FusionConceptAI.t0_parent_authority_commitment_v1(
            build.input.witness.g2.record))
    @test build.input.witness.children.expected_commitment.commitment_hash ==
        build.input.formal_gate.g3_authority_commitment
    @test build.input.formal_gate.formal_t1_software_acceptance_receipt_hash !=
        T2_NEG_ZERO_DIGEST
    @test build.input.formal_gate.candidate_t1_admission_receipt_hash !=
        T2_NEG_ZERO_DIGEST
    recheck_projection = FusionConceptAI._vnext_t2_t1_recheck_projection_v2(
        material.t1.admission_input.t0_recheck)
    @test keys(recheck_projection) == (:domain, :status, :resolution,
        :accepted, :claim_ceiling, :output, :errors, :reasons,
        :prior_bundle_bytes, :prior_bundle_sha256)
    @test keys(recheck_projection.output) == (:domain, :candidate_ref,
        :bundle_hash, :declarations, :children, :feedback,
        :g3_children_deferred)
    @test recheck_projection.status ==
        material.t1.admission_input.t0_recheck.status
    @test recheck_projection.output.declarations ==
        material.t1.admission_input.t0_recheck.output.declarations
    @test recheck_projection.prior_bundle_bytes ===
        material.t1.admission_input.t0_recheck.prior_bundle_bytes
    @test FusionConceptAI._vnext_t2_t1_recheck_projection_v2(nothing) ==
        (domain="vnext-t2-t1-recheck-v2/nothing",)
    typed_absent_output =
        FusionConceptAI.VNextAuthorityRecheckLocalV2TypedAbsent(
            material.t1.admission_input.candidate_ref,
            material.t1.admission_input.transport.bundle_hash,
            (:fixture_typed_absence,), true)
    typed_absent_projection =
        FusionConceptAI._vnext_t2_t1_recheck_output_projection_v2(
            typed_absent_output)
    @test keys(typed_absent_projection) == (:domain, :candidate_ref,
        :bundle_hash, :reasons, :g3_children_deferred)
    @test build.input.witness.g1.declaration isa
        FusionConceptAI.G1DiffusionDeclarationV1
    @test build.input.witness.g2.declaration isa FusionConceptAI.G2MBDeclarationV1
    @test build.input.witness.g3.declaration isa FusionConceptAI.G3SFDeclarationV1
    @test result.ledger.receipts[3].status === :typed_absent
    @test result.ledger.receipts[3].resolution === :terminal_deferred
    @test result.ledger.receipts[4].status === :typed_absent
    @test result.ledger.receipts[4].resolution === :terminal_deferred
    @test result.ledger.accepted === false
    @test result.ledger.claim_ceiling === :contract_only
    @test build.input.package.package_hash == package_hash_before
    @test FusionConceptAI.vnext_t1_package_v2_validate(
        build.input.package) === nothing
    candidate
end

function _t2_neg_fault_case!(stream, baseline, stage, expected_reason,
        expected_order)
    before = _t2_neg_state(baseline)
    actual = try
        FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(baseline.input,
            fault_after_stage=stage)
    catch error
        error
    end
    after = _t2_neg_state(baseline)
    case_id = "FAULT_" * uppercase(String(stage))
    _t2_neg_observe!(stream, case_id, actual, before, after,
        attacked_input_hash=baseline.input.input_hash)
    @test actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2
    actual isa FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2 ||
        return actual
    @test actual.status === :program_exception
    @test actual.resolution === :none
    @test actual.reason === expected_reason
    @test !actual.committed
    @test actual.ledger === nothing
    @test actual.committed_counts == T2_NEG_ZERO_COUNTS
    @test Tuple(x.consumer_id for x in actual.attempted_trace.events) ==
        expected_order
    expected_count = length(expected_order)
    expected_counts = FusionConceptAI.VNextT2InvocationCountsV2(
        expected_count >= 1 ? 1 : 0,
        expected_count >= 2 ? 1 : 0,
        expected_count >= 3 ? 1 : 0,
        expected_count >= 4 ? 1 : 0,
        expected_count >= 5 ? 1 : 0,
        0, 0, 0)
    @test actual.attempted_trace.counts == expected_counts
    @test before == after
    actual
end

function _t2_neg_run(manifest_path, manifest_sha, verification_path,
        verification_sha, candidate_path, candidate_sha, package_path,
        package_sha, output_dir)
    mkpath(output_dir)
    observations_path = joinpath(output_dir, "observations.jsonl")
    ispath(observations_path) && error(:negative_observations_already_exist)
    summary_path = joinpath(output_dir, "summary.json")
    ispath(summary_path) && error(:negative_summary_already_exists)

    manifest_raw = _t2_neg_verify_raw(manifest_path, manifest_sha,
        :software_manifest)
    verification_raw = _t2_neg_verify_raw(verification_path, verification_sha,
        :software_verification)
    candidate_raw = _t2_neg_verify_raw(candidate_path, candidate_sha,
        :candidate_t1_admission_receipt)
    package_raw = _t2_neg_verify_raw(package_path, package_sha,
        :producer_candidate_package)
    manifest_doc = JSON3.read(String(manifest_raw.bytes))
    verification_doc = JSON3.read(String(verification_raw.bytes))
    String(manifest_doc.schema) ==
        "vnext-t1-software-acceptance-manifest-r1" ||
        error(:software_manifest_schema_mismatch)
    manifest_doc.formal_t1_software_accepted === true ||
        error(:software_manifest_not_accepted)
    String(manifest_doc.repository_head) == T2_NEG_EXPECTED_HEAD ||
        error(:software_manifest_head_mismatch)
    String(verification_doc.schema) ==
        "vnext-t1-software-acceptance-verification-r1" ||
        error(:software_verification_schema_mismatch)
    verification_doc.verified === true || error(:software_verification_failed)
    String(verification_doc.manifest_sha256) == lowercase(manifest_sha) ||
        error(:software_verification_manifest_mismatch)

    t1 = t2_t1_admission_fixture()
    package = Serialization.deserialize(IOBuffer(copy(package_raw.bytes)))
    package isa FusionConceptAI.CandidateStatePackageV5NextV2 ||
        error(:producer_candidate_package_type_invalid)
    FusionConceptAI._vnext_t2_t1_package_content_equal_v2(
        t1.admission.package, package) ||
        error(:producer_candidate_package_expected_admission_mismatch)
    FusionConceptAI.vnext_t1_package_v2_validate(package) === nothing ||
        error(:producer_candidate_package_invalid)
    base_adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package)
    base_adapter.input === nothing && error(:negative_adapter_input_absent)
    adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package,
        (base_adapter.input,))
    adapter.binding === nothing && error(:negative_binding_absent)
    material = (t1=t1, admission=t1.admission, package=package,
        adapter=adapter, package_bytes=package_raw.bytes,
        package_sha256=package_raw.sha256)
    candidate_receipt = _t2_neg_candidate_receipt(material,
        FusionConceptAI.Digest256(lowercase(manifest_sha)),
        FusionConceptAI.Digest256(lowercase(verification_sha)))
    material = merge(material, (candidate_receipt=candidate_receipt,))
    expected_candidate = _t2_neg_canonical_artifact(candidate_receipt)
    expected_candidate.sha256 == candidate_raw.sha256 ||
        error((:candidate_receipt_identity_mismatch,
            expected_candidate.sha256, candidate_raw.sha256))
    expected_candidate.bytes == candidate_raw.bytes ||
        error(:candidate_receipt_bytes_mismatch)

    gate = FusionConceptAI.vnext_t2_formal_gate_identity_v2(
        package.candidate_ref, T2_NEG_SCENARIO,
        t1.source.witness.witness_hash, package.package_hash,
        package.semantic_identity, package.bundle_hash, package.wire.sha256,
        FusionConceptAI.canonical_hash(FusionConceptAI.semantic_view(adapter)),
        adapter.binding.receipt_hash, t1.t1_parents,
        t1.source.expected.commitment_hash,
        FusionConceptAI.Digest256(lowercase(manifest_sha)),
        FusionConceptAI.Digest256(candidate_raw.sha256),
        evidence_kind=:formal_t1_actual, formal_t1_accepted=true)
    build = FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
        t1.source.witness, t1.admission_input, t1.admission, package,
        adapter, gate, scenario=T2_NEG_SCENARIO)
    package_hash_before = build.input.package.package_hash
    result = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(build)

    observed_case_ids = String[]
    test_error = nothing
    stream = open(observations_path, "w")
    wire_before = _t2_neg_sha256(FusionConceptAI.copy_bytes(package.wire))
    try
        @testset "VNext T2 actual formal independent negatives" begin
            baseline = _t2_neg_require_baseline!(stream, build, result,
                material, package_hash_before)
            push!(observed_case_ids, "ACTUAL_BASELINE_POSITIVE")

            for (case_id, mode) in (("SRC_BYTES_ONLY", :bytes_only),
                    ("SRC_HASH_ONLY", :hash_only),
                    ("SRC_BYTES_REHASHED", :bytes_rehashed),
                    ("SRC_ZERO_BYTES_HASH", :zero))
                attacked = _t2_neg_source_carrier_input(baseline.input, mode)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_source_carrier_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            source_edit = _t2_neg_source_edit_no_rebuild_input(baseline.input)
            _t2_neg_run_zero!(stream, "SOURCE_EDIT_NO_REBUILD", source_edit,
                :t2_preflight_source_edit_without_rebuild, baseline)
            push!(observed_case_ids, "SOURCE_EDIT_NO_REBUILD")

            wire_gate = _t2_neg_gate_with(baseline.input.formal_gate,
                wire_hash=_t2_neg_digest("wire-stale"))
            wire_input = _t2_neg_input_with(baseline.input, gate=wire_gate)
            _t2_neg_run_zero!(stream, "WIRE_GATE_STALE", wire_input,
                :t2_preflight_wire_hash_mismatch, baseline)
            push!(observed_case_ids, "WIRE_GATE_STALE")

            semantic_gate = _t2_neg_gate_with(baseline.input.formal_gate,
                semantic_identity=_t2_neg_digest("semantic-foreign"))
            semantic_input = _t2_neg_input_with(baseline.input,
                gate=semantic_gate)
            _t2_neg_run_zero!(stream, "SEMANTIC_GATE_FOREIGN", semantic_input,
                :t2_preflight_semantic_identity_mismatch, baseline)
            push!(observed_case_ids, "SEMANTIC_GATE_FOREIGN")

            package_gate = _t2_neg_gate_with(baseline.input.formal_gate,
                package_hash=_t2_neg_digest("package-foreign"))
            package_input = _t2_neg_input_with(baseline.input,
                gate=package_gate)
            _t2_neg_run_zero!(stream, "PACKAGE_GATE_FOREIGN", package_input,
                :t2_preflight_package_hash_mismatch, baseline)
            push!(observed_case_ids, "PACKAGE_GATE_FOREIGN")

            for label in ("stale", "foreign")
                candidate = FusionConceptAI.QualifiedRefV1(
                    "formal-negative://candidate/" * label, "v5")
                candidate_gate = _t2_neg_gate_with(
                    baseline.input.formal_gate, candidate_ref=candidate)
                candidate_input = _t2_neg_input_with(baseline.input,
                    gate=candidate_gate)
                case_id = "CANDIDATE_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, candidate_input,
                    :t2_preflight_candidate_ref_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            for label in ("stale", "foreign")
                attacked = _t2_neg_t0_input(baseline.input, label)
                case_id = "T0_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_t0_bundle_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            for label in ("stale", "foreign")
                attacked = _t2_neg_axis_input(baseline.input, label)
                case_id = "AXIS_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_axis_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            for (label, foreign) in (("stale", false), ("foreign", true))
                attacked = _t2_neg_children_input(baseline.input, label,
                    foreign=foreign)
                case_id = "CHILD_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_child_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            for (label, foreign) in (("stale", false), ("foreign", true))
                attacked = _t2_neg_feedback_input(baseline.input, label,
                    foreign=foreign)
                case_id = "FEEDBACK_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_feedback_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            chain_view = (source=t1.source, t1_parents=t1.t1_parents,
                gate=baseline.input.formal_gate)
            for (label, foreign) in (("stale", false), ("foreign", true))
                attacked = _t2_neg_parent_input(baseline.input, chain_view,
                    label, foreign=foreign)
                case_id = "PARENT_" * uppercase(label)
                if label == "stale"
                    stale_parent_build = FusionConceptAI.
                        vnext_t2_up2_input_from_t1_admission_v2(
                            attacked.witness, t1.admission_input, t1.admission,
                            package, adapter, attacked.formal_gate,
                            scenario=T2_NEG_SCENARIO)
                    _t2_neg_run_build_zero!(stream, case_id,
                        stale_parent_build, :fail_closed, :none,
                        :t2_preflight_parent_commitment_mismatch, baseline)
                    @test attacked.witness.parent_bundle.g1.
                        authority_commitment == t1.t1_parents[1]
                    @test !FusionConceptAI.
                        verify_present_t0_local_parent_bundle_v1(
                            attacked.witness.parent_bundle,
                            FusionConceptAI.t0_parent_authority_commitment_v1(
                                attacked.witness.g1.record),
                            FusionConceptAI.t0_parent_authority_commitment_v1(
                                attacked.witness.g2.record))
                else
                    _t2_neg_run_zero!(stream, case_id, attacked,
                        :t2_preflight_parent_commitment_mismatch, baseline)
                end
                push!(observed_case_ids, case_id)
            end

            for label in ("stale", "foreign")
                g3_gate = _t2_neg_gate_with(baseline.input.formal_gate,
                    g3_authority_commitment=_t2_neg_digest("g3-" * label))
                attacked = _t2_neg_input_with(baseline.input, gate=g3_gate)
                case_id = "G3_" * uppercase(label)
                _t2_neg_run_zero!(stream, case_id, attacked,
                    :t2_preflight_g3_authority_mismatch, baseline)
                push!(observed_case_ids, case_id)
            end

            foreign_scenario = _t2_neg_input_with(baseline.input,
                scenario="vnext-t2-foreign-scenario-negative-r1")
            _t2_neg_run_zero!(stream, "ACTUAL_FOREIGN_SCENARIO",
                foreign_scenario, :t2_preflight_scenario_mismatch, baseline)
            push!(observed_case_ids, "ACTUAL_FOREIGN_SCENARIO")

            absent_build = FusionConceptAI.vnext_t2_up2_input_from_t1_v2(
                nothing, package, adapter, baseline.input.formal_gate)
            before = _t2_neg_state(baseline)
            absent = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                absent_build, prior_ledger=baseline.result.ledger)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_TYPED_ABSENCE", absent,
                before, after, attacked_input_hash=absent_build.input_hash)
            @test absent.status === :typed_absent
            @test absent.resolution === :terminal_deferred
            @test !absent.committed
            @test absent.ledger === baseline.result.ledger
            @test absent.committed_counts == baseline.result.ledger.counts
            @test isempty(absent.attempted_trace.events)
            @test absent.attempted_trace.counts == T2_NEG_ZERO_COUNTS
            @test before == after
            push!(observed_case_ids, "ACTUAL_TYPED_ABSENCE")

            rejected_gate = _t2_neg_gate_with(baseline.input.formal_gate,
                software_receipt_hash=T2_NEG_ZERO_DIGEST,
                candidate_receipt_hash=T2_NEG_ZERO_DIGEST,
                formal_t1_accepted=false)
            rejected_build =
                FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
                    t1.source.witness, t1.admission_input, t1.admission,
                    package, adapter, rejected_gate, scenario=T2_NEG_SCENARIO)
            _t2_neg_run_build_zero!(stream,
                "ACTUAL_FORMAL_GATE_REJECTION", rejected_build,
                :fail_closed, :none,
                :t2_preflight_formal_t1_not_accepted, baseline)
            @test rejected_gate.formal_t1_software_acceptance_receipt_hash ==
                T2_NEG_ZERO_DIGEST
            @test rejected_gate.candidate_t1_admission_receipt_hash ==
                T2_NEG_ZERO_DIGEST
            push!(observed_case_ids, "ACTUAL_FORMAL_GATE_REJECTION")

            no_prior_before = _t2_neg_state(baseline)
            rejected_without_prior = try
                FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                    rejected_build)
            catch error
                error
            end
            no_prior_after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream,
                "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
                rejected_without_prior, no_prior_before, no_prior_after,
                attacked_input_hash=rejected_build.input_hash,
                note="unaccepted formal gate without a prior committed ledger")
            @test rejected_without_prior isa
                FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2
            if rejected_without_prior isa
                    FusionConceptAI.VNextT2IdentityReceiptIntegrationResultV2
                @test rejected_without_prior.status === :fail_closed
                @test rejected_without_prior.resolution === :none
                @test rejected_without_prior.reason ===
                    :t2_preflight_formal_t1_not_accepted
                @test !rejected_without_prior.committed
                @test rejected_without_prior.ledger === nothing
                @test rejected_without_prior.committed_counts ==
                    T2_NEG_ZERO_COUNTS
                @test isempty(rejected_without_prior.attempted_trace.events)
                @test rejected_without_prior.attempted_trace.counts ==
                    T2_NEG_ZERO_COUNTS
            end
            @test no_prior_before == no_prior_after
            push!(observed_case_ids,
                "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR")

            before = _t2_neg_state(baseline)
            duplicate = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                baseline.input, prior_ledger=baseline.result.ledger)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_DUPLICATE_INVOCATION",
                duplicate, before, after,
                attacked_input_hash=baseline.input.input_hash)
            @test duplicate.status === :fail_closed
            @test duplicate.reason === :t2_preflight_duplicate_invocation
            @test !duplicate.committed
            @test duplicate.ledger === baseline.result.ledger
            @test duplicate.committed_counts == baseline.result.ledger.counts
            @test isempty(duplicate.attempted_trace.events)
            @test before == after
            push!(observed_case_ids, "ACTUAL_DUPLICATE_INVOCATION")

            for (stage, reason, order) in (
                    (:e0, :e0_program_exception, (:E0,)),
                    (:gi1a, :gi1a_program_exception, (:E0, :GI1A)),
                    (:e1, :e1_program_exception, (:E0, :GI1A, :E1)),
                    (:e2, :e2_program_exception, (:E0, :GI1A, :E1, :E2)),
                    (:up2, :up2_program_exception,
                        (:E0, :GI1A, :E1, :E2, :UP2_N10)))
                _t2_neg_fault_case!(stream, baseline, stage, reason, order)
                push!(observed_case_ids,
                    "FAULT_" * uppercase(String(stage)))
            end

            projection = FusionConceptAI.n10_identity_projection_from_a(
                baseline.input)
            projection_validation =
                FusionConceptAI.vnext_t2_validate_identity_receipt_v2(
                    projection)
            before = _t2_neg_state(baseline)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_N10_BASELINE",
                projection_validation, before, after,
                attacked_input_hash=baseline.input.input_hash,
                note="actual formal N10 projection before row attacks")
            @test projection_validation.status === :valid
            @test projection_validation.resolution === :terminal_deferred
            @test Tuple(x.row_id for x in projection.fields) ==
                FusionConceptAI.VNEXT_T2_IDENTITY_ROW_IDS_V2
            @test projection.gaps == (:legacy_migration_provenance_absent,)
            @test projection.fields[1].original_value.value ==
                FusionConceptAI.g1_diffusion_schema_hash_v1()
            @test projection.fields[2].original_value.value ==
                FusionConceptAI.g2mb_canonicalization_hash_v1()
            @test projection.fields[3].original_value.child_contract_ref ==
                baseline.input.witness.children.binding_state.source_payload.child_contract_ref
            @test projection.fields[4].authoritative_value.value ==
                FusionConceptAI.vnext_t1_package_v2_manifest_hash(
                    baseline.input.package)
            @test projection.fields[5].original_value.binding_receipt_hash ==
                baseline.input.adapter.binding.receipt_hash
            @test before == after
            push!(observed_case_ids, "ACTUAL_N10_BASELINE")
            reasons = (
                :up2_n10_01_g1_schema_descriptor_mismatch,
                :up2_n10_02_g2_canonicalization_descriptor_mismatch,
                :up2_n10_03_g3_binding_child_identity_mismatch,
                :up2_n10_04_t1_package_hash_mismatch,
                :up2_n10_05_reload_binding_identity_mismatch)
            for (row_id, expected_reason) in zip(
                    FusionConceptAI.VNEXT_T2_IDENTITY_ROW_IDS_V2, reasons)
                attacked = FusionConceptAI.vnext_t2_identity_projection_attack_v2(
                    projection, row_id)
                before = _t2_neg_state(baseline)
                rejected = FusionConceptAI.vnext_t2_validate_identity_receipt_v2(
                    attacked)
                after = _t2_neg_state(baseline)
                case_id = "ACTUAL_N10_" * uppercase(String(row_id))
                _t2_neg_observe!(stream, case_id, rejected, before, after,
                    attacked_input_hash=baseline.input.input_hash,
                    note="direct N10 validation from actual formal input")
                @test attacked.projection_hash != projection.projection_hash
                @test rejected.status === :fail_closed
                @test rejected.resolution === :none
                @test rejected.reason === expected_reason
                @test rejected.row_id === row_id
                @test before == after
                push!(observed_case_ids, case_id)
            end
            projection_io = IOBuffer()
            Serialization.serialize(projection_io, projection)
            projection_reload = Serialization.deserialize(IOBuffer(
                take!(projection_io)))
            @test projection_reload.projection_hash ==
                projection.projection_hash
            @test FusionConceptAI.vnext_t2_validate_identity_receipt_v2(
                projection_reload).status === :valid

            coupling_input = _t2_neg_coupling_input(baseline.input)
            before = _t2_neg_state(baseline)
            coupling = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                coupling_input, prior_ledger=baseline.result.ledger)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION",
                coupling, before, after,
                attacked_input_hash=coupling_input.input_hash,
                note="formal diagnostic mutation; distinct from the natural producer contradiction")
            @test coupling.status === :fail_closed
            @test coupling.reason === :e2_declared_source_child_contradiction
            @test !coupling.committed
            @test coupling.ledger === baseline.result.ledger
            @test coupling.committed_counts == baseline.result.ledger.counts
            @test Tuple(x.consumer_id for x in
                coupling.attempted_trace.events) == (:E0, :GI1A, :E1, :E2)
            @test coupling.attempted_trace.counts ==
                FusionConceptAI.VNextT2InvocationCountsV2(
                    1, 1, 1, 1, 0, 0, 0, 0)
            @test before == after
            push!(observed_case_ids,
                "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION")

            source_parent_commitments = (
                t1.source.parent.output.g1.authority_commitment,
                t1.source.parent.output.g2.authority_commitment)
            mixed_admission_input = FusionConceptAI.VNextT1AdmissionInputV2(
                t1.admission_input.candidate_ref,
                t1.admission_input.transport,
                t1.admission_input.t0_recheck,
                source_parent_commitments,
                t1.admission_input.g3_expected_commitment,
                t1.admission_input.g3_authority)
            mixed_admission = FusionConceptAI.vnext_t1_admit_v2(
                mixed_admission_input)
            mixed_build = FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
                t1.source.witness, mixed_admission_input, mixed_admission,
                nothing, nothing, nothing,
                scenario="vnext-t2-mixed-parent-domain-negative-r1")
            before = _t2_neg_state(baseline)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_T1_PARENT_DOMAIN_INPUT",
                mixed_admission, before, after,
                attacked_input_hash=mixed_build.input_hash,
                note="observe T1 parent-domain rejection before T2 assertions")
            @test mixed_admission.status === :fail_closed
            @test mixed_admission.resolution === :none
            @test mixed_admission.package === nothing
            @test mixed_admission.errors == (:parent_commitment_mismatch,)
            _t2_neg_run_build_zero!(stream,
                "ACTUAL_T1_PARENT_DOMAIN_MISMATCH", mixed_build,
                :fail_closed, :none,
                :t2_preflight_t1_admission_input_mismatch, baseline)
            push!(observed_case_ids, "ACTUAL_T1_PARENT_DOMAIN_MISMATCH")

            missing_admission_input = FusionConceptAI.VNextT1AdmissionInputV2(
                t1.admission_input.candidate_ref, nothing, nothing,
                t1.t1_parents, t1.admission_input.g3_expected_commitment,
                t1.admission_input.g3_authority)
            missing_admission = FusionConceptAI.vnext_t1_admit_v2(
                missing_admission_input)
            missing_build = FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
                t1.source.witness, missing_admission_input,
                missing_admission, nothing, nothing, nothing,
                scenario="vnext-t2-missing-admission-negative-r1")
            before = _t2_neg_state(baseline)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_T1_ABSENCE_INPUT",
                missing_admission, before, after,
                attacked_input_hash=missing_build.input_hash,
                note="observe typed T1 absence before T2 assertions")
            @test missing_admission.status === :terminal_deferred
            @test missing_admission.resolution === :terminal_deferred
            @test missing_admission.gaps == (:t0_transport_required,)
            _t2_neg_run_build_zero!(stream, "ACTUAL_T1_ABSENCE_HANDOFF",
                missing_build, :typed_absent, :terminal_deferred,
                :t2_preflight_t1_admission_absent, baseline)
            push!(observed_case_ids, "ACTUAL_T1_ABSENCE_HANDOFF")

            malformed_bytes = FusionConceptAI.copy_bytes(
                t1.admission_input.t0_recheck.prior_bundle_bytes)
            malformed_bytes[1] = xor(malformed_bytes[1], 0x01)
            malformed_recheck = _t2_neg_replace(
                t1.admission_input.t0_recheck, :prior_bundle_bytes,
                FusionConceptAI.VNextT1CanonicalBytesV2(malformed_bytes))
            malformed_input = _t2_neg_replace(t1.admission_input,
                :t0_recheck, malformed_recheck)
            malformed_admission = FusionConceptAI.vnext_t1_admit_v2(
                malformed_input)
            stale_result_build =
                FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
                    t1.source.witness, malformed_input, t1.admission,
                    package, adapter, baseline.input.formal_gate,
                    scenario=T2_NEG_SCENARIO)
            before = _t2_neg_state(baseline)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "ACTUAL_T1_MALFORMED_WIRE_INPUT",
                malformed_admission, before, after,
                attacked_input_hash=stale_result_build.input_hash,
                note="observe actual T1 malformed-wire first error")
            @test malformed_admission.status === :fail_closed
            @test malformed_admission.errors ==
                (:t0_recheck_wire_hash_mismatch,)
            _t2_neg_run_build_zero!(stream, "ACTUAL_T1_STALE_RESULT",
                stale_result_build, :fail_closed, :none,
                :t2_preflight_t1_admission_result_mismatch, baseline)
            push!(observed_case_ids, "ACTUAL_T1_STALE_RESULT")

            forged_admission = FusionConceptAI.VNextT1AdmissionResultV2(
                t1.admission.status, t1.admission.resolution,
                t1.admission.accepted, t1.admission.claim_ceiling,
                t1.admission.package, t1.admission.errors,
                (:forged_gap,), (:entry, :forged_trace))
            forged_build = FusionConceptAI.vnext_t2_up2_input_from_t1_admission_v2(
                t1.source.witness, t1.admission_input, forged_admission,
                package, adapter, baseline.input.formal_gate,
                scenario=T2_NEG_SCENARIO)
            _t2_neg_run_build_zero!(stream, "ACTUAL_T1_FORGED_RESULT",
                forged_build, :fail_closed, :none,
                :t2_preflight_t1_admission_result_mismatch, baseline)
            push!(observed_case_ids, "ACTUAL_T1_FORGED_RESULT")

            thrown = try
                FusionConceptAI.vnext_t2_formal_gate_identity_v2(
                    package.candidate_ref, T2_NEG_SCENARIO,
                    t1.source.witness.witness_hash, package.package_hash,
                    package.semantic_identity, package.bundle_hash,
                    package.wire.sha256,
                    FusionConceptAI.canonical_hash(
                        FusionConceptAI.semantic_view(adapter)),
                    adapter.binding.receipt_hash, t1.t1_parents,
                    t1.source.expected.commitment_hash,
                    T2_NEG_ZERO_DIGEST, T2_NEG_ZERO_DIGEST,
                    evidence_kind=:formal_t1_actual,
                    formal_t1_accepted=true)
                nothing
            catch error
                error
            end
            before = _t2_neg_state(baseline)
            after = _t2_neg_state(baseline)
            _t2_neg_observe!(stream, "SUP_CONSTRUCTOR_BOUNDARY", thrown,
                before, after, note="supplementary constructor boundary only")
            @test thrown isa ArgumentError
            @test before == after
            push!(observed_case_ids, "SUP_CONSTRUCTOR_BOUNDARY")
        end
    catch error
        test_error = error
    finally
        wire_after = _t2_neg_sha256(FusionConceptAI.copy_bytes(package.wire))
        package_artifact_after = read(package_path)
        candidate_artifact_after = read(candidate_path)
        close(stream)
        summary = (schema="vnext-t2-independent-actual-negative-summary-r1",
            driver_version=T2_NEG_DRIVER_VERSION,
            status=test_error === nothing ? :pass : :fail,
            observed_case_ids=Tuple(observed_case_ids),
            observed_case_count=length(observed_case_ids),
            producer_package_path=package_path,
            producer_package_sha256=package_raw.sha256,
            producer_package_bytes_after=length(package_artifact_after),
            producer_package_sha256_after=
                _t2_neg_sha256(package_artifact_after),
            producer_package_unchanged=package_artifact_after ==
                package_raw.bytes,
            candidate_receipt_path=candidate_path,
            candidate_receipt_sha256=candidate_raw.sha256,
            candidate_receipt_bytes_after=length(candidate_artifact_after),
            candidate_receipt_sha256_after=
                _t2_neg_sha256(candidate_artifact_after),
            candidate_receipt_unchanged=candidate_artifact_after ==
                candidate_raw.bytes,
            software_manifest_sha256=manifest_raw.sha256,
            software_verification_sha256=verification_raw.sha256,
            package_wire_direct_sha256_before=wire_before,
            package_wire_direct_sha256_after=wire_after,
            package_wire_unchanged=wire_before == wire_after,
            final_package_fingerprint=_t2_neg_package_fingerprint(package),
            final_ledger_fingerprint=
                _t2_neg_ledger_fingerprint(result.ledger),
            observation_file_sha256=_t2_neg_sha256(read(observations_path)),
            formal_gate_evidence_kind=:formal_t1_actual,
            formal_t2_accepted=false, physical_acceptance=false,
            scientific_acceptance=false,
            actual_model_attestation="unavailable",
            error_type=test_error === nothing ? nothing :
                string(typeof(test_error)),
            error_text=test_error === nothing ? nothing : sprint(showerror,
                test_error))
        open(summary_path, "w") do io
            write(io, FusionConceptAI.canonical_json(summary) * "\n")
            flush(io)
        end
        println("VNEXT_T2_NEGATIVE_SUMMARY=" *
            FusionConceptAI.canonical_json(summary))
        flush(stdout)
    end
    test_error === nothing || throw(test_error)
    println("VNEXT_T2_ACTUAL_FORMAL_NEGATIVES=PASS")
    flush(stdout)
    nothing
end

length(ARGS) == 9 || error(
    "expected manifest path/hash, verification path/hash, candidate receipt path/hash, producer package path/hash, output dir")

_t2_neg_run(abspath(ARGS[1]), lowercase(ARGS[2]), abspath(ARGS[3]),
    lowercase(ARGS[4]), abspath(ARGS[5]), lowercase(ARGS[6]),
    abspath(ARGS[7]), lowercase(ARGS[8]), abspath(ARGS[9]))
