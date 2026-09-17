# AD-31 G3 control child editability audit

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Dirty worktree rows observed: `306`

## Decision

`GO`, limited to a separately reviewed contract proposal for one control-only,
candidate-owned source-edit precursor. The proposal may be dispatched after a
different Luna reviews this report and manifest. It does not authorize code,
tests, Julia/DESC, provider, engineering, physical, T0/T1/T2, B00/B04 or
R01--R10 acceptance in this audit.

The control slice should be a sibling of the AD-31 realization precursor. It
should depend on the accepted G3 SourceFeedback V1 declaration contract, but it
does not need a realization child, a realization implementation receipt, or a
T0 package. Making it depend on realization would add no information needed to
validate control semantics and would make the future three-child T1 join harder
to schedule. T1 remains the single later owner of the lossless mapping of all
present children into `CandidateStatePackageV5Next`.

The old `ControlGenomeV5` and `RealizationControlGenomeV5` remain read-only.
This proposal is an additive source contract, not an adapter or a relaxation
of the old concrete-type checks.

## Current source findings

The old control child contains the following semantic groups:

* signal ports: `port_id`, signal kind, direction, `UnitSignature`, and account;
* controllers: sensor ports, actuator ports, resource actuator ports, fault
  membership, typed initial states and typed events;
* fault paths: `fault_id`, target controller, fault mode, safe action, detection
  signal and positive deadline; and
* a plan whose controller, signal and fault ID sets must exactly match the
  child collections.

`g3_validate_control` checks duplicate IDs, signal directions, controller
references, fault targets and detection signals, and exact plan membership.
The existing `g3_edit_fault(genome, fault_id, mode)` is the narrowest actual
control edit: it finds one fault, reconstructs that path with a new mode, and
rebuilds the old control object and its hashes. The new slice should preserve
that semantic intent without calling or aliasing the old type.

The current G3 V1 declaration supplies the candidate-owned parent declaration,
source identity, owner scope, source/field/return/heat law, ledger closure and
feedback authority boundary. It does not contain a control child. A control
child therefore cannot be inferred from G3 V1, an old candidate hash, a fixture,
or a URI. Until a fresh same-candidate source and authority receipt exists, the
control child remains a local contract state with typed absence/deferred
provenance.

## Proposed bounded contract

The future machine node is
`UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`. Its implementation owns exactly:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`.

It is a parallel sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`. Its only prerequisite is
`UP2-01-G3-SOURCE-FEEDBACK-V1` plus the accepted architecture boundary for
AD-31. The implementation must not edit the core plan, task manifest, old G3
files, T0 files, package, registry, historical receipts, or the realization
precursor files.

### Closed typed source body

The new source must define closed local records. No `Dict`, open `NamedTuple`,
JSON blob, dynamic field path, old V5 alias, or `Any` semantic body is allowed.
The body must retain all control semantics needed for a later lossless mapping:

```text
G3ControlSourceBodyV1(
    source_id::String,
    owner_scope::String,
    signal_ports::Tuple{Vararg{G3ControlSignalV1}},
    controllers::Tuple{Vararg{G3ControlControllerV1}},
    faults::Tuple{Vararg{G3ControlFaultV1}},
    plan::G3ControlPlanV1)
```

The local records mirror the old fields with new names and types: typed signal
kind/direction/unit/account; typed controller sensor, actuator and resource
port IDs, fault IDs, initial states and events; typed fault target, mode, safe
action, detection signal and exact positive deadline; and exact plan ID tuples.
Constructors must validate unique IDs, reference resolution, sensor/actuator
direction, controller membership, fault target and detection membership, and
exact plan sets. They must preserve ordered tuples for canonical hashing.

The child key is:

```text
G3ControlChildKeyV1(
    candidate_ref::QualifiedRefV1,              # version=v5
    parent_g3_declaration_hash::Digest256,
    child_kind::Symbol,                         # constructor fixes :control
    child_id::String)
```

The payload must additionally carry a typed
`parent_g3_declaration_ref::QualifiedRefV1` with version `v1`, the matching
parent hash, an additive control child contract ref and independently computed
contract identity hash, `source_uri`, `source_version`, the closed body, a
closed source record, and `source_content_hash`. Parent ref/hash, candidate,
child kind/id, layer, URI and contract identity are exact fields; a parsed URI
or label cannot construct authority.

