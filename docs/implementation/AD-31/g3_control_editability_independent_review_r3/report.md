# AD-31 G3 control-only source-edit proposal R3: independent review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

R3 closes most of the R2 contract gaps. The immutable source payload versus
editable materialized body is a coherent design for a control-only mode edit,
the initial status is now included in the frozen initial hash, typed absence is
represented explicitly, and the operation history recipe avoids the previous
current-state self-recursion. The old `g3_edit_fault` semantics, sibling
scheduling, no-T0 boundary and physical evidence ceiling are preserved.

One identity gap remains material: the operation input has a
`source_record_ref`, but the operation record and operation hash omit it; the
state's `source_payload_ref` also omits the parent declaration ref, child
contract ref and source-record URI/version. Therefore an exact source/ref
identity change can be hidden behind the same source-record/content hashes and
the same operation hash unless an unstated external lookup rule is added.
There are two smaller schema gaps around the unparameterized history tuple and
the physical deferred reason. These must be closed before implementation
dispatch.

## R3 checks that pass

R3 freezes the complete control body field order and the principal type and
symbol domains. The signal, controller, initial-state, event, fault and plan
records preserve the old fields and validation meaning: direction and unit,
sensor/actuator/resource memberships, cardinality, fault references, positive
deadline, typed state/events and exact plan membership. It keeps the new body
disjoint from `ControlGenomeV5`, `RealizationControlGenomeV5` and the old
package/registry.

The provenance slot, source record, source-record reference, source-payload
reference, payload, present state and typed-absent state now have explicit
field orders and types. Present slots bind their candidate; absent slots have
no value/source hash and carry a reason and absence hash. A typed-absent state
has no editable body, no source payload ref and no valid edit path.

The source/edit split is mechanically coherent. A valid operation keeps the
sealed source payload, source record/axes, child key and contract identity,
source-content hash, parent hash and both initial hashes unchanged. It changes
only the editable body, appended operation record, last operation hash and
resulting current-state hash. The historical name
`replace_fault_source_payload` is explicitly documented as updating editable
state only, so the implementation can preserve compatibility without mutating
the source layer.

The operation record and hash chain are now acyclic: the operation hash omits
the resulting state hash, the resulting hash uses prior operation hashes and
the new operation hash, and the result hash is stored only after that
calculation. The previous-state chain, duplicate/order controls and
byte-preserving failure requirement are explicit. The control slice remains a
sibling of realization and T0, with no realization dependency, no T0 import or
authority redefinition, no feedback/binding child, and no provider,
engineering, solver, mesh or physical credit.

## Required repairs before implementation dispatch

1. Bind `source_record_ref` into the operation identity. The exact operation
   input contains `source_record_ref`, but `G3ControlOperationRecordV1` has no
   such field and `operation_hash` is calculated without it. Add the closed
   record reference to the operation record and hash, or make it a strict
   deterministic field of the source-payload reference and state that this is
   the sole identity. The successful receipt and current-state identity must
   bind the exact record URI, record version and record hash. A changed record
   locator/ref with the same content hash must fail closed.

2. Complete the source-payload identity carried by state. The present
   `G3ControlSourcePayloadRefV1` has candidate ref, parent hash, child contract
   identity hash, source URI/version, source-record hash and source-content
   hash, but omits the parent declaration ref, actual child contract ref and
   source-record URI/version. Either add those typed fields in frozen order or
   define a separately recomputable payload identity that includes them and is
   validated before every edit. The state must be able to prove exact
   same-candidate parent/child/source refs without dereferencing an unstated
   external store. This is especially needed because source-content hash
   includes the full payload, while the state ref currently does not carry the
   full identity that it claims to reference.

3. Parameterize the history type and freeze its canonical representation. The
   state sketch still says `operation_history::Tuple`; require
   `Tuple{Vararg{G3ControlOperationRecordV1}}` (or an equally closed typed
   variant) and define the canonical serialization used by the state hash.
   Keep the stated uniqueness of operation ID, operation hash and
   `(fault_id, previous_state_hash)`, and reject a reused ID or edited record
   before state mutation.

4. State the exact five-layer recipes in one canonical field list. R3 gives
   exact formulas for initial, operation and resulting-state hashes, but the
   child-contract identity and source-content recipes are described in prose,
   and the source-record recipe says “first six fields” without repeating the
   slot field order. Freeze the complete canonical inputs, including whether
   source-record URI/version and operation source-record ref are semantic
   inputs. The recipes must remain acyclic and independently recomputable by
   the focused tests.

5. Fix initial and absent sentinel details. Define
   `last_operation_hash=ZERO_DIGEST` for an empty history and for a typed-absent
   state, and make that value derived/validated or included in the initial
   identity. Define the exact allowed reason/authority representation when a
   present state uses `physical_resolution=:terminal_deferred`; R3 says an
   explicit typed deferred reason is supplied but the state has no dedicated
   field for it. It must not be an unbound status symbol or a local promotion.

6. Preserve the byte-invariance claim with an executable canonical-byte rule.
   “Original state object and its canonical bytes unchanged” is the correct
   boundary, but the implementation must specify the canonical serializer and
   return the exact prior state for every stale, forged, foreign, malformed,
   duplicate, reordered, typed-absent and non-mode failure. This includes
   source-record-ref mismatch and payload-ref mismatch after repairs above.

## Scheduling and evidence boundary

After the above repair, the finite implementation may remain a control-only
sibling of `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` and
`UP1-04A-VNEXT-T0`, depending only on `UP2-01-G3-SOURCE-FEEDBACK-V1` and the
accepted AD-31 architecture boundary. It must not import or redefine T0,
depend on realization, modify old V5/package/registry data, or add a
sibling-to-sibling edge. T1 remains the only later owner of the fresh
same-candidate three-child lossless mapping.

This review writes only this report and manifest. No Julia, DESC, provider,
mesh, solver, engineering or physical command was run. Any future focused
receipt can establish only the local software contract/editability slice;
actual-child authority, T0/T1/T2 completion, provider, engineering, mesh,
physical, search, B00, B04 and R01--R10 remain false.

