# AD-31 G3 control-only source-edit proposal R2: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R2 correctly repairs the central R1 issue. Separating an immutable
`G3ControlSourcePayloadV1`/`source_content_hash` from a materialized
`editable_body` and its immutable operation history is semantically sound for
this bounded edit slice. A mode edit changes the materialized control state
and operation/current-state identities while retaining the sealed source
identity. The sibling scheduling, T0 bypass, old-type read-only boundary and
contract-only evidence ceiling are also correct.

The proposal is close, but implementation dispatch is still premature. The
source-record/ref schema and operation-history record schema are not frozen
with the same precision as the body records, and the stated history relation
can create a recursive current-state hash. Typed-absent state representation
and status derivation also need an exact rule. These are contract issues, not
physical execution issues, and require a repair before another independent
review.

## R1 requirements that are closed

R2 freezes the signal, initial-state, event, controller, fault, plan and source
body field order and the principal symbol domains. It carries the old control
semantics needed for a lossless later mapping: signal direction/unit/account,
controller sensor/actuator/resource/fault memberships, typed initial states and
events, fault target/mode/safe-action/detection/deadline, and exact plan tuples.
It states the old cardinality, reference, direction, duplicate-ID and plan-set
invariants.

The fixed operation is now explicitly mode-only. It requires one existing
fault ID, a changed allowed mode, unchanged tuple lengths/order, unchanged
source/owner/signals/controllers/controller memberships/states/events/plan,
unchanged non-target fault fields and unchanged source/provenance/identity
references. This preserves the semantic intent of old `g3_edit_fault`, whose
implementation reconstructs one existing fault path and changes only its mode.

The source/edit split is internally appropriate: `source_content_hash` binds
the complete sealed source payload, while `editable_body` is the materialized
current control body. R2 explicitly keeps source content, source record, four
axes, child key/contract identity, `initial_source_content_hash` and
`initial_state_hash` unchanged across a valid edit. The operation and current
state hashes are the only intended changing identities.

The R2 recipes also cover independent source-record, source-content, initial,
operation and current-state hashes; stale source/state paths; foreign
same-candidate references; unsupported/non-mode/multi-fault edits; duplicate
or reordered history; and byte-preserving failure behavior. It keeps control
independent from realization, binding, feedback and T0, and leaves timing,
actuator/resource capability, fault response, compilation, engineering and
physical evidence deferred.

## Required repairs before implementation dispatch

1. Freeze the complete source-record and reference schemas. R2 freezes only
   the four slot names/order. It must define the ordered fields and types of
   `G3ControlSourceRecordV1`, each present/typed-absent slot, and
   `G3ControlSourceRecordRefV1`, including record URI/version, slot value/ref,
   source path/ref, source hash, candidate ref, layer/status, reason and
   absence-content hash. The hash recipe must list every included field and
   explicitly include record identity fields and slot names/order. A present
   slot must bind to the child key candidate; an absent slot must carry no
   value/source hash/identity and must have a fixed allowed status/reason
   domain.

2. Freeze the source-payload reference type. `source_payload_ref` is described
   as “exact source identity, or typed absent” but no closed record, field order
   or absent representation is specified. Define whether it carries key,
   parent ref/hash, child contract identity, source URI/version,
   source-record URI/version/hash and source-content hash. Present and absent
   variants must be typed, and all fields used to prove source immutability
   must be included in the current-state identity or independently validated.

3. Remove the possible current-state hash recursion. R2 says operation history
   stores typed operation records “including each prior/current state relation”,
   while `current_state_hash` covers the full history. If a history record
   contains its resulting/current state hash, the current hash includes itself
   through that record. Freeze an acyclic operation-record field list: it may
   include operation ID, operation hash, expected prior state/source hashes,
   replacement body digest or canonical edit body, source-record ref and
   resulting-state hash only if the resulting hash is excluded from the state
   hash input or stored in a separately derived receipt. State-hash inputs must
   be explicit and non-recursive. Add an independent recomputation test for
   the first and second operations.

4. Freeze operation-history order and identity. Define the exact typed
   operation-record fields and tuple order. State whether uniqueness is by
   operation ID alone or by an operation ID/hash pair; in either case reject a
   reused ID, including reuse with a different payload/hash, before mutation.
   Define whether the history stores full canonical operation records or
   immutable receipts, and ensure the current-state hash covers the ordered
   immutable identities without admitting an unbounded self-reference. The
   successful receipt must bind prior state hash, prior source hash, operation
   hash, replacement/edit identity, initial anchors and resulting state hash.

5. Make initial status derivation explicit. `initial_state_hash` currently
   covers key, source reference, source hash, present body, zero operation and
   empty history, while `contract_admission` and `physical_resolution` are
   fields of the state but are omitted from that recipe. Freeze whether these
   initial statuses are strict functions of the source/provenance state or
   include them in the initial hash. A forged initial status or initial body
   must fail closed, and every later state must preserve the independently
   recomputed initial anchors. Apply the same rule to typed-absent states.

6. Complete the typed-absent state contract. The state sketch fixes
   `editable_body::G3ControlSourceBodyV1` but later says an absent state has no
   source payload/body. Define `editable_body` and `source_payload_ref` as
   closed present/typed-absent variants, or define a canonical absent body
   marker with no semantic control fields. The absent marker, absence hash,
   missing slots, `contract_admission=:terminal_deferred`, and
   `physical_resolution` must be hashable and must not be passed to the mode
   edit path.

7. Keep source/edit naming and equality executable. The operation name
   `replace_fault_source_payload` is retained by the work order, but R2 now
   means “replace the materialized editable body under an immutable source
   payload.” The implementation and tests must make this non-mutating behavior
   explicit: source payload object/ref, source record/ref, source hash, axes,
   parent/child identity and initial anchors are compared byte-for-byte or by
   their canonical typed identity before applying one mode edit. Every rejected
   path must return the prior state unchanged at the state-object byte level.

## Scheduling and evidence boundary

The control precursor remains a sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, depending only on the G3 SourceFeedback V1 declaration and
accepted AD-31 architecture boundary. It must not import or redefine T0, use
the realization implementation, populate binding/feedback/realization
children, modify old V5/package/registry data or add a sibling-to-sibling DAG
edge. T1 remains the sole later owner of the fresh same-candidate three-child
lossless mapping.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. A later software pass
can establish only the local contract/editability slice; it cannot grant
actual-child authority, T0/T1/T2 completion, provider, engineering, mesh,
physical, search, B00, B04 or R01--R10 credit.

