# H0-A focused R6 independent postrun review

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Review mode:** read-only source, test, fixture, runner, receipt, and raw
  output audit. This reviewer did not run Julia or DESC and did not modify
  production source, tests, fixtures, or the runner.

## Runtime evidence and frozen inputs

The single serialized R6 run is a real failed execution, not a documentation
or exit-code substitution:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The preserved receipt records PID `48048`, UTC interval
`2026-09-14T22:34:23.8569218Z` through `2026-09-14T22:38:10.8831794Z`, and
exit code `1`. The raw outputs were independently rehashed from disk:

| artifact | bytes | SHA-256 |
|---|---:|---|
| `focused_r6/stdout.raw` | 8091 | `7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b` |
| `focused_r6/stderr.raw` | 311 | `71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565` |

The live source, test, fixture, and runner all still match the R15 frozen
inputs and the R6 receipt:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 40742 | `9c5ecf8f2f212b2298eff5a8129a618114185867c21b83dcd4e3ff1982b36599` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

The receipt's pre/post dirty snapshots are byte-identical (304 non-empty
porcelain rows; snapshot SHA-256
`0be08949e78b7fd6372b17a16dd8b74d5c4a819722a115b87fc605c807f32eab` on both
files). Its pre/post process snapshots are also identical empty arrays (4
bytes, SHA-256
`a5338d955b09046ec0b16f3a9625b7955c763aae07dc722e474e6078745f932f`). The
current live status remains 304 rows. The receipt contains 46 assertion-group
summaries; the six H0-A groups are recorded there, with the trusted group at
17 passed, 2 failed, 19 total. Stderr's terminal summary is
`17 passed, 2 failed, 0 errored, 0 broken` for that group.

## Independent attribution of both failures

The first failure at
`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:286` is expected from the
current source contract. `_h0a_equation()` constructs two dimensionless input
units at test lines 42–45. The actual G3 child fixture supplies an effort unit
`(1,2,-3,-1,0,0,0)` and a flow unit `(0,0,0,1,0,0,0)` at
`test/GenomeV5/G3/fixtures.json:43-44`. The production validator compares the
equation input tuple with those source-derived units at
`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:566-567` and appends
`law_input_unit_equation_mismatch` to `errors`. The validator then gives errors
priority over gaps at lines 729–740 and returns `fail_closed`.

This is a physical/unit contradiction in the supplied declaration, not an
authority gap. The expected value `terminal_deferred` at line 286 therefore
does not match the declaration the test constructs. No source classification
or authority change is justified by this failure. The raw receipt does not
print `trusted.errors`, but the source path and frozen typed inputs determine
the first error deterministically; a future diagnostic should print
`trusted.status`, `trusted.errors`, `trusted.gaps`, `trusted.declaration` type,
and the equivalent admission fields.

The second failure at line 291 has a separate, representational cause. The
actual package's G3 admission records `feedback_authority_gap:<id>:<layer>`
for each feedback relation. `_n06_h0a_feedback_authority` recognizes that
candidate-matched ref plus the G3 admission gap and returns
`:external_ref_required` (source lines 501–512). The four-argument admission
then deliberately throws `N06H0AKnownGapError` at line 752. Its catch block
formats the typed exception with `sprint(showerror, typed)` and stores that
decorated string as the sole result gap at lines 761–765. The resulting value
is shaped like `N06 H0-A known gap [external_ref_required]: ...`; it does not
start with `external_ref_required`, and the endpoint short-circuit means it
does not contain `calibration`. Thus line 291's predicate rejects an existing
typed external-authority gap. This is a test/output-shape mismatch, not lost
authority and not a change in terminal classification. The preceding F06
direct-binding assertion sees raw endpoint gap tokens, while this admission
wrapper sees a formatted reason, so the two assertions are not equivalent.

The focused execution therefore supplies valid software evidence of two test
contract defects and no evidence of a production source defect. It remains a
failed suite and cannot be accepted as H0-A.

## R16 minimum repair contract

R16 should be test-owned and additive:

1. In `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl`, retain the
   dimensionless `_h0a_equation()` as a deliberate contradiction control and
   change the trusted validation expectation to `fail_closed`, asserting the
   source-derived `law_input_unit_equation_mismatch` token in
   `trusted.errors`.
2. For the four-argument admission assertion, check the typed absent
   declaration's `gap_code == :external_ref_required`, or use
   `contains("external_ref_required", ...)` on the decorated reason. Do not
   require a raw-token prefix from a wrapper that stores `showerror` output.
3. If the product contract specifically requires a trusted declaration to
   reach `terminal_deferred`, add a separate source-shaped case with actual
   G3 effort/flow units and all locally consistent source joins while keeping
   calibration/closure/law provenance absent. That case must assert the typed
   authority gap; it must not weaken the contradiction case or fabricate a
   law.

The R16 author owns only the N06 test file and its new repair receipt/report.
The fixture and runner remain protected. No production source change is
authorized by this review. After the edit, one serialized focused run must
freeze the four hashes again, capture fresh dirty/process snapshots, PID, UTC
interval, raw output hashes, and real exit code; the suite must exit 0 with the
trusted contradiction and decorated external-gap assertions passing. A
different Luna must then independently review the new receipt. Even then H0-A
remains `accepted=false` until the higher authority and physical/engineering
gates are separately evidenced.

## Ceiling

This review grants no H0-A acceptance, UP2-total credit, B00/B04 credit,
provider, mesh, solver, engineering, physical, or R01–R10 credit. It also does
not convert the R6 runner's exit code or test counts into physical evidence.

