# UP2-00C N10 identity and receipt projection

Status: `accepted_limited`  
Accepted: `true`  
Scope: `actual_a_identity_receipt_projection_limited`

This additive work order defines a five-row N10 projection from an actual
UP1-04A `CandidateStatePackageV5`. The source-backed rows are:

- N10-01: `component_identity.g1_ref.schema_hash` (`Digest256`)
- N10-02: `component_identity.g2_ref.canonicalization_hash` (`Digest256`)
- N10-03: the typed `package.g3.binding.contract_binding.contract_ref`
  (`GenomeContractRef`) compared field by field with
  `component_identity.g3_child_refs.binding` (the five-field identity
  projection); the sibling control child used for the negative control is the
  actual `package.g3.control.contract_binding.contract_ref`
- N10-04: `package.candidate_hash` compared with its package canonical hash
- N10-05: fresh `migration_receipt.candidate_identity_after` compared with the
  identity and axes canonical hash

The factory accepts only a structurally valid actual A package. It verifies the
candidate ref, G1/G2/G3 component hashes, G2 candidate URI and typed binding,
G3 binding child ref, component identity projections, candidate hash, and fresh
receipt identity-after. The G2 plan may be reused, but the candidate ref, G2
component hash, and package identity must be rebuilt. A foreign G2 object is
rejected by the N10 factory. Wrong G3 child layer/ref, candidate hash, and fresh
receipt identity-after are source-derived `invalid_type` plus `fail_closed`.
The package-owned N10-04 and N10-05 rows carry the candidate `QualifiedRefV1`
as their source owner and the package hash as their source hash; they are not
attributed to the G3 outer ref.

All five rows retain a baseline package hash, exact source locator/type, source
ref, component hash, schema/canonicalization hashes, original and attempted
typed values, mutation hash, derived error path/code, and zero
compile/provider/solver counters. `expected_error` is test oracle metadata and
is not read by the classifier. Constructor or factory rejection must retain the
baseline and attempted value in a future execution receipt.

The fresh A receipt has `status=:pending` and no records. N10-05 therefore
covers only a fresh candidate identity-after mismatch; it is not stale legacy
receipt evidence. Actual V4 legacy source refs, before/after hashes, axes,
field mappings, identity rebuild, algorithm revision, and provenance are absent
and remain an independent `terminal_deferred` gap.

The source, fixture, tests, runner, and archive were frozen before the focused
run. The exact command then ran once in the allocated serialized lane. r1
finished with real process exit `0`: the actual-A identity and receipt suite
passed `80/80`, and the foreign candidate/receipt controls passed `7/7`.
stdout is 4294 bytes, stderr is empty, and the process record is preserved.
The process began at `2026-09-14T08:52:34.9350195+08:00` with PID `24168` and
ended at `2026-09-14T08:54:45.6496764+08:00`; no Julia or DESC process remained.
Short-lived Julia children are the runner's existing child-fixture invocations.

This is contract-only evidence. No B00/B04, provider, solver, mesh,
engineering, physical, or R01-R10 credit is claimed. The archive remains
The pre-integration author snapshot was `review_pending`/`accepted=false`;
that history is retained below alongside the later independent review.

## Limited acceptance integration

Sol accepted the independent Luna r1 `pass_limited` review for the five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding only. The independent manifest is immutable at SHA256 `ea1a548b6aeadd3c65159b043f3da203d0654c9757dea194f59dab0297cea2d0`; its reviewer runtime recorded exit `0`, actual-A identity/receipt `80/80`, foreign candidate/receipt controls `7/7`, compile/provider/solver counters `0/0/0`, and no post-run Julia/DESC process. The accepted scope is contract-only and keeps N10-04's synthetic attempted-hash boundary, N10-05's fresh-receipt-only boundary, and missing V4 legacy provenance as `terminal_deferred`.

This integration preserves the author history and the independent archive. The prior aborted `acceptance_integration/x.txt` was recorded by hash and removed as non-evidence in `acceptance_integration/aborted_artifact_removal.json`. UP2 total, all 50 formal B04 receipts/checker/two-process replay, B00, provider resolution, mesh, engineering, physical, and R01-R10 credit remain false; task-manifest total status remains `review_pending`.
