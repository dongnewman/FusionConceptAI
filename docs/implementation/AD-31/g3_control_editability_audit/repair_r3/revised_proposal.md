# AD-31 G3 control child editability audit — revised proposal R3

Date: 2026-09-15  
Revision: `R3`  
Parent records preserved: [R1 audit](../report.md) and [R2 proposal](../repair_r2/revised_proposal.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R3 is a proposal-only repair. R1 and R2 remain byte-preserved. This revision
freezes the source record/ref and typed-absent shapes, removes state-hash
self-recursion from the operation history recipe, and makes the immutable
source layer versus editable state layer mechanically checkable.

## Decision and scheduling boundary

`GO` remains pending a different Luna independent review. No implementation is
authorized by this record. The proposed slice is control-only, candidate-owned
and contract-only. It does not run Julia/DESC, import T0, populate a
realization/binding/feedback child, establish actual child authority, claim
provider/engineering/physical evidence, or close T0/T1/T2, B00/B04 or
R01--R10.

The future node is a sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and `UP1-04A-VNEXT-T0`. Its only task
dependency is `UP2-01-G3-SOURCE-FEEDBACK-V1` plus the accepted AD-31
architecture boundary. It must not depend on the realization implementation:
control validation uses no realization data, and a child-to-child edge would
create an unnecessary serial dependency before the later T1 exact join. T1 is
the only future owner of the source-backed lossless mapping into
`CandidateStatePackageV5Next`.

All old G3 V5 types, old bundle/package, shared entries, registry, T0 records,
historical receipts and hashes remain read-only.

## Closed control body and frozen record order

The new implementation must define disjoint local typed records. No `Dict`,
open `NamedTuple`, JSON blob, dynamic field path, old V5 object or `Any`
semantic body is allowed. The following field order is canonical and must be
used by constructors, `semantic_view`, hash recipes and receipts.

```text
G3ControlSignalV1(
    port_id::String,
    signal_kind::Symbol,                    # non-empty symbol
    direction::Symbol,                      # :in | :out | :bidirectional
    unit::UnitSignature,
    account_id::String)

G3ControlInitialStateV1(
    state_id::String,
    unit::UnitSignature,
    value::Rational{Int64})

G3ControlEventV1(
    event_id::String,
    trigger::Symbol,                        # :initial | :scheduled | :fault | :threshold
    time::Rational{Int64},                  # non-negative
    action::Symbol)                         # :enable | :disable | :hold | :trip | :recover

G3ControlControllerV1(
    controller_id::String,
    sensor_port_ids::Tuple{Vararg{String}},
    actuator_port_ids::Tuple{Vararg{String}},
    actuator_resource_port_ids::Tuple{Vararg{String}},
    fault_ids::Tuple{Vararg{String}},
    initial_states::Tuple{Vararg{G3ControlInitialStateV1}},
    events::Tuple{Vararg{G3ControlEventV1}})

G3ControlFaultV1(
    fault_id::String,
    target_id::String,
    mode::Symbol,                            # :open_circuit | :short_circuit |
                                             # :sensor_dropout | :actuator_stuck |
                                             # :overtemperature
    safe_action::Symbol,                     # :trip | :hold | :disable | :recover
    detection_signal_id::String,
    deadline::Rational{Int64})                # positive

G3ControlPlanV1(
    controller_ids::Tuple{Vararg{String}},
    signal_port_ids::Tuple{Vararg{String}},
    fault_ids::Tuple{Vararg{String}})

G3ControlSourceBodyV1(
    source_id::String,
    owner_scope::String,
    signal_ports::Tuple{Vararg{G3ControlSignalV1}},
    controllers::Tuple{Vararg{G3ControlControllerV1}},
    faults::Tuple{Vararg{G3ControlFaultV1}},
    plan::G3ControlPlanV1)
```

All strings are non-empty valid UTF-8. All collection tuples are immutable and
retain declared order. IDs are unique within each namespace. Sensor IDs must
resolve to `:in`/`:bidirectional` signals; actuator IDs to
`:out`/`:bidirectional`; resource actuator IDs and fault IDs must resolve.
Each controller has non-empty sensors and actuators, equal sensor/actuator
cardinality, and equal actuator/resource-actuator cardinality. Fault targets
and detection signals must resolve. Plan tuples are unique and set-equal to
the complete body collections. These constraints are local contract
invariants, not provider, engineering or physical evidence.

## Child identity and immutable source records

The key is closed and immutable:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,           # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                      # constructor fixes :control
    child_id::String)
```

The parent declaration ref is a separate typed
`QualifiedRefV1` with version `v1`; its hash must equal the key's parent hash.
The additive child contract ref and its identity hash are separate fields and
are never derived from a URI label.

The exact provenance slot type is:

```text
G3ControlProvenanceSlotV1(
    slot_kind::Symbol,                       # :payload_schema_version |
                                             # :canonicalization_profile_version |
                                             # :applicability_profile_version |
                                             # :evidence_receipt_version
    status::Symbol,                          # :present | :typed_absent
    value_ref::Union{Nothing,QualifiedRefV1},
    source_path::Union{Nothing,String},
    source_hash::Union{Nothing,Digest256},
    candidate_ref::QualifiedRefV1,            # always v5; binds absence too
    reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256})
