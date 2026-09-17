# AD-31 G3 control-only source-edit proposal: independent review R1

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The audit has a sound additive boundary and is suitable for a bounded repair
round. It correctly keeps the control child beside the realization precursor,
keeps both paths out of T0, reserves the later same-candidate lossless join for
T1, and preserves the old control types, old package and registry as read-only.
It also identifies the right control-only semantic groups and restricts the
operation to an existing fault's mode.

Implementation dispatch is not yet safe because several properties are stated
as prose or negative-control names without a complete, enforceable canonical
recipe. A complete payload replacement must not become a hidden provenance,
ordering or initial-state editor. The following repairs are required before a
new independent review can pass the work order.

## Checks that pass

The source comparison is materially correct. `ControlGenomeV5` contains typed
signal ports, controllers, fault paths and an exact controller/signal/fault
plan. Its `g3_validate_control` checks duplicate IDs, sensor and actuator
direction, controller fault references, fault target and detection references,
and exact plan membership. `g3_edit_fault` reconstructs exactly one existing
fault path with a new allowed mode while preserving target, safe action,
detection signal, deadline, all other faults, all ports, controllers, plan and
the old contract binding/provider scope.

The proposed local body is closed and control-only. It carries signals,
controllers, faults and plan as typed tuples, and the proposed key carries the
candidate, parent declaration hash, fixed `:control` kind and child ID. The
payload also carries a typed parent declaration reference, additive child
contract identity, source URI/version, source record and source-content hash.
The proposal explicitly forbids `Dict`, open semantic bodies, dynamic paths,
insert/delete/rebind, realization/binding/feedback children, T0 imports,
legacy package substitution, registry mutation and physical promotion.

The proposed four provenance axes are typed present/absent slots, with absent
slots carrying no fabricated source value or source hash. Separate
`contract_admission` and `physical_resolution` statuses are present, and the
proposal keeps timing, actuator/resource behavior, fault response, thermal and
manufacturing obligations outside this local contract slice. The sibling
dependency and future T1 join do not introduce a control-to-realization cycle.

## Required repairs before implementation dispatch

1. Freeze the exact local record schemas and field order. The audit names
   `G3ControlSignalV1`, `G3ControlControllerV1`, `G3ControlFaultV1`,
   `G3ControlPlanV1`, the source record and the source-record reference, but it
   does not yet provide their complete ordered fields, allowed symbol domains,
   or constructor invariants. The frozen schema must preserve every old control
   field, including signal kind/direction/unit/account, sensor/actuator/resource
   port IDs, fault IDs, typed initial states/events, fault safe action, target,
   detection signal, positive exact deadline, and ordered plan tuples. It must
   also state the old validation implications: resource actuator cardinality,
   controller fault membership, direction checks, duplicate-ID checks and exact
   plan-set equality. The field order must be the order used by canonical hash
   helpers.

2. Make the one-fault restriction an executable equality rule. The operation
   must require unchanged tuple lengths and order for signals, controllers,
   controller internals, plan and faults; exactly one existing `fault_id` must
   occur once in both bodies; exactly one semantic field may differ, namely
   `mode`; and the new mode must differ from the expected prior mode and belong
   to the frozen allowed mode set. A changed safe action, target, detection
   signal, deadline, controller membership, plan membership, signal field,
   controller state/event, fault ordering or second fault must fail closed.
   “Complete replacement” must remain an atomic transport shape, not a generic
   patch interface.

3. Freeze source-record and provenance immutability for this operation. The
   audit requires the replacement record reference to match the replacement
   record, but it does not explicitly require the replacement source record,
   all four slots, candidate binding, source URI/version and child contract
   identity to equal the current state. Add that equality rule, together with
   independent recomputation of the replacement record hash and source-content
   hash. A fault-mode operation must not change a provenance slot, source
   identity, child identity or axis status while claiming to change one fault
   mode. Any such change must be rejected or assigned to a future operation.

4. Make the initial state an immutable checked anchor. The constructor and edit
   path must verify that `initial_source_content_hash` and `initial_state_hash`
   are recomputed from the original present/typed-absent state with the frozen
   zero-operation digest, and that every successful edit carries them forward
   unchanged. The current-state identity must either include these immutable
   anchors or validate them as derived values on every transition. Add a
   negative control that forges or changes either initial value and proves
   `fail_closed` with the prior state unchanged.

5. Specify operation-history identity and uniqueness. The report names a
   duplicate-operation negative control but leaves the history representation
   and comparison rule open. Freeze whether history stores ordered
   `(operation_id, operation_hash)` receipts or another equivalent immutable
   identity, require operation IDs to be non-empty and unique within the
   state lineage before mutation, and include the ordered identities in the
   state hash. Reusing an operation ID with a different payload/hash must fail
   closed. The successful edit receipt must bind the exact prior state hash,
   prior source-content hash, replacement source-content hash, operation hash,
   initial anchors and resulting state hash.

6. Bind every reference at the same-candidate boundary. The implementation
   must require exact equality among the key candidate, parent declaration ref
   and parent hash, payload candidate/parent data, child contract ref/identity,
   source-record candidate refs and every present provenance slot. A URI,
   fixture seed, old candidate hash, layer name or T0 typed-absent marker must
   never stand in for a source-backed ref/hash. The identity and canonicalization
   recipes must be written as exact field lists and must remain acyclic:
   source-record hash excludes itself and content/operation hashes; source
   content includes the sealed record hash; operation hash excludes the
   resulting state hash; state hash includes the ordered operation identities.

7. Keep the exit gate aligned with these repairs. The implementation tests must
   independently recompute all five hash layers, test one valid mode-only edit,
   test two changed faults and every non-mode mutation, test source-record and
   initial-anchor forgery, test duplicate operation IDs, and verify that all
   failed paths preserve the prior state byte-for-byte. No Julia, DESC,
   provider, mesh, solver, engineering or physical claim is granted by this
   review.

## Scheduling and evidence boundary

The control precursor remains a sibling of
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, with the G3 SourceFeedback V1 declaration as its only
semantic prerequisite. It must not import or redefine T0 and must not depend on
the realization precursor. The later T1 node remains the only owner of the
lossless three-child mapping into `CandidateStatePackageV5Next`.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. A future software pass,
even with a clean focused receipt, can only establish the local contract slice;
it cannot grant actual-child authority, T0/T1/T2 completion, provider,
engineering, mesh, physical, search, B00, B04 or R01--R10 credit.

