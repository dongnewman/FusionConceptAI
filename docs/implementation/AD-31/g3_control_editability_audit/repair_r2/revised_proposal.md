# AD-31 G3 control child editability audit — revised proposal R2

Date: 2026-09-15  
Revision: `R2`  
Parent record: [R1 audit](../report.md)  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

R1 is preserved byte-for-byte. This R2 repairs the independent-review finding
that a mode-only control edit must not be represented as a mutation of the
source identity. The source record, source payload and editable materialized
state are now separate layers: a source payload is immutable for this slice;
`replace_fault_source_payload` creates a new state from the same source
identity and one changed fault mode. A future source rebind is outside this
work order.

## Decision and boundary

`GO` remains a proposal-only decision pending a different Luna review of this
R2. It is not an implementation dispatch and does not accept an actual control
child. The proposed node remains control-only, candidate-owned and
contract-only. It does not import T0, populate realization/binding/feedback,
claim provider or engineering capability, run Julia/DESC, or close B00/B04 or
R01--R10.

The control precursor is a sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and `UP1-04A-VNEXT-T0`. It depends only
on the G3 SourceFeedback V1 declaration contract and the accepted AD-31
architecture boundary. It must not depend on the realization implementation:
control validation requires no realization fields, and making either child
wait for the other would create a false serial edge before the later T1
three-child join. T1 is the only future owner of the source-backed lossless
mapping into `CandidateStatePackageV5Next`.

The old `ControlGenomeV5`, `RealizationControlGenomeV5`, old bundle, package,
shared entry and `default_operator_registry()` remain read-only. No ref-only
adapter or old hash alias is permitted.

## Source findings and exact closed records

The old control semantics are the authority for field meaning only. Its
`ControlGenomeV5` contains `contract_binding`, ordered `signal_ports`, ordered
`controllers`, ordered `faults`, `plan`, `provider_match`, `plan_hash` and
`candidate_hash`. `g3_validate_control` rejects duplicate IDs, bad signal
directions, missing controller/fault references and plan-set mismatch. Its
`g3_edit_fault(genome, fault_id, mode)` reconstructs exactly one fault path,
changing only `mode`, then recomputes the old object hashes.

The new source file must define disjoint local types and freeze the following
field order and symbol domains. The order is part of canonical semantics and
must not be inferred from a dictionary or a reflection order.

```text
G3ControlSignalV1(
    port_id::String,
    signal_kind::Symbol,                  # non-empty symbol, old V5 accepts any non-empty kind
    direction::Symbol,                    # :in | :out | :bidirectional
    unit::UnitSignature,
    account_id::String)

G3ControlInitialStateV1(
    state_id::String,
    unit::UnitSignature,
    value::Rational{Int64})

G3ControlEventV1(
    event_id::String,
    trigger::Symbol,                       # :initial | :scheduled | :fault | :threshold
    time::Rational{Int64},                 # non-negative
    action::Symbol)                        # :enable | :disable | :hold | :trip | :recover

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
    mode::Symbol,                          # :open_circuit | :short_circuit |
                                           # :sensor_dropout | :actuator_stuck |
                                           # :overtemperature
    safe_action::Symbol,                   # :trip | :hold | :disable | :recover
    detection_signal_id::String,
    deadline::Rational{Int64})              # positive

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

The body is closed: no open `NamedTuple`, `Dict`, JSON blob, dynamic field,
old V5 instance or `Any` semantic body. Every ID is valid non-empty UTF-8 and
unique within its record collection. Controller sensor IDs must resolve to
signals with direction `:in` or `:bidirectional`; actuator IDs must resolve to
`:out` or `:bidirectional`; actuator-resource IDs and fault IDs must resolve to
their declared domains. Each controller must have non-empty sensor and
actuator lists with equal sensor/actuator cardinality and equal actuator/
resource-actuator cardinality, matching the old constructor. Controller fault
IDs must resolve to faults. Each fault target and detection signal must
resolve. The plan controller, signal and fault tuples must each be unique and
set-equal to the complete body collections. Ordered tuples remain ordered in
canonical serialization; set equality is only a validation invariant.

The child key is closed and immutable:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,          # version must be v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                     # constructor fixes :control
    child_id::String)
```

The payload carries `parent_g3_declaration_ref::QualifiedRefV1` with version
`v1`, the exact matching parent hash, an additive control contract ref and
independent contract identity hash, `source_uri`, `source_version`, the closed
body, the closed source record and `source_content_hash`. Candidate, parent
ref/hash, child kind/id, contract URI/version/profile, source URI/version and
all source record fields are exact typed values. A URI, fixture seed, old
candidate hash, or T0 bundle hash cannot construct any of them.

## Source layer, editable state layer and provenance

The source layer is immutable within this slice:

```text
G3ControlSourcePayloadV1(
    key,
    parent_g3_declaration_ref,
    parent_g3_declaration_hash,
    child_contract_ref,
    child_contract_identity_hash,
    source_uri,
    source_version,
    body::G3ControlSourceBodyV1,
    source_record::G3ControlSourceRecordV1,
    source_content_hash)
```

