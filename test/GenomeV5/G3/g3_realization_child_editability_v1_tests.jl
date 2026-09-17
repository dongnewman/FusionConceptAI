using Test
using FusionConceptAI

const _G3RCE_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3RCE_ROOT, "G3RealizationChildEditabilityV1.jl"))
const G = FusionConceptAI

const _G3RCE_CANDIDATE = QualifiedRefV1("candidate-g3rce-001", "v5")
const _G3RCE_PARENT = QualifiedRefV1("g3-declaration-001", "v1")
const _G3RCE_PARENT_HASH = digest256_text("g3-parent-declaration-001")
const _G3RCE_UNIT = UnitSignature()

function _g3rce_ports()
    (
        G.G3RealizationSourcePortV1("source-port", :source, _G3RCE_UNIT, :out, 1, "candidate-owner"),
        G.G3RealizationSourcePortV1("field-port", :field, _G3RCE_UNIT, :in, 1, "candidate-owner"),
        G.G3RealizationSourcePortV1("return-port", :return, _G3RCE_UNIT, :in, 1, "candidate-owner"),
        G.G3RealizationSourcePortV1("heat-port", :heat, _G3RCE_UNIT, :in, 1, "candidate-owner"),
    )
end

function _g3rce_body(; source=100, field=70, returned=20, heat=10, ports=_g3rce_ports(),
        closure_balance=0, closure_domain=:energy, component_port_ids=("source-port", "field-port", "return-port", "heat-port"),
        ledger_unit=_G3RCE_UNIT)
    component = G.G3RealizationComponentV1("component-001", :source_component,
        component_port_ids, 120, _G3RCE_UNIT,
        "material-001", "process-001")
    material = G.G3RealizationMaterialDomainV1("material-001", :strength, 0, 10, _G3RCE_UNIT)
    process = G.G3RealizationManufacturingDomainV1("process-001", :thickness, 1, 2, _G3RCE_UNIT)
    accounts = (G.G3RealizationLedgerAccountV1("energy-account", :energy, ledger_unit, "candidate-owner"),)
    entries = (
        G.G3RealizationLedgerEntryV1("entry-source", "energy-account", "source-port", "component-001", source, ledger_unit, :source),
        G.G3RealizationLedgerEntryV1("entry-field", "energy-account", "field-port", "component-001", -field, ledger_unit, :load),
        G.G3RealizationLedgerEntryV1("entry-return", "energy-account", "return-port", "component-001", -returned, ledger_unit, :return),
        G.G3RealizationLedgerEntryV1("entry-heat", "energy-account", "heat-port", "component-001", -heat, ledger_unit, :heat_rejection),
    )
    closures = (G.G3RealizationLedgerClosureV1("energy-closure", closure_domain, ("energy-account",), closure_balance),)
    G.G3RealizationSourceBodyV1("source-001", "candidate-owner", ports,
        source, field, returned, heat, 120, _G3RCE_UNIT, 0,
        (component,), (material,), (process,), accounts, entries, closures)
end

function _g3rce_record(; complete=true)
    if complete
        return G.g3_realization_source_record_v1(_G3RCE_CANDIDATE;
            schema_ref=QualifiedRefV1("schema-record-001", "v1"),
            schema_hash=digest256_text("schema-content-001"),
            canonicalization_ref=QualifiedRefV1("canonical-record-001", "v1"),
            canonicalization_hash=digest256_text("canonical-content-001"),
            profile_ref=QualifiedRefV1("profile-record-001", "v1"),
            profile_hash=digest256_text("profile-content-001"),
            evidence_receipt_ref=QualifiedRefV1("evidence-record-001", "v1"),
            evidence_receipt_hash=digest256_text("evidence-content-001"))
    end
    G.g3_realization_source_record_v1(_G3RCE_CANDIDATE)
end

function _g3rce_payload(; body=_g3rce_body(), candidate=_G3RCE_CANDIDATE,
        parent=_G3RCE_PARENT, parent_hash=_G3RCE_PARENT_HASH, complete=true)
    key = G.G3RealizationChildKeyV1(candidate, parent_hash, :realization, body.source_id)
    record = _g3rce_record(complete=complete)
    G.g3_realization_source_payload_v1(key, parent, body, record)
