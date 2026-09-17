# Core status synchronization independent review R2

Date: 2026-09-15 UTC  
Reviewer: independent Luna/high  
Conclusion: `pass_limited`

This read-only review checked the R1 repair in
`docs/implementation/CORE-STATUS-SYNC-AD36-AD38-PREPS/repair_r1/` against the
current core documents and status records. The repaired files were not
modified. The four R1 findings are closed within the declared documentation
and status scope.

The current v4 README records 485 relative links, matching a fresh direct
`validate_plan.py` run (exit 0): 31 markdown files, 485 relative links, 39
tasks and an acyclic DAG. The task manifest remains unchanged at SHA256
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`; its live
task count is 39. The retained
`environment_gate.task_count_unchanged=false` field is now explicitly
explained in the README as an AD-29 comparison with the earlier 31-task
baseline, while the current 39-task manifest/hash remains stable.

UP4's root manifest and acceptance record now consistently say
`accepted_limited`, `accepted=true`, `review_status=accepted_limited`, and
`claim_ceiling=contract_only`. The earlier `review_pending`/`accepted=false`
state remains preserved in the package's prior status-sync history. UP4 is
still only a preparation/template package; inverse solving, engineering
back-substitution, closed-loop realization and all formal credits remain
pending.

AD-38 now records the AD-36 mandatory evidence-sidecar policy gate as
satisfied. Its current blocked set still contains checked-present same-
candidate T0 authority, the T1/T2 identity chain, fresh G1/G2/G3 and provider
receipts, accepted UP2 receipts and independent replay. AD-38 credits for UP2,
T0, T1, T2, provider, mesh, solver, engineering, physical, B00, B04 and
R01–R10 remain false. No `PhysicsCompilerV5` or machine node was opened.

AD-36 remains limited to the evidence-sidecar scope contract. AD-37 remains
limited to the absent present-baseline audit and future publication boundary;
present G1/G2 are false and no machine node exists. UP3, UP4, UP5 and UP6
remain preparation/template-only with applicable execution flags false and
formal conclusions pending. A direct task-manifest scan found zero machine
nodes for AD-36–AD-38 or the four preparation package identifiers. The checked
status records grant no provider, mesh, solver, search, engineering, physical,
B00, B04, R01–R10 or L4 credit; L4 credible count remains zero.

The repair R1 receipt was independently rechecked. All 8 current output
records and all 20 raw receipts recorded by the repair manifest matched their
current byte counts and SHA256 values: 28/28 checks passed, including the
20/20 raw receipt closure. Twenty relevant JSON manifests parsed successfully,
the nine-file control-character scan found zero control characters, and the
scoped `git diff --check` exited 0. No Julia, DESC, provider, mesh, solver,
search, engineering or physical command was run.

Evidence and raw receipts are retained beside this report:

- `validate_plan.*` records the current planning validator and real PID/UTC;
- `hash_bytes_checks.*` records the 8-output plus 20-raw-receipt closure;
- `json_state_checks.*` records parsing and state assertions for 20 JSON files;
- `control_check.*`, `diff_check.*` and `machine_node_check.*` record the
  remaining independent checks and their process receipts.

This `pass_limited` result accepts only the repaired core status consistency
and the stated contract/template boundaries. It does not accept any formal
execution gate, source-backed present declaration, provider, mesh, physical,
engineering, search or parent R01–R10 objective.

Cleanup was limited to this review-owned directory. Existing dirty work,
repair history, accepted artifacts and prior receipts were preserved; no
launcher or unrelated temporary file was created.
