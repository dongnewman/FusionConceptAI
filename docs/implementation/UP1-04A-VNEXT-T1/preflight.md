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

## R1 runtime attempt (2026-09-18)

The append-only R1 runner was invoked once against the focused Julia command.
The durable receipt records `status=child_nonzero`, `exitCode=1`,
`executionStarted=true`, `startCount=1`, `autoRetry=false`, and
`timeoutClassified=false`; this is a `program_exception` caused by the fixture
calling the unsupported Julia method form `first(predicate, tuple)` at line
37. The child produced `2` passing assertions and `1` error before the test
set terminated. The runner captured all streams and performed both postflight
process observations: `preflightProcessCount=0`, both postflight counts `0`,
and `postflightZeroJuliaDesc=true`. All `15/15` protected owned paths were
unchanged (`ownedFileCount=15`, `ownedFilesUnchanged=true`). No retry was
performed and no Julia/DESC process remained. This R1 attempt grants no T1,
T2, UP1, provider, mesh, solver, physical, engineering, or authority credit.

## R2 runtime attempt (2026-09-18)

The append-only R2 runner was invoked once after the R1 program exception was
archived. The receipt is `fail_closed` at the T1 projection boundary: `11`
checks passed, `3` failed, and `14` errored (`11 pass / 3 fail / 14 error`).
The runner recorded `executionStarted=true`, one start, no retry, and no
timeout classification. All `15/15` protected owned paths were unchanged;
the preflight and both postflight process observations were zero, so no
Julia/DESC process remained. This is a projection/admission failure receipt,
not T1 runtime admission, T2 rebinding, UP1 completion, or any provider,
mesh, solver, physical, engineering, or authority credit.

## R3 runtime attempt (2026-09-18)

The append-only R3 runner was invoked once against the same focused T1 command
after the R2 archive. It again failed closed at the projection boundary with
`11 pass / 3 fail / 14 error`; `15/15` protected owned paths were unchanged,
and the receipt records one start with no retry. The focused fixture's bare
`catch` reduced the underlying exception to `:t1_projection_invalid`, so this
receipt does not expose the root exception and must not be treated as a
diagnosis or acceptance. Preflight and both postflight process observations
were zero, with no timeout and no remaining Julia/DESC process. R3 grants no
T1, T2, UP1, provider, mesh, solver, physical, engineering, or authority
credit; the next action is a narrow diagnostic that preserves the immutable
R1–R3 receipts.
