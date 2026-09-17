# H0-A focused R8 execution receipt

Status: `executed_exit0`; `exit_code=0`; `accepted=false`; `review_pending=true`.

After the R20 `pass_limited` precheck and a fresh four-input freeze, the
serialized runner was launched exactly once with a non-reserved child PID
variable and redirected raw stdout/stderr streams:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

PID: `25164`. UTC interval:
`2026-09-15T00:01:45.3282274Z` to `2026-09-15T00:07:20.0290209Z`. The process exited 0 and no Julia or
DESC process remained. The earlier R6/R7 receipts were retained.

The raw output contains **75** `Test Summary` blocks. All observed summaries
pass, including the 11 H0-A groups. The full two-line summaries are retained
in `group_summaries.txt`; no shorter expected count was substituted. Key H0-A
results are:

| group | pass | total |
|---|---:|---:|
| `H0-A unit equation constructor dispatch` | 9 | 9 |
| `H0-A exact source match classification` | 22 | 22 |
| `H0-A fixture and contract schema` | 10 | 10 |
| `H0-A contradiction, absent, and exception taxonomy` | 4 | 4 |
| `H0-A actual-A source binding remains deferred` | 7 | 7 |
| `H0-A F06 actual pending authority and foreign-target controls` | 9 | 9 |
| `H0-A trusted package/E0 admission revalidates every identity field` | 22 | 22 |
| `H0-A source-derived endpoint identity and mutation controls` | 29 | 29 |
| `H0-A trusted semantic and G2 provenance controls` | 39 | 39 |
| `H0-A typed input mismatch is fail-closed` | 3 | 3 |
| `H0-A upstream taxonomy is typed before public admission` | 23 | 23 |


The prior R7 failure at line 551 is cleared: the trusted semantic and G2
provenance group now reports `39/39`. The actual-A source-binding group reports
`7/7` and remains a deferred contract test. The runner does not print a
structured actual-A status, declaration type, or compile/provider/solver
counter fields; those receipt fields remain explicitly `not_printed_by_runner`.
No authority or physical result is inferred from the passing group.

## Hash audit

| artifact | bytes | SHA-256 |
|---|---:|---|
| input `src\GenomeV5\UP2\N06DimensionedLedgerLawV1.jl` | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` |
| input `test\GenomeV5\UP2\n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| input `test\GenomeV5\UP2\n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| input `test\GenomeV5\UP2\run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |
| stdout.raw | 10342 | `9c97f086a3b5f9dadce1be39656b84c949b7ba494f63630ac9f405363b06d820` |
| stderr.raw | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The four input hashes are identical before and after execution. Raw streams,
pre/post dirty snapshots, and explicit empty pre/post process snapshots are
preserved. This is software-contract evidence only. H0-A remains
`accepted=false`; N06 actual authority, UP2 total, B00/B04, provider, mesh,
physical, engineering, and R credit remain unclaimed.
