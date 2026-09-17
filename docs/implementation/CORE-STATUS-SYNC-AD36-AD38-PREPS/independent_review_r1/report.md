# Core status synchronization independent review R1

Date: 2026-09-15 (UTC)
Reviewer: independent Luna/high
Conclusion: `changes_requested`

This is a read-only review of the current AD-36 R3 receipt, AD-37/AD-38
acceptance chains, UP3–UP6 early-preparation packages, the active core planning
documents, and `task_manifest.json`. At the time of the review there was no
pre-existing `docs/implementation/CORE-STATUS-SYNC-AD36-AD38-PREPS/` status
sync directory; this directory is the review-owned output. The existing
`CORE-STATUS-SYNC-N10/` directory is an unrelated historical record and was
not treated as the requested sync.

The independent checks confirmed the main frozen boundaries. The task manifest
parsed, contains 39 tasks, and has SHA256
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`, matching
the hash recorded by AD-36 status_sync_r3. The planning validator exited 0 and
reported 31 markdown files, 485 relative links, 39 tasks and an acyclic DAG.
The selected T0/T1/T2, upstream declaration and UP2 execution tasks remain
planned/unaccepted. The parent goal still lists R01–R10, has
`discovery_goal_achieved=false`, and has zero credible candidates. No machine
node, provider, mesh, solver, search, engineering, physical, B00, B04 or
R01–R10 credit was found in the checked status records.

AD-36 is correctly limited to the mandatory evidence-sidecar scope contract;
its parent count/DAG fields remain 39/unchanged, and its current root and R3
manifests agree. AD-37 is correctly limited to present G1/G2 absence and
future publication boundaries: both present flags and both future publication
statuses remain blocked, and no machine node is created. AD-38 is correctly a
static compile/discretization gap audit with execution and PhysicsCompilerV5
closed. UP3–UP6 all retain `claim_ceiling=contract_only` and all applicable
execution flags are false. Their acceptance text retains pending formal gates,
and no preparation package is treated as a candidate, solver, physical or
engineering result.

The AD-36 R3 receipt is internally closed under an independent recomputation:
27 referenced input/raw files matched their recorded byte counts and SHA256
values; the preserved reconciliation failure has exit 1 and the final
reconciliation has exit 0. The JSON parse, scoped `git diff --check`, control
character scan and independent planning validation all exited 0. The raw
receipts and failed attempt remain append-only and were not overwritten.

The review cannot pass the current core synchronization because three
current-state inconsistencies remain:

1. `docs/v4_multitopology_generation/README.md:148` records 466 relative
   links, while the direct current validator reports 485. The 485 value is the
   verified current value and must be the value used by the core sync; the
   stale 466 statement must be corrected or explicitly retained as historical.
2. `docs/implementation/README.md:80` describes UP4 as `accepted_limited`, but
   `docs/implementation/UP4-EARLY-PREPARATION/manifest.json` remains
   `status=review_pending` and `accepted=false`, and its acceptance record
   repeats that machine status. The index must not promote this package until
   its root decision is synchronized, or must state the pending status.
3. AD-38 acceptance and manifest still list `AD-36 review_pending accepted=false`
   as a blocker, although the current AD-36 root and R3 records are
   `accepted_limited`/`accepted=true`. This stale blocker needs a status repair
   or an explicit historical qualifier so the current acceptance chain is
   self-consistent.

The active task manifest also contains the legacy
`environment_gate.task_count_unchanged=false` field even though the live task
count is 39 and the manifest hash is stable. It does not change the observed
39-task DAG, but the core sync should either explain this historical field or
avoid presenting it as a current mutation indicator.

No source, test, launcher, task manifest, machine node, shared registry,
candidate package, run artifact or prior receipt was modified. No Julia, DESC,
provider, mesh, solver, search or physical command was run. The review result
is therefore a documentation/status consistency result only; it provides no
physical, engineering, provider or parent-goal credit.

Evidence and raw receipts are in this review directory:

- `audit_checks.json` and `audit.receipt.json` — 25 independent boundary checks;
- `ad36_r3_hash_closure.json`, `ad36_r3_hash_closure.stdout` and its receipt —
  current input/raw receipt closure;
- `json_parse.stdout`, `json_parse.stderr` and receipt — ten JSON manifests;
- `validate_plan.stdout`, `validate_plan.stderr` and receipt — direct planning
  validator;
- `git_diff_check.stdout`, `git_diff_check.stderr` and receipt — scoped diff
  check.

The review-owned files were created under the exact path requested by the
dispatch. Cleanup was limited to review-owned temporary material; all existing
dirty files, historical failures and prior receipts were protected.
