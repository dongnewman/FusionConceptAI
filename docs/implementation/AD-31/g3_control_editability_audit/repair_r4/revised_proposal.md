# AD-31 G3 control child editability audit — revised proposal R4

Date: 2026-09-15  
Revision: `R4`  
Parent records preserved: [R1 audit](../report.md), [R2 proposal](../repair_r2/revised_proposal.md), and [R3 proposal](../repair_r3/revised_proposal.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R4 is a proposal-only repair. It closes the remaining identity and receipt
gaps: operation records now carry and hash the exact source-record reference;
the source-payload reference carries the complete parent/child/source-record
identity; operation history is a closed parameterized typed tuple; empty and
typed-absent states have explicit ZERO rules; and physical deferral has a typed
reason. R1--R3 remain byte-preserved.

## Decision and scheduling boundary

`GO` remains pending a different Luna independent review. This record does not
authorize implementation, testing, Julia/DESC, T0 import, actual child
authority, provider, engineering or physical execution. The slice is
control-only and admits at most one existing fault mode edit in a local
contract state.

The proposed node is a sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and `UP1-04A-VNEXT-T0`. It depends
only on `UP2-01-G3-SOURCE-FEEDBACK-V1` and the accepted AD-31 architecture
boundary. It must not depend on realization, T0, binding or feedback-child
implementation. T1 remains the only later owner of the fresh same-candidate
lossless mapping into `CandidateStatePackageV5Next`.

Old G3 V5 types, old bundle/package, shared entries, registry, T0 records,
historical receipts and hashes remain read-only.

## Closed control body

The future implementation defines new local records with fixed canonical field
order. No `Dict`, open `NamedTuple`, JSON blob, dynamic field path, old V5
object or `Any` semantic body is accepted.

```text
G3ControlSignalV1(
    port_id::String, signal_kind::Symbol,
    direction::Symbol, unit::UnitSignature, account_id::String)
    # direction: :in | :out | :bidirectional

G3ControlInitialStateV1(
    state_id::String, unit::UnitSignature, value::Rational{Int64})

G3ControlEventV1(
    event_id::String, trigger::Symbol,
    time::Rational{Int64}, action::Symbol)
    # trigger: :initial | :scheduled | :fault | :threshold
    # action: :enable | :disable | :hold | :trip | :recover

G3ControlControllerV1(
    controller_id::String,
    sensor_port_ids::Tuple{Vararg{String}},
    actuator_port_ids::Tuple{Vararg{String}},
    actuator_resource_port_ids::Tuple{Vararg{String}},
    fault_ids::Tuple{Vararg{String}},
    initial_states::Tuple{Vararg{G3ControlInitialStateV1}},
    events::Tuple{Vararg{G3ControlEventV1}})

G3ControlFaultV1(
    fault_id::String, target_id::String, mode::Symbol,
    safe_action::Symbol, detection_signal_id::String,
    deadline::Rational{Int64})
    # mode: :open_circuit | :short_circuit | :sensor_dropout |
    #       :actuator_stuck | :overtemperature
    # safe_action: :trip | :hold | :disable | :recover

G3ControlPlanV1(
    controller_ids::Tuple{Vararg{String}},
    signal_port_ids::Tuple{Vararg{String}},
    fault_ids::Tuple{Vararg{String}})

G3ControlSourceBodyV1(
    source_id::String, owner_scope::String,
    signal_ports::Tuple{Vararg{G3ControlSignalV1}},
    controllers::Tuple{Vararg{G3ControlControllerV1}},
    faults::Tuple{Vararg{G3ControlFaultV1}}, plan::G3ControlPlanV1)
```

Strings are non-empty valid UTF-8; tuples are immutable and order-preserving.
IDs are unique within every namespace. Sensor/actuator directions,
controller cardinalities, resource actuator references, controller fault
membership, fault targets/detection signals and exact plan set membership are
validated with the same local semantics as old `ControlGenomeV5`.

## Candidate, parent, contract and source identity

The key is:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,           # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                      # constructor fixes :control
    child_id::String)
```

The parent declaration ref is a typed `QualifiedRefV1` with version `v1` and
must hash to the key's parent hash. The additive child contract ref is a real
`GenomeContractRef`; its identity hash is independently computed and is never
derived from a URI label.

The exact source-record slot is:

```text
G3ControlProvenanceSlotV1(
    slot_kind::Symbol,
    status::Symbol,
    value_ref::Union{Nothing,QualifiedRefV1},
    source_path::Union{Nothing,String},
    source_hash::Union{Nothing,Digest256},
    candidate_ref::QualifiedRefV1,
    reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256})
```

`slot_kind` is exactly one of `:payload_schema_version`,
`:canonicalization_profile_version`, `:applicability_profile_version`, or
`:evidence_receipt_version`; `status` is exactly `:present` or
`:typed_absent`. Present slots require value ref, source path and source hash,
and reject reason/absence hash. Typed-absent slots require reason and absence
hash and reject value ref/source path/source hash. The candidate ref is always
present and must equal the child key candidate, including for absence.

The source record field order is:

```text
G3ControlSourceRecordV1(
    source_uri::String,
    source_version::String,
    payload_schema_version::G3ControlProvenanceSlotV1,
    canonicalization_profile_version::G3ControlProvenanceSlotV1,
    applicability_profile_version::G3ControlProvenanceSlotV1,
    evidence_receipt_version::G3ControlProvenanceSlotV1,
    source_record_hash::Digest256)