### Provenance, state and hashes

Use the same repository canonicalizer as AD-31, with a control-local schema,
canonicalization and applicability profile. The source record is closed and
has exactly four present-or-typed-absent slots:
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. A present
slot carries its exact typed value/ref, source path/ref, source hash, candidate
ref and status. An absent slot carries no value or fabricated hash, an explicit
reason and an absence-content hash. The source record hash excludes itself and
all source-content and operation hashes.

The materialized state must carry:

```text
initial_source_content_hash::Union{Nothing,Digest256}
source_content_hash::Union{Nothing,Digest256}
initial_state_hash::Digest256
state_hash::Digest256
operation_hash::Digest256
contract_admission::(:declared_consistent | :terminal_deferred |
                     :fail_closed | :program_exception)
physical_resolution::(:unknown | :terminal_deferred)
```

For a present payload, compute:

1. `child_contract_identity_hash = H(canonical(control_contract_ref))`,
   excluding its own hash;
2. `source_record_hash = H(canonical(source_uri, source_version, four slots))`,
   excluding itself;
3. `source_content_hash = H(canonical(child_key, parent ref/hash,
   child contract identity, source URI/version, closed body,
   source_record_hash))`, excluding itself;
4. `initial_state_hash = H(canonical(child_key, :present,
   source_content_hash, operation_hash=ZERO_DIGEST))`; and
5. `state_hash = H(canonical(child_key, state status, source content hash,
   operation hash, ordered operation history))`.

An absent child has no payload or source hash, a stable absence-content hash,
`contract_admission=:terminal_deferred`, and a state hash over the typed absent
marker. Missing source/axis authority is an evidence gap, not a child identity.
Conflicting candidate, parent, contract, source, slot, or body data is
`fail_closed`. `physical_resolution` is independent and cannot be promoted by
a constructor, hash, test, provider label, runner exit code or
`bridge_ready` marker.

### The one fixed edit

The only operation is
`replace_fault_source_payload`. It is an atomic replacement of the complete
closed control payload, guarded by:

```text
G3ControlReplaceFaultSourcePayloadV1(
    operation_id::String,
    key::G3ControlChildKeyV1,
    fault_id::String,
    expected_prior_mode::Symbol,
    expected_prior_state_hash::Digest256,
    expected_prior_source_content_hash::Digest256,
    replacement_payload::G3ControlSourcePayloadV1,
    source_record_ref::G3ControlSourceRecordRefV1,
    operation_hash::Digest256)
```

The operation is deliberately narrower than a generic source editor and
matches old `g3_edit_fault`: candidate, parent, child key, source URI/version,
contract identity, all signal/controller/plan fields and all non-target fault
fields must remain equal; exactly one existing `fault_id` may change its
allowed `mode`, and `expected_prior_mode` must match it. The replacement body
must pass every closed-body invariant. `safe_action`, target, detection signal,
deadline, controller membership and plan membership cannot be changed by this
operation. A future operation for those fields is a separate work order.

The operation hash covers the operation ID, key, fault ID, expected mode and
both expected prior hashes, complete replacement payload and exact source
record ref, excluding resulting state hash. The source record ref must equal the
replacement record URI/version/hash. A stale state hash returns
`fail_closed:stale_state_hash`; a stale source hash returns
`fail_closed:stale_source_content_hash`; either leaves the old state and every
hash unchanged. Forged replacement, operation or source-record hashes,
foreign key, missing fault, more than one semantic difference, unsupported mode
or dynamic operation input also fails closed.

### Four-axis and evidence state

The control source record must preserve the four provenance axes as typed
present/absent slots. A local profile constant is not a candidate-bound
receipt. The source and state identity must include the slots and absence
markers so changing any axis invalidates the affected hashes. Any absent axis
is `terminal_deferred`; a contradictory axis is `fail_closed`.

Record control status separately from external evidence:

| Axis | Local contract slice | Required evidence before promotion |
|---|---|---|
| `contract_admission` | typed body, reference/closure checks, deterministic hashes and fixed fault edit | independent source/identity review and fresh receipt bytes |
| `physical_resolution` | `unknown` or declared `terminal_deferred` only | candidate-bound control timing, fault response, actuator/resource behavior, compiled/discretized coupled execution and applicable measured or solver evidence |

