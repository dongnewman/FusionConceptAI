# AD-34 G3 binding / feedback independent review R2

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g3_control_arch_independent_review`)  
Parent review: `docs/implementation/AD-34/g3_binding_feedback_independent_review_r1/`  
Repair reviewed: `docs/implementation/AD-34/g3_binding_feedback_audit/repair_r1/`  
Decision: `changes_requested`  
Scope: read-only architecture and boundary review; no implementation acceptance

## Evidence boundary

I read the R1 independent review, the repair proposal and manifest, current
`G3SourceFeedbackLawV1`, current T0 declaration transport, the current control
source/test/archive, and AD-31/AD-32 acceptance records. The repair proposal
hash in its manifest matches the local file (`15eed51b...d5cb4e`). No reviewed
file was modified. No Julia, DESC, or heavy Python command was run.

The repair is directionally correct and closes the broad model ambiguity: the
binding is an editable sibling with an immutable source payload and separate
editable body; `insert_link`, `replace_link`, and `delete_link` are the only
state operations; feedback stays in the T0/T1 transport boundary; target
metadata is separated from runtime numerical evidence; and the two child slots
are explicit `PresentChildBindingV1 | AbsentChildBindingV1` unions with an
absence digest. Those points are not enough to dispatch the implementation.

## R1 findings

### B01 — partially closed: source/body hash contract is still not executable

The immutable source versus editable body choice is now the right choice. The
proposal says source, source-record, parent, child-slot and child-identity
hashes remain fixed while body, operation, state and ordered history change.
That closes the original semantic conflict.

The field and hash freeze is incomplete, however:

* the proposal derives `initial_body_hash` from an “initial link set declared by
  the immutable source payload”, but `G3BindingSourcePayloadV1` has no
  `initial_links` field and `immutable_binding_schema` explicitly excludes a
  mutable link tuple;
* `initial_source_state_hash` is defined in a recipe but is absent from
  `G3BindingStateV1` and from the manifest hash-layer list;
* `child_identity_hash` is derived and then used as
  `fixed_child_identity_hash`, but the source payload has no field carrying the
  binding child identity or a precise construction step that seals it before
  the editable body is built;
* `ordered_operation_history::Tuple` has no element type or canonical rule for
  storing complete receipts versus operation IDs. The proposal requires one
  appended ID but does not define duplicate operation-ID rejection, ordering,
  or the zero-operation/latest-operation invariant.

Before dispatch, freeze the missing fields and canonical bytes. State whether
initial links are an explicit immutable source field or the first editable
body, add the initial-state identity consistently (or remove its recipe), put
the binding child identity in one named owner, and type history with a unique,
ordered representation plus a distinct duplicate-operation failure. The
operation must remain a state edit only; rebind, source publication and child
promotion must stay outside CAS.

### B02 — not closed: current declaration still has two authority representations

The repair proposes a T0-owned `G3DeclarationAuthorityRefV1`, one object per
`(candidate_ref, layer)`, exact canonical-byte equality, and fail-closed
duplicate/foreign/stale/contradictory controls. That is the correct target
architecture, but it is not mapped to the current contract.

The current `G3SFFeedbackTargetV1` still stores
`authority::G3SFAuthorityV1`, while `G3SFDeclarationV1` separately stores an
`upstream_authority::Tuple{Vararg{G3SFAuthorityV1}}`. Current G3 validation and
T0 transport check candidate/status conditions on those collections separately;
they do not enforce target-to-upstream canonical equality. The repair does not
specify whether the existing target field is removed, treated as a legacy view,
or deterministically converted to the new typed declaration reference. It also
uses `:typed_absent | :present | :actual_claim`, whereas the current source
uses `:actual | :missing | :historical_absent | :stale | :contradictory`, with no
closed mapping.

Keep feedback child creation forbidden, but add a field-level migration rule:
one declaration-level authority object is canonical, every target carries only
its typed reference (or an explicitly non-authoritative legacy projection),
and T0/T1 reject any mismatch in candidate, layer, declaration ref/hash,
canonical bytes, status, attestation, or receipt. Freeze the status domain and
negative-control ownership in the T0/T1 work order. Until that rule exists,
the “single authority” claim is only a proposal statement.

### B03 — closed at architecture level

The repair correctly assigns target path, quantity, unit, direction, sign,
source ID and authority edits to a rebuilt parent G3 declaration followed by a
new T0 bundle. It assigns residual/loss/thermal/deformation numbers to a
candidate/scenario/solver-input/provider/evidence record. Those values do not
enter the binding body, T0 declaration metadata, CAS, or authority promotion.
No feedback-child files are admitted. This finding is closed subject to the
future owner recording the stated evidence identity and provenance.

### B04 — closed at architecture level

The repair gives present and typed-absent branches with no fabricated child
reference or identity in the absent branch, computes an independent
`absence_digest`, and makes absent-to-present promotion a fresh same-candidate
source publication rather than a CAS operation. It also keeps the binding
child identity separate from realization/control child identities. The future
implementation must preserve these exact unions and reject fixture-derived or
foreign promotion.

### B05 — not closed: control refresh receipt is wrong and now stale again

The repair manifest says the supplied `7a11562...b4882` identity is the
control source but compares it to
`src/GenomeV5/G3/ControlGenomeV5.jl` (`eb0c672d...c7135`), which is the old
control genome. The supplied identity belongs to the separate
`G3ControlChildEditabilityV1.jl` artifact. A comparison between those two
paths is not a source refresh.

The current read-only checkout has since changed local control bytes again:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`:
  `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`;
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`:
  `b14d2623dceb95b034dde6f07ec418d6bb60f0c69493f4a4fca6627661da7abd`;
* the control archive manifest still records the older `7a11562...b4882` and
  `aa34bcb...4fb9` values.

Refresh the AD-34 repair receipt with the exact current paths and hashes, and
state that the control archive is a separate pending-review record. Do not
back-attribute any current control source, focused test, or software receipt
to AD-34/AD-32. Keep actual control, source-backed T1, T0/T1/T2, provider,
engineering, physical, search, B00, B04 and R01–R10 credits false.

## Boundary and dispatch ruling

The six-file future binding scope remains acceptable and disjoint from the
old binding/package/registry, AD-31, AD-32, T0 and feedback transport paths.
The DAG remains acyclic: source-feedback precursor in parallel with AD-31,
AD-32, binding and T0, followed by a same-candidate T1 join and T2 receipt
rebuild. The listed CAS order, complete before/after link hashes, stale-source/
body/state checks, atomic failure bytes and no feedback child are the correct
exit conditions.

`pass_limited` is therefore not granted. The minimum repair is to close the
source initial-state/identity/history fields, define the current-to-single-
authority mapping and exact status domain, and correct the control refresh
paths and hashes. After that, Sol may accept only the architecture/work-order
boundary and dispatch a different Luna implementer plus independent reviewer;
no machine node may be created as accepted, and no implementation, feedback
child, T0/T1, engineering or physical credit may be promoted by this review.