G3ControlSourceRecordRefV1(
    record_uri::String, record_version::String, record_hash::Digest256)
```

The record hash covers the first six fields only. A source-record ref is an
exact URI/version/hash triple; a URI or version without its digest is not a
ref and cannot satisfy an operation.

The complete immutable source-payload reference is:

```text
G3ControlSourcePayloadRefV1(
    candidate_ref::QualifiedRefV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_contract_ref::GenomeContractRef,
    child_contract_identity_hash::Digest256,
    source_uri::String,
    source_version::String,
    source_record_ref::G3ControlSourceRecordRefV1,
    source_content_hash::Digest256)
```

This ref contains the actual additive child contract ref, parent G3 ref/hash,
source URI/version, and source-record URI/version/hash. It is complete enough
to identify the immutable payload without dereferencing an unbound label. The
full payload is:

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

The payload's derived `source_payload_ref` must equal the state ref exactly.
Parent, child contract, source record, axes and source content are immutable
for the fixed edit.

## State and typed physical deferral

Physical status is a closed typed record, not an unqualified symbol:

```text
G3ControlPhysicalResolutionV1(
    status::Symbol,                          # :unknown | :terminal_deferred
    reason::Union{Nothing,String},
    evidence_ref::Union{Nothing,QualifiedRefV1})
```

For `:unknown`, reason and evidence ref are `nothing`. For
`:terminal_deferred`, reason is a non-empty typed explanation and evidence ref
is either `nothing` or a real external receipt ref; a local test/runner/hash
cannot make it actual. The external physical obligation remains deferred.

The materialized state field order is:

```text
G3ControlSourceStateV1(
    key::G3ControlChildKeyV1,
    source_payload_ref::Union{Nothing,G3ControlSourcePayloadRefV1},
    editable_body::Union{Nothing,G3ControlSourceBodyV1},
    initial_source_content_hash::Union{Nothing,Digest256},
    initial_state_hash::Digest256,
    current_state_hash::Digest256,
    last_operation_hash::Digest256,
    operation_history::Tuple{Vararg{G3ControlOperationRecordV1}},
    state_status::Symbol,                    # :present | :typed_absent
    contract_admission::Symbol,               # :declared_consistent | :terminal_deferred |
                                              # :fail_closed | :program_exception
    physical_resolution::G3ControlPhysicalResolutionV1,
    absence_reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256})
