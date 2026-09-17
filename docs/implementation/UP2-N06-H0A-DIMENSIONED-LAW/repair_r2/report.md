# UP2-N06 H0-A repair R2

Verdict: `changes_requested`; `status=review_pending`; `accepted=false`.
This is a static implementation handoff. Julia and DESC were intentionally not
run because the work order requires a different Luna R2 precheck before the
serial focused lane.

The read-only independent R1 review is preserved at
[`UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md`](../../UP2-N06-DIMENSIONED-LAW-PREPARATION/independent_precheck_r1/report.md).
That report was accidentally written under the preparation directory; it is
linked here and was not overwritten or treated as an H0-A archive file.

## F01–F06 disposition

| finding | R2 implementation | remaining boundary |
|---|---|---|
| F01 | `_n06_h0a_endpoint_set` searches every equation and occurrence for the four exact authored selectors, then attaches the owning equation, closure, and typed source ref/hash/path/type. | A duplicate or missing source row remains fail-closed or typed deferred. |
| F02 | Low-level `n06_h0a_present` is schema-only. `n06_h0a_admit_present` and `n06_h0a_validate(present, package, e0)` recompute package, E0, refs, component hashes, axes, and endpoints. | No authored actual-A law exists. |
| F03 | Endpoint and law checks cover typed coefficients, unit algebra, effort×flow power, scale/efficiency, direction/sign, owner scope, and closure balances. | No physical execution or calibration authority is claimed. |
| F04 | Every endpoint row, G1 equation/closure, coefficient-bearing occurrence, G2 locator, G3 row, and law calibration/closure input carries typed provenance in the content identity. | A source hash mutation is a fail-closed negative control. |
| F05 | `N06H0AKnownGapError`, `N06H0AConflictError`, and `N06H0AProgramError` provide stable classification. Contradictions return `fail_closed` without a typed absence. | Julia execution remains pending. |
| F06 | G3 port/account/entry/closure/link/feedback joins are checked. Missing feedback authority is an independent `external_ref_required` deferred gap. | Actual A still has no dimensioned G1→G3 law. |

The actual-A route is intended to resolve the four G1 rows and then return
`dimensioned_law_missing` / `terminal_deferred`. Synthetic present construction
is explicitly `schema_validation_only`; it carries no real physical, B00, B04,
provider, mesh, engineering, physical, or R01–R10 credit.

## Static QA

JSON parsing and `validate_plan.py` passed. `git diff --check` reported only
pre-existing LF-to-CRLF warnings. The final process sweep found no Julia or
DESC process. The protected G1/G2/G3/E0/N06/core and AD-24/26/27 files retain
the recorded hashes in `evidence_manifest.json`.
