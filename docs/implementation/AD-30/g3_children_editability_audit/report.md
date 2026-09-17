# AD-30 G3 child editability audit

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

G3 V1 can provide a useful contract-only precursor for candidate-owned
realization, control, and coupled-binding editability. It cannot populate an
actual child bundle yet. The precursor may proceed in parallel with the AD-30
T0 transport work because it only needs typed local bodies, a new versioned
contract, and explicit absence records. A populated child, a T1 package, or an
actual feedback authority remains gated by a fresh same-candidate G1/G2
binding envelope and source-backed four-axis records.

The old `RealizationGenomeV5`, `ControlGenomeV5`,
`CoupledRealizationControlBindingV2`, `RealizationControlGenomeV5`, their
integration entry, `CandidateStatePackageV5`, the shared registry, and all old
receipts remain read-only. A ref-only adapter or a projection that drops G3 V1
law/authority/edit fields is rejected as lossy.

This audit is read-only except for this report and its manifest. It did not run
Julia, DESC, a provider, a mesh, a solver, or a physical calculation.

## Source comparison

`G3SourceFeedbackLawV1` is already candidate-owned and content-hashed at the
declaration level. Its complete body contains `candidate_ref`, `source_id`,
`owner_scope`, typed source/field/return/heat/ledger endpoints, a conservative
split, heat and ledger relations, all ledger entries and closure, feedback
targets, and upstream G1/G2 authority state. `declaration_hash` is recomputed
from that complete body. Feedback also retains target path, quantity, unit,
direction, sign, source ID, authority ref/hash/status and attestation. The
current source intentionally has no realization, control, or binding child
fields; its missing authority remains `terminal_deferred` and its execution
ceiling is contract-only.

The old realization child has a typed resource network: resource ports,
components with capacities/material/manufacturing links and state/events,
material and manufacturing domains, ledger accounts/entries/closures,
provider status, `plan_hash`, and `candidate_hash`. Its only exposed edit
helper is component capacity replacement, which reconstructs the network and
both hashes. It does not carry a source payload/provenance object or a general
edit receipt.

The old control child has signal ports, controllers, faults, a control plan,
provider status, `plan_hash`, and `candidate_hash`. Its edit helper changes a
fault mode and reconstructs the candidate hash. It has no source payload,
source identity, edit operation hash, or physical feedback result.

The old coupled binding has typed child contract bindings, control-resource
links, and a compact feedback channel. It validates link ownership and target
URI/version shape, but its feedback channel omits the G3 V1 target path,
quantity, direction, sign, authority ref/hash/status and attestation. The old
bundle requires all three concrete children and cannot represent a typed
absent child. Its candidate hash is therefore not a lossless carrier for the
new declaration.

The old integration and package perform concrete type checks for the old G1,
G2, and G3 types. This is an explicit compatibility boundary: old package
construction cannot be used to install the V1 declarations without dropping
semantics.

## Minimal additive successor

The bounded successor should be a new, disjoint `G3ChildEditabilityV1`
contract. It may be implemented as one new file containing the following
typed records; it must not alter or subtype the old V5 records:

* `G3ChildSourcePayloadV1`: `child_kind` (`realization`, `control`, or
  `binding`), stable `child_id`, candidate ref, parent G3 declaration ref and
  hash, layer contract ref, source URI/version, complete typed semantic body,
  source provenance status, and `source_content_hash`. The body must contain
  every field needed by the selected child: the realization resource,
  material, manufacturing and ledger structures; the control signal,
  controller, fault and plan structures; or the binding links and the full
  G3 V1 feedback target/authority structures.
* `G3ChildEditOperationV1`: immutable operation ID, child kind, canonical field
  path, operation (`insert`, `replace`, `delete`, or `rebind_source`), typed
  before/after value or typed absence, expected prior child/content hash,
  authoring source/provenance ref, and operation hash. Unknown paths,
  duplicate IDs, and an old-hash mismatch must fail closed.
* `G3ChildStateV1`: one materialized child payload or an explicit typed-absent
  marker. A child marked absent has `child_ref=nothing`,
  `source_content_hash=nothing`, a stable absence reason, its own absence
  content hash, and an independent `terminal_deferred` gap. An `actual` child
  requires a same-candidate source payload, exact public contract ref, all
  four axes, and the required trusted external receipt; a label or fixture
  cannot supply these.
* `G3ChildEditabilityEnvelopeV1`: parent G3 declaration candidate/ref/hash,
  three independently named child states, the ordered edit-operation tuple,
  per-child four-axis provenance, binding links/feedback state, and a bundle
  identity. The envelope records realization, control, and binding status
  separately, so one missing child does not erase another child's evidence
  gap.

The successor's realization body should preserve the old network fields and
add candidate-owned source/provenance and edit identity. Its control body
should preserve the old signal/controller/fault/plan fields and add the same
identity envelope. Its binding body should preserve link ownership fields and
add exact realization/control child refs and hashes, parent G3 declaration
hash, full feedback target metadata, and authority status. No field is copied
from an old receipt unless a fresh source-bound migration record proves the
mapping.

The local edit API is intentionally narrow but composable:

* realization: replace a component capacity, resource port, material or
  manufacturing domain, ledger entry/closure, state, or event;
* control: replace signal port, controller, fault path, plan membership,
  state, or event;
* binding: insert/replace/delete a control-resource link or a complete
  feedback target, including its target ref, path, quantity, unit, direction,
  sign and authority state; and