```

The constructor accepts only the parameterized operation tuple; a tuple with
any other element type, a vector, open record or arbitrary object is rejected.
The empty history is the typed empty tuple
`Tuple{Vararg{G3ControlOperationRecordV1}}()` and has no implicit operation.

For `:present`, source ref, editable body and initial source hash are present,
absence fields are `nothing`, and the editable body initially equals the
immutable source body. For `:typed_absent`, source ref, editable body and
initial source hash are `nothing`, absence reason/hash are present, and
contract admission is exactly `:terminal_deferred`; no operation is admitted.

## Five hash layers and ZERO rules

All hashes use one canonical byte encoder: valid UTF-8 without BOM, LF line
endings, ordinal field order frozen above, declared tuple order, exact symbol
spelling, normalized exact `Rational{Int64}`, and lowercase fixed-width
SHA-256 digest text. No platform newline, map order, locale, floating-point
pretty printer or omitted `nothing` field is permitted. Every hash input is
the canonical bytes of the complete listed fields, and every excluded hash
field is omitted rather than zeroed.

The five main hashes are:

1. **Source-record hash**

   `H(canonical(source_uri, source_version,
   payload_schema_version, canonicalization_profile_version,
   applicability_profile_version, evidence_receipt_version))`.

   Each slot includes all eight slot fields in its frozen order. The record's
   own hash and every source-content, operation, state and result hash are
   excluded. A `G3ControlSourceRecordRefV1` is exactly
   `(record_uri, record_version, record_hash)` and must match the source record
   URI/version/hash byte-for-byte.

2. **Source-content hash**

   `H(canonical(key, parent_g3_declaration_ref,
   parent_g3_declaration_hash, child_contract_ref,
   child_contract_identity_hash, source_uri, source_version, body,
   source_record_ref))`.

   The source-record ref includes URI/version/hash. The source-content hash
   itself is excluded. This hash belongs to the immutable source payload and
   cannot change under the fixed mode edit.

3. **Initial-state hash**

   `H(canonical(key, state_status, source_payload_ref_or_nothing,
   editable_body_or_nothing, initial_source_content_hash_or_nothing,
   absence_reason_or_nothing, absence_content_hash_or_nothing,
   contract_admission, physical_resolution,
   operation_hash=ZERO_DIGEST, operation_history=typed_empty_tuple))`.

   Status and both status records are included explicitly. For a present state,
   the source ref/body/hash are present; for typed absence they are all
   `nothing` and the absence marker is present. This hash is computed once and
   remains immutable.

4. **Operation hash**

   The operation record has this exact field order:

   ```text
   G3ControlOperationRecordV1(
       operation_id::String,
       operation_kind::Symbol,                # :replace_fault_source_payload
       key::G3ControlChildKeyV1,
       fault_id::String,
       expected_prior_mode::Symbol,
       resulting_mode::Symbol,
       previous_state_hash::Digest256,
       expected_prior_source_content_hash::Digest256,
       source_record_ref::G3ControlSourceRecordRefV1,
       source_payload_ref::G3ControlSourcePayloadRefV1,
       operation_hash::Digest256,
       resulting_state_hash::Digest256)
   ```

   `operation_hash = H(canonical(operation_id, operation_kind, key, fault_id,
   expected_prior_mode, resulting_mode, previous_state_hash,
   expected_prior_source_content_hash, source_record_ref,
   source_payload_ref))`. The operation hash and resulting-state hash fields
   are excluded. Thus the exact source-record ref is both recorded and hashed,
   and cannot be replaced by a URI/version label.

5. **Resulting-state hash**

   After operation hash computation and before appending the record:

   `H(canonical(key, state_status, source_payload_ref, editable_body_after,
   initial_source_content_hash, initial_state_hash, previous_state_hash,
   prior_operation_hashes_in_order, operation_hash, contract_admission,
   physical_resolution))`.

   `prior_operation_hashes_in_order` is a tuple of operation hashes only; it
   contains no resulting-state hash. The resulting state hash is written into
   the operation record after it is calculated and is never an input to that
   operation's hash or to the prior-history digest. This is acyclic.

For an empty history, `last_operation_hash=ZERO_DIGEST` and
`current_state_hash == initial_state_hash` exactly; no second hash is silently
invented. The first operation uses `previous_state_hash=initial_state_hash`
and `prior_operation_hashes_in_order=()`. Every later operation uses the prior
record's resulting state hash as `previous_state_hash`. For typed absence,
`initial_source_content_hash=nothing`, source ref/body are `nothing`, history is
the typed empty tuple, `last_operation_hash=ZERO_DIGEST`, and
`current_state_hash == initial_state_hash`; edit returns the original absent
state unchanged.

## Fixed one-fault mode operation

The historical fixed operation name remains
`replace_fault_source_payload`, but its canonical semantics are **replace the
editable state body only**. It never changes the immutable source payload,
source record/ref, axes, source hash, parent identity or child identity. A
future source rebind is outside this work order.

```text
G3ControlReplaceFaultSourcePayloadV1(
    operation_id::String,
    key::G3ControlChildKeyV1,
    fault_id::String,
    expected_prior_mode::Symbol,
    expected_prior_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    replacement_edit_body::G3ControlSourceBodyV1,
    source_record_ref::G3ControlSourceRecordRefV1,
    source_payload_ref::G3ControlSourcePayloadRefV1,
    operation_hash::Digest256)
```

Admission verifies exact same-candidate key/parent/child/source identity,
source record ref, expected state/source hashes and operation hash. The complete
replacement body is compared with the current editable body. Exactly one
existing `fault_id` may differ, and only its `mode` may change to another
allowed mode. Every signal/controller/plan field and tuple byte, all non-target
fault fields, controller membership, target, safe action, detection signal,
deadline, units, directions, events and source metadata must remain equal.

On success, only editable body, operation history, operation hash,
`last_operation_hash` and resulting/current state hash change. The source
payload/ref, source-record ref/hash, axes, source-content hash,
initial-source hash, initial-state hash, key, parent and child identities are
unchanged.

On every failure, the function returns the original state's canonical bytes
exactly unchanged: no field, history tuple, digest, absence marker or status
may be rewritten. This includes stale state/source hash, source-record-ref
mismatch, foreign candidate/parent/key, malformed provenance, forged hashes,
missing/duplicate fault, unsupported mode, non-mode or multi-fault change,
duplicate/reordered history, dynamic path, insert, delete, rebind and any
typed-absent edit.

## Exit gate and evidence boundary

The future implementation owns exactly:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`.

It must capture raw focused stdout/stderr bytes, SHA-256, PID and exit code,
and a different Luna must review all hash layers, source-record refs, typed
history, failure byte invariance and dirty protection. This R4 audit itself
does not run Julia/DESC and does not edit code, tests, core planning files or
old receipts.

Local typed construction, hashes, tests and runner exits establish only
`contract_admission`. `physical_resolution` remains `:unknown` or typed
`:terminal_deferred` with a reason. Control timing, actuator/resource
capability, fault response, manufacturing/thermal/structural feasibility,
coupled compiled/discretized execution and measured/solver evidence remain
external gates. No document, test, hash, provider label or `bridge_ready`
marker promotes physical status.

Only `accepted_limited` software contract scope could be accepted later;
actual child authority, T0/T1 mapping, provider, engineering, mesh, solver,
physical, search, B00, B04 and R01--R10 remain false. The control and
realization siblings feed T1 independently; no edge between them is allowed.
