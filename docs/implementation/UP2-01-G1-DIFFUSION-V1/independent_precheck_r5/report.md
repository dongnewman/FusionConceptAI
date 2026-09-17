# UP2-01-G1-DIFFUSION-V1 independent static precheck R5

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

The R5 repair is an additive documentation erratum for the R4 fixture and
static-QA hash crossover. The four target files are byte-for-byte unchanged
within the R5 receipt: each current `before` equals `after`, and an independent
hash assertion passed. The R4 error is correctly explained: its fixture
`r3_before` and `r4_after` values were reversed, while the static-QA `r4_after`
value was stale (`b8fe5945...`). R5's current target ledger fixes those values
to the current four hashes without changing source, Julia test, fixture, or
static-QA bytes.

There is a separate historical-receipt blocker. R5 claims that the R3 report
and manifest are untouched at `0956b606...` and `0faed483...`, but the current
files at `repair_r3/report.md` and `repair_r3/evidence_manifest.json` hash to
`7e1ab164...` and `2beb6360...` and have different byte counts. The claimed
`0956b606...` / `0faed483...` pair is present at `repair_r2/`, not at the R3
paths. R4 and R5 therefore cannot currently prove that the R3 archive was
untouched. This is a provenance inconsistency even though the R5 target
before/after hashes are correct.

The narrow repair is an additive R5 provenance correction: record the actual
current R3 path hashes and explain the R2/R3 path collision, or restore and
independently attest the intended immutable R3 archive before claiming it was
untouched. Do not modify the four target files, R3/R4 archives, or source.
Until this historical receipt is reconciled, R5 is not ready for the serial
focused lane.

R5 state fields are otherwise correct: `review_pending=true`, `accepted=false`,
`runtime=not_run`, and `target_mutation_in_r5=false`. The current R5 manifest
parses as JSON. The permitted Python static QA exited `0` with
`static_qa=pass` and `julia_or_desc_executed=false`; no Julia or DESC process
was observed and no Julia/DESC command was run. No compiler, provider, mesh,
solver, physical, engineering, current-A, B00, B04, or R01-R10 credit is
claimed.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Pre-write full dirty snapshot: 3,670 entries; UTF-8/LF status SHA-256
  `58d9cb795a60e27d2a149e6ee0d1dc67565c61f7b480534d4dc58baccca7f3b2`.
- Current target hashes are source `14d26ee5...` (31,743 bytes), Julia test
  `34bfaf76...` (9,655 bytes), fixture `7b580bf9...` (1,582 bytes), and
  static QA `87f511f5...` (4,499 bytes).
- R3 actual current path hashes are report `7e1ab164339f782a83b7819cca39c5a31276782e5b66ddc0e0262531356f1560`
  (3,554 bytes) and manifest `2beb6360023fce345760e618b845d8dca66f0de964c0f1d230e812188f63b813`
  (2,499 bytes).
- R4 report/manifest remain at `43f793be...` / `907dbc10...`.

