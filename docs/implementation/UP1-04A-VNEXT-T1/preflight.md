# UP1-04A VNext T1 preflight handoff

Date: 2026-09-18 (Asia/Shanghai)

## Result

| Item | Result |
| --- | --- |
| T0 transport | consumed as typed local input |
| T0 authority recheck | consumed as `local_checked_present` or typed absence |
| T1 positive path | structurally implemented; not executed |
| T1 negative path | structurally dispatched; not executed |
| Static QA | `PASS`; dynamically counted checks; `9` named negative cases |
| Julia/DESC/provider/mesh/solver | not invoked |
| Claim ceiling | `contract_only` |
| Stage status | `prepared_not_executed` |
| Commit | parent-controlled |

The positive package path preserves the source-backed candidate, declaration,
body, locator, factory and declaration receipts, checks component count 3,
recomputes owned byte hashes, and retains the T0 canonical bundle bytes and
hash in the T1 gate. The label-erased component identity excludes visible
semantic labels, while `package_hash` still binds the complete T0 gate.

Locator provenance remains a T0 responsibility: the local authority recheck
validates repository root, observed head, path status, working-tree status,
head blob and locator provenance against the source-backed receipt. T1 then
rechecks the retained locator's candidate/source reference, byte length and
source digest joins; it does not independently re-read the repository or
promote provenance into a stronger authority claim.

The negative matrix has nine named dispatches: missing T0 recheck, missing
transport, foreign candidate, foreign no-legacy receipt, invalid transport,
feedback reorder, duplicate feedback, bundle hash mismatch, and the legacy
receipt/status constructor boundary. The ninth case is dispatched through
`vnext_t1_admit_skeleton_v1` using a forged legacy receipt identity; the
closed constructor's invalid-status rejection is also asserted. Typed-absent T0 is an additional explicit
fail-closed test because it must never be promoted into a T1 package.

## Evidence boundary and gaps

This is a code/fixture/static-QA preflight only. It does not establish Julia
runtime execution, independent replay, T1 runtime admission, T2 rebinding,
provider evidence, mesh/solver execution, conservation, convergence, error
budget, or engineering/physical validation. No existing source package,
shared registry, old receipt, or dirty authority test is modified by this
surface. The next handoff must independently review the T0 transport bytes,
T0 output identity, frozen factory/contract IDs, candidate/body joins, and the
typed-absence fail-closed behavior before any runtime credit is assigned.
