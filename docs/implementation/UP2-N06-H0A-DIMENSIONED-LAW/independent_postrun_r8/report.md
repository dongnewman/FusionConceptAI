# H0-A focused R8 independent postrun review

- **Verdict:** `accepted_limited` for the H0-A local software contract
  precursor only
- **H0-A acceptance:** `accepted=false`
- **Scope:** independent read-only receipt rehash and bounded software
  contract review. This reviewer did not run Julia/DESC and did not modify
  source, tests, fixtures, runner, or prior R6/R7 receipts.

## Receipt integrity

R8 records one serialized command,

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

with PID `25164`, UTC interval
`2026-09-15T00:01:45.3282274Z`–`2026-09-15T00:07:20.0290209Z`, and real exit
code `0`. The four input hashes before and after are identical:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

Independent hashes of the R8 receipt artifacts are:

- `stdout.raw`: 10342 bytes, SHA-256
  `9c97f086a3b5f9dadce1be39656b84c949b7ba494f63630ac9f405363b06d820`;
- `stderr.raw`: 0 bytes, SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
- `execution_receipt.json`: SHA-256
  `67c718afdada6e16dbab5245b0c9480f10da4b542585bd2b798dce111d54708a`;
- `group_summaries.txt`: SHA-256
  `04a8e7495c5e91a5a25353aa84da4b1f650b3443f7f770f9f459a5ece0c56835`.

The receipt contains 75 `Test Summary` blocks and 11 H0-A groups. Pre/post
dirty snapshots are both 14750 bytes with SHA-256
`d280467f0fab754c39bcfdc2754ee83fea6831a4dde8386b1a113baac0747ec0`; pre/post
process snapshots are empty arrays, each 4 bytes with SHA-256
`a5338d955b09046ec0b16f3a9625b7955c763aae07dc722e474e6078745f932f`.

R6 and R7 remain historical exit-1 receipts with their original raw files;
R8 did not overwrite either failure. The R8 JSON records parse successfully.

## H0-A software result

All 11 H0-A groups passed, including:

- trusted semantic and G2 provenance: `39/39`;
- actual-A source binding remains deferred: `7/7`;
- source-derived endpoint identity and mutation controls: `29/29`;
- upstream typed taxonomy: `23/23`;
- constructor, source-match classification, schema, contradiction, F06,
  identity, and typed-input groups: all pass as recorded in the receipt.

The R20 role-sign correction is consistent with the R7 defect evidence:
actual G3 coefficients `10/-8/-2/-1` now pass the sign projection while full
coefficient equality remains enforced. No new failure, stream error, input
hash drift, or dirty-worktree drift is present.

This supports a bounded **local software contract precursor**: the tested
N06 H0-A constructors, source selector classification, identity/provenance
checks, typed error outcomes, R20 role-sign projection, and zero execution
counters represented by the result structures are locally consistent under
the executed test path.

## Evidence boundaries

The runner does not print a structured actual-A result status, declaration
type, or compile/provider/solver counter values. These fields remain exactly
`not_printed_by_runner`; the actual-A `7/7` is only a passing group summary.
It cannot establish candidate-owned law authority, a positive actual-A
declaration, external feedback authority, or physical validity.

Accordingly the following remain false and receive no credit from R8:

- N06 actual candidate authority or dimensioned-law authority;
- UP2 total completion;
- B00 or B04;
- provider execution or provider authority;
- mesh or DESC physical result;
- engineering readiness;
- physical validation;
- any R01-R10 credit.

R8 is therefore `accepted_limited` only for the local H0-A software contract
precursor. It is not H0-A acceptance and does not close the parent goal.
