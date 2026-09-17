"""Closed, control-only candidate-owned source editability precursor for G3 V1.

This additive file intentionally has no include in the shared module.  It owns
only the local control child contract and a single atomic fault-mode edit.  The
immutable source payload, source record, axes, identities and child key are
separate from the editable body/state; no T0, package, registry, provider,
engineering or physical path is imported.
"""

const G3_CONTROL_CHILD_EDIT_SCHEMA_ID_V1 =
    "GenomeV5/G3/G3ControlChildEditabilityV1"
const G3_CONTROL_CHILD_EDIT_VERSION_V1 = "v1"
const G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1 =
    "fusionconceptai://GenomeV5/G3/control-child-editability"
const G3_CONTROL_CHILD_EDIT_PROFILE_V1 = "closed-control-source-edit-v1"
const G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1 =
    "fusionconceptai://GenomeV5/G3/control-source-record"
const G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1 = "v1"
const G3_CONTROL_CHILD_EDIT_KIND_V1 = :control
const G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1 = Digest256(repeat("0", 64))
const G3_CONTROL_CHILD_EDIT_DIRECTIONS_V1 = (:in, :out, :bidirectional)
const G3_CONTROL_CHILD_EDIT_SIGNAL_KINDS_V1 =
    (:sensor, :command, :status, :feedback)
const G3_CONTROL_CHILD_EDIT_TRIGGERS_V1 =
    (:initial, :scheduled, :fault, :threshold)
const G3_CONTROL_CHILD_EDIT_ACTIONS_V1 =
    (:enable, :disable, :hold, :trip, :recover)
const G3_CONTROL_CHILD_EDIT_FAULT_MODES_V1 =
    (:open_circuit, :short_circuit, :sensor_dropout, :actuator_stuck,
     :overtemperature)
const G3_CONTROL_CHILD_EDIT_SAFE_ACTIONS_V1 = (:trip, :hold, :disable, :recover)
const G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1 =
    (:payload_schema_version, :canonicalization_profile_version,
     :applicability_profile_version, :evidence_receipt_version)
const G3_CONTROL_CHILD_EDIT_SLOT_STATUSES_V1 = (:present, :typed_absent)
const G3_CONTROL_CHILD_EDIT_CONTRACT_STATUSES_V1 =
    (:declared_consistent, :terminal_deferred, :fail_closed, :program_exception)
const G3_CONTROL_CHILD_EDIT_RESULT_STATUSES_V1 =
    (:applied, :fail_closed, :terminal_deferred, :program_exception)
const G3_CONTROL_CHILD_EDIT_ABSENT_STATUS_V1 = :terminal_deferred
const G3_CONTROL_CHILD_EDIT_SOURCE_ABSENCE_REASONS_V1 =
    (:missing_provenance, :source_admission_deferred, :source_admission_conflict)
const G3_CONTROL_CHILD_EDIT_SIGNAL_DIRECTIONS_IN_V1 = (:in, :bidirectional)
const G3_CONTROL_CHILD_EDIT_SIGNAL_DIRECTIONS_OUT_V1 = (:out, :bidirectional)

