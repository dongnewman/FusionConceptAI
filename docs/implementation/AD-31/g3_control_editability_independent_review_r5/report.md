# AD-31 G3 control-only source-edit proposal R5: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R5 closes the R4 ref and hash gaps substantially. Source-record URI/version/
hash are now fields of the source record and exact-match refs; parent binding
and child-contract identity recipes are explicit; slot and state absence
digests are defined; operation history carries complete prior/replacement body
hashes; ZERO and last-operation rules are present; and canonical failure-byte
checks are executable. The source-versus-editable split remains coherent, and
the operation still changes only one existing fault's mode.

One material identity omission remains: the R5 `initial_state_hash` recipe
does not include the `key`, while `G3ControlSourcePayloadRefV1` does not carry
the child kind/id. Thus two different child keys can share the same source,
editable body, statuses and empty history yet receive the same initial-state
identity. This violates candidate/child-bound state identity and must be
repaired before implementation dispatch. Two related equality/derived-field
rules should also be made hard constructor invariants rather than left as
prose.

## R5 checks that pass

The closed control records retain the old `ControlGenomeV5` semantic fields and
domains: signal kind/direction/unit/account, controller sensor/actuator/
resource/fault memberships and cardinalities, initial states/events, fault
target/mode/safe-action/detection/deadline and exact plan sets. The proposal
keeps the new records disjoint from old V5 types, package, registry, T0 and
other G3 children.

The source record now contains `record_uri`, `record_version`, all four typed
provenance slots and its own digest; the ref is an exact URI/version/hash
triple. Parent binding, child contract identity, source payload ref and source
content recipe are explicit and candidate-bound. Slot and state typed absence
have deterministic canonical absence hashes, and absent states have no editable
body or edit path.

The immutable source payload versus editable state layer is semantically sound:
a valid operation retains source payload/ref, source record/ref, axes, parent
binding, child contract identity, source-content hash and both initial hashes.
It changes only the editable body, operation record/history, operation hash,
last-operation hash and current-state hash. The operation hash includes prior
and replacement editable body hashes, exact source refs and prior state/source
hashes; the resulting-state recipe uses only prior operation hashes and the
new operation hash, so no result-hash recursion is present.

The fixed name `replace_fault_source_payload` is explicitly historical and
updates editable state only. Exactly one existing fault's mode may change to a
different allowed mode; all other fields, tuple order/count, plan bytes,
identities and source metadata are immutable. The canonical byte equality
failure test covers stale, forged, foreign, malformed, duplicate, reordered,
non-mode, multi-fault and typed-absent paths. The sibling/no-T0 boundary and
physical `unknown`/typed `terminal_deferred` ceiling remain correct.

## Required repairs before implementation dispatch

1. Add the child key to the initial-state hash. The exact present and absent
   initial recipes must include `key` before state status and the remaining
   fields. The state constructor must independently recompute this hash and
   reject a state whose key, candidate, parent hash, child kind or child ID is
   not bound to the initial identity. The source payload ref currently carries
   candidate and parent/contract/source identity but not child kind/id, so the
   key cannot be inferred from the ref.

2. Make parent-binding/direct-field equality executable. The source payload ref
   carries both `parent_binding` and direct parent declaration ref/hash fields;
   the payload carries direct fields. Require exact equality of candidate,
   declaration ref and declaration hash across the key, parent binding, ref and
   payload, and require the binding hash and child-contract identity hash to
   recompute from their complete typed records. A mismatch must fail closed
   before any hash or edit is accepted.

3. Make the result-state last-operation rule explicit in the hash transition.
   For a successful operation, the value used as `last_operation_hash` while
   computing the resulting state must be the new `operation_hash`; for empty or
   absent history it must be `ZERO_DIGEST`. The constructor must verify that
   the stored last-operation field equals the last typed history record's
   operation hash (or ZERO for empty history). Either include this derived
   equality in the state recipe or reject forged values before admission.

4. Preserve the complete canonical field list in the implementation contract.
   The five recipes are now substantially complete, but the focused test must
   verify the key inclusion in the repaired initial hash, the full parent/child
   binding equality, slot/source-record/ref byte match, body-hash inputs and
   last-operation transition over both the first and second edits. A changed
   key must produce a distinct initial identity and fail closed when applied to
   an existing state.

## Scheduling and evidence boundary

After this repair, the finite implementation may remain a control-only sibling
of `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, depending only on `UP2-01-G3-SOURCE-FEEDBACK-V1` and the
accepted AD-31 architecture boundary. It must not import/redefine T0, depend
on realization, modify old V5/package/registry data, or add a sibling edge. T1
remains the only later owner of the fresh same-candidate three-child mapping.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. Any future focused
receipt establishes only local contract/editability software evidence; actual
child authority, T0/T1/T2 completion, provider, engineering, mesh, physical,
search, B00, B04 and R01--R10 remain false.

