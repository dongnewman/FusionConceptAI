# UP6-EARLY-PREPARATION independent review R2

Date: 2026-09-15
Reviewer: different Luna/high, read-only
Scope: repair R1, the original preparation package, protected R1 review,
recursive JSON/path/reference checks, and cleanup ownership

## Verdict

`changes_requested`.

Repair R1 fixes both substantive R1 findings. Every one of the 15 engineering
rows now carries the required typed pending fields and closed reasons, and all
five provider records expose fresh receipts with the required exact identity
joins. The only remaining defect is a stale count in the package validation
report after its root manifest was expanded from ten to twelve writable and
deliverable paths.

The package may receive credit only as an early-preparation template after that
static record is synchronized. UP6-01/02/03, provider/toolchain admission,
engineering, VVUQ, net output, originality, replay, L4 and R01–R10 remain
pending with no evidence credit.

## Recomputed checks

The recursive package contains nine JSON files: seven root templates, the
protected R1 review manifest, and the repair R1 manifest. All nine parse. The
15 obligation IDs are unique, and all ten R01–R10 entries are unique, pending,
`accepted=false`, and owned for terminal disposition by
`FinalWholeDeviceAuthorityV4`. The manifest lists 19 existing input
files/directories.

All 15 obligation rows share one complete key set and include typed pending
records for candidate, scenario, physical subject, solver input, quantity,
unit, threshold, comparison, owner, provider, data, model, verification,
validation, model discrepancy, uncertainty/UQ, fresh receipt and limitation.
Every nested field has `state=pending`, `value=null`, and a nonempty reason.

All five provider records carry a fresh receipt with pending exact joins for
candidate, scenario, physical subject, solver input, provider and version/hash,
toolchain and hash, source tree and hash, build and hash, channel and lock
hash, interpreter and hash, module and hash, command, cwd, start/end, exit
code, raw stdout/stderr/combined, their hashes, input/output/artifact hashes,
status, applicability and limitation. The receipt contract requires exact
equality and freshness and explicitly rejects provider ID or input hash alone.

No future 64-character identity hash is present in the nine JSON files. The
cleanup inventory preserves the original ten-file package and protected
`independent_review_r1`; no task-owned scratch, cache, bytecode, run, or
unrelated file is present. No reviewed file was changed by this review.

## Remaining finding

### VALIDATION-COUNT-001: validation report is stale after repair

`docs/implementation/UP6-EARLY-PREPARATION/manifest.json` now declares twelve
writable/deliverable paths: the original ten plus
`repair_r1/report.md` and `repair_r1/manifest.json`. However,
`validation_report.md` still states that ten writable files exist and that the
task added ten status entries. Those statements no longer match the manifest
or the cleanup inventory. Update the validation report to say twelve declared
writable/deliverable paths and twelve target-package status entries (while
retaining the separate recursive JSON count of nine and the protected R1
review directory). Re-run the same static checks after this documentation-only
repair.

## Execution and authority boundary

No Julia, DESC, FreeGS, VMEX, Pleiades, CQL3D, provider, mesh, solver,
physical, net-output, independent replay, originality search, web search,
download or external-data operation was run. This review wrote only its own
`independent_review_r2/report.md` and `manifest.json`.

After `VALIDATION-COUNT-001` is repaired and the nine JSON, 15-row, five-
provider, ten-R-entry, cross-reference, path, future-hash and cleanup checks
are rerun, a new limited review may accept the early-preparation template.
That acceptance must not close UP6 or any R01–R10 obligation.
