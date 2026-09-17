# CORE-STATUS-SYNC-AD40-AD42-BINDING independent review R1

Date: 2026-09-15 UTC  
Reviewer: different Luna/high, read-only  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Verdict: `changes_requested`

## Scope

This review read `AGENTS.md`, the v4 README, the common contract, the
orchestration contract, the execution work orders, the task manifest, the
implementation index, the previous core-sync independent review R2, the
current core-sync report/manifest/raw status records, AD-39, AD-40 and its W2
R2 review, AD-41 R3, AD-42 and its independent review, and the G3 binding
precursor and status review. No reviewed file, source, test, fixture, task
manifest, historical receipt or core document was modified.

The current planning validator passed with 31 markdown files, 497 relative
links, 39 tasks and an acyclic DAG (PID `84936`, exit `0`). The current task
manifest has 39 tasks and SHA-256
`7D1700038F78DD1EA872CBC3FD6DA29C5071596DAE40D0C43B598B501195BAE8`.
The exact task-owned directory scope is closed at 14 files (PID `76064`,
exit `0`), and the scoped diff check exited `0` (PID `80792`). A supplemental
five-document whitespace/conflict scan also exited `0` (PID `44764`).

## Finding requiring repair

The core-sync manifest has an invalid output hash entry for
`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md`.
The current file is 77,295 bytes with SHA-256
`A5DBBCA671F6F988D9B769D2C5C96D2861BEB9F7B8FE3F28385CA9BBED29614F` (64
hexadecimal characters). The manifest records
`A5DBBCA671F6F988D9B769D2C5C96D2861BEB9F7B8FE3F28385CA9BBED29614F7` (65
characters), which is not a SHA-256 value and does not close against the
file. The fresh JSON/hash closure therefore exited `1` (PID `81204`). The
other four synchronized-document hashes, byte counts, task-manifest hash and
task count passed.

Repair only the task-owned synchronization evidence: replace that malformed
manifest value with the recomputed 64-character SHA-256, rerun the complete
JSON/hash/control/scope validation, and append a fresh receipt. Do not alter
the five core documents or reinterpret any status. The existing first
unordered scope-check failure remains correctly preserved as historical
evidence; the later exact scope check passed.

## Status and claim-boundary review

The five core documents accurately preserve the requested architecture
boundary after the hash-record defect is set aside. AD-39 and AD-41 remain
`accepted_limited` static/audit scopes. AD-40 remains limited to the
RepositoryDesignSourceAuthorityV1 architecture and seven finite work-order
contracts. The AD-40 W2 R2 review covers four repaired typed-absence authoring
observations; the payloads have no candidate identity or authority and do not
promote present, T0, T1, T2, provider, mesh, solver, engineering, physical,
search or R01-R10 evidence.

AD-42 remains `accepted_limited` for the cycle-break and W0 to W2R1
preparation boundary. Its four W0 products hash-close (PID `53108`, exit `0`)
but are explicitly parallel, prepare-only, excluded from acceptance and grant
no authority, present, T0 or R01-R10 credit. W2R1 future products remain
absent. The AD-42 earlier checker failures remain preserved.

The local G3 binding precursor is accepted only for its local typed-absence
software slice. Its machine node remains
`planned`/`proposal`/`accepted=false`/`review_pending`; no checked-present
authority, actual binding/feedback child or CAS promotion exists. The task
manifest contains no AD-39, AD-40, AD-41, AD-42, W0 or W2R1 machine node.
The synchronized claims remain `present=false`, `T0=false`, `T1=false`,
`T2=false`, `UP2=false`, provider/mesh/solver/engineering/physical/search/
`B00`/`B04`/`R01-R10=false`, and `L4_credible_count=0`.

## Decision

`changes_requested`: the architecture and status boundaries are otherwise
consistent, but the malformed 65-character output hash prevents evidence
closure. After the manifest-only repair and fresh receipt pass, this review
can be rerun without changing any implementation or claim ceiling.

Cleanup was limited to this review-owned directory. No task-owned temporary or
unrelated file was removed; dirty work, accepted artifacts and historical
failure receipts remain protected.
