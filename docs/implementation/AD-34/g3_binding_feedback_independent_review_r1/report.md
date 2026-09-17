# AD-34 G3 binding / feedback independent review R1

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g3_control_arch_independent_review`)  
Decision: `changes_requested`  
Scope: read-only architecture and boundary review; no implementation acceptance

## Evidence reviewed

I read the repository guidance and current v4 README, common contract, Genome
upgrade execution, orchestration, work orders, architecture decisions and task
manifest. I also read the AD-34 audit report and manifest, current
`G3SourceFeedbackLawV1` source/tests/archive, the AD-30 T0 transport/source and
tests, AD-31 realization records, AD-32 control records, the old G3 binding and
bundle implementations, `CandidateStatePackageV5`, and the old registry path.
No source, test, old receipt or core planning file was changed. No Julia, DESC
or heavy Python command was run.

The audit's direction is sound: binding is a plausible editable sibling
because it owns realization/control link compatibility and local closure, while
feedback is a cross-layer declaration/transport concern and must not become a
second G3 child. The proposed binding file set is disjoint from the current
realization/control/T0 paths, includes a binding source payload, source record,
state and operation receipts, and the dependency graph keeps the precursor
parallel to AD-31, AD-32 and T0 with T1/T2 mapping downstream.

The audit cannot be accepted for dispatch yet because four contract gaps and
one evidence-integrity gap remain.

## Blocking findings

### 1. Link edit conflicts with source immutability

The audit says child rebind, contract change and source-record change require a
new source payload with fresh provenance, and it describes a binding source
payload as a closed source body. It also says a successful `insert_link`,
`replace_link` or `delete_link` changes the “source/content” identities.
Those statements describe two incompatible edit models:

* If the source payload/content is immutable as in the accepted AD-31/AD-32
  child contracts, a link operation must change only an explicit editable link
  body/state. `source_content_hash`, source-record ref, initial source hash and
  child identities remain unchanged. The operation needs complete prior and
  replacement editable-body/link hashes.
* If a link operation changes the source body/content hash, it is a new source
  payload publication. The operation must carry the resulting payload/source
  record identity and fresh provenance, and cannot be the stated immutable
  source CAS edit.

The audit must choose one model and freeze the fields and hash recipe before a
binding work order is dispatched. The minimum repair consistent with AD-31 and
AD-32 is an immutable source payload plus an explicit editable binding body;
the three link operations update only that editable body/state.

### 2. Duplicate G1/G2 authority is not closed

`G3SFDeclarationV1` has both declaration-level `upstream_authority` and an
embedded authority in every `G3SFFeedbackTargetV1`. Current validation and T0
transport checks validate these collections separately; they do not require
the target authority for layer G1/G2 to be byte-equal to the one canonical
declaration-level authority. Therefore the proposed statement that feedback
cannot become a second G1/G2 authority is not yet an executable invariant.

The repair must define the sole authority owner. Either feedback targets carry
only a typed reference to the declaration-level authority, or T0/G3 validation
must require exact semantic/canonical equality by `(candidate_ref, layer)` and
fail closed on any mismatch. A target-level `actual` status must never promote
authority independently of the canonical upstream receipt. The rule must be
carried into the T0 negative controls and later T1 join.

### 3. Feedback target metadata and feedback values are conflated by omission

The current G3 feedback target is a route declaration containing target layer,
path, quantity, unit, direction, sign, source ID and authority; it has no
numeric feedback value. The audit correctly keeps target metadata in the G3
declaration/T0 bundle, but it does not state the boundary for a runtime
feedback value. The repair must explicitly freeze both cases:

* changing target path, quantity, unit, direction, sign, source ID or authority
  is a parent G3 declaration edit and rebuilds the declaration and T0 bundle;
* a runtime numeric residual/loss/thermal/deformation value is not a G3 child
  edit and is not a T0 declaration value. It belongs to a candidate/scenario/
  input/provider/evidence record owned by the relevant execution/T1 boundary,
  with its own source and hash. It cannot be changed through a feedback-child
  CAS or used to promote authority.

If a future design wants a candidate-editable feedback value, it must first add
an explicit typed parent declaration field and hash/provenance rule; it cannot
be smuggled into the proposed transport record.

### 4. Typed absent child refs are underspecified

The proposed binding body lists `realization_child_ref/hash` and
`control_child_ref/hash`, then says a precursor may carry “typed absent child
references.” This is unsafe wording: a placeholder or synthetic ref/hash can
look like actual child authority. The repair must give each child ref/hash an
explicit present-or-typed-absent union, with absence reason and independent
absence digest, no fabricated child ref/hash in the absent branch, and an
exact same-candidate/source-backed check before T1 promotes the child. The
binding source payload must retain its own source child identity separately
from these optional downstream child refs.

## Evidence and current-state issue

The AD-34 manifest is stale against the current control slice. Its recorded
hash for `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` is
`9884bffce32676240320536592cc9b8796fcc4e8233bbefd02a860bd856be1da9`, while
the current file is
`aa34bcb8fef7211d071d8f2b3a23fd193e6d0081ecf1908cc3fafa679f794fb9`.
The current control source also exists with SHA-256
`7a11562caf25e138e6e8ae0adac79d4e384577c936e8fb7f29dcb8c8256b4882`, and its
implementation archive is present and still `review_pending` with
`actual_control_child=false`. The AD-34 manifest does not list that current
source hash even though its report says current source/test/fixture bytes were
recorded. Refresh the AD-34 input receipt and report before using the audit as
a binding dispatch basis; do not back-attribute the current control slice to
AD-34 or treat its `51/51` focused software receipt as physical or actual
control authority.

## Required minimum repair before dispatch

1. Freeze immutable-source versus editable-link semantics and rewrite the
   source/content/state/operation hash layers accordingly.
2. Add the single-authority equality rule for upstream and target feedback
   authority, including T0/T1 fail-closed negatives.
3. Separate declaration target edits from runtime feedback values and state
   the owner and identity of value/evidence records.
4. Specify typed absent child refs/hashes and absence digests without
   placeholder authority.
5. Refresh the AD-34 manifest/report inputs for the current control source,
   test and archive, preserving actual binding/feedback/T0/T1/T2/provider/
   engineering/physical/search/B00/B04/R01--R10 as false.

After these repairs, the binding sibling can be independently re-reviewed for
dispatch. Feedback should remain a T0/T1-owned immutable transport boundary;
no feedback-child source/test/fixture/static-QA scope should be created.
