# Core status synchronization: AD-39–AD-42 and G3 binding

Date: 2026-09-15  
Owner: Sol/root architecture lane  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

This record synchronizes the current core documents after the independent
reviews of AD-39, AD-40, AD-40 W2, AD-41, AD-42 and the G3 binding precursor.
The scope is documentation/index synchronization and static planning
validation. It does not modify `task_manifest.json`, source, tests, runners,
fixtures or historical receipts.

AD-39 and AD-41 are `accepted_limited` static audit scopes. AD-40 is
`accepted_limited` for the RepositoryDesignSourceAuthorityV1 architecture and
seven finite work-order contracts. The repaired AD-40 W2 payload/receipt
outputs are point-in-time, typed-absence observations and remain excluded from
source authority, candidate identity and present publication. AD-42 is
`accepted_limited` for the schema/profile → fresh-seed → payload cycle break and
the W0→W2R1 preparation boundary; W0 remains parallel and prepare-only.

The G3 binding precursor is `accepted_limited` only for its local typed-absence
software behavior and source/test evidence. Its machine node remains
`planned`/`proposal`/`accepted=false`/`review_pending`. No checked-present
authority, actual binding or feedback child, CAS promotion, candidate hash, T0,
T1 or T2 result is created or inferred.

## Preserved boundaries

G1/G2 source-backed public refs, payload authority and present publication
remain false. T0/T1/T2, UP2, provider, mesh, solver, engineering, physical,
search, B00/B04 and R01–R10 remain false; L4 credible count remains zero.
The ordered UP1→UP2→UP3→UP4→UP5→UP6 gates and the separately authorized UP3–UP6
preparation limits are unchanged. No AD-39–AD-42 or W0/W2 machine node was
added.

## Validation evidence

The plan validator passed with 31 markdown files, 497 relative links, 39 tasks,
and an acyclic DAG. The unchanged task manifest has 39 tasks and SHA-256
`7D1700038F78DD1EA872CBC3FD6DA29C5071596DAE40D0C43B598B501195BAE8`. Scoped
`git diff --check` passed for all five synchronized documents. The measured
link-token count in the five edited documents was 429; this is a static
documentation measurement and is not physics or implementation evidence.

Raw stdout/stderr, PID, UTC and exit records are preserved under this task's
`status/` directory. Cleanup found no task-owned temporary or unrelated files;
pre-existing dirty work, other-agent files and historical failure receipts were
left untouched. The first unordered scope-check invocation returned exit 1 due
to its checker comparison, with no file mutation; that receipt is preserved and
the corrected sorted-set check returned exit 0 with an exact ten-file owned set.

## Repair R1

Independent review R1 found one evidence-closure defect: the main manifest
recorded a 65-character SHA field for
`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md`.
The original bad value and review receipt remain append-only. Repair R1 changed
only that manifest field to the recomputed 64-character SHA
`A5DBBCA671F6F988D9B769D2C5C96D2861BEB9F7B8FE3F28385CA9BBED29614F` for the
unchanged 77,295-byte file. The repair reran JSON/hash, plan validation,
path-scope, control-character and scoped diff checks; all final exits were zero.