`source_content_hash` commits to the complete source payload, including the
closed body and source-record hash. It is not changed by a mode-only edit in
this slice. The source record has exactly four ordered slots:
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. A present
slot contains its exact typed value/ref, source path/ref, source hash,
candidate ref and status. A typed-absent slot contains no value or fabricated
source hash, an explicit reason and an absence-content hash. Its own
`source_record_hash` excludes itself and every source/content/operation/state
hash. The operation may refer to it only through a closed record ref containing
URI, version and record hash.

The editable state is a separate immutable-history record:

```text
G3ControlSourceStateV1(
    key,
    source_payload_ref,                    # exact source identity, or typed absent
    source_content_hash,                   # unchanged across mode edits
    editable_body::G3ControlSourceBodyV1,   # materialized current control body
    initial_source_content_hash,
    initial_state_hash,
    current_state_hash,
    last_operation_hash,
    operation_history::Tuple,
    state_status,                          # :present | :typed_absent
    contract_admission,                    # :declared_consistent | :terminal_deferred |
                                           # :fail_closed | :program_exception
    physical_resolution)                   # :unknown | :terminal_deferred
```

For a present state, `source_payload_ref` and
`source_content_hash == initial_source_content_hash` remain fixed across the
operation history. `editable_body` starts as the source body and changes only
through the fixed operation. `initial_state_hash` is computed once and never
recomputed after the first state. For an absent state, source payload and
source hashes are absent, a stable absence marker is used, and
`contract_admission=:terminal_deferred`. All fields above are immutable values;
an accepted operation returns a new state and does not mutate the prior state.

## Five independent hash recipes

The implementation must use the repository canonicalizer: valid UTF-8, LF,
ordinal field order exactly as frozen above, declared tuple order, normalized
exact rationals, and SHA-256. Each layer is independently recomputable from
its body; no copied expected string is sufficient.

1. `child_contract_identity_hash`:
   `H(canonical(child_contract_ref))`, excluding its own digest field.
2. `source_record_hash`:
   `H(canonical(source_uri, source_version, schema_slot,
   canonicalization_slot, applicability_slot, evidence_slot))`, excluding
   itself and all source/content/operation/state hashes.
3. `source_content_hash`:
   `H(canonical(key, parent_ref, parent_hash, child_contract_ref,
   child_contract_identity_hash, source_uri, source_version, body,
   source_record_hash))`, excluding itself. This is the immutable source
   identity; it is not rewritten by the mode edit.
4. `initial_state_hash`:
   `H(canonical(key, source_payload_ref, initial_source_content_hash,
   state_status=:present, editable_body=source_body,
   operation_hash=ZERO_DIGEST, operation_history=()))`. The initial state
   hash is frozen and is included in every later state identity.
5. `operation_hash` and `current_state_hash`:
   `operation_hash = H(canonical(operation_id, key, fault_id,
   expected_prior_mode, expected_prior_state_hash,
   expected_prior_source_content_hash, replacement_edit_body,
   source_record_ref))`, excluding the resulting state hash; and
   `current_state_hash = H(canonical(key, source_payload_ref,
   initial_source_content_hash, initial_state_hash, source_content_hash,
   editable_body, ordered_operation_history, last_operation_hash,
   state_status, contract_admission, physical_resolution))`.

The complete ordered operation history stores immutable typed operation
records, including each prior/current state relation. Reordering, deleting,
duplicating or omitting a prior operation changes the current state hash and
is rejected. Duplicate operation IDs and duplicate fault IDs are rejected
globally, including across the history and current body where the contract
defines an ID namespace. A source record hash, source content hash, initial
state hash, operation hash and current state hash are never used as aliases
for one another.

## The one fixed operation

The only operation is `replace_fault_source_payload`. Its source payload input
is immutable and its editable result is explicit:

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
    operation_hash::Digest256)