const _G3_CONTROL_CHILD_EDIT_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/G3/G3ControlChildEditabilityV1
version=v1
scope=control-only candidate-owned closed source body
body=source_id,owner_scope,signal_ports,controllers,faults,plan
signal=port_id,signal_kind,direction,unit,account_id
controller=controller_id,sensor_port_ids,actuator_port_ids,actuator_resource_port_ids,fault_ids,initial_states,events
fault=fault_id,target_id,mode,safe_action,detection_signal_id,deadline
plan=controller_ids,signal_port_ids,fault_ids
payload=key,parent_g3_declaration_ref,parent_g3_declaration_hash,child_contract_ref,child_contract_identity_hash,source_uri,source_version,body,source_record,source_content_hash
operation=replace_fault_source_payload,one-existing-fault-mode,immutable-source
"""
const _G3_CONTROL_CHILD_EDIT_CANONICAL_SOURCE_V1 = """
encoding=UTF-8;line_endings=LF;tuple_order=declared;symbols=ordinal;rationals=normalized
hash_layers=source_record,source_content,initial_state,operation,current_state
operation_hash=full-prior-and-replacement-editable-body-hash,fault-id,before-after-mode,previous-state,derived-refs
failure=old-state-canonical-bytes-unchanged
"""
const _G3_CONTROL_CHILD_EDIT_PROFILE_SOURCE_V1 = """
admission=closed typed construction, exact candidate-parent-child identity and source-record derivation
missing_provenance=typed_absent; local status=terminal_deferred
conflict=fail_closed; unexpected=program_exception
physical_resolution=independent unknown or terminal_deferred; local edit cannot promote physical
"""

g3_control_child_edit_schema_hash_v1() = digest256_text(_G3_CONTROL_CHILD_EDIT_SCHEMA_SOURCE_V1)
g3_control_child_edit_canonicalization_hash_v1() = digest256_text(_G3_CONTROL_CHILD_EDIT_CANONICAL_SOURCE_V1)
g3_control_child_edit_profile_hash_v1() = digest256_text(_G3_CONTROL_CHILD_EDIT_PROFILE_SOURCE_V1)

function _g3ce_text(value, field::AbstractString)
    value isa AbstractString || throw(ArgumentError("$field must be String"))
    text = String(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field must be non-empty UTF-8"))
    text
end
_g3ce_ref(value, field) = value isa QualifiedRefV1 ? value : throw(ArgumentError("$field must be QualifiedRefV1"))
_g3ce_ref_equal(a::QualifiedRefV1, b::QualifiedRefV1) = a.id == b.id && a.version == b.version
_g3ce_digest(value, field) = value isa Digest256 ? value : throw(ArgumentError("$field must be Digest256"))
_g3ce_unit(value, field) = value isa UnitSignature ? value : throw(ArgumentError("$field must be UnitSignature"))
_g3ce_tuple(value, field) = value isa Tuple ? value : throw(ArgumentError("$field must be an immutable Tuple"))
_g3ce_symbol(value, allowed, field) = begin
    symbol = value isa Symbol ? value : Symbol(value)
    symbol in allowed || throw(ArgumentError("$field is invalid: $symbol"))
    symbol
end
_g3ce_rat(value, field; positive=false) = begin
    value isa Bool && throw(ArgumentError("$field must be exact Rational"))
    value isa Rational || value isa Integer || throw(ArgumentError("$field must be exact Rational or integer"))
    result = try Rational{Int64}(value) catch
        throw(ArgumentError("$field is outside Int64 rational range"))
    end
    positive && result <= 0 && throw(ArgumentError("$field must be positive"))
    result
end

function _g3ce_candidate(value, field="candidate_ref")
    ref = _g3ce_ref(value, field)
    ref.version == "v5" || throw(ArgumentError("$field must use candidate version v5"))
    ref
end

function _g3ce_parent(value)
    ref = _g3ce_ref(value, "parent_g3_declaration_ref")
    ref.version == "v1" || throw(ArgumentError("parent G3 declaration ref must use version v1"))
    ref
end

function _g3ce_unique_strings(value, field; nonempty=true)
    tuple = _g3ce_tuple(value, field)
    all(x -> x isa AbstractString && (!nonempty || !isempty(String(x))), tuple) ||
        throw(ArgumentError("$field must contain strings"))
    result = Tuple(String(x) for x in tuple)
    length(unique(result)) == length(result) || throw(ArgumentError("$field must be unique"))
    result
end

struct G3ControlChildKeyV1
    candidate_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_kind::Symbol
    child_id::String
    function G3ControlChildKeyV1(candidate_ref::Any, parent_hash::Any,
            child_kind::Any, child_id::Any)
        new(_g3ce_candidate(candidate_ref), _g3ce_digest(parent_hash, "parent_g3_declaration_hash"),
            _g3ce_symbol(child_kind, (G3_CONTROL_CHILD_EDIT_KIND_V1,), "child_kind"),
            _g3ce_text(child_id, "child_id"))
    end
end

struct G3ControlSignalV1
    port_id::String
    signal_kind::Symbol
    direction::Symbol
    unit::UnitSignature
    account_id::String
    function G3ControlSignalV1(port_id::Any, signal_kind::Any, direction::Any,
            unit::Any, account_id::Any)
        new(_g3ce_text(port_id, "signal port_id"),
            _g3ce_symbol(signal_kind, G3_CONTROL_CHILD_EDIT_SIGNAL_KINDS_V1, "signal kind"),
            _g3ce_symbol(direction, G3_CONTROL_CHILD_EDIT_DIRECTIONS_V1, "signal direction"),
            _g3ce_unit(unit, "signal unit"), _g3ce_text(account_id, "signal account_id"))
    end
end

struct G3ControlInitialStateV1
    state_id::String
    unit::UnitSignature
    value::Rational{Int64}
    function G3ControlInitialStateV1(state_id::Any, unit::Any, value::Any)
        new(_g3ce_text(state_id, "initial state_id"), _g3ce_unit(unit, "initial state unit"),
            _g3ce_rat(value, "initial state value"))
    end
end

struct G3ControlEventV1
    event_id::String
    trigger::Symbol
    time::Rational{Int64}
    action::Symbol
    function G3ControlEventV1(event_id::Any, trigger::Any, time::Any, action::Any)
        new(_g3ce_text(event_id, "event_id"),
            _g3ce_symbol(trigger, G3_CONTROL_CHILD_EDIT_TRIGGERS_V1, "event trigger"),
            _g3ce_rat(time, "event time"),
            _g3ce_symbol(action, G3_CONTROL_CHILD_EDIT_ACTIONS_V1, "event action"))
    end
end

struct G3ControlControllerV1
    controller_id::String
    sensor_port_ids::Tuple{Vararg{String}}
    actuator_port_ids::Tuple{Vararg{String}}
    actuator_resource_port_ids::Tuple{Vararg{String}}
    fault_ids::Tuple{Vararg{String}}
    initial_states::Tuple{Vararg{G3ControlInitialStateV1}}
    events::Tuple{Vararg{G3ControlEventV1}}
    function G3ControlControllerV1(controller_id::Any, sensor_port_ids::Any,
            actuator_port_ids::Any, actuator_resource_port_ids::Any,
            fault_ids::Any, initial_states::Any=(), events::Any=())
        sensors = _g3ce_unique_strings(sensor_port_ids, "sensor_port_ids")
        actuators = _g3ce_unique_strings(actuator_port_ids, "actuator_port_ids")
        resources = _g3ce_unique_strings(actuator_resource_port_ids, "actuator_resource_port_ids")
        faults = _g3ce_unique_strings(fault_ids, "fault_ids")
        !isempty(sensors) && !isempty(actuators) || throw(ArgumentError("controller requires sensor and actuator ports"))
        length(sensors) == length(actuators) || throw(ArgumentError("sensor/actuator cardinality mismatch"))
        length(actuators) == length(resources) || throw(ArgumentError("actuator/resource cardinality mismatch"))
        states = _g3ce_tuple(initial_states, "initial_states")
        events = _g3ce_tuple(events, "events")
        all(x -> x isa G3ControlInitialStateV1, states) || throw(ArgumentError("invalid initial state"))
        all(x -> x isa G3ControlEventV1, events) || throw(ArgumentError("invalid event"))
        ids = Tuple(x.state_id for x in states)
        length(unique(ids)) == length(ids) || throw(ArgumentError("initial state ids must be unique"))
        event_ids = Tuple(x.event_id for x in events)
        length(unique(event_ids)) == length(event_ids) || throw(ArgumentError("event ids must be unique"))
        new(_g3ce_text(controller_id, "controller_id"), sensors, actuators, resources, faults,
            Tuple(states), Tuple(events))
    end
end

struct G3ControlFaultV1
    fault_id::String
    target_id::String
    mode::Symbol
    safe_action::Symbol
    detection_signal_id::String
    deadline::Rational{Int64}
    function G3ControlFaultV1(fault_id::Any, target_id::Any, mode::Any,
            safe_action::Any, detection_signal_id::Any, deadline::Any)
        new(_g3ce_text(fault_id, "fault_id"), _g3ce_text(target_id, "fault target_id"),
            _g3ce_symbol(mode, G3_CONTROL_CHILD_EDIT_FAULT_MODES_V1, "fault mode"),
            _g3ce_symbol(safe_action, G3_CONTROL_CHILD_EDIT_SAFE_ACTIONS_V1, "fault safe_action"),
            _g3ce_text(detection_signal_id, "fault detection_signal_id"),
            _g3ce_rat(deadline, "fault deadline"; positive=true))
    end
end

struct G3ControlPlanV1
    controller_ids::Tuple{Vararg{String}}
    signal_port_ids::Tuple{Vararg{String}}
    fault_ids::Tuple{Vararg{String}}
    function G3ControlPlanV1(controller_ids::Any, signal_port_ids::Any, fault_ids::Any)
        cs = _g3ce_unique_strings(controller_ids, "plan controller_ids")
        ss = _g3ce_unique_strings(signal_port_ids, "plan signal_port_ids")
        fs = _g3ce_unique_strings(fault_ids, "plan fault_ids")
        !isempty(cs) && !isempty(ss) && !isempty(fs) || throw(ArgumentError("control plan cannot be empty"))
        new(cs, ss, fs)
    end
end

struct G3ControlSourceBodyV1
    source_id::String
    owner_scope::String
    signal_ports::Tuple{Vararg{G3ControlSignalV1}}
    controllers::Tuple{Vararg{G3ControlControllerV1}}
    faults::Tuple{Vararg{G3ControlFaultV1}}
    plan::G3ControlPlanV1
    function G3ControlSourceBodyV1(source_id::Any, owner_scope::Any, signal_ports::Any,
            controllers::Any, faults::Any, plan::Any)
        signals = _g3ce_tuple(signal_ports, "signal_ports")
        control = _g3ce_tuple(controllers, "controllers")
        fault_tuple = _g3ce_tuple(faults, "faults")
        all(x -> x isa G3ControlSignalV1, signals) || throw(ArgumentError("invalid signal port"))
        all(x -> x isa G3ControlControllerV1, control) || throw(ArgumentError("invalid controller"))
        all(x -> x isa G3ControlFaultV1, fault_tuple) || throw(ArgumentError("invalid fault"))
        plan isa G3ControlPlanV1 || throw(ArgumentError("invalid control plan"))
        length(unique(x.port_id for x in signals)) == length(signals) || throw(ArgumentError("duplicate signal port"))
        length(unique(x.controller_id for x in control)) == length(control) || throw(ArgumentError("duplicate controller"))
        length(unique(x.fault_id for x in fault_tuple)) == length(fault_tuple) || throw(ArgumentError("duplicate fault"))
        new(_g3ce_text(source_id, "source_id"), _g3ce_text(owner_scope, "owner_scope"),
            Tuple(signals), Tuple(control), Tuple(fault_tuple), plan)
    end
end

struct G3ControlProvenanceSlotV1
    slot_kind::Symbol
    status::Symbol
    value_ref::Union{Nothing,QualifiedRefV1}
    source_path::Union{Nothing,String}
    source_hash::Union{Nothing,Digest256}
    candidate_ref::QualifiedRefV1
    reason::Union{Nothing,String}
    absence_content_hash::Union{Nothing,Digest256}
    function G3ControlProvenanceSlotV1(slot_kind::Any, status::Any, value_ref::Any,
            source_path::Any, source_hash::Any, candidate_ref::Any,
            reason::Any, absence_content_hash::Any)
        kind = _g3ce_symbol(slot_kind, G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1, "slot_kind")
        st = _g3ce_symbol(status, G3_CONTROL_CHILD_EDIT_SLOT_STATUSES_V1, "slot status")
        candidate = _g3ce_candidate(candidate_ref, "slot candidate_ref")
        ref = value_ref === nothing ? nothing : _g3ce_ref(value_ref, "slot value_ref")
        path = source_path === nothing ? nothing : _g3ce_text(source_path, "slot source_path")
        hash = source_hash === nothing ? nothing : _g3ce_digest(source_hash, "slot source_hash")
        why = reason === nothing ? nothing : _g3ce_text(reason, "slot reason")
        absent_hash = absence_content_hash === nothing ? nothing : _g3ce_digest(absence_content_hash, "slot absence_content_hash")
        if st === :present
            ref !== nothing && path !== nothing && hash !== nothing || throw(ArgumentError("present slot requires ref/path/hash"))
            why === nothing && absent_hash === nothing || throw(ArgumentError("present slot cannot carry absence"))
        else
            ref === nothing && path === nothing && hash === nothing || throw(ArgumentError("typed absent slot cannot carry present data"))
            why !== nothing && absent_hash !== nothing || throw(ArgumentError("typed absent slot requires reason/hash"))
            expected = canonical_hash((domain="g3-control-provenance-slot-absence-v1",
                slot_kind=kind, status=:typed_absent, candidate_ref=candidate, reason=why))
            absent_hash == expected || throw(ArgumentError("slot absence hash mismatch"))
        end
        new(kind, st, ref, path, hash, candidate, why, absent_hash)
    end
end

struct G3ControlSourceRecordV1
    record_uri::String
    record_version::String
    payload_schema_version::G3ControlProvenanceSlotV1
    canonicalization_profile_version::G3ControlProvenanceSlotV1
    applicability_profile_version::G3ControlProvenanceSlotV1
    evidence_receipt_version::G3ControlProvenanceSlotV1
    source_record_hash::Digest256
    function G3ControlSourceRecordV1(record_uri::Any, record_version::Any,
            payload_schema_version::Any, canonicalization_profile_version::Any,
            applicability_profile_version::Any, evidence_receipt_version::Any,
            source_record_hash::Any)
        uri = _g3ce_text(record_uri, "record_uri")
        version = _g3ce_text(record_version, "record_version")
        slots = (payload_schema_version, canonicalization_profile_version,
            applicability_profile_version, evidence_receipt_version)
        all(x -> x isa G3ControlProvenanceSlotV1, slots) || throw(ArgumentError("invalid source record slot"))
        kinds = Tuple(x.slot_kind for x in slots)
        kinds == G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1 || throw(ArgumentError("source record slot order mismatch"))
        candidates = Tuple(x.candidate_ref for x in slots)
        all(x -> _g3ce_ref_equal(x, candidates[1]), candidates) || throw(ArgumentError("source record candidates mismatch"))
        hash = _g3ce_digest(source_record_hash, "source_record_hash")
        record = new(uri, version, slots[1], slots[2], slots[3], slots[4], hash)
        hash == canonical_hash(_g3ce_source_record_body(record)) || throw(ArgumentError("source_record_hash mismatch"))
        record
    end
end

struct G3ControlSourceRecordRefV1
    record_uri::String
    record_version::String
    record_hash::Digest256
    function G3ControlSourceRecordRefV1(record_uri::Any, record_version::Any, record_hash::Any)
        new(_g3ce_text(record_uri, "record_uri"), _g3ce_text(record_version, "record_version"),
            _g3ce_digest(record_hash, "record_hash"))
    end
end

struct G3ControlParentDeclarationBindingV1
    candidate_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    declaration_hash::Digest256
    binding_hash::Digest256
    function G3ControlParentDeclarationBindingV1(candidate_ref::Any, declaration_ref::Any,
            declaration_hash::Any, binding_hash::Any)
        c = _g3ce_candidate(candidate_ref)
        d = _g3ce_parent(declaration_ref)
        h = _g3ce_digest(declaration_hash, "declaration_hash")
        b = _g3ce_digest(binding_hash, "binding_hash")
        expected = canonical_hash((candidate_ref=c, declaration_ref=d, declaration_hash=h))
        b == expected || throw(ArgumentError("parent binding hash mismatch"))
        new(c, d, h, b)
    end
end

struct G3ControlSourcePayloadRefV1
    candidate_ref::QualifiedRefV1
    parent_binding::G3ControlParentDeclarationBindingV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_contract_ref::GenomeContractRef
    child_contract_identity_hash::Digest256
    source_record_ref::G3ControlSourceRecordRefV1
    source_content_hash::Digest256
    function G3ControlSourcePayloadRefV1(candidate_ref::Any, parent_binding::Any,
            parent_ref::Any, parent_hash::Any, child_ref::Any, child_hash::Any,
            source_ref::Any, content_hash::Any)
        c = _g3ce_candidate(candidate_ref)
        p = parent_binding isa G3ControlParentDeclarationBindingV1 ? parent_binding : throw(ArgumentError("invalid parent binding"))
        pr = _g3ce_parent(parent_ref)
        ph = _g3ce_digest(parent_hash, "parent hash")
        cr = child_ref isa GenomeContractRef ? child_ref : throw(ArgumentError("invalid child contract ref"))
        ch = _g3ce_digest(child_hash, "child identity hash")
        sr = source_ref isa G3ControlSourceRecordRefV1 ? source_ref : throw(ArgumentError("invalid source record ref"))
        sh = _g3ce_digest(content_hash, "source content hash")
        _g3ce_ref_equal(p.candidate_ref, c) && _g3ce_ref_equal(p.declaration_ref, pr) && p.declaration_hash == ph ||
            throw(ArgumentError("payload ref parent binding mismatch"))
        ch == canonical_hash((child_contract_ref=cr,)) || throw(ArgumentError("child identity hash mismatch"))
        new(c, p, pr, ph, cr, ch, sr, sh)
    end
end

struct G3ControlSourcePayloadV1
    key::G3ControlChildKeyV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_contract_ref::GenomeContractRef
    child_contract_identity_hash::Digest256
    source_uri::String
    source_version::String
    body::G3ControlSourceBodyV1
    source_record::G3ControlSourceRecordV1
    source_content_hash::Digest256
    function G3ControlSourcePayloadV1(key::Any, parent_ref::Any, parent_hash::Any,
            child_ref::Any, child_hash::Any, source_uri::Any, source_version::Any,
            body::Any, source_record::Any, content_hash::Any)
        k = key isa G3ControlChildKeyV1 ? key : throw(ArgumentError("invalid child key"))
        p = _g3ce_parent(parent_ref)
        h = _g3ce_digest(parent_hash, "parent hash")
        h == k.parent_g3_declaration_hash || throw(ArgumentError("parent hash/key mismatch"))
        cr = child_ref isa GenomeContractRef ? child_ref : throw(ArgumentError("invalid child contract ref"))
        ch = _g3ce_digest(child_hash, "child identity hash")
        ch == canonical_hash((child_contract_ref=cr,)) || throw(ArgumentError("child identity hash mismatch"))
        u = _g3ce_text(source_uri, "source_uri")
        v = _g3ce_text(source_version, "source_version")
        b = body isa G3ControlSourceBodyV1 ? body : throw(ArgumentError("invalid source body"))
        r = source_record isa G3ControlSourceRecordV1 ? source_record : throw(ArgumentError("invalid source record"))
        u == r.record_uri && v == r.record_version || throw(ArgumentError("source URI/version record mismatch"))
        slots = (r.payload_schema_version, r.canonicalization_profile_version,
            r.applicability_profile_version, r.evidence_receipt_version)
        all(slot -> _g3ce_ref_equal(slot.candidate_ref, k.candidate_ref), slots) ||
            throw(ArgumentError("source provenance candidate/key mismatch"))
        k.child_kind === G3_CONTROL_CHILD_EDIT_KIND_V1 ||
            throw(ArgumentError("payload child kind mismatch"))
        source_hash = _g3ce_digest(content_hash, "source_content_hash")
        payload = new(k, p, h, cr, ch, u, v, b, r, source_hash)
        source_hash == canonical_hash(_g3ce_source_content_body(payload)) ||
            throw(ArgumentError("source_content_hash mismatch"))
        derived_ref = _g3ce_payload_ref(payload)
        _g3ce_ref_equal(derived_ref.candidate_ref, k.candidate_ref) &&
            _g3ce_ref_equal(derived_ref.parent_binding.candidate_ref, k.candidate_ref) &&
            _g3ce_ref_equal(derived_ref.parent_g3_declaration_ref, p) &&
            derived_ref.parent_g3_declaration_hash == k.parent_g3_declaration_hash &&
            derived_ref.child_contract_ref == cr &&
            derived_ref.child_contract_identity_hash == ch ||
            throw(ArgumentError("payload parent/child binding mismatch"))
        payload
    end
end

struct G3ControlOperationRecordV1
    operation_id::String
    operation_kind::Symbol
    key::G3ControlChildKeyV1
    fault_id::String
    expected_prior_mode::Symbol
    resulting_mode::Symbol
    previous_state_hash::Digest256
    expected_prior_source_content_hash::Digest256
    prior_editable_body_hash::Digest256
    replacement_editable_body_hash::Digest256
    source_record_ref::G3ControlSourceRecordRefV1
    source_payload_ref::G3ControlSourcePayloadRefV1
    operation_hash::Digest256
    resulting_state_hash::Digest256
end

struct G3ControlStateV1
    key::G3ControlChildKeyV1
    source_payload_ref::Union{Nothing,G3ControlSourcePayloadRefV1}
    editable_body::Union{Nothing,G3ControlSourceBodyV1}
    initial_source_content_hash::Union{Nothing,Digest256}
    state_status::Symbol
    absence_reason::Union{Nothing,String}
    absence_content_hash::Union{Nothing,Digest256}
    missing_slots::Tuple{Vararg{Symbol}}
    initial_state_hash::Digest256
    current_state_hash::Digest256
    last_operation_hash::Digest256
    contract_admission::Symbol
    physical_resolution::Symbol
    operation_history::Tuple{Vararg{G3ControlOperationRecordV1}}
    function G3ControlStateV1(key::Any, source_payload_ref::Any, editable_body::Any,
            initial_source_content_hash::Any, state_status::Any, absence_reason::Any,
            absence_content_hash::Any, missing_slots::Any, initial_state_hash::Any,
            current_state_hash::Any, last_operation_hash::Any, contract_admission::Any,
            physical_resolution::Any, operation_history::Any)
        k = key isa G3ControlChildKeyV1 ? key : throw(ArgumentError("invalid state key"))
        status = _g3ce_symbol(state_status, (:present, :typed_absent), "state_status")
        admission = _g3ce_symbol(contract_admission, G3_CONTROL_CHILD_EDIT_CONTRACT_STATUSES_V1, "contract_admission")
        physical = _g3ce_symbol(physical_resolution, (:unknown, :terminal_deferred), "physical_resolution")
        payload_ref = source_payload_ref === nothing ? nothing : source_payload_ref isa G3ControlSourcePayloadRefV1 ? source_payload_ref : throw(ArgumentError("invalid state payload ref"))
        body = editable_body === nothing ? nothing : editable_body isa G3ControlSourceBodyV1 ? editable_body : throw(ArgumentError("invalid editable body"))
        initial_source = initial_source_content_hash === nothing ? nothing : _g3ce_digest(initial_source_content_hash, "initial source hash")
        missing = _g3ce_tuple(missing_slots, "missing_slots")
        all(x -> x isa Symbol && x in G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1, missing) || throw(ArgumentError("invalid missing slot"))
        length(unique(missing)) == length(missing) || throw(ArgumentError("duplicate missing slot"))
        history = _g3ce_tuple(operation_history, "operation_history")
        all(x -> x isa G3ControlOperationRecordV1, history) || throw(ArgumentError("invalid operation record"))
        length(unique(x.operation_id for x in history)) == length(history) || throw(ArgumentError("duplicate operation id"))
        initial = _g3ce_digest(initial_state_hash, "initial_state_hash")
        current = _g3ce_digest(current_state_hash, "current_state_hash")
        last = _g3ce_digest(last_operation_hash, "last_operation_hash")
        reason = absence_reason === nothing ? nothing : _g3ce_text(absence_reason, "absence_reason")
        absence = absence_content_hash === nothing ? nothing : _g3ce_digest(absence_content_hash, "absence_content_hash")
        if status === :present
            payload_ref !== nothing && body !== nothing && initial_source !== nothing || throw(ArgumentError("present state requires payload/body/source"))
            reason === nothing && absence === nothing && isempty(missing) || throw(ArgumentError("present state cannot carry absence"))
            admission === :declared_consistent || throw(ArgumentError("present state admission"))
        else
            payload_ref === nothing && body === nothing && initial_source === nothing || throw(ArgumentError("typed absent state carries present data"))
            reason !== nothing && absence !== nothing || throw(ArgumentError("typed absent state absence fields"))
            isempty(history) || throw(ArgumentError("typed absent state cannot have history"))
            admission === :terminal_deferred || throw(ArgumentError("typed absent admission"))
        end
        previous = initial
        for record in history
            record.operation_kind === :replace_fault_source_payload || throw(ArgumentError("operation kind mismatch"))
            record.key == k || throw(ArgumentError("operation key mismatch"))
            record.previous_state_hash == previous || throw(ArgumentError("operation previous-state chain mismatch"))
            record.operation_hash == canonical_hash(_g3ce_operation_record_body(record)) ||
                throw(ArgumentError("operation record hash mismatch"))
            status === :present || throw(ArgumentError("typed absent history"))
            _g3ce_payload_ref_equal(record.source_payload_ref, payload_ref) ||
                throw(ArgumentError("operation payload ref mismatch"))
            _g3ce_source_ref_equal(record.source_record_ref, payload_ref.source_record_ref) ||
                throw(ArgumentError("operation source record ref mismatch"))
            record.resulting_state_hash != G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1 ||
                throw(ArgumentError("operation resulting state hash is zero"))
            previous = record.resulting_state_hash
        end
        expected_last = isempty(history) ? G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1 : history[end].operation_hash
        last == expected_last || throw(ArgumentError("last_operation_hash mismatch"))
        if isempty(history)
            initial_expected = _g3ce_initial_hash(k, status, payload_ref, body, initial_source,
                reason, absence, missing, admission, physical)
            initial == initial_expected || throw(ArgumentError("initial_state_hash mismatch"))
        else
            initial != G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1 ||
                throw(ArgumentError("non-empty history requires initial hash"))
        end
        current_expected = _g3ce_state_hash(k, status, payload_ref, body, initial_source,
            reason, absence, missing, admission, physical, history)
        current == current_expected || throw(ArgumentError("current_state_hash mismatch"))
        isempty(history) || history[end].resulting_state_hash == current ||
            throw(ArgumentError("terminal resulting state hash mismatch"))
        new(k, payload_ref, body, initial_source, status, reason, absence, Tuple(missing),
            initial, current, last, admission, physical, Tuple(history))
    end
end

struct G3ControlReplaceFaultSourcePayloadV1
    operation_id::String
    key::G3ControlChildKeyV1
    fault_id::String
    expected_prior_mode::Symbol
    resulting_mode::Symbol
    expected_prior_state_hash::Digest256
    expected_prior_source_content_hash::Digest256
    replacement_editable_body::G3ControlSourceBodyV1
    source_record_ref::G3ControlSourceRecordRefV1
    source_payload_ref::G3ControlSourcePayloadRefV1
    prior_editable_body_hash::Digest256
    replacement_editable_body_hash::Digest256
    operation_hash::Digest256
    function G3ControlReplaceFaultSourcePayloadV1(operation_id::Any, key::Any,
            fault_id::Any, expected_prior_mode::Any, resulting_mode::Any,
            expected_prior_state_hash::Any, expected_prior_source_content_hash::Any,
            replacement_editable_body::Any, source_record_ref::Any,
            source_payload_ref::Any, prior_editable_body_hash::Any,
            replacement_editable_body_hash::Any, operation_hash::Any)
        new(_g3ce_text(operation_id, "operation_id"),
            key isa G3ControlChildKeyV1 ? key : throw(ArgumentError("invalid operation key")),
            _g3ce_text(fault_id, "operation fault_id"),
            _g3ce_symbol(expected_prior_mode, G3_CONTROL_CHILD_EDIT_FAULT_MODES_V1, "expected prior mode"),
            _g3ce_symbol(resulting_mode, G3_CONTROL_CHILD_EDIT_FAULT_MODES_V1, "resulting mode"),
            _g3ce_digest(expected_prior_state_hash, "expected prior state hash"),
            _g3ce_digest(expected_prior_source_content_hash, "expected prior source hash"),
            replacement_editable_body isa G3ControlSourceBodyV1 ? replacement_editable_body : throw(ArgumentError("invalid replacement body")),
            source_record_ref isa G3ControlSourceRecordRefV1 ? source_record_ref : throw(ArgumentError("invalid operation source ref")),
            source_payload_ref isa G3ControlSourcePayloadRefV1 ? source_payload_ref : throw(ArgumentError("invalid operation payload ref")),
            _g3ce_digest(prior_editable_body_hash, "prior editable body hash"),
            _g3ce_digest(replacement_editable_body_hash, "replacement editable body hash"),
            _g3ce_digest(operation_hash, "operation hash"))
    end
end

struct G3ControlOperationReceiptV1
    operation_id::String
    operation_hash::Digest256
    source_record_ref::G3ControlSourceRecordRefV1
    source_payload_ref::G3ControlSourcePayloadRefV1
    initial_state_hash::Digest256
    state_hash::Digest256
    contract_admission::Symbol
    physical_resolution::Symbol
end

struct G3ControlReplaceResultV1
    status::Symbol
    state::G3ControlStateV1
    receipt::Union{Nothing,G3ControlOperationReceiptV1}
    errors::Tuple{Vararg{String}}
    function G3ControlReplaceResultV1(status::Any, state::Any, receipt::Any, errors::Any)
        s = _g3ce_symbol(status, G3_CONTROL_CHILD_EDIT_RESULT_STATUSES_V1, "result status")
        state isa G3ControlStateV1 || throw(ArgumentError("result state type"))
        receipt === nothing || receipt isa G3ControlOperationReceiptV1 || throw(ArgumentError("result receipt type"))
        es = _g3ce_tuple(errors, "result errors")
        all(x -> x isa AbstractString, es) || throw(ArgumentError("result errors must be strings"))
        s === :applied && receipt === nothing && throw(ArgumentError("applied result requires receipt"))
        s !== :applied && receipt !== nothing && throw(ArgumentError("failed result cannot carry receipt"))
        new(s, state, receipt, Tuple(String(x) for x in es))
    end
    function G3ControlReplaceResultV1(status::Any, state::Any, receipt::Any, errors::Any,
            ::Val{:internal_program_exception})
        status === :program_exception || throw(ArgumentError("program exception constructor"))
        state isa G3ControlStateV1 || throw(ArgumentError("result state type"))
        receipt === nothing || throw(ArgumentError("program exception receipt"))
        es = _g3ce_tuple(errors, "result errors")
        new(:program_exception, state, nothing, Tuple(String(x) for x in es))
    end
end

semantic_view(x::G3ControlChildKeyV1) =
    (candidate_ref=x.candidate_ref, parent_g3_declaration_hash=x.parent_g3_declaration_hash,
     child_kind=x.child_kind, child_id=x.child_id)
semantic_view(x::G3ControlSignalV1) =
    (port_id=x.port_id, signal_kind=x.signal_kind, direction=x.direction,
     unit=x.unit, account_id=x.account_id)
semantic_view(x::G3ControlInitialStateV1) =
    (state_id=x.state_id, unit=x.unit, value=x.value)
semantic_view(x::G3ControlEventV1) =
    (event_id=x.event_id, trigger=x.trigger, time=x.time, action=x.action)
semantic_view(x::G3ControlControllerV1) =
    (controller_id=x.controller_id, sensor_port_ids=x.sensor_port_ids,
     actuator_port_ids=x.actuator_port_ids,
     actuator_resource_port_ids=x.actuator_resource_port_ids,
     fault_ids=x.fault_ids, initial_states=x.initial_states, events=x.events)
semantic_view(x::G3ControlFaultV1) =
    (fault_id=x.fault_id, target_id=x.target_id, mode=x.mode,
     safe_action=x.safe_action, detection_signal_id=x.detection_signal_id,
     deadline=x.deadline)
semantic_view(x::G3ControlPlanV1) =
    (controller_ids=x.controller_ids, signal_port_ids=x.signal_port_ids, fault_ids=x.fault_ids)
semantic_view(x::G3ControlSourceBodyV1) =
    (source_id=x.source_id, owner_scope=x.owner_scope, signal_ports=x.signal_ports,
     controllers=x.controllers, faults=x.faults, plan=x.plan)
semantic_view(x::G3ControlProvenanceSlotV1) =
    (slot_kind=x.slot_kind, status=x.status, value_ref=x.value_ref,
     source_path=x.source_path, source_hash=x.source_hash, candidate_ref=x.candidate_ref,
     reason=x.reason, absence_content_hash=x.absence_content_hash)
semantic_view(x::G3ControlSourceRecordV1) =
    (record_uri=x.record_uri, record_version=x.record_version,
     payload_schema_version=x.payload_schema_version,
     canonicalization_profile_version=x.canonicalization_profile_version,
     applicability_profile_version=x.applicability_profile_version,
     evidence_receipt_version=x.evidence_receipt_version,
     source_record_hash=x.source_record_hash)
semantic_view(x::G3ControlSourceRecordRefV1) =
    (record_uri=x.record_uri, record_version=x.record_version, record_hash=x.record_hash)
semantic_view(x::G3ControlParentDeclarationBindingV1) =
    (candidate_ref=x.candidate_ref, declaration_ref=x.declaration_ref,
     declaration_hash=x.declaration_hash, binding_hash=x.binding_hash)
semantic_view(x::G3ControlSourcePayloadRefV1) =
    (candidate_ref=x.candidate_ref, parent_binding=x.parent_binding,
     parent_g3_declaration_ref=x.parent_g3_declaration_ref,
     parent_g3_declaration_hash=x.parent_g3_declaration_hash,
     child_contract_ref=x.child_contract_ref,
     child_contract_identity_hash=x.child_contract_identity_hash,
     source_record_ref=x.source_record_ref, source_content_hash=x.source_content_hash)
semantic_view(x::G3ControlSourcePayloadV1) =
    (key=x.key, parent_g3_declaration_ref=x.parent_g3_declaration_ref,
     parent_g3_declaration_hash=x.parent_g3_declaration_hash,
     child_contract_ref=x.child_contract_ref,
     child_contract_identity_hash=x.child_contract_identity_hash,
     source_uri=x.source_uri, source_version=x.source_version, body=x.body,
     source_record=x.source_record, source_content_hash=x.source_content_hash)
semantic_view(x::G3ControlOperationRecordV1) =
    (operation_id=x.operation_id, operation_kind=x.operation_kind, key=x.key,
     fault_id=x.fault_id, expected_prior_mode=x.expected_prior_mode,
     resulting_mode=x.resulting_mode, previous_state_hash=x.previous_state_hash,
     expected_prior_source_content_hash=x.expected_prior_source_content_hash,
     prior_editable_body_hash=x.prior_editable_body_hash,
     replacement_editable_body_hash=x.replacement_editable_body_hash,
     source_record_ref=x.source_record_ref, source_payload_ref=x.source_payload_ref,
     operation_hash=x.operation_hash, resulting_state_hash=x.resulting_state_hash)
semantic_view(x::G3ControlStateV1) =
    (key=x.key, source_payload_ref=x.source_payload_ref, editable_body=x.editable_body,
     initial_source_content_hash=x.initial_source_content_hash, state_status=x.state_status,
     absence_reason=x.absence_reason, absence_content_hash=x.absence_content_hash,
     missing_slots=x.missing_slots, initial_state_hash=x.initial_state_hash,
     current_state_hash=x.current_state_hash, last_operation_hash=x.last_operation_hash,
     contract_admission=x.contract_admission, physical_resolution=x.physical_resolution,
     operation_history=x.operation_history)
semantic_view(x::G3ControlReplaceFaultSourcePayloadV1) =
    (operation_id=x.operation_id, key=x.key, fault_id=x.fault_id,
     expected_prior_mode=x.expected_prior_mode, resulting_mode=x.resulting_mode,
     expected_prior_state_hash=x.expected_prior_state_hash,
     expected_prior_source_content_hash=x.expected_prior_source_content_hash,
     replacement_editable_body=x.replacement_editable_body,
     source_record_ref=x.source_record_ref, source_payload_ref=x.source_payload_ref,
     prior_editable_body_hash=x.prior_editable_body_hash,
     replacement_editable_body_hash=x.replacement_editable_body_hash,
     operation_hash=x.operation_hash)
semantic_view(x::G3ControlOperationReceiptV1) =
    (operation_id=x.operation_id, operation_hash=x.operation_hash,
     source_record_ref=x.source_record_ref, source_payload_ref=x.source_payload_ref,
     initial_state_hash=x.initial_state_hash, state_hash=x.state_hash,
     contract_admission=x.contract_admission, physical_resolution=x.physical_resolution)
semantic_view(x::G3ControlReplaceResultV1) =
    (status=x.status, state=x.state, receipt=x.receipt, errors=x.errors)

_g3ce_semantic_equal(a, b) = canonical_json(semantic_view(a)) == canonical_json(semantic_view(b))
Base.:(==)(a::G3ControlSignalV1, b::G3ControlSignalV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlInitialStateV1, b::G3ControlInitialStateV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlEventV1, b::G3ControlEventV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlControllerV1, b::G3ControlControllerV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlFaultV1, b::G3ControlFaultV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlPlanV1, b::G3ControlPlanV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlSourceBodyV1, b::G3ControlSourceBodyV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlProvenanceSlotV1, b::G3ControlProvenanceSlotV1) = _g3ce_semantic_equal(a, b)
Base.:(==)(a::G3ControlSourceRecordV1, b::G3ControlSourceRecordV1) = _g3ce_semantic_equal(a, b)

Base.:(==)(a::G3ControlChildKeyV1, b::G3ControlChildKeyV1) =
    _g3ce_ref_equal(a.candidate_ref, b.candidate_ref) &&
    a.parent_g3_declaration_hash == b.parent_g3_declaration_hash &&
    a.child_kind === b.child_kind && a.child_id == b.child_id
Base.:(==)(a::G3ControlSourceRecordRefV1, b::G3ControlSourceRecordRefV1) = semantic_view(a) == semantic_view(b)
Base.:(==)(a::G3ControlParentDeclarationBindingV1, b::G3ControlParentDeclarationBindingV1) =
    _g3ce_ref_equal(a.candidate_ref, b.candidate_ref) &&
    _g3ce_ref_equal(a.declaration_ref, b.declaration_ref) &&
    a.declaration_hash == b.declaration_hash && a.binding_hash == b.binding_hash
Base.:(==)(a::G3ControlSourcePayloadRefV1, b::G3ControlSourcePayloadRefV1) =
    _g3ce_payload_ref_equal(a, b)

_g3ce_source_record_body(record::G3ControlSourceRecordV1) =
    (record_uri=record.record_uri, record_version=record.record_version,
     payload_schema_version=record.payload_schema_version,
     canonicalization_profile_version=record.canonicalization_profile_version,
     applicability_profile_version=record.applicability_profile_version,
     evidence_receipt_version=record.evidence_receipt_version)
_g3ce_parent_binding(payload) = G3ControlParentDeclarationBindingV1(
    payload.key.candidate_ref, payload.parent_g3_declaration_ref,
    payload.parent_g3_declaration_hash,
    canonical_hash((candidate_ref=payload.key.candidate_ref,
        declaration_ref=payload.parent_g3_declaration_ref,
        declaration_hash=payload.parent_g3_declaration_hash)))
_g3ce_source_record_ref(payload) = G3ControlSourceRecordRefV1(
    payload.source_record.record_uri, payload.source_record.record_version,
    payload.source_record.source_record_hash)
_g3ce_child_identity(payload) = canonical_hash((child_contract_ref=payload.child_contract_ref,))
_g3ce_payload_ref(payload) = G3ControlSourcePayloadRefV1(
    payload.key.candidate_ref, _g3ce_parent_binding(payload),
    payload.parent_g3_declaration_ref, payload.parent_g3_declaration_hash,
    payload.child_contract_ref, _g3ce_child_identity(payload),
    _g3ce_source_record_ref(payload), payload.source_content_hash)
_g3ce_source_content_body(payload) =
    (key=payload.key, parent_g3_declaration_ref=payload.parent_g3_declaration_ref,
     child_contract_ref=payload.child_contract_ref,
     source_uri=payload.source_uri, source_version=payload.source_version,
     body=payload.body, source_record_ref=_g3ce_source_record_ref(payload))

function _g3ce_validate_body(body::G3ControlSourceBodyV1)
    errors = String[]
    signals = Dict(x.port_id => x for x in body.signal_ports)
    controllers = Dict(x.controller_id => x for x in body.controllers)
    faults = Dict(x.fault_id => x for x in body.faults)
    for controller in body.controllers
        for id in controller.sensor_port_ids
            haskey(signals, id) || push!(errors, "missing_sensor_port:" * id)
            haskey(signals, id) && signals[id].direction in G3_CONTROL_CHILD_EDIT_SIGNAL_DIRECTIONS_IN_V1 ||
                (haskey(signals, id) && push!(errors, "sensor_direction_invalid:" * id))
        end
        for id in controller.actuator_port_ids
            haskey(signals, id) || push!(errors, "missing_actuator_port:" * id)
            haskey(signals, id) && signals[id].direction in G3_CONTROL_CHILD_EDIT_SIGNAL_DIRECTIONS_OUT_V1 ||
                (haskey(signals, id) && push!(errors, "actuator_direction_invalid:" * id))
        end
        for id in controller.actuator_resource_port_ids
            haskey(signals, id) || push!(errors, "missing_actuator_resource_port:" * id)
        end
        for id in controller.fault_ids
            haskey(faults, id) || push!(errors, "missing_controller_fault:" * id)
        end
    end
    for fault in body.faults
        haskey(controllers, fault.target_id) || push!(errors, "fault_target_missing:" * fault.fault_id)
        haskey(signals, fault.detection_signal_id) || push!(errors, "fault_detection_signal_missing:" * fault.fault_id)
        haskey(controllers, fault.target_id) && fault.target_id in body.plan.controller_ids ||
            (haskey(controllers, fault.target_id) && push!(errors, "fault_target_not_planned:" * fault.fault_id))
    end
    Set(body.plan.controller_ids) == Set(keys(controllers)) || push!(errors, "control_plan_controller_mismatch")
    Set(body.plan.signal_port_ids) == Set(keys(signals)) || push!(errors, "control_plan_signal_mismatch")
    Set(body.plan.fault_ids) == Set(keys(faults)) || push!(errors, "control_plan_fault_mismatch")
    unique!(errors)
end

function _g3ce_initial_hash(key, status, payload_ref, body, initial_source,
        reason, absence, missing, admission, physical)
    canonical_hash((domain="g3-control-initial-state-v1", key=key, state_status=status,
        source_payload_ref=payload_ref, editable_body=body,
        initial_source_content_hash=initial_source, absence_reason=reason,
        absence_content_hash=absence, missing_slots=missing,
        contract_admission=admission, physical_resolution=physical,
        last_operation_hash=G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1,
        operation_history=()))
end

_g3ce_history_hashes(history) = Tuple(x.operation_hash for x in history)
function _g3ce_state_hash(key, status, payload_ref, body, initial_source,
        reason, absence, missing, admission, physical, history)
    isempty(history) && return _g3ce_initial_hash(key, status, payload_ref, body,
        initial_source, reason, absence, missing, admission, physical)
    last = isempty(history) ? G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1 : history[end].operation_hash
    canonical_hash((domain="g3-control-current-state-v1", key=key, state_status=status,
        source_payload_ref=payload_ref, editable_body=body,
        initial_source_content_hash=initial_source, absence_reason=reason,
        absence_content_hash=absence, missing_slots=missing,
        contract_admission=admission, physical_resolution=physical,
        last_operation_hash=last, operation_history=_g3ce_history_hashes(history)))
end

function _g3ce_operation_body(operation::G3ControlReplaceFaultSourcePayloadV1)
    (domain="g3-control-replace-fault-source-payload-v1",
     operation_id=operation.operation_id, key=operation.key,
     fault_id=operation.fault_id, expected_prior_mode=operation.expected_prior_mode,
     resulting_mode=operation.resulting_mode,
     expected_prior_state_hash=operation.expected_prior_state_hash,
     expected_prior_source_content_hash=operation.expected_prior_source_content_hash,
     prior_editable_body_hash=operation.prior_editable_body_hash,
     replacement_editable_body_hash=operation.replacement_editable_body_hash,
     source_record_ref=operation.source_record_ref,
     source_payload_ref=operation.source_payload_ref)
end

function _g3ce_operation_record_body(record::G3ControlOperationRecordV1)
    (domain="g3-control-replace-fault-source-payload-v1",
     operation_id=record.operation_id, key=record.key,
     fault_id=record.fault_id, expected_prior_mode=record.expected_prior_mode,
     resulting_mode=record.resulting_mode,
     expected_prior_state_hash=record.previous_state_hash,
     expected_prior_source_content_hash=record.expected_prior_source_content_hash,
     prior_editable_body_hash=record.prior_editable_body_hash,
     replacement_editable_body_hash=record.replacement_editable_body_hash,
     source_record_ref=record.source_record_ref,
     source_payload_ref=record.source_payload_ref)
end

function _g3ce_operation_record(operation, resulting_state_hash)
    G3ControlOperationRecordV1(operation.operation_id,
        :replace_fault_source_payload, operation.key, operation.fault_id,
        operation.expected_prior_mode, operation.resulting_mode,
        operation.expected_prior_state_hash,
        operation.expected_prior_source_content_hash,
        operation.prior_editable_body_hash,
        operation.replacement_editable_body_hash,
        operation.source_record_ref, operation.source_payload_ref,
        operation.operation_hash, resulting_state_hash)
end

function _g3ce_fault_mode(body, fault_id)
    found = nothing
    for fault in body.faults
        fault.fault_id == fault_id && (found = fault; break)
    end
    found
end

function _g3ce_replace_fault_mode(body::G3ControlSourceBodyV1, fault_id, mode)
    rebuilt = G3ControlFaultV1[]
    found = false
    for fault in body.faults
        if fault.fault_id == fault_id
            found = true
            push!(rebuilt, G3ControlFaultV1(fault.fault_id, fault.target_id, mode,
                fault.safe_action, fault.detection_signal_id, fault.deadline))
        else
            push!(rebuilt, fault)
        end
    end
    found || throw(ArgumentError("unknown fault"))
    G3ControlSourceBodyV1(body.source_id, body.owner_scope, body.signal_ports,
        body.controllers, Tuple(rebuilt), body.plan)
end

function _g3ce_source_ref_equal(a, b)
    a.record_uri == b.record_uri && a.record_version == b.record_version && a.record_hash == b.record_hash
end

function _g3ce_payload_ref_equal(a, b)
    _g3ce_ref_equal(a.candidate_ref, b.candidate_ref) &&
    a.parent_binding == b.parent_binding &&
    _g3ce_ref_equal(a.parent_g3_declaration_ref, b.parent_g3_declaration_ref) &&
    a.parent_g3_declaration_hash == b.parent_g3_declaration_hash &&
    a.child_contract_ref == b.child_contract_ref &&
    a.child_contract_identity_hash == b.child_contract_identity_hash &&
    a.source_record_ref == b.source_record_ref &&
    a.source_content_hash == b.source_content_hash
end

function g3_control_initial_state_v1(key::G3ControlChildKeyV1,
        payload::G3ControlSourcePayloadV1)
    key == payload.key || throw(ArgumentError("state key/payload key mismatch"))
    isempty(_g3ce_validate_body(payload.body)) || throw(ArgumentError("control body is not locally admissible"))
    ref = _g3ce_payload_ref(payload)
    initial = _g3ce_initial_hash(key, :present, ref, payload.body,
        payload.source_content_hash, nothing, nothing, (), :declared_consistent, :unknown)
    state = _g3ce_state_hash(key, :present, ref, payload.body,
        payload.source_content_hash, nothing, nothing, (), :declared_consistent, :unknown, ())
    G3ControlStateV1(key, ref, payload.body, payload.source_content_hash, :present,
        nothing, nothing, (), initial, state, G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1,
        :declared_consistent, :unknown, ())
end

function g3_control_typed_absent_state_v1(key::G3ControlChildKeyV1, reason::Any;
        missing_slots=G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1,
        physical_resolution=:terminal_deferred)
    why = _g3ce_text(reason, "absence reason")
    missing = _g3ce_tuple(missing_slots, "missing_slots")
    all(x -> x isa Symbol && x in G3_CONTROL_CHILD_EDIT_SLOT_KINDS_V1, missing) || throw(ArgumentError("invalid missing slot"))
    length(unique(missing)) == length(missing) || throw(ArgumentError("missing slots must be unique"))
    physical = _g3ce_symbol(physical_resolution, (:unknown, :terminal_deferred), "physical_resolution")
    absence = canonical_hash((domain="g3-control-state-absence-v1", key=key,
        state_status=:typed_absent, reason=why, missing_slots=missing,
        physical_resolution=physical, last_operation_hash=G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1,
        operation_history=()))
    initial = _g3ce_initial_hash(key, :typed_absent, nothing, nothing, nothing,
        why, absence, missing, :terminal_deferred, physical)
    state = _g3ce_state_hash(key, :typed_absent, nothing, nothing, nothing,
        why, absence, missing, :terminal_deferred, physical, ())
    G3ControlStateV1(key, nothing, nothing, nothing, :typed_absent, why, absence,
        missing, initial, state, G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1,
        :terminal_deferred, physical, ())
end

function g3_control_admit_v1(key::G3ControlChildKeyV1,
        payload::G3ControlSourcePayloadV1)
    errors = _g3ce_validate_body(payload.body)
    isempty(errors) && return g3_control_initial_state_v1(key, payload)
    g3_control_typed_absent_state_v1(key, "control admission conflict: " * join(errors, ",");
        missing_slots=(), physical_resolution=:terminal_deferred)
end

function g3_control_admit_source_v1(key::G3ControlChildKeyV1,
        parent_ref::QualifiedRefV1, body::G3ControlSourceBodyV1,
        child_ref::GenomeContractRef, source_record::G3ControlSourceRecordV1)
    slots = (source_record.payload_schema_version, source_record.canonicalization_profile_version,
        source_record.applicability_profile_version, source_record.evidence_receipt_version)
    missing = Tuple(s.slot_kind for s in slots if s.status === :typed_absent)
    !isempty(missing) && return g3_control_typed_absent_state_v1(key,
        "source provenance unavailable"; missing_slots=missing)
    try
        identity = canonical_hash((child_contract_ref=child_ref,))
        payload_ref_body = (key=key, parent_g3_declaration_ref=parent_ref,
            parent_g3_declaration_hash=key.parent_g3_declaration_hash,
            child_contract_ref=child_ref, child_contract_identity_hash=identity,
            source_uri=source_record.record_uri,
            source_version=source_record.record_version, body=body,
            source_record=source_record)
        content = canonical_hash((key=key, parent_g3_declaration_ref=parent_ref,
            child_contract_ref=child_ref, source_uri=source_record.record_uri,
            source_version=source_record.record_version, body=body,
            source_record_ref=G3ControlSourceRecordRefV1(source_record.record_uri,
                source_record.record_version, source_record.source_record_hash)))
        payload = G3ControlSourcePayloadV1(key, parent_ref,
            key.parent_g3_declaration_hash, child_ref, identity,
            source_record.record_uri, source_record.record_version, body,
            source_record, content)
        g3_control_initial_state_v1(key, payload)
    catch err
        g3_control_typed_absent_state_v1(key, "source admission conflict: " * string(typeof(err));
            missing_slots=(), physical_resolution=:terminal_deferred)
    end
end

function g3_control_replace_operation_v1(operation_id::Any,
        key::G3ControlChildKeyV1, fault_id::Any, expected_prior_mode::Any,
        resulting_mode::Any, expected_prior_state_hash::Digest256,
        expected_prior_source_content_hash::Digest256,
        replacement_editable_body::G3ControlSourceBodyV1,
        source_record_ref::G3ControlSourceRecordRefV1,
        source_payload_ref::G3ControlSourcePayloadRefV1,
        prior_editable_body_hash::Digest256,
        replacement_editable_body_hash::Digest256)
    draft = G3ControlReplaceFaultSourcePayloadV1(operation_id, key, fault_id,
        expected_prior_mode, resulting_mode, expected_prior_state_hash,
        expected_prior_source_content_hash, replacement_editable_body,
        source_record_ref, source_payload_ref, prior_editable_body_hash,
        replacement_editable_body_hash, G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1)
    G3ControlReplaceFaultSourcePayloadV1(draft.operation_id, draft.key, draft.fault_id,
        draft.expected_prior_mode, draft.resulting_mode, draft.expected_prior_state_hash,
        draft.expected_prior_source_content_hash, draft.replacement_editable_body,
        draft.source_record_ref, draft.source_payload_ref, draft.prior_editable_body_hash,
        draft.replacement_editable_body_hash, canonical_hash(_g3ce_operation_body(draft)))
end

function _g3ce_fail(state, status, errors)
    G3ControlReplaceResultV1(status, state, nothing, Tuple(String(e) for e in errors))
end

function replace_fault_source_payload(state::G3ControlStateV1,
        operation::G3ControlReplaceFaultSourcePayloadV1)
    try
        state.state_status === :present || return _g3ce_fail(state, :terminal_deferred, ("typed_absent_state",))
        operation.key == state.key || return _g3ce_fail(state, :fail_closed, ("child_key_mismatch",))
        operation.operation_hash == canonical_hash(_g3ce_operation_body(operation)) ||
            return _g3ce_fail(state, :fail_closed, ("operation_hash_mismatch",))
        operation.operation_id in Tuple(x.operation_id for x in state.operation_history) &&
            return _g3ce_fail(state, :fail_closed, ("duplicate_operation_id",))
        operation.expected_prior_state_hash == state.current_state_hash ||
            return _g3ce_fail(state, :fail_closed, ("stale_state_hash",))
        operation.expected_prior_source_content_hash == state.initial_source_content_hash ||
            return _g3ce_fail(state, :fail_closed, ("stale_source_content_hash",))
        _g3ce_source_ref_equal(operation.source_record_ref,
            state.source_payload_ref.source_record_ref) ||
            return _g3ce_fail(state, :fail_closed, ("source_record_ref_mismatch",))
        _g3ce_payload_ref_equal(operation.source_payload_ref,
            state.source_payload_ref) ||
            return _g3ce_fail(state, :fail_closed, ("source_payload_ref_mismatch",))
        operation.replacement_editable_body.source_id == state.editable_body.source_id ||
            return _g3ce_fail(state, :fail_closed, ("source_id_mutation",))
        operation.replacement_editable_body.owner_scope == state.editable_body.owner_scope ||
            return _g3ce_fail(state, :fail_closed, ("owner_scope_mutation",))
        operation.replacement_editable_body.signal_ports == state.editable_body.signal_ports ||
            return _g3ce_fail(state, :fail_closed, ("signal_ports_mutation",))
        operation.replacement_editable_body.controllers == state.editable_body.controllers ||
            return _g3ce_fail(state, :fail_closed, ("controllers_mutation",))
        operation.replacement_editable_body.plan == state.editable_body.plan ||
            return _g3ce_fail(state, :fail_closed, ("plan_mutation",))
        prior = _g3ce_fault_mode(state.editable_body, operation.fault_id)
        prior === nothing && return _g3ce_fail(state, :fail_closed, ("unknown_fault",))
        prior.mode == operation.expected_prior_mode || return _g3ce_fail(state, :fail_closed, ("prior_mode_mismatch",))
        length(operation.replacement_editable_body.faults) == length(state.editable_body.faults) ||
            return _g3ce_fail(state, :fail_closed, ("fault_count_mutation",))
        changed = Tuple(i for i in eachindex(state.editable_body.faults)
            if state.editable_body.faults[i] != operation.replacement_editable_body.faults[i])
        length(changed) == 1 || return _g3ce_fail(state, :fail_closed, ("must_change_one_fault",))
        replacement_fault = operation.replacement_editable_body.faults[first(changed)]
        replacement_fault.fault_id == operation.fault_id || return _g3ce_fail(state, :fail_closed, ("fault_id_mutation",))
        replacement_fault.mode == operation.resulting_mode || return _g3ce_fail(state, :fail_closed, ("resulting_mode_mismatch",))
        replacement_fault.mode != prior.mode || return _g3ce_fail(state, :fail_closed, ("mode_not_changed",))
        replacement_fault.target_id == prior.target_id || return _g3ce_fail(state, :fail_closed, ("fault_target_mutation",))
        replacement_fault.safe_action == prior.safe_action || return _g3ce_fail(state, :fail_closed, ("fault_safe_action_mutation",))
        replacement_fault.detection_signal_id == prior.detection_signal_id || return _g3ce_fail(state, :fail_closed, ("fault_detection_signal_mutation",))
        replacement_fault.deadline == prior.deadline || return _g3ce_fail(state, :fail_closed, ("fault_deadline_mutation",))
        operation.prior_editable_body_hash == canonical_hash(state.editable_body) ||
            return _g3ce_fail(state, :fail_closed, ("prior_body_hash_mismatch",))
        operation.replacement_editable_body_hash == canonical_hash(operation.replacement_editable_body) ||
            return _g3ce_fail(state, :fail_closed, ("replacement_body_hash_mismatch",))
        isempty(_g3ce_validate_body(operation.replacement_editable_body)) ||
            return _g3ce_fail(state, :fail_closed, ("replacement_body_invalid",))
        operation_body_hash = canonical_hash(_g3ce_operation_body(operation))
        operation_body_hash == operation.operation_hash || return _g3ce_fail(state, :fail_closed, ("operation_hash_mismatch",))
        # State hashing uses operation hashes only, so resulting_state_hash is
        # computed after operation_hash without a recursive hash dependency.
        record_template = _g3ce_operation_record(operation,
            G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1)
        provisional_history = (state.operation_history..., record_template)
        new_state_hash = _g3ce_state_hash(state.key, :present,
            state.source_payload_ref, operation.replacement_editable_body,
            state.initial_source_content_hash, nothing, nothing, (),
            :declared_consistent, :unknown, provisional_history)
        final_record = _g3ce_operation_record(operation, new_state_hash)
        final_history = (state.operation_history..., final_record)
        final_state_hash = _g3ce_state_hash(state.key, :present,
            state.source_payload_ref, operation.replacement_editable_body,
            state.initial_source_content_hash, nothing, nothing, (),
            :declared_consistent, :unknown, final_history)
        final_state_hash == new_state_hash || throw(ArgumentError("state hash transition mismatch"))
        new_state = G3ControlStateV1(state.key, state.source_payload_ref,
            operation.replacement_editable_body, state.initial_source_content_hash,
            :present, nothing, nothing, (), state.initial_state_hash,
            final_state_hash, operation.operation_hash, :declared_consistent,
            :unknown, final_history)
        receipt = G3ControlOperationReceiptV1(operation.operation_id,
            operation.operation_hash, operation.source_record_ref,
            operation.source_payload_ref, state.initial_state_hash,
            final_state_hash, :declared_consistent, :unknown)
        G3ControlReplaceResultV1(:applied, new_state, receipt, ())
    catch err
        G3ControlReplaceResultV1(:program_exception, state, nothing,
            (string(typeof(err)),), Val(:internal_program_exception))
    end
end

const g3_control_replace_fault_source_payload_v1 = replace_fault_source_payload

g3_control_source_record_ref_v1(payload::G3ControlSourcePayloadV1) = _g3ce_source_record_ref(payload)
g3_control_parent_binding_v1(payload::G3ControlSourcePayloadV1) = _g3ce_parent_binding(payload)
g3_control_source_payload_ref_v1(payload::G3ControlSourcePayloadV1) = _g3ce_payload_ref(payload)
g3_control_canonical_bytes_v1(x) = Vector{UInt8}(codeunits(canonical_json(semantic_view(x))))

export G3_CONTROL_CHILD_EDIT_SCHEMA_ID_V1, G3_CONTROL_CHILD_EDIT_VERSION_V1,
       G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1, G3_CONTROL_CHILD_EDIT_PROFILE_V1,
       G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1, G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
       G3_CONTROL_CHILD_EDIT_KIND_V1, G3_CONTROL_CHILD_EDIT_ZERO_DIGEST_V1,
       G3ControlChildKeyV1, G3ControlSignalV1, G3ControlInitialStateV1,
       G3ControlEventV1, G3ControlControllerV1, G3ControlFaultV1,
       G3ControlPlanV1, G3ControlSourceBodyV1, G3ControlProvenanceSlotV1,
       G3ControlSourceRecordV1, G3ControlSourceRecordRefV1,
       G3ControlParentDeclarationBindingV1, G3ControlSourcePayloadRefV1,
       G3ControlSourcePayloadV1, G3ControlOperationRecordV1, G3ControlStateV1,
       G3ControlReplaceFaultSourcePayloadV1, G3ControlOperationReceiptV1,
       G3ControlReplaceResultV1, g3_control_child_edit_schema_hash_v1,
       g3_control_child_edit_canonicalization_hash_v1,
       g3_control_child_edit_profile_hash_v1, g3_control_initial_state_v1,
       g3_control_typed_absent_state_v1, g3_control_admit_v1,
       g3_control_admit_source_v1, g3_control_replace_operation_v1,
       replace_fault_source_payload, g3_control_replace_fault_source_payload_v1,
       g3_control_source_record_ref_v1, g3_control_parent_binding_v1,
       g3_control_source_payload_ref_v1, g3_control_canonical_bytes_v1
