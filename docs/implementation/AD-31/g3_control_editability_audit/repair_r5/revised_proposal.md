# AD-31 G3 control child editability audit — revised proposal R5

Date: 2026-09-15  
Revision: `R5`  
Parent records preserved: R1 [audit](../report.md), R2 [proposal](../repair_r2/revised_proposal.md), R3 [proposal](../repair_r3/revised_proposal.md), and R4 [proposal](../repair_r4/revised_proposal.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R5 is a proposal-only repair. It closes the remaining identity and executable
failure-evidence gaps. R1--R4 remain byte-preserved.

## Decision and scope

`GO` remains pending a different Luna independent review. This proposal does
not authorize implementation, Julia/DESC, T0 import, actual child authority,
provider, engineering or physical execution. The bounded slice remains one
control-only candidate-owned state edit: exactly one existing fault's `mode`
may change.

The future node is a sibling of the realization precursor and T0. It depends
only on `UP2-01-G3-SOURCE-FEEDBACK-V1` and the accepted AD-31 architecture
boundary; it must not depend on realization implementation or T0. T1 remains
the only future owner of a fresh same-candidate lossless mapping into
`CandidateStatePackageV5Next`. Old G3 V5 types, package, registry, T0 records,
historical receipts and hashes remain read-only.

## Closed control records

The implementation must define new local closed records. `Dict`, open
`NamedTuple`, JSON blobs, dynamic paths, old V5 objects and `Any` semantic
bodies are rejected. Canonical field order is frozen.

```text
G3ControlSignalV1(
    port_id::String, signal_kind::Symbol, direction::Symbol,
    unit::UnitSignature, account_id::String)
    # direction: :in | :out | :bidirectional

G3ControlInitialStateV1(state_id::String, unit::UnitSignature,
                        value::Rational{Int64})

G3ControlEventV1(event_id::String, trigger::Symbol,
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

The constructors enforce valid UTF-8, non-empty strings, immutable declared
tuple order, namespace uniqueness, signal direction/unit references,
controller cardinalities, fault target/detection references and exact plan set
membership. These are local control-contract invariants only.

## Exact provenance and identity records

The child key is:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,           # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                      # fixed :control
    child_id::String)
```

The parent binding is a closed record whose binding digest is independently
derived:

```text
G3ControlParentDeclarationBindingV1(
    candidate_ref::QualifiedRefV1,
    declaration_ref::QualifiedRefV1,          # version=v1
    declaration_hash::Digest256,
    binding_hash::Digest256)
```

`binding_hash = H(canonical(candidate_ref, declaration_ref,
declaration_hash))`, excluding `binding_hash`. The binding candidate equals
the child key candidate; `declaration_hash` equals the child key parent hash.
Neither a ref URI nor a copied hash label can satisfy this relation.

The exact provenance slot is:

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

`slot_kind` is one of `:payload_schema_version`,
`:canonicalization_profile_version`, `:applicability_profile_version`, or
`:evidence_receipt_version`; `status` is `:present` or `:typed_absent`. A
present slot requires value ref, source path and source hash and rejects
reason/absence hash. A typed-absent slot requires reason and absence hash and
rejects value/source fields. The slot candidate always equals the child
candidate, including absence.

The slot absence digest is:

```text
absence_content_hash = H(canonical(
    domain="g3-control-provenance-slot-absence-v1",
    slot_kind, status=:typed_absent, candidate_ref, reason))
```

The absence digest itself is excluded. Its reason is non-empty valid UTF-8.

The exact source record field order is:

```text
G3ControlSourceRecordV1(
    record_uri::String,
    record_version::String,
    payload_schema_version::G3ControlProvenanceSlotV1,
    canonicalization_profile_version::G3ControlProvenanceSlotV1,
    applicability_profile_version::G3ControlProvenanceSlotV1,
    evidence_receipt_version::G3ControlProvenanceSlotV1,
    source_record_hash::Digest256)

G3ControlSourceRecordRefV1(
    record_uri::String, record_version::String, record_hash::Digest256)
```

`source_record_hash = H(canonical(record_uri, record_version, all four
complete slots))`, excluding itself and all downstream hashes. The source
record's own `record_uri` and `record_version` are the authority. A
`SourceRecordRefV1` is valid only when its URI, version and hash equal those
three source-record fields byte-for-byte; no separate source URI/version label
may substitute for them.

The complete immutable source payload ref is:

```text
G3ControlSourcePayloadRefV1(
    candidate_ref::QualifiedRefV1,
    parent_binding::G3ControlParentDeclarationBindingV1,
    parent_g3_declaration_ref::QualifiedRefV1,
    parent_g3_declaration_hash::Digest256,
    child_contract_ref::GenomeContractRef,
    child_contract_identity_hash::Digest256,
    source_record_ref::G3ControlSourceRecordRefV1,
    source_content_hash::Digest256)
```

The actual additive child contract identity is exact:

```text
child_contract_identity_hash =
    H(canonical(child_contract_ref))
```

The identity hash excludes itself. The payload reference carries the complete
parent binding, actual child contract ref/hash and source-record URI/version/
hash. The full payload additionally carries `source_uri`, `source_version`
and the closed source body; `source_uri == source_record.record_uri` and
`source_version == source_record.record_version` are required. The source
content hash is:

```text
H(canonical(key, parent_binding, parent_g3_declaration_ref,
  parent_g3_declaration_hash, child_contract_ref,
  child_contract_identity_hash, source_uri, source_version,
  source_record_ref, body))
```

It excludes itself and belongs to the immutable source payload.

## State, typed absence and physical deferral

Physical status is typed:

```text
G3ControlPhysicalResolutionV1(
    status::Symbol,                          # :unknown | :terminal_deferred
    reason::Union{Nothing,String},
    evidence_ref::Union{Nothing,QualifiedRefV1})
```

`:unknown` requires `reason=nothing,evidence_ref=nothing`. `:terminal_deferred`
requires a non-empty typed reason; evidence ref is nothing or a real external
receipt. Local software cannot promote either status.

The state field order is:

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

Present state requires source ref, editable body and initial source hash;
absence fields are nothing. Typed-absent state requires all three source/edit
fields to be nothing, a non-empty absence reason, an absence digest and
`contract_admission=:terminal_deferred`; no edit is admitted.

The state absence digest is:

```text
state_absence_content_hash = H(canonical(
    domain="g3-control-state-absence-v1",
    key, state_status=:typed_absent,
    contract_admission=:terminal_deferred,
    physical_resolution, absence_reason,
    source_payload_ref=nothing, editable_body=nothing,
    initial_source_content_hash=nothing,
    last_operation_hash=ZERO_DIGEST,
    operation_history=typed_empty_tuple))
```

It excludes itself. The state `absence_content_hash` must equal this digest.

## Five hashes, operation history and ZERO rules

All hash inputs use canonical bytes: valid UTF-8 without BOM, LF line endings,
frozen ordinal field order, declared tuple order, exact symbol spelling,
normalized exact `Rational{Int64}`, lowercase fixed-width SHA-256 digests, and
explicit `nothing` fields. No map/set order, locale, float formatting or
platform newline is allowed.

The five principal layers are:

1. **Source record:** `H(canonical(record_uri, record_version, all four
   complete slots))`; own and downstream hashes excluded. Its ref is the
   exact byte-matching `(record_uri, record_version, record_hash)` triple.
2. **Source content:** `H(canonical(key, complete parent binding/ref/hash,
   actual child contract ref/hash, source URI/version, complete source-record
   ref, complete body))`; own hash excluded and immutable during editing.
3. **Initial state:** `H(canonical(state_status, source ref/body/hash or
   typed-absent marker, admission, typed physical resolution,
   operation_hash=ZERO_DIGEST, typed empty history))`; status is included and
   the digest is frozen forever.
4. **Operation:** the operation hash covers operation ID/kind, key, exact
   fault ID, before/after mode, `previous_state_hash`,
   `expected_prior_source_content_hash`, complete prior editable body hash,
   complete replacement editable body hash, exact `source_record_ref` and
   exact `source_payload_ref`. It excludes its own hash and resulting state
   hash.
5. **Resulting state:** `H(canonical(key, state_status,
   source_payload_ref, editable_body_after, initial source/state hashes,
   previous_state_hash, prior operation hashes in order, operation hash,
   last_operation_hash, admission, typed physical resolution))`; it contains
   no resulting-state hash as an input.

The exact operation record is:

```text
G3ControlOperationRecordV1(
    operation_id::String,
    operation_kind::Symbol,                  # :replace_fault_source_payload
    key::G3ControlChildKeyV1,
    fault_id::String,
    expected_prior_mode::Symbol,
    resulting_mode::Symbol,
    previous_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    prior_editable_body_hash::Digest256,
    replacement_editable_body_hash::Digest256,
    source_record_ref::G3ControlSourceRecordRefV1,
    source_payload_ref::G3ControlSourcePayloadRefV1,
    operation_hash::Digest256,
    resulting_state_hash::Digest256)
```

`operation_hash = H(canonical(operation_id, operation_kind, key, fault_id,
expected_prior_mode, resulting_mode, previous_state_hash,
expected_prior_source_content_hash, prior_editable_body_hash,
replacement_editable_body_hash, source_record_ref, source_payload_ref))`.
The complete prior and replacement bodies are independently hashed from their
canonical bytes before this recipe is evaluated.

`operation_history` is exactly
`Tuple{Vararg{G3ControlOperationRecordV1}}`. Operation IDs, operation hashes
and `(fault_id, previous_state_hash)` pairs are globally unique. Each
`previous_state_hash` equals the prior state hash; tuple order cannot change.

For empty history, `last_operation_hash=ZERO_DIGEST` and
`current_state_hash == initial_state_hash` exactly. The first operation uses
`previous_state_hash=initial_state_hash` and an empty prior-operation-hash
tuple. Later operations use the previous record's `resulting_state_hash`.
For typed absence, source/edit fields are nothing, the state absence digest is
used in the initial hash, history is the typed empty tuple,
`last_operation_hash=ZERO_DIGEST`, current equals initial, and edit returns the
same absent state.

## Fixed operation and executable failure invariance

The historical name `replace_fault_source_payload` is retained, but its
semantics are fixed: it replaces only the editable state body and never
rewrites the immutable source payload, source record/ref, axes, source hash,
parent binding, child contract identity or child key.

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

Admission requires exact same-candidate identity and refs, valid source-record
byte match, expected state/source hashes, and operation hash. The replacement
body must differ from current editable body in exactly one existing `fault_id`
and only its `mode`; all other fields, tuple order/count, plan bytes, units,
directions, targets, safe actions, detection signals, deadlines, events and
controller membership must be equal. The complete prior editable body hash and
replacement body hash are recomputed from bytes, never trusted from input.

On success, only editable body, operation history, operation hash,
`last_operation_hash` and current state hash change. On failure, the result
must preserve the old state canonical bytes exactly. The executable focused
test captures:

```text
before_bytes  = canonical_json(semantic_view(old_state))
before_hash   = sha256(before_bytes)
result        = replace_fault_source_payload(old_state, invalid_operation)
after_bytes   = canonical_json(semantic_view(result.state))
after_hash    = sha256(after_bytes)
assert after_bytes == before_bytes
assert after_hash == before_hash
```

Because the contract returns the original state on failure, the test also
asserts `result.state === old_state` when the repository runtime provides a
meaningful immutable-object identity check. If that check is unavailable for
the runtime, the byte and digest equality above are mandatory and sufficient;
no failure may return a semantically equal state with different canonical
bytes. The same check covers stale state/source, forged refs/hashes, foreign
identity, missing/duplicate fault, unsupported mode, non-mode or multi-fault
change, duplicate/reordered history, typed-absent edit, dynamic path,
insert/delete and rebind.

## Exit gate and evidence ceiling

The future implementation owns only:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`.

It must capture raw stdout/stderr, SHA-256, PID and exit code; a different Luna
must review source/ref identity, all five hashes, typed history, ZERO/absence
rules and failure byte invariance. This R5 audit itself does not run
Julia/DESC or edit code, tests, core planning files or old receipts.

Local contract admission remains separate from physical evidence. Physical
resolution remains typed `:unknown` or `:terminal_deferred` with a reason.
Control timing, actuator/resource capability, fault response, manufacturing,
thermal/structural feasibility, coupled compiled/discretized execution and
measured/solver evidence are external gates. No document, test, hash,
provider label or `bridge_ready` marker promotes them. Future acceptance can
only be `accepted_limited` software contract scope; T0/T1 mapping, provider,
engineering, mesh, solver, physical, search, B00, B04 and R01--R10 remain false.