* source rebinding: replace a typed source URI/version/payload only with a new
  candidate-bound source receipt, otherwise return typed deferred or
  fail-closed conflict.

Every accepted local edit reconstructs the affected typed body and validates
its local invariants. It then recomputes all affected hashes and the envelope
identity. A stale supplied hash is never silently repaired. These are editable
contract states; they do not claim provider, engineering, or physical
feedback.

## Identity and hash recipe

Use the repository canonical UTF-8/UTF-8-valid, LF, ordinal-field,
order-preserving tuple canonicalizer and SHA-256. The recipe must be written
in the future implementation source and independently reproduced by its
reviewer:

1. `source_content_hash = H((child_kind, source_uri, source_version,
   candidate_ref, source_content))`. The source content is the complete typed
   child body, never a URI, fixture seed, or field-hash list.
2. `operation_hash = H((operation_id, child_kind, field_path, operation,
   before_value, after_value, expected_prior_hash, provenance_ref))`.
3. `child_hash = H((child_kind, child_id, parent_g3_ref,
   parent_g3_declaration_hash, candidate_ref, contract_ref, four_axes,
   source_content_hash, semantic_body, ordered_operation_hashes, status))`.
4. `binding_hash = H((candidate_ref, parent_g3_declaration_hash,
   realization_child_ref/hash, control_child_ref/hash, links, full_feedback,
   four_axes, status))`.
5. `envelope_hash = H((parent_g3_body_hash, three_child_states, all source,
   child, operation and binding hashes, axis records, feedback/authority
   records, independent gaps, resolution))`.

The typed-absent marker is part of the envelope hash. It must have a stable
absence-content hash but must not fabricate a child ref or source hash. Any
source rebinding, body edit, parent declaration edit, axis change, authority
change, child state change, or operation-order change invalidates the affected
hashes and the envelope identity.

## Four axes and same-candidate binding

Each child state needs an explicit source-backed record for
`payload_schema_version`, `canonicalization_profile_version`,
`applicability_profile_version`, and `evidence_receipt_version`. Each record
must include axis name, exact typed ref/value, source ref/path, source hash and
status. Missing axis provenance is an independent `terminal_deferred` gap;
conflicting value, source hash, candidate, layer, or version is
`fail_closed`. A local schema constant or the old G3 V5 `G3VersionAxesV2`
default is not candidate authority for a new child.

The envelope must use one fresh `QualifiedRefV1` candidate identity shared by
G1, G2, G3 and all present children. G2's current V1 candidate field is a
`GenomeContractRef`, so the envelope must carry a typed
`GenomeContractRef -> QualifiedRefV1` mapping receipt and verify exact source,
version, schema/canonical/profile hashes and candidate identity. It must never
parse a URI, reuse a fixture seed, or alias a hash. G3 feedback authority must
compare the full target ref and child/parent candidate identity; an unattested
or foreign `actual` authority is fail-closed, while genuinely missing external
authority stays an independent deferred gap.

Actual realization/control/binding child acceptance therefore requires AD-30
T0's fresh same-candidate envelope and real four-axis/source receipts. The
contract-only child precursor does not require those receipts; it records them
as typed absent/deferred inputs and can be developed while T0 is reviewed.

## External evidence boundary

Local typed construction, invariant checks, content hashes and edit receipts
can establish only `contract_admission`. A provider receipt is needed for
resource/material/manufacturing/control capability matching. Engineering
evidence additionally needs manufacturability, thermal, structural, supply,
control timing and fault-behaviour evidence from the applicable real source.
Physical evidence additionally needs the candidate-bound compiled/discretized
model, mesh/solver receipts and/or measured hardware data with the required
uncertainty and independent review. None of these can be inferred from a
passing static checker, Julia exit code, child hash, `bridge_ready`, or an edit
operation.

## Proposed finite work order

Suggested ID: `UP1-04A-VNEXT-G3-CHILD-EDITABILITY-PREC`. This is a parallel
contract-only precursor to T0, not a replacement for T0/T1/T2 and not a new
parent obligation. One Luna implementer owns exactly:

* `src/GenomeV5/G3/G3ChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-CHILD-EDITABILITY-PREC/`.

Inputs are the current G3 V1 source, the three read-only old G3 V5 files and
bundle, AD-30/T0's accepted-limited transport contract, and no historical
candidate receipts. Outputs are the four typed successor records, canonical
hash/edit helpers, an evidence manifest, a bounded focused test receipt, and
an explicit status matrix. The implementer must not edit old G3 files,
`CandidateStatePackageV5`, integration/registry files, core planning files,
or old receipts.

Required local negative controls are: foreign child or parent candidate;
G2 mapping by URI/seed alias; missing and conflicting axes; stale source or
child hash after an edit; unknown/duplicate edit path; absent marker carrying a
child ref/hash; actual child without source/axis/trusted receipt; binding link
to an absent or foreign child; full feedback path/quantity/unit/direction/sign
or authority mismatch; and attempted old-package/registry mutation. The
focused Julia process must capture raw stdout/stderr bytes, SHA-256, PID and
exit code. A different Luna must review source, receipts, all negative
controls, and dirty-work protection.

Exit status is `accepted_limited` only for the local contract/editability
scope after independent review. T0 remains required for a fresh exact join;
T1 remains gated. Provider, mesh, engineering, physical, search, B00/B04 and
R01-R10 remain false.

