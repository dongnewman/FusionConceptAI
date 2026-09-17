using Test

include(joinpath(@__DIR__, "..", "..", "..", "src", "FusionConceptAI.jl"))
Base.include(FusionConceptAI,
    joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3", "G3ControlChildEditabilityV1.jl"))
using .FusionConceptAI

const UNIT = UnitSignature((0, 0, 0, 0, 0, 0, 0))
const CANDIDATE = QualifiedRefV1("fusionconceptai://candidate/control-1", "v5")
const PARENT = QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback-1", "v1")
const PARENT_HASH = digest256_text("same-candidate-g3-parent")
const CHILD_CONTRACT = GenomeContractRef(
    G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
    G3_CONTROL_CHILD_EDIT_VERSION_V1,
    g3_control_child_edit_schema_hash_v1(),
    g3_control_child_edit_canonicalization_hash_v1(),
    G3_CONTROL_CHILD_EDIT_PROFILE_V1)

function make_body(mode=:open_circuit; owner_scope="control-scope", extra_fault=nothing,
        plan_override=nothing, target_id="controller-1", safe_action=:trip,
        detection_signal_id="sensor-1", deadline=1//1)
    sensor = G3ControlSignalV1("sensor-1", :sensor, :in, UNIT, "sensor-account")
    actuator = G3ControlSignalV1("actuator-1", :command, :out, UNIT, "actuator-account")
    initial = G3ControlInitialStateV1("state-1", UNIT, 0//1)
    event = G3ControlEventV1("event-1", :initial, 0//1, :enable)
    controller = G3ControlControllerV1("controller-1", ("sensor-1",),
        ("actuator-1",), ("actuator-1",), ("fault-1",), (initial,), (event,))
    fault = G3ControlFaultV1("fault-1", target_id, mode, safe_action,
        detection_signal_id, deadline)
    faults = extra_fault === nothing ? (fault,) : (fault, extra_fault)
    plan = plan_override === nothing ? G3ControlPlanV1(("controller-1",),
        ("sensor-1", "actuator-1"), extra_fault === nothing ? ("fault-1",) : ("fault-1", "fault-2")) : plan_override
    G3ControlSourceBodyV1("control-source-1", owner_scope, (sensor, actuator),
        (controller,), faults, plan)
end

function make_source_record(candidate_ref=CANDIDATE)
    function slot(kind, label)
        G3ControlProvenanceSlotV1(kind, :present,
            QualifiedRefV1("fusionconceptai://evidence/" * label, "v1"),
            "inputs/" * label * ".json", digest256_text(label), candidate_ref,
            nothing, nothing)
    end
    slots = (slot(:payload_schema_version, "schema"),
        slot(:canonicalization_profile_version, "canonical"),
        slot(:applicability_profile_version, "profile"),
        slot(:evidence_receipt_version, "receipt"))
    body = (record_uri=G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
        record_version=G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
        payload_schema_version=slots[1], canonicalization_profile_version=slots[2],
        applicability_profile_version=slots[3], evidence_receipt_version=slots[4])
    G3ControlSourceRecordV1(body.record_uri, body.record_version,
        slots[1], slots[2], slots[3], slots[4], canonical_hash(body))
end

function assert_failure_unchanged(state, thunk; expected_status=:fail_closed)
    before_bytes = g3_control_canonical_bytes_v1(state)
    before_sha = digest256_text(String(copy(before_bytes)))
    before_history = state.operation_history
    before_last = state.last_operation_hash
    before_current = state.current_state_hash
    result = thunk()
    @test result.status === expected_status
    @test result.state === state
    @test g3_control_canonical_bytes_v1(result.state) == before_bytes
    @test digest256_text(String(g3_control_canonical_bytes_v1(result.state))) == before_sha
    @test result.state.operation_history === before_history
    @test result.state.last_operation_hash == before_last
    @test result.state.current_state_hash == before_current
    result
end

function make_operation(id, state, body; expected=:sensor_dropout,
        resulting=:actuator_stuck, fault_id="fault-1")
    g3_control_replace_operation_v1(id, state.key, fault_id, expected, resulting,
        state.current_state_hash, state.initial_source_content_hash, body,
        state.source_payload_ref.source_record_ref, state.source_payload_ref,
        canonical_hash(state.editable_body), canonical_hash(body))
end

function make_payload(body=make_body())
    key = G3ControlChildKeyV1(CANDIDATE, PARENT_HASH, :control, "control-child-1")
    record = make_source_record()
    record_ref = G3ControlSourceRecordRefV1(record.record_uri, record.record_version,
        record.source_record_hash)
    identity = canonical_hash((child_contract_ref=CHILD_CONTRACT,))
    content = canonical_hash((key=key, parent_g3_declaration_ref=PARENT,
        child_contract_ref=CHILD_CONTRACT,
        source_uri=record.record_uri, source_version=record.record_version,
        body=body, source_record_ref=record_ref))
    G3ControlSourcePayloadV1(key, PARENT, PARENT_HASH, CHILD_CONTRACT, identity,
        record.record_uri, record.record_version, body, record, content)
end

@testset "G3 control child editability V1 closed contract" begin
    payload = make_payload()
    key = payload.key
    state = g3_control_initial_state_v1(key, payload)
    @test state.state_status === :present
    @test state.contract_admission === :declared_consistent
    @test state.physical_resolution === :unknown
    @test state.source_payload_ref == g3_control_source_payload_ref_v1(payload)
    @test g3_control_source_record_ref_v1(payload) == state.source_payload_ref.source_record_ref
    @test g3_control_parent_binding_v1(payload).candidate_ref.id == CANDIDATE.id
    @test g3_control_canonical_bytes_v1(state) == Vector{UInt8}(codeunits(canonical_json(semantic_view(state))))
    @test canonical_hash(state) == digest256_text(String(g3_control_canonical_bytes_v1(state)))
    @test state.last_operation_hash == G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1
    @test state.current_state_hash == state.initial_state_hash
    @test isempty(state.operation_history)

    foreign_candidate = QualifiedRefV1("fusionconceptai://candidate/foreign", "v5")
    foreign_record = make_source_record(foreign_candidate)
    foreign_record_ref = G3ControlSourceRecordRefV1(foreign_record.record_uri,
        foreign_record.record_version, foreign_record.source_record_hash)
    foreign_content = canonical_hash((key=key,
        parent_g3_declaration_ref=PARENT, child_contract_ref=CHILD_CONTRACT,
        source_uri=foreign_record.record_uri, source_version=foreign_record.record_version,
        body=payload.body, source_record_ref=foreign_record_ref))
    @test_throws ArgumentError G3ControlSourcePayloadV1(key, PARENT, PARENT_HASH,
        CHILD_CONTRACT, canonical_hash((child_contract_ref=CHILD_CONTRACT,)),
        foreign_record.record_uri, foreign_record.record_version, payload.body,
        foreign_record, foreign_content)

    replacement1 = make_body(:short_circuit)
    op1 = g3_control_replace_operation_v1("operation-1", key, "fault-1",
        :open_circuit, :short_circuit, state.current_state_hash,
        payload.source_content_hash, replacement1,
        state.source_payload_ref.source_record_ref, state.source_payload_ref,
        canonical_hash(state.editable_body), canonical_hash(replacement1))
    result1 = replace_fault_source_payload(state, op1)
    @test result1.status === :applied
    @test result1.state !== state
    @test result1.state.editable_body.faults[1].mode === :short_circuit
    @test result1.state.source_payload_ref == state.source_payload_ref
    @test result1.state.initial_source_content_hash == state.initial_source_content_hash
    @test result1.state.last_operation_hash == op1.operation_hash
    @test length(result1.state.operation_history) == 1
    @test result1.state.operation_history[1].previous_state_hash == state.initial_state_hash
    @test result1.receipt.state_hash == result1.state.current_state_hash

    replacement2 = make_body(:sensor_dropout)
    op2 = g3_control_replace_operation_v1("operation-2", key, "fault-1",
        :short_circuit, :sensor_dropout, result1.state.current_state_hash,
        payload.source_content_hash, replacement2,
        result1.state.source_payload_ref.source_record_ref,
        result1.state.source_payload_ref,
        canonical_hash(result1.state.editable_body), canonical_hash(replacement2))
    result2 = replace_fault_source_payload(result1.state, op2)
    @test result2.status === :applied
    @test result2.state.editable_body.faults[1].mode === :sensor_dropout
    @test result2.state.operation_history[2].previous_state_hash == result1.state.current_state_hash
    @test result2.state.last_operation_hash == op2.operation_hash
    @test result2.state.current_state_hash != result1.state.current_state_hash
    @test result2.state.source_payload_ref == state.source_payload_ref

    stale = g3_control_replace_operation_v1("operation-stale", key, "fault-1",
        :sensor_dropout, :actuator_stuck, digest256_text("stale-state"),
        payload.source_content_hash, make_body(:actuator_stuck),
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref,
        canonical_hash(result2.state.editable_body), canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, stale))

    duplicate_result = assert_failure_unchanged(result1.state,
        () -> replace_fault_source_payload(result1.state, op1))

    foreign_key = G3ControlChildKeyV1(QualifiedRefV1("foreign", "v5"),
        PARENT_HASH, :control, "control-child-1")
    foreign_op = g3_control_replace_operation_v1("operation-foreign", foreign_key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, make_body(:actuator_stuck),
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref,
        canonical_hash(result2.state.editable_body), canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, foreign_op))

    bad_record_ref = G3ControlSourceRecordRefV1("forged", "v1", digest256_text("forged-record"))
    bad_record_op = g3_control_replace_operation_v1("operation-record", key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, make_body(:actuator_stuck), bad_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, bad_record_op))

    stale_source_op = g3_control_replace_operation_v1("operation-stale-source", key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        digest256_text("stale-source-content"), make_body(:actuator_stuck),
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, stale_source_op))

    foreign_parent_key = G3ControlChildKeyV1(CANDIDATE,
        digest256_text("foreign-parent"), :control, "control-child-1")
    foreign_parent_op = g3_control_replace_operation_v1("operation-parent", foreign_parent_key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, make_body(:actuator_stuck),
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, foreign_parent_op))

    foreign_child_key = G3ControlChildKeyV1(CANDIDATE, PARENT_HASH,
        :control, "foreign-child")
    foreign_child_op = g3_control_replace_operation_v1("operation-child", foreign_child_key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, make_body(:actuator_stuck),
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(make_body(:actuator_stuck)))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, foreign_child_op))

    dynamic_body = make_body(:actuator_stuck; owner_scope="forged-scope")
    dynamic_op = g3_control_replace_operation_v1("operation-dynamic", key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, dynamic_body,
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(dynamic_body))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, dynamic_op))

    second_fault = G3ControlFaultV1("fault-2", "controller-1", :open_circuit,
        :hold, "sensor-1", 2//1)
    multi_body = make_body(:actuator_stuck; extra_fault=second_fault)
    multi_op = g3_control_replace_operation_v1("operation-multi", key,
        "fault-1", :sensor_dropout, :actuator_stuck, result2.state.current_state_hash,
        payload.source_content_hash, multi_body,
        result2.state.source_payload_ref.source_record_ref,
        result2.state.source_payload_ref, canonical_hash(result2.state.editable_body),
        canonical_hash(multi_body))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, multi_op))

    zero_mode_op = make_operation("operation-zero-mode", result2.state,
        make_body(:sensor_dropout))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, zero_mode_op))

    delete_body = G3ControlSourceBodyV1(result2.state.editable_body.source_id,
        result2.state.editable_body.owner_scope, result2.state.editable_body.signal_ports,
        result2.state.editable_body.controllers, (), result2.state.editable_body.plan)
    delete_op = make_operation("operation-delete", result2.state, delete_body)
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, delete_op))

    rebind_op = make_operation("operation-rebind", result2.state,
        make_body(:actuator_stuck; target_id="controller-2"))
    assert_failure_unchanged(result2.state,
        () -> replace_fault_source_payload(result2.state, rebind_op))

    carried_variants = (
        ("target", make_body(:actuator_stuck; target_id="controller-2")),
        ("safe_action", make_body(:actuator_stuck; safe_action=:hold)),
        ("detection_signal", make_body(:actuator_stuck; detection_signal_id="actuator-1")),
        ("deadline", make_body(:actuator_stuck; deadline=2//1)),
        ("combined", make_body(:actuator_stuck; target_id="controller-2",
            safe_action=:hold, detection_signal_id="actuator-1", deadline=2//1)))
    for (label, carried_body) in carried_variants
        carried_op = make_operation("operation-carried-" * label, result2.state, carried_body)
        assert_failure_unchanged(result2.state,
            () -> replace_fault_source_payload(result2.state, carried_op))
    end

    absent_pre = g3_control_typed_absent_state_v1(
        key, "control timing not supplied")
    absent_result = assert_failure_unchanged(absent_pre,
        () -> replace_fault_source_payload(absent_pre, zero_mode_op);
        expected_status=:terminal_deferred)

    last_record = result2.state.operation_history[end]
    forged_last = G3ControlOperationRecordV1(last_record.operation_id,
        last_record.operation_kind, last_record.key, last_record.fault_id,
        last_record.expected_prior_mode, last_record.resulting_mode,
        last_record.previous_state_hash, last_record.expected_prior_source_content_hash,
        last_record.prior_editable_body_hash, last_record.replacement_editable_body_hash,
        last_record.source_record_ref, last_record.source_payload_ref,
        last_record.operation_hash, digest256_text("forged-terminal-result"))
    @test_throws ArgumentError G3ControlStateV1(result2.state.key,
        result2.state.source_payload_ref, result2.state.editable_body,
        result2.state.initial_source_content_hash, :present, nothing, nothing, (),
        result2.state.initial_state_hash, result2.state.current_state_hash,
        result2.state.last_operation_hash, :declared_consistent, :unknown,
        (result2.state.operation_history[1], forged_last))

    @test_throws ArgumentError G3ControlSourceBodyV1("s", "o", [], (), (), payload.body.plan)
    @test_throws ArgumentError G3ControlSourcePayloadV1(key, PARENT, PARENT_HASH,
        CHILD_CONTRACT, digest256_text("forged-child"), payload.source_uri,
        payload.source_version, payload.body, payload.source_record,
        payload.source_content_hash)
    @test_throws ArgumentError G3ControlStateV1(key, nothing, nothing, nothing,
        :typed_absent, "missing", digest256_text("absence"), (),
        state.initial_state_hash, state.initial_state_hash,
        G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1, :declared_consistent,
        :unknown, ())
    @test_throws ArgumentError G3ControlStateV1(key, result2.state.source_payload_ref,
        result2.state.editable_body, result2.state.initial_source_content_hash,
        :present, nothing, nothing, (), result2.state.initial_state_hash,
        result2.state.current_state_hash, result2.state.last_operation_hash,
        :declared_consistent, :unknown,
        (reverse(result2.state.operation_history)...,))

    absent = g3_control_typed_absent_state_v1(key, "control timing not supplied";
        missing_slots=(:payload_schema_version, :evidence_receipt_version))
    @test absent.state_status === :typed_absent
    @test absent.source_payload_ref === nothing
    @test absent.editable_body === nothing
    @test absent.contract_admission === :terminal_deferred
    @test absent.physical_resolution === :terminal_deferred
    @test isempty(absent.operation_history)
    @test absent.last_operation_hash == G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1

    @test_throws ArgumentError G3ControlProvenanceSlotV1(:payload_schema_version,
        :typed_absent, nothing, nothing, nothing, CANDIDATE, "missing", nothing)
    absent_hash = canonical_hash((domain="g3-control-provenance-slot-absence-v1",
        slot_kind=:payload_schema_version, status=:typed_absent,
        candidate_ref=CANDIDATE, reason="missing"))
    @test G3ControlProvenanceSlotV1(:payload_schema_version, :typed_absent,
        nothing, nothing, nothing, CANDIDATE, "missing", absent_hash).status === :typed_absent
end
