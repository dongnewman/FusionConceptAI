# CORE-STATUS-SYNC-AD40-AD42-BINDING independent review R2

Date: 2026-09-15 UTC  
Reviewer: different Luna/high, read-only  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Verdict: `pass_limited`

This review checked the parent core synchronization, repair R1, the prior
independent R1, and the current core contracts/status records. No reviewed
file, source, test, fixture, task manifest, historical receipt or core
document was modified. Only this `independent_review_r2/` directory was
created.

The repair is closed. The current
`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md`
is 77,295 bytes with SHA-256
`A5DBBCA671F6F988D9B769D2C5C96D2861BEB9F7B8FE3F28385CA9BBED29614F`, and the
parent sync manifest records the same 64-character value. The former invalid
65-character value ending in `...29614F7` remains preserved in
`repair_r1/manifest.json` as `before_bad_sha256` and in the prior R1 report and
raw receipt. The repair manifest is `accepted_limited` for this one evidence
field correction only; no status or claim was promoted.

Fresh validation passed:

- planning validator: 31 markdown files, 497 relative links, 39 tasks and an
  acyclic DAG; PID `72612`, exit `0`;
- JSON/hash closure: all five synchronized-document hashes and byte counts
  match, all recorded SHA-256 values are 64 characters, and repair before/after
  provenance closes; PID `80624`, exit `0`;
- repair scope: exact 14 files, no missing or extra paths; PID `14556`, exit
  `0`;
- control-character scan: 13 JSON/text sidecars clean; PID `18032`, exit `0`;
- scoped diff check: exit `0`, PID `77496`;
- no-credit/status scan: all claims remain false, L4 remains zero, the G3
  binding machine node remains `planned`/`proposal`/`accepted=false`/
  `review_pending`, and no AD-39/AD-40/AD-41/AD-42/W0/W2R1 machine node exists;
  PID `82000`, exit `0`.

The AD boundaries remain accurate: AD-39 and AD-41 are static audits; AD-40
is limited to RSDA architecture and seven finite work orders; AD-40 W2 remains
four typed-absence, point-in-time excluded observations; AD-42 remains the
cycle-break and W0→W2R1 preparation boundary. W0 parallel products remain
excluded from acceptance and W2R1 products remain absent. The local G3 binding
precursor remains typed-absence software scope only. Present, T0, T1, T2,
UP2, provider, mesh, solver, engineering, physical, search, B00, B04 and
R01–R10 remain false; L4 credible count remains zero.

`pass_limited` accepts only the repaired documentation evidence closure and
the preserved architecture/status ceilings. It grants no implementation,
source-backed present authority, candidate identity, execution, physical or
parent-goal credit.

Cleanup was limited to this review-owned directory. No task-owned temporary or
unrelated file was removed; pre-existing dirty work, accepted artifacts and
historical failure receipts remain protected.