```

The replacement body is a complete candidate-owned materialized body, but the
admission rule compares it to the current `editable_body` and allows exactly
one semantic difference: the `mode` of the existing `fault_id`. Source ID,
owner, signal tuple and bytes, controller tuple and bytes, controller fault
membership, initial states, events, plan tuple and bytes, every non-target
fault field, source payload ref, source URI/version, source record ref and
four-axis slots must remain equal. The target fault ID must already exist;
`expected_prior_mode` must equal the current mode; the new mode must be one of
`:open_circuit`, `:short_circuit`, `:sensor_dropout`, `:actuator_stuck`, or
`:overtemperature`, and it must differ from the prior mode. `safe_action`,
target, detection signal, deadline, controller membership, plan membership,
signal direction/unit/account, events and controller lists cannot change.

Thus the edit changes `editable_body` and the operation/state identities, but
does not change `source_content_hash`, `source_record_hash`, any axis hash,
child key, parent hash, or child contract identity. This is the explicit
resolution of the source/hash conflict: source identity describes the sealed
source; state identity describes the candidate's ordered control edit history.
If a caller wants to change source URI, source version, provenance, signal
definition, controller structure, fault target or any non-mode field, it must
create a new source payload through a future separately gated source-rebind or
control work order. It is not this operation.

The operation must verify, in order, exact candidate/parent/key and source
record identity, source-content equality with the state, expected state and
source hashes, expected mode, operation-hash recomputation, complete-body
invariants and the exactly-one-mode-difference rule. A valid operation returns
a new state with the same `initial_source_content_hash`, `initial_state_hash`
and immutable `source_content_hash`; `last_operation_hash` is the new
operation hash; the operation is appended to history; and only
`current_state_hash` is newly computed from the new editable body and full
history. `contract_admission=:declared_consistent` may remain local; physical
resolution stays `:unknown` or an explicitly recorded `:terminal_deferred`.

Every failure returns `fail_closed` or typed deferred without changing the
prior state bytes, operation history, source payload, source hash, initial
hashes or current hash. In particular, stale state and stale source checks are
independent: `fail_closed:stale_state_hash` and
`fail_closed:stale_source_content_hash`. Forged operation/replacement/source
record hashes, foreign candidate/parent/key, source identity mismatch, missing
fault, two changed faults, changed non-target field, duplicate operation ID,
unsupported mode, dynamic path, insert, delete and rebind all preserve the
prior state byte-for-byte.

## Exact same-candidate and four-axis rules

The candidate ref in the child key, parent G3 declaration ref/hash, child
contract identity, source record slots and all present provenance source refs
must be the same candidate. A present slot whose candidate, layer, URI, version
or digest disagrees is `fail_closed`. A missing slot is typed absence with
`contract_admission=:terminal_deferred`; a local constant is not evidence.
Changes to any axis are source changes and therefore cannot be performed by
`replace_fault_source_payload`; they require a future source-backed operation.

The control child remains independent of G3 feedback authority. A control edit
cannot create G1/G2 authority or a binding/realization child. T1 may later
join this control state with fresh same-candidate realization/binding/source
records and perform the only lossless package mapping. Until then, actual child
authority remains false.

## Inputs, outputs, negative controls and exit gate

Inputs are the current G3 SourceFeedback V1 declaration, read-only old control
field definitions and validator, the accepted AD-31 closed-source/hash
boundary and fresh typed local values. Historical receipts, fixture seeds and
old hashes are excluded.

Outputs are one closed control source payload, separate editable state and
ordered operation history, the fixed mode-only operation, canonical hash
helpers, typed provenance/absence behavior and a software-only archive. The
future implementation owns exactly:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`.

Required negative controls are:

1. every foreign candidate, parent ref/hash, child key, contract identity,
   source record, axis or source payload -> `fail_closed`;
2. every open/wrong-typed body, duplicate local ID, duplicate history ID, bad
   reference, unit/direction/cardinality error, controller/fault reference or
   plan mismatch -> `fail_closed`;
3. missing provenance -> typed absence and `terminal_deferred`, with no
   fabricated source/child hash;
4. independent recomputation of all five hash layers and proof that the source
   and initial hashes do not change after a valid mode edit;
5. valid one-fault mode edit changes only target mode, operation history,
   operation hash and current state hash;
6. stale source and stale state checks independently reject and preserve the
   prior state byte-for-byte;
7. forged replacement/operation/source-record hash, changed non-target field,
   two changed faults, changed source/axis/child identity, unsupported mode,
   duplicate operation, reordered history, dynamic field path, insert, delete
   or rebind -> `fail_closed` with prior state unchanged; and
8. old V5/package/registry/T0/realization/binding/feedback substitution or
   import -> rejected.

The future implementation exit gate requires static ownership and forbidden
import checks, valid UTF-8/JSON, one fresh Julia process with raw stdout/stderr
bytes, SHA-256, PID and exit code, and a different Luna review of source,
hashes, failure byte invariance and dirty protection. This audit itself runs no
Julia/DESC and edits no code, test, core plan or old receipt.

The only possible future acceptance is `accepted_limited` for local software
contract/editability. `physical_resolution` remains `unknown` or
`terminal_deferred`; external promotion requires candidate-bound control timing,
fault response, actuator/resource capability, coupled compilation/discretized
execution and applicable measured or solver evidence. No document, test,
runner exit, provider label, child hash or `bridge_ready` marker supplies that
evidence.

## Scheduling and no-go conditions

Go after independent R2 review for a finite control-only implementation. No-go
for any implementation that mutates the source identity during a mode edit,
allows a non-mode change, drops any frozen field, reorders or rewrites history,
uses old V5/T0 authority, depends on realization, or promotes physical status.
The control and realization siblings both feed T1; adding an edge between them
is prohibited because it is unnecessary and risks a DAG cycle when binding
requires both children.

R01--R10, UP1--UP6, T0/T1/T2, provider, engineering, mesh, solver, physical,
search, B00 and B04 remain independently gated and unchanged.