end

@testset "G3 realization child editability V1 contract" begin
    @test G.g3_realization_child_edit_schema_hash_v1() isa Digest256
    @test G.g3_realization_child_edit_canonicalization_hash_v1() isa Digest256
    @test G.g3_realization_child_edit_profile_hash_v1() isa Digest256

    payload = _g3rce_payload()
    @test payload.key.child_kind == :realization
    @test isempty(G._g3rce_payload_valid(payload))
    @test payload.child_contract_ref.uri == G.G3_REALIZATION_CHILD_EDIT_CONTRACT_URI_V1
    @test payload.child_contract_ref.version == "v1"
    @test payload.source_record.source_record_hash ==
        canonical_hash(G._g3rce_source_record_body(payload.source_record))
    @test payload.source_content_hash == canonical_hash(G._g3rce_payload_body(payload))

    state = G.g3_realization_initial_state_v1(payload.key, payload)
    @test state.contract_admission == :declared_consistent
    @test state.physical_resolution == :unknown
    @test state.source_content_hash == payload.source_content_hash
    @test state.initial_state_hash != state.state_hash
    @test state.initial_state_hash == canonical_hash((
        domain="g3-realization-initial-state-v1", key=state.key,
        state_status=:present, source_content_hash=state.source_content_hash,
        absence_content_hash=nothing,
        missing_slots=(), operation_history=(),
        operation_hash=G.G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1))
    @test state.state_hash == canonical_hash((
        domain="g3-realization-state-v1", key=state.key,
        state_status=:present, source_content_hash=state.source_content_hash,
        absence_content_hash=nothing,
        missing_slots=(), operation_history=(),
        operation_hash=G.G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1))

    replacement = _g3rce_payload(body=_g3rce_body(source=90, field=60, returned=20, heat=10))
    @test replacement.source_content_hash != payload.source_content_hash
    @test replacement.body != payload.body
    op = G.g3_realization_replace_operation_v1("op-001", state.key, state.state_hash,
        state.source_content_hash, replacement,
        G.G3RealizationSourceRecordRefV1(replacement.source_record.source_uri,
            replacement.source_record.source_version, replacement.source_record.source_record_hash))
    result = G.replace_source_payload(state, op)
    @test result.status == :applied
    @test result.receipt !== nothing
    @test result.state.payload.source_content_hash == replacement.source_content_hash
    @test result.state.initial_state_hash == state.initial_state_hash
    @test result.state.initial_source_content_hash == state.initial_source_content_hash
    @test result.state.state_hash != state.state_hash
    @test result.state.operation_history == ("op-001",)
    @test result.state.physical_resolution == :unknown

    second_operation = G.g3_realization_replace_operation_v1("op-002", result.state.key,
        result.state.state_hash, result.state.source_content_hash, payload,
        G.G3RealizationSourceRecordRefV1(payload.source_record.source_uri,
            payload.source_record.source_version, payload.source_record.source_record_hash))
    second_result = G.replace_source_payload(result.state, second_operation)
    @test second_result.status == :applied
    @test second_result.state.operation_history == ("op-001", "op-002")
    duplicate_operation = G.g3_realization_replace_operation_v1("op-001", second_result.state.key,
        second_result.state.state_hash, second_result.state.source_content_hash, payload,
        G.G3RealizationSourceRecordRefV1(payload.source_record.source_uri,
            payload.source_record.source_version, payload.source_record.source_record_hash))
    duplicate_result = G.replace_source_payload(second_result.state, duplicate_operation)
    @test duplicate_result.status == :fail_closed
    @test duplicate_result.errors == ("duplicate_operation_id",)

    stale_state = G.g3_realization_replace_operation_v1("op-stale-state", state.key,
        digest256_text("stale-state"), state.source_content_hash, replacement,
        G.G3RealizationSourceRecordRefV1(replacement.source_record.source_uri,
            replacement.source_record.source_version, replacement.source_record.source_record_hash))
    stale_state_result = G.replace_source_payload(state, stale_state)
    @test stale_state_result.status == :fail_closed
    @test stale_state_result.errors == ("stale_state_hash",)
    @test stale_state_result.state.state_hash == state.state_hash

    stale_source = G.g3_realization_replace_operation_v1("op-stale-source", state.key,
        state.state_hash, digest256_text("stale-source"), replacement,
        G.G3RealizationSourceRecordRefV1(replacement.source_record.source_uri,
            replacement.source_record.source_version, replacement.source_record.source_record_hash))
    stale_source_result = G.replace_source_payload(state, stale_source)
    @test stale_source_result.status == :fail_closed
    @test stale_source_result.errors == ("stale_source_content_hash",)
    @test stale_source_result.state.state_hash == state.state_hash

    foreign_key = G.G3RealizationChildKeyV1(QualifiedRefV1("foreign-candidate", "v5"),
        _G3RCE_PARENT_HASH, :realization, "source-001")
    foreign_operation = G.g3_realization_replace_operation_v1("op-foreign", foreign_key,
        state.state_hash, state.source_content_hash, replacement,
        G.G3RealizationSourceRecordRefV1(replacement.source_record.source_uri,
            replacement.source_record.source_version, replacement.source_record.source_record_hash))
    @test G.replace_source_payload(state, foreign_operation).status == :fail_closed

    forged_operation = G.G3RealizationReplaceSourcePayloadV1(op.operation_id, op.key,
        op.expected_prior_state_hash, op.expected_prior_source_content_hash,
        op.replacement_payload, op.source_record_ref, digest256_text("forged-operation"))
    @test G.replace_source_payload(state, forged_operation).errors == ("operation_hash_mismatch",)

    absent_record = _g3rce_record(complete=false)
    absent_state = G.g3_realization_admit_source_v1(G.G3RealizationChildKeyV1(
        _G3RCE_CANDIDATE, _G3RCE_PARENT_HASH, :realization, "source-001"),
        _G3RCE_PARENT, _g3rce_body(), absent_record)
    @test absent_state.state_status == :typed_absent
    @test absent_state.payload === nothing
    @test absent_state.source_content_hash === nothing
    @test absent_state.contract_admission == :terminal_deferred
    @test absent_state.physical_resolution == :unknown
    @test absent_state.missing_slots == (:schema, :canonicalization, :profile, :evidence_receipt)
    @test absent_state.absence_content_hash == canonical_hash((
        domain="g3-realization-state-absence-v1", key=absent_state.key,
        reason="source provenance unavailable", missing_slots=absent_state.missing_slots))

    one_reason_record = G.g3_realization_source_record_v1(_G3RCE_CANDIDATE;
        absence_reasons=((:schema => "schema unavailable"),))
    @test one_reason_record.schema.reason == "schema unavailable"
    multiple_reason_record = G.g3_realization_source_record_v1(_G3RCE_CANDIDATE;
        absence_reasons=((:schema => "first reason"), (:schema => "second reason")))
    @test startswith(multiple_reason_record.schema.reason, "structural conflict:")
    multiple_reason_state = G.g3_realization_admit_source_v1(
        G.G3RealizationChildKeyV1(_G3RCE_CANDIDATE, _G3RCE_PARENT_HASH,
            :realization, "source-001"), _G3RCE_PARENT, _g3rce_body(), multiple_reason_record)
    @test multiple_reason_state.contract_admission == :fail_closed
    @test multiple_reason_state.physical_resolution == :unknown

    foreign_record = G.g3_realization_source_record_v1(QualifiedRefV1("foreign-candidate", "v5");
        schema_ref=QualifiedRefV1("schema-record-foreign", "v1"),
        schema_hash=digest256_text("schema-content-foreign"),
        canonicalization_ref=QualifiedRefV1("canonical-record-foreign", "v1"),
        canonicalization_hash=digest256_text("canonical-content-foreign"),
        profile_ref=QualifiedRefV1("profile-record-foreign", "v1"),
        profile_hash=digest256_text("profile-content-foreign"),
        evidence_receipt_ref=QualifiedRefV1("evidence-record-foreign", "v1"),
        evidence_receipt_hash=digest256_text("evidence-content-foreign"))
    foreign_payload = G.g3_realization_source_payload_v1(payload.key, _G3RCE_PARENT,
        _g3rce_body(), foreign_record)
    foreign_admission = G.g3_realization_admit_v1(payload.key, foreign_payload)
    @test foreign_admission.contract_admission == :fail_closed
    @test foreign_admission.state_status == :typed_absent

    @test_throws ArgumentError G.G3RealizationSourceBodyV1("source-001", "candidate-owner",
        (G.G3RealizationSourcePortV1("source-port", :source, _G3RCE_UNIT, :in, 1, "candidate-owner"),
         _g3rce_ports()[2], _g3rce_ports()[3], _g3rce_ports()[4]),
        100, 70, 20, 10, 120, _G3RCE_UNIT, 0)
    wrong_owner_ports = (G.G3RealizationSourcePortV1("source-port", :source, _G3RCE_UNIT, :out, 1, "foreign-owner"),
        _g3rce_ports()[2], _g3rce_ports()[3], _g3rce_ports()[4])
    @test_throws ArgumentError _g3rce_body(ports=wrong_owner_ports)
    duplicate_ports = (G.G3RealizationSourcePortV1("source-port", :source, _G3RCE_UNIT, :out, 1, "candidate-owner"),
        G.G3RealizationSourcePortV1("source-port", :field, _G3RCE_UNIT, :in, 1, "candidate-owner"),
        _g3rce_ports()[3], _g3rce_ports()[4])
    @test_throws ArgumentError _g3rce_body(ports=duplicate_ports)
    @test_throws ArgumentError _g3rce_body(closure_balance=1)
    @test_throws ArgumentError _g3rce_body(closure_domain=:thermal)
    @test_throws ArgumentError _g3rce_body(ledger_unit=UnitSignature([1, 0, 0, 0, 0, 0, 0]))
    @test_throws ArgumentError _g3rce_body(component_port_ids=("source-port", "missing-port", "return-port", "heat-port"))
    @test_throws ArgumentError G.G3RealizationSourceStateV1(state.key, state.payload,
        state.source_content_hash, state.initial_source_content_hash, :invalid_status, nothing, nothing,
        (),
        state.initial_state_hash, state.state_hash, state.operation_hash,
        :declared_consistent, :unknown, ())
    @test_throws ArgumentError G.G3RealizationOperationReceiptV1("bad-status",
        state.operation_hash, payload.source_record.source_record_hash,
        payload.source_content_hash, state.initial_state_hash, state.state_hash,
        :invalid_status, :unknown)
    @test_throws ArgumentError G.G3RealizationOperationReceiptV1("physical-promotion",
        state.operation_hash, payload.source_record.source_record_hash,
        payload.source_content_hash, state.initial_state_hash, state.state_hash,
        :declared_consistent, :actual)
    @test_throws ArgumentError G.G3RealizationReplaceResultV1(:program_exception,
        state, nothing, ("user-forged",))
    @test_throws ArgumentError G.G3RealizationSourceStateV1(state.key, state.payload,
        state.source_content_hash, state.initial_source_content_hash, :present, nothing, nothing,
        (), state.initial_state_hash, state.state_hash, state.operation_hash,
        :program_exception, :unknown, ())
    @test G.g3_realization_source_payload_v1(
        G.G3RealizationChildKeyV1(_G3RCE_CANDIDATE, _G3RCE_PARENT_HASH,
            :realization, "source-001"), _G3RCE_PARENT, _g3rce_body(), _g3rce_record()).source_content_hash !=
        _G3RCE_PARENT_HASH

    @test_throws ArgumentError G.G3RealizationSourceProvenanceV1(:schema, nothing,
        _G3RCE_CANDIDATE, digest256_text("absent-cannot-carry-source-hash"),
        :typed_absent, "missing", digest256_text("absence"))
    @test_throws ArgumentError G.g3_realization_source_payload_v1(
        G.G3RealizationChildKeyV1(_G3RCE_CANDIDATE, _G3RCE_PARENT_HASH,
            :realization, "source-001"), _G3RCE_PARENT, _g3rce_body(), absent_record)
end