```

For `:present`, `value_ref`, `source_path`, and `source_hash` are present;
`reason` and `absence_content_hash` are `nothing`. For `:typed_absent`,
`value_ref`, `source_path`, and `source_hash` are `nothing`; `reason` is a
non-empty string and `absence_content_hash` is present. The slot's candidate
ref must equal the child key candidate in both states. A typed absence is not
authority and cannot be converted into a present value by a local edit.

The exact source record field order is:

```text
G3ControlSourceRecordV1(
    source_uri::String,
    source_version::String,
    payload_schema_version::G3ControlProvenanceSlotV1,
    canonicalization_profile_version::G3ControlProvenanceSlotV1,
    applicability_profile_version::G3ControlProvenanceSlotV1,
    evidence_receipt_version::G3ControlProvenanceSlotV1,
    source_record_hash::Digest256)
```

Each slot's `slot_kind` must match its field position, all four slot candidate
refs must match, source URI/version must be non-empty valid UTF-8, and the
record hash is computed from the first six fields only. It excludes itself and
all source-content, operation, state and result hashes.

The exact source record reference is:

```text
G3ControlSourceRecordRefV1(
    record_uri::String,
    record_version::String,
    record_hash::Digest256)
```

The exact immutable source payload reference is:

```text
G3ControlSourcePayloadRefV1(
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_contract_identity_hash::Digest256,
    source_uri::String,
    source_version::String,
    source_record_hash::Digest256,
    source_content_hash::Digest256)
```

The full immutable payload is:

```text
G3ControlSourcePayloadV1(
    key::G3ControlChildKeyV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_contract_ref::GenomeContractRef,
    child_contract_identity_hash::Digest256,
    source_uri::String,
    source_version::String,
    body::G3ControlSourceBodyV1,
    source_record::G3ControlSourceRecordV1,
    source_content_hash::Digest256)
```

Its payload ref must be exactly derived from the corresponding payload. A
source URI/version, source record, four-axis slot, parent identity, child
contract or source body never changes in the fixed mode-edit operation.

## State layer and typed absence

The materialized state is separate from and points to the immutable source:

```text
G3ControlSourceStateV1(
    key::G3ControlChildKeyV1,
    source_payload_ref::Union{Nothing,G3ControlSourcePayloadRefV1},
    editable_body::Union{Nothing,G3ControlSourceBodyV1},
    initial_source_content_hash::Union{Nothing,Digest256},
    initial_state_hash::Digest256,
    current_state_hash::Digest256,
    last_operation_hash::Digest256,
    operation_history::Tuple,
    state_status::Symbol,                    # :present | :typed_absent
    contract_admission::Symbol,              # :declared_consistent | :terminal_deferred |
                                             # :fail_closed | :program_exception
    physical_resolution::Symbol,             # :unknown | :terminal_deferred
    absence_reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256})
```

For `state_status=:present`, `source_payload_ref`, `editable_body` and
`initial_source_content_hash` are present; `absence_reason` and
`absence_content_hash` are `nothing`; `source_payload_ref.source_content_hash`
equals `initial_source_content_hash`. The editable body initially equals the
source payload body.

For `state_status=:typed_absent`, `source_payload_ref`, `editable_body` and
`initial_source_content_hash` are `nothing`; `absence_reason` is non-empty;
`absence_content_hash` is present; and `contract_admission` is exactly
`:terminal_deferred`. No operation is valid on an absent state. Its state
identity contains the absence marker, so absence cannot be mistaken for an
empty control body or a fabricated source.

The initial status is included in the initial hash, rather than derived:

```text
initial_state_hash = H(canonical(
    key, state_status, source_payload_ref_or_nothing,
    editable_body_or_nothing, initial_source_content_hash_or_nothing,
    absence_reason_or_nothing, absence_content_hash_or_nothing,
    contract_admission, physical_resolution,
    operation_hash=ZERO_DIGEST, operation_history=()))
```

This formula is used once at construction and never recomputed after the first
state. A present state starts with `contract_admission=:declared_consistent`
only if all local checks pass; missing source provenance creates the typed
absent state instead. `physical_resolution` starts `:unknown` unless an
external, typed deferred reason is explicitly supplied; local construction
cannot promote it.

## Acyclic operation history and state hash

The fixed operation name remains `replace_fault_source_payload` for continuity
with R1/R2, but its precise meaning is **replace the editable materialized
state body only**. It never replaces, rewrites or rebinds the immutable source
payload. A future source rebind has a different work order and operation.

The exact operation record field order is:

```text
G3ControlOperationRecordV1(
    operation_id::String,
    operation_kind::Symbol,                  # exactly :replace_fault_source_payload
    key::G3ControlChildKeyV1,
    fault_id::String,
    expected_prior_mode::Symbol,
    resulting_mode::Symbol,
    previous_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    source_payload_ref::G3ControlSourcePayloadRefV1,
    operation_hash::Digest256,
    resulting_state_hash::Digest256)