This slice must not define realization, binding or feedback edits. G3 V1
feedback remains a parent authority declaration; a control edit cannot create or
attest G1/G2 authority. Control timing, actuator capability, fault response,
thermal/resource coupling, manufacturing feasibility and physical behavior are
external engineering/physical obligations and stay unexecuted here.

## Inputs, outputs and negative controls

Inputs are the current G3 SourceFeedback V1 contract, read-only old control
field definitions and validator for semantic comparison, AD-31's accepted
closed-source/hash boundary, and fresh typed local values. Historical candidate
receipts, fixture seeds and old hashes are not inputs.

Outputs are one closed control payload/state, the fixed fault source replacement
operation, canonical hash helpers, typed provenance/absence behavior, a focused
software receipt and an implementation manifest. The archive must record raw
stdout/stderr bytes, SHA-256, PID, exit code, exact input hashes and dirty-file
protection. A successful local run remains contract-only evidence.

Required negative controls include:

1. foreign candidate, parent ref/hash, child kind/id or child contract identity;
2. open/wrong-typed body, duplicate IDs, missing references, bad unit or
   direction, invalid controller/fault membership and plan mismatch;
3. missing provenance slot -> typed absence and `terminal_deferred`, with no
   fabricated source or child hash;
4. conflicting provenance candidate, source hash, axis value or status ->
   `fail_closed`;
5. independent recomputation of source-record, source-content, initial-state,
   operation and current-state hashes;
6. successful one-fault-mode replacement changes the expected source/content,
   operation and state identities while preserving all unrelated control fields;
7. stale source and stale state paths independently fail closed and preserve
   the prior state byte-for-byte;
8. forged replacement/operation hash, changed key, changed non-target fault
   field, two changed faults, unsupported mode, insert/delete/rebind or dynamic
   field path; and
9. attempted import/substitution of old V5/package/registry/T0/realization or
   feedback authority.

## Exit gate and scheduling ruling

The finite work order is `GO` only after a different Luna independently
reviews this proposal, exact file ownership and the operation's one-field
semantic restriction. The implementation exit gate is:

* static checks show only the three owned paths changed, valid UTF-8/JSON and
  no forbidden imports or old-file mutations;
* one fresh Julia process captures raw streams, hashes, PID and exit code;
* all typed/hash/absence/stale and one-fault-mode controls pass from source
  invariants; and
* a different Luna reviews the source, receipt bytes and dirty protection.

The resulting status may be `accepted_limited` only for this software contract
slice. It must remain `actual_child_authority=false`, `T0_authority=false`,
`T1_mapping=false`, `provider=false`, `engineering=false`, `mesh=false`,
`physical=false`, `search=false`, `B00=false`, `B04=false` and `R01_R10=false`.

No realization dependency is required. The control and realization precursors
can both feed a later T1 exact same-candidate join. T1 must carry the three
child keys, parent G3 declaration hash, source/child/operation identities,
four-axis provenance and typed absent/actual status. It is the only place that
may perform the unique lossless control mapping into `CandidateStatePackageV5Next`.
Adding a control -> realization or realization -> control edge would create a
false serial dependency and risks a cycle when binding later requires both
children; neither edge should be added.

## Go/no-go and required changes

Go for proposal review and, after independent pass, a bounded implementation
dispatch with the exact files above. No-go for any implementation that uses an
old `ControlGenomeV5` object as the source body, exposes generic path edits,
allows an edit to rewrite non-target fault semantics, imports T0, populates a
realization/binding/feedback child, or promotes physical status from local
execution.

Required changes before dispatch are limited to freezing the control-local
contract URI/profile hashes, exact closed record field order, operation hash
recipe, and the negative controls above in the implementation source and test.
No core planning change is needed for this audit; if the architecture owner
later accepts it, a separate status-sync task may add the new sibling node to
the machine DAG without changing R01--R10 or the AD-31 realization node.

## Evidence boundary

This audit is a source/document read and architecture proposal. No Julia,
DESC, provider, mesh, solver, engineering or physical command was run. The
current dirty worktree was preserved. Passing this audit or any future local
test cannot close the frozen parent goal.
