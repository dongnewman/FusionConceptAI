# AD-31 G3 control child editability audit — revised proposal R6

Date: 2026-09-15  
Revision: `R6`  
Parent records preserved: R1 [audit](../report.md), R2 [proposal](../repair_r2/revised_proposal.md), R3 [proposal](../repair_r3/revised_proposal.md), R4 [proposal](../repair_r4/revised_proposal.md), and R5 [proposal](../repair_r5/revised_proposal.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R6 is a proposal-only repair. R1--R5 remain byte-preserved. R5's closed
records, five hashes, canonical bytes, typed absence, fixed mode-only edit,
failure-byte invariance, control-only scope and evidence ceiling are inherited
unchanged except for the hard identity and transition invariants written here.

## Decision and DAG boundary

`GO` remains pending a different Luna independent review. This record does not
authorize implementation, Julia/DESC, T0 import, actual child authority,
provider, engineering or physical execution. The future node remains
`UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`, a sibling of the realization precursor
and T0. It depends only on `UP2-01-G3-SOURCE-FEEDBACK-V1` plus AD-31's accepted
architecture boundary and must not depend on realization implementation or T0.
T1 alone may later perform the fresh same-candidate lossless mapping into
`CandidateStatePackageV5Next`. Old G3 V5 types, package, registry, T0 records,
historical receipts and hashes remain read-only.

## Inherited closed control contract

The future implementation uses the R5 frozen local records and field order:

```text
G3ControlSignalV1(
    port_id::String, signal_kind::Symbol, direction::Symbol,
    unit::UnitSignature, account_id::String)
G3ControlInitialStateV1(state_id::String, unit::UnitSignature,
                        value::Rational{Int64})
G3ControlEventV1(event_id::String, trigger::Symbol,
                time::Rational{Int64}, action::Symbol)
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

The R5 symbol domains remain fixed: directions `:in|:out|:bidirectional`,
event triggers `:initial|:scheduled|:fault|:threshold`, event actions
`:enable|:disable|:hold|:trip|:recover`, fault modes
`:open_circuit|:short_circuit|:sensor_dropout|:actuator_stuck|:overtemperature`,
and safe actions `:trip|:hold|:disable|:recover`. Valid UTF-8, immutable
declared tuple order, unique IDs, direction/unit/reference/cardinality
constraints and exact plan set equality remain hard local invariants.

## Exact identity and hard constructor invariants

The child key remains the complete four-field identity:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,           # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                      # fixed :control
    child_id::String)
```

The parent binding remains:

```text
G3ControlParentDeclarationBindingV1(
    candidate_ref::QualifiedRefV1,
    declaration_ref::QualifiedRefV1,          # version=v1
    declaration_hash::Digest256,
    binding_hash::Digest256)
```

with `binding_hash = H(canonical(candidate_ref, declaration_ref,
declaration_hash))`, excluding its own field.

The source payload reference remains:

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

The following are constructor hard invariants, not derived warnings:

```text
payload.key.candidate_ref == payload_ref.candidate_ref
payload.key.parent_g3_declaration_hash == payload_ref.parent_g3_declaration_hash
payload.parent_g3_declaration_ref == payload_ref.parent_g3_declaration_ref
payload.parent_g3_declaration_hash == payload_ref.parent_g3_declaration_hash
payload.parent_binding.candidate_ref == payload.key.candidate_ref
payload.parent_binding.declaration_ref == payload.parent_g3_declaration_ref
payload.parent_binding.declaration_hash == payload.key.parent_g3_declaration_hash
payload.parent_binding.binding_hash ==
    H(canonical(payload.parent_binding.candidate_ref,
                payload.parent_binding.declaration_ref,
                payload.parent_binding.declaration_hash))
payload.child_contract_ref == payload_ref.child_contract_ref
payload.child_contract_identity_hash == payload_ref.child_contract_identity_hash
payload.child_contract_identity_hash ==
    H(canonical(payload.child_contract_ref))
payload.source_record_ref == payload_ref.source_record_ref
payload.source_record_ref.record_uri == payload.source_record.record_uri
payload.source_record_ref.record_version == payload.source_record.record_version
payload.source_record_ref.record_hash == payload.source_record.source_record_hash
payload.source_uri == payload.source_record.record_uri
payload.source_version == payload.source_record.record_version
payload.source_content_hash == payload_ref.source_content_hash
```

Any mismatch is `fail_closed`; no constructor may normalize one side or accept
a matching URI with a different digest. R5's slot type and source-record field
order remain fixed:

```text
G3ControlProvenanceSlotV1(
    slot_kind::Symbol, status::Symbol,
    value_ref::Union{Nothing,QualifiedRefV1},
    source_path::Union{Nothing,String},
    source_hash::Union{Nothing,Digest256},
    candidate_ref::QualifiedRefV1,
    reason::Union{Nothing,String},
    absence_content_hash::Union{Nothing,Digest256})

G3ControlSourceRecordV1(
    record_uri::String, record_version::String,
    payload_schema_version::G3ControlProvenanceSlotV1,
    canonicalization_profile_version::G3ControlProvenanceSlotV1,
    applicability_profile_version::G3ControlProvenanceSlotV1,
    evidence_receipt_version::G3ControlProvenanceSlotV1,
    source_record_hash::Digest256)
```

The record ref is the exact `(record_uri, record_version, record_hash)`
triple. Child contract identity, parent binding, source-record and source
content recipes remain R5's exact canonical recipes.

## State identity hard invariant

The state remains R5's closed record with
`source_payload_ref::Union{Nothing,G3ControlSourcePayloadRefV1}`,
`editable_body::Union{Nothing,G3ControlSourceBodyV1}`,
`initial_source_content_hash::Union{Nothing,Digest256}`,
`operation_history::Tuple{Vararg{G3ControlOperationRecordV1}}`, typed physical
resolution, and explicit absence fields.

R6 corrects the initial-state formula by writing the complete child key as an
explicit input. The present initial hash is:

```text
initial_state_hash = H(canonical(
    key.candidate_ref,
    key.parent_g3_declaration_hash,
    key.child_kind,
    key.child_id,
    state_status=:present,
    source_payload_ref,
    editable_body,
    initial_source_content_hash,
    absence_reason=nothing,
    absence_content_hash=nothing,
    contract_admission,
    physical_resolution,
    operation_hash=ZERO_DIGEST,
    operation_history=typed_empty_tuple))
```

The explicit key fields prevent two children with different candidate, parent,
kind or ID from sharing an initial hash even if their source bodies happen to
match. The canonical `key` record is also included as the first grouped field
when the repository canonicalizer serializes this tuple; implementations must
not omit or replace any of the four fields.

For a typed-absent initial state, replace `:present` and the source/edit/hash
values with the R5 absence marker: source ref, editable body and initial source
hash are `nothing`, `absence_reason` and the independently computed
`state_absence_content_hash` are present, admission is exactly
`:terminal_deferred`, physical resolution is typed, operation is ZERO and
history is the typed empty tuple. The complete key fields remain in the
formula. The absence hash is:

```text
H(canonical(
    domain="g3-control-state-absence-v1", key.candidate_ref,
    key.parent_g3_declaration_hash, key.child_kind, key.child_id,
    state_status=:typed_absent,
    contract_admission=:terminal_deferred,
    physical_resolution, absence_reason,
    source_payload_ref=nothing, editable_body=nothing,
    initial_source_content_hash=nothing,
    last_operation_hash=ZERO_DIGEST,
    operation_history=typed_empty_tuple))
```

It excludes its own absence hash. A typed-absent state cannot be edited.

## Operation chain hard invariants

The operation name remains `replace_fault_source_payload`, but it only changes
the editable state body and exactly one existing `fault.mode`. The immutable
source payload, source-record ref, axes, parent/child identities, source hash,
initial source hash and initial state hash never change.

The operation record remains the R5 closed order:

```text
G3ControlOperationRecordV1(
    operation_id::String,
    operation_kind::Symbol,
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

The operation hash directly covers both complete prior/replacement editable
body hashes, fault ID, before/after mode, previous state hash, exact source
record ref and exact source payload ref. It excludes operation and resulting
state hashes. The resulting state hash is computed afterward and contains the
ordered prior operation hashes, the new operation hash and the explicit
`last_operation_hash` value.

`last_operation_hash` is a hard invariant:

```text
isempty(operation_history) && last_operation_hash == ZERO_DIGEST
!isempty(operation_history) &&
    last_operation_hash == operation_history[end].operation_hash
```

For empty history, `current_state_hash == initial_state_hash` exactly. For a
present first operation, the required transition is:

```text
s0 = initial_state
op1.previous_state_hash == s0.current_state_hash == s0.initial_state_hash
op1.operation_hash = H(full_op1_identity)
s1.current_state_hash = H(state_after_op1, prior_hashes=(), op1.operation_hash,
                           last_operation_hash=op1.operation_hash)
history(s1) == (op1,)
s1.last_operation_hash == op1.operation_hash
op1.resulting_state_hash == s1.current_state_hash
```

For the second operation:

```text
op2.previous_state_hash == s1.current_state_hash
op2.operation_hash = H(full_op2_identity)
s2.current_state_hash = H(state_after_op2, prior_hashes=(op1.operation_hash,),
                           op2.operation_hash,
                           last_operation_hash=op2.operation_hash)
history(s2) == (op1, op2)
s2.last_operation_hash == op2.operation_hash
op2.resulting_state_hash == s2.current_state_hash
```

The constructor and transition function must reject a wrong previous hash,
wrong last hash, wrong resulting hash, reordered/omitted/duplicated operation,
duplicate operation ID/hash, or any history whose record key/source refs do not
match the state. Every rejection returns the old state's canonical bytes
unchanged.

## Fixed edit, failure check and evidence ceiling

Admission still requires exact same-candidate parent/child/source identity,
source-record ref byte-match, expected state/source hashes, complete prior and
replacement body hashes, and exactly one mode-only difference. All R5
negative controls remain mandatory.

For every failed operation, the focused test must execute:

```text
before_bytes = canonical_json(semantic_view(old_state))
before_hash  = sha256(before_bytes)
result = replace_fault_source_payload(old_state, invalid_operation)
after_bytes = canonical_json(semantic_view(result.state))
after_hash = sha256(after_bytes)
assert after_bytes == before_bytes
assert after_hash == before_hash
assert result.state === old_state when runtime identity is meaningful
```

If immutable-object identity is not meaningful in the runtime, the canonical
serialized bytes and digest equality are mandatory; no semantically equal but
different state serialization is accepted. This applies to stale/forged,
foreign, malformed, non-mode, multi-fault, duplicate/reordered, typed-absent,
dynamic, insert, delete and rebind failures.

The future implementation owns only the control source/test/archive paths
already frozen in R5. It must not edit core planning files, old V5/package/
registry, T0, realization files or receipts. A different Luna reviews R6
before implementation. Local contract evidence cannot promote typed physical
resolution; provider, engineering, mesh, solver, physical, search, B00, B04
and R01--R10 remain false.