```

The operation hash excludes `resulting_state_hash` and is:

```text
operation_hash = H(canonical(
    operation_id, operation_kind, key, fault_id,
    expected_prior_mode, resulting_mode,
    previous_state_hash, expected_prior_source_content_hash,
    source_payload_ref))
```

The new state hash is computed only after the operation hash and before the
record is appended:

```text
history_operation_hashes_before =
    Tuple(record.operation_hash for record in operation_history)

resulting_state_hash = H(canonical(
    key, state_status, source_payload_ref, editable_body_after,
    initial_source_content_hash, initial_state_hash,
    previous_state_hash, history_operation_hashes_before,
    operation_hash, contract_admission, physical_resolution))
```

The operation record then stores this resulting state hash. It is an audit
field only: neither `operation_hash` nor `history_operation_hashes_before`
includes it. Therefore the recipe has no current-state/self-recursive cycle.
The next operation's `previous_state_hash` must equal this resulting hash, so
the ordered hash chain remains fully linked without recursion. The current
state hash is the last resulting state hash, or the initial state hash when
history is empty.

The entire operation history is an ordered immutable tuple. Every record must
have the same key and source payload ref; each record's previous hash must
equal the prior state hash; its resulting hash must independently recompute;
operation IDs, operation hashes and `(fault_id, previous_state_hash)` pairs
must be globally unique. Reordering, omitting, duplicating or editing a record
fails closed. A record's result hash is never used to calculate its own
operation hash, eliminating the R2 recursion gap.

## Fixed mode-only edit

The operation input is:

```text
G3ControlReplaceFaultSourcePayloadV1(
    operation_id::String,
    key::G3ControlChildKeyV1,
    fault_id::String,
    expected_prior_mode::Symbol,
    expected_prior_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    replacement_edit_body::G3ControlSourceBodyV1,
    source_payload_ref::G3ControlSourcePayloadRefV1,
    source_record_ref::G3ControlSourceRecordRefV1,
    operation_hash::Digest256)
```

The operation verifies exact same-candidate key, parent hash, child contract,
source payload ref, source record ref and four-axis slots. It verifies the
expected state and immutable source hashes, then compares the complete
replacement body with the current editable body. Exactly one existing
`fault_id` may differ, and only its `mode` may change. The target's prior mode
must equal `expected_prior_mode`; the new mode must be in the fixed domain and
must differ. All source fields, signal/controller/plan tuples, target fault
identity, safe action, detection signal, deadline, controller membership,
events, units, directions and every non-target fault remain byte-semantically
equal. No source record, axis, identity or payload ref can be changed.

On success, the source payload, `source_content_hash`, source record hash,
axis slots, child key, parent hash, child contract identity,
`initial_source_content_hash` and `initial_state_hash` are unchanged. Only
`editable_body`, the appended operation record, `last_operation_hash` and
`current_state_hash` change. `contract_admission` remains local declared
consistency, and `physical_resolution` remains `:unknown` or explicit
`:terminal_deferred`.

Every failure returns the original state object and its canonical bytes
unchanged. Independent failure classes include stale state,
`stale_source_content_hash`, source/ref mismatch, foreign candidate/parent/key,
bad provenance, forged operation/source-record/replacement hash, missing or
duplicate fault, unsupported mode, changed non-target field, two changed
faults, duplicate/reordered history, dynamic path, insert, delete or rebind.
Typed absence returns the original absent state with `terminal_deferred`; it
does not create an editable empty body.

## Required controls and external evidence boundary

The future implementation must test all frozen field types/domains and
reference/cardinality/plan invariants; exact recomputation of source-record,
source-content, initial-state, operation and resulting-state hashes; immutable
source and initial hashes across a valid mode edit; previous-state chain and
full-history duplicate/order rejection; typed-absent construction; and
byte-identical prior state on every failure path.

Static and focused software receipts may establish only local
`contract_admission`. They cannot establish control timing, actuator/resource
capability, fault response, manufacturing/thermal/structural feasibility,
coupled compiled/discretized execution or measured/solver physical behavior.
`physical_resolution` therefore remains `unknown` or `terminal_deferred`.
No test, runner exit, provider label, child hash, document or `bridge_ready`
marker can promote it.

The future implementation owns only:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`.

It must not edit core planning files, task manifest, old V5/package/registry,
T0, realization precursor files or historical receipts. A different Luna must
review the implementation, raw stdout/stderr bytes, hashes, PID, exit code and
dirty protection before any limited acceptance.

The only possible future status is `accepted_limited` for this software
contract/editability slice. Actual child authority, T0/T1 mapping, provider,
engineering, mesh, solver, physical, search, B00, B04 and R01--R10 remain
false. The control and realization siblings feed T1 independently; no edge
between them is permitted.
