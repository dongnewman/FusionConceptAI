# UP1 external-blocker closure R4 — root acceptance

## Decision

`root_accepted_scope_limited`.

Root accepts the reviewed `20-root-decision-draft` only at the following
bounded ceiling:

| Scope | Accepted disposition |
|---|---|
| Software | `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION` |
| Formal / external | `BLOCKED_NO_CREDIT` |

This is a local software handoff and scope decision. It is not external
authority, formal credit, publication permission, physical or engineering
validation, T0/T1/T2 credit, AD/S3 credit, or parent-goal closure. The parent
goal remains `active`.

## Accepted evidence boundary

- The external snapshot is `26/26 typed_absent`; usable external inputs remain
  zero.
- No new AD and no S3 rerun are authorized or claimed.
- T0, authority recheck, T1, and T2 are not authorized or executed.
- The 39-node DAG and R01–R10 remain unchanged.
- Finding counts are P0=`0`, P1=`0`, P2=`2`. The two deferred P2 items are
  Windows reparse runtime coverage and R22 direct-wire acceptance; neither is
  promoted to a pass by this acceptance.
- The local evidence remains the R3 atomic focused suite (`25 tests + 1
  skipped`) twice, the R4 full tree (`98 passed + 2 skipped`) twice, static
  compile/import boundary exit `0`, and unchanged 48-file source/test hash
  closure.

The reviewed draft's split disposition is accepted without changing source,
tests, historical evidence, or the frozen gate state. No network, Julia/DESC,
solver, heavy lane, external channel, T0, or S3 execution is authorized by
this record.

## Hygiene boundary

The `99-hygiene-cleanup` evidence records 57 unique cache artifacts (17
`__pycache__` directories and 40 `*.pyc` files) whose deletion was blocked by
host execution policy; they remain a cleanup obligation and are not silently
treated as removed. The separately misplaced cleanup file was deleted. Its
empty parent directory may remain because the policy rejected removal of that
empty directory.

## Evidence references

This acceptance cites, without rewriting, the following frozen records:

- `20-root-decision-draft/decision_draft.md`
- `20-root-decision-draft/decision_draft.json`
- `20-root-decision-draft/hash_manifest.json`
- `reviews/20-root-decision-independent-review-r2-fast/review.md`
- `reviews/20-root-decision-independent-review-r2-fast/hashes.json`
- `reviews/20-root-decision-independent-review-r2/review.md`
- `19-final-full-regression/report.md`
- `19-final-full-regression/run_manifest.json`
- `19-final-full-regression/hash_comparison.json`
- `99-hygiene-cleanup/hygiene-cleanup-2026-09-17.md`
- `99-hygiene-cleanup/retry.md`

Only the three files in this `21-root-acceptance` directory are new. This
record must not be interpreted as permission to close the parent goal or to
advance any externally gated stage.
