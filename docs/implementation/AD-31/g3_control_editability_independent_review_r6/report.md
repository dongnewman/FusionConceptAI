# AD-31 G3 control-only source-edit proposal R6: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R6 closes the main R5 identity and transition findings. The complete child key
is now included in the initial-state identity; parent binding and direct
parent/child fields have hard equality rules; `last_operation_hash` has ZERO
and latest-operation invariants; and the first and second operation
transitions, bad chains, duplicate history and canonical failure bytes are
explicitly controlled.

One schema error and one hash-serialization ambiguity remain material. The
hard invariant refers to `payload.source_record_ref`, but the declared
`G3ControlSourcePayloadV1` has only `source_record` and no
`source_record_ref` field. Also, the initial hash is described first as four
explicit key fields and then as including a grouped canonical key record; an
implementation cannot choose both representations without changing the hash.
The payload-ref derivation for `parent_binding` and the source-record ref must
also be stated as one exact rule. These are bounded contract repairs required
before implementation dispatch.

## R6 checks that pass

The inherited closed body and symbol domains remain aligned with old
`ControlGenomeV5`: signal kind/direction/unit/account, controller sensor/
actuator/resource/fault memberships and cardinalities, typed initial states and
events, fault target/mode/safe-action/detection/deadline and exact plan sets.
The new slice stays disjoint from old G3 V5, package, registry, T0,
realization, binding and feedback authority.

R6 explicitly binds candidate, parent declaration ref/hash, parent binding,
child contract ref/hash, source-record URI/version/hash, source content and
source slots. The child identity and parent binding recipes are independently
recomputable, and the typed slot/state absence digests are deterministic.

The source-versus-editable split remains sound. A valid operation changes only
the editable body, operation history, operation hash, latest-operation hash and
current-state hash. The source payload, source record/ref, axes, parent/child
identity, source-content hash, initial source hash and initial state hash stay
fixed. The operation continues to allow exactly one existing fault's mode to
change, with all other fields and tuple order/count fixed.

The operation transition is now sufficiently explicit for first and second
edits: previous-state hash chaining, prior operation hashes, latest-operation
hash, resulting-state hash and history records are cross-checked. Wrong
previous/last/result hashes, reordering, omission, duplication and ref/key
mismatch fail closed with the old state's canonical bytes unchanged. The hash
chain contains no result-hash recursion. Physical status remains typed
`unknown` or `terminal_deferred`, and no provider, engineering, mesh, solver,
physical, search, B00, B04 or R01--R10 credit is granted.

## Required repairs before implementation dispatch

1. Resolve the payload/source-record ref schema error. Either add an explicit
   `source_record_ref::G3ControlSourceRecordRefV1` field to
   `G3ControlSourcePayloadV1`, or replace every `payload.source_record_ref`
   reference with one canonical derived expression
   `G3ControlSourceRecordRefV1(payload.source_record.record_uri,
   payload.source_record.record_version,
   payload.source_record.source_record_hash)`. The source-payload reference,
   source-content recipe, constructor and operation must all use the same
   choice. A ref must be compared to the source record's URI/version/hash
   before any source or edit hash is accepted.

2. Freeze one initial-state serialization. Choose either the four ordered key
   fields `(candidate_ref, parent_hash, child_kind, child_id)` or one grouped
   `key` record, then use exactly that representation in present and
   typed-absent `initial_state_hash` and in the independent recomputation test.
   Do not serialize both or let the repository canonicalizer implicitly add a
   second key group. The chosen form must bind all four child-key fields and
   remain distinct for different candidates, parents, kinds and child IDs.

3. Make payload-ref derivation fully closed. Require
   `payload_ref.parent_binding` to equal the binding derived from the payload's
   candidate/declaration ref/hash, and require every direct parent field in the
   payload ref to equal that binding. Require the payload ref's source-record
   ref to equal the single source-record ref selected in repair 1, and require
   child-contract and source-content fields to equal their recomputed values.
   Every mismatch must fail closed without normalizing either side.

4. Preserve the transition controls in implementation tests. The first and
   second successful edits must independently recompute operation/body hashes,
   previous/resulting state hashes, prior-operation tuple, latest-operation
   hash and history records. Tests must forge each of the bad-chain values,
   change the key, and alter the derived payload/source-record ref, then prove
   old canonical bytes and digest remain identical.

## Scheduling and evidence boundary

After these repairs, the finite work order may remain a control-only sibling
of `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, depending only on `UP2-01-G3-SOURCE-FEEDBACK-V1` and the
accepted AD-31 architecture boundary. It must not import/redefine T0, depend
on realization, modify old V5/package/registry data or add a sibling edge. T1
remains the only later owner of the fresh same-candidate three-child mapping.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. A later focused pass
can establish only local contract/editability software evidence; actual child
authority, T0/T1/T2 completion, provider, engineering, mesh, physical, search,
B00, B04 and R01--R10 remain false.

