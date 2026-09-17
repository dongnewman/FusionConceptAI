# AD-31 G3 control child editability audit — revised proposal R7

Date: 2026-09-15  
Revision: `R7`  
Parent records preserved: R1 [audit](../report.md), R2 [proposal](../repair_r2/revised_proposal.md), R3 [proposal](../repair_r3/revised_proposal.md), R4 [proposal](../repair_r4/revised_proposal.md), R5 [proposal](../repair_r5/revised_proposal.md), and R6 [proposal](../repair_r6/revised_proposal.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R7 is a proposal-only repair. R1--R6 remain byte-preserved. This revision
chooses one identity rule everywhere: references are derived from their owning
payload and are never an independent second source of truth. It also chooses
one grouped child-key serialization in the initial-state hash.

## Decision and boundary

`GO` remains pending a different Luna independent review. No implementation,
Julia/DESC run, T0 import, actual child authority, provider, engineering or
physical execution is authorized by this proposal. The slice remains
control-only, candidate-owned, contract-only and limited to one existing fault
`mode` edit.

The future node is `UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`, a sibling of the
realization precursor and T0. It depends only on
`UP2-01-G3-SOURCE-FEEDBACK-V1` and the accepted AD-31 architecture boundary;
it must not depend on realization implementation or T0. T1 is the only future
owner of the fresh same-candidate lossless mapping into
`CandidateStatePackageV5Next`. Old G3 V5 types, package, registry, T0 records,
historical receipts and hashes remain read-only.

## Closed body and key

The implementation defines new local closed records. `Dict`, open
`NamedTuple`, JSON blobs, dynamic paths, old V5 objects and `Any` semantic
bodies are rejected. The frozen local body is:

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

The domains remain fixed: direction `:in|:out|:bidirectional`; trigger
`:initial|:scheduled|:fault|:threshold`; action
`:enable|:disable|:hold|:trip|:recover`; fault mode
`:open_circuit|:short_circuit|:sensor_dropout|:actuator_stuck|:overtemperature`;
safe action `:trip|:hold|:disable|:recover`. Valid UTF-8, immutable tuple
order, unique IDs, direction/unit/reference/cardinality constraints and exact
plan-set equality are hard local invariants.

The child key is the sole child identity record:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,           # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                      # constructor fixes :control
    child_id::String)
```

The grouped key record includes all four fields exactly once whenever it is
serialized. No hash recipe may repeat those four components outside the
grouped key field.

## Single-source-of-truth derivation

The full immutable source payload has this exact field order:

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

No `parent_binding` or `source_record_ref` is independently stored in this
payload. They are derived only as follows:

```text
derive_parent_binding(payload) =
    G3ControlParentDeclarationBindingV1(
        candidate_ref=payload.key.candidate_ref,
        declaration_ref=payload.parent_g3_declaration_ref,
        declaration_hash=payload.parent_g3_declaration_hash,
        binding_hash=H(canonical(payload.key.candidate_ref,
                                payload.parent_g3_declaration_ref,
                                payload.parent_g3_declaration_hash)))

derive_child_contract_identity(payload) = H(canonical(payload.child_contract_ref))

derive_source_record_ref(payload) =
    G3ControlSourceRecordRefV1(
        record_uri=payload.source_record.record_uri,
        record_version=payload.source_record.record_version,
        record_hash=payload.source_record.source_record_hash)
```

`derive_parent_binding` is the only parent binding: its candidate equals the
key candidate, its declaration ref is version `v1`, and its declaration hash
equals the key parent hash. `derive_child_contract_identity` is the only child
identity hash. `derive_source_record_ref` is the only source-record reference
rule. No caller-supplied alternate ref is accepted.

The derived source payload reference has this exact field order:

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

```text
derive_source_payload_ref(payload) = G3ControlSourcePayloadRefV1(
    candidate_ref=payload.key.candidate_ref,
    parent_binding=derive_parent_binding(payload),
    parent_g3_declaration_ref=payload.parent_g3_declaration_ref,
    parent_g3_declaration_hash=payload.parent_g3_declaration_hash,
    child_contract_ref=payload.child_contract_ref,
    child_contract_identity_hash=derive_child_contract_identity(payload),
    source_record_ref=derive_source_record_ref(payload),
    source_content_hash=payload.source_content_hash)
```

The payload constructor hard-checks that its child identity hash equals the
derived value; source URI/version equal source-record URI/version; and its
source content hash equals the canonical recipe using the derived parent
binding and source-record ref. The state and every operation store only a
value checked equal to `derive_source_payload_ref(payload)`. A forged parent
binding, child identity or source-record ref fails closed, including a matching
URI with a different digest.

## Source record and typed absence

The exact slot and record field order is:

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

G3ControlSourceRecordRefV1(
    record_uri::String, record_version::String, record_hash::Digest256)
```

`derive_source_record_ref` is always used; its fields equal the source record's
own URI, version and hash. Present/typed-absent slot rules remain closed:
present requires value/path/hash and rejects reason/absence hash; absent
requires reason/absence hash and rejects value/path/source hash. The slot
absence hash is `H(canonical(domain="g3-control-provenance-slot-absence-v1",
slot_kind, status=:typed_absent, candidate_ref, reason))`, excluding itself.

For a typed-absent state, source payload ref, editable body and initial source
hash are `nothing`; admission is exactly `:terminal_deferred`; the state
absence digest includes the complete grouped key, typed physical resolution,
reason, `ZERO_DIGEST` and typed empty history.

## State, fixed edit and operation chain

The state remains a closed record with
`source_payload_ref::Union{Nothing,G3ControlSourcePayloadRefV1}`,
`editable_body::Union{Nothing,G3ControlSourceBodyV1}`,
`initial_source_content_hash::Union{Nothing,Digest256}`,
`initial_state_hash`, `current_state_hash`, `last_operation_hash`,
`operation_history::Tuple{Vararg{G3ControlOperationRecordV1}}`, status fields,
typed physical resolution and explicit absence fields.

The operation name remains `replace_fault_source_payload`, but it only updates
editable state and exactly one existing fault `mode`; it never changes source
payload, derived payload ref, source record, axes, source hash, parent binding,
child identity or key. The operation record remains R5's closed field order:

```text
G3ControlOperationRecordV1(
    operation_id::String, operation_kind::Symbol,
    key::G3ControlChildKeyV1, fault_id::String,
    expected_prior_mode::Symbol, resulting_mode::Symbol,
    previous_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    prior_editable_body_hash::Digest256,
    replacement_editable_body_hash::Digest256,
    source_record_ref::G3ControlSourceRecordRefV1,
    source_payload_ref::G3ControlSourcePayloadRefV1,
    operation_hash::Digest256, resulting_state_hash::Digest256)
```

In R7, operation `source_record_ref` is derived only from the immutable source
payload's `source_record`; operation `source_payload_ref` is derived only from
that same payload. They are stored receipt values checked against their
derived values, never free inputs. The operation hash includes both complete
prior/replacement editable body hashes, fault ID, before/after mode, previous
state hash and these two derived refs; it excludes its own and resulting-state
hash fields.

The initial hash sequence is frozen and contains the grouped key once:

```text
initial_state_hash = H(canonical(
    key,
    state_status,
    source_payload_ref_or_nothing,
    editable_body_or_nothing,
    initial_source_content_hash_or_nothing,
    absence_reason_or_nothing,
    absence_content_hash_or_nothing,
    contract_admission,
    physical_resolution,
    operation_hash=ZERO_DIGEST,
    operation_history=typed_empty_tuple))
```

`key` serializes exactly `(candidate_ref,parent_g3_declaration_hash,
child_kind,child_id)` once. Those four fields are not repeated as extra
top-level hash inputs. Thus different candidate, parent, kind or ID cannot
share an initial hash merely because source bodies match.

For empty history, `last_operation_hash=ZERO_DIGEST` and
`current_state_hash==initial_state_hash`. For the first operation,
`previous_state_hash=initial_state_hash`, prior operation hashes are `()`, and
the resulting state hash is computed after the operation hash. For the second,
`previous_state_hash=op1.resulting_state_hash`, prior hashes are
`(op1.operation_hash,)`, and `last_operation_hash=op2.operation_hash`.
Generally, non-empty history requires
`last_operation_hash==operation_history[end].operation_hash`; wrong previous,
last or resulting hash, reordered/omitted/duplicated history, or mismatched
derived refs fails closed.

## Canonical failure evidence and ceiling

All hash bytes use valid UTF-8 without BOM, LF endings, frozen ordinal field
order, declared tuple order, exact symbols, normalized exact rationals,
lowercase fixed-width SHA-256 and explicit `nothing`. Every failure must
return old-state canonical bytes unchanged. The focused test will capture
`canonical_json(semantic_view(old_state))` and SHA256 before an invalid call,
then capture result bytes/digest and assert exact equality; where runtime
identity is meaningful it also asserts `result.state === old_state`.

The future implementation owns only the R5 control source/test/archive paths.
A different Luna reviews R7 before implementation. No Julia/DESC is run here.
Local contract evidence cannot promote physical status, which remains typed
`:unknown` or `:terminal_deferred` with a reason. T0/T1 mapping, provider,
engineering, mesh, solver, physical, search, B00, B04 and R01--R10 remain
false.
