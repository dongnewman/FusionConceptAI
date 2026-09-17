# UP2-N06-H0A-DIMENSIONED-LAW focused R5 execution receipt

Disposition: `focused_test_failed`; `accepted=false`; `review_pending=true`.
The command was executed exactly once after a fresh R11 manifest-driven
preflight. stdout/stderr were redirected before start, the child PID was
captured in `$childProcessId`, `WaitForExit()` completed, and the real exit
code was recorded. No rerun or automatic fix was performed.

Command:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The run used PID `38540`, from UTC
`2026-09-14T21:37:45.1812844Z` to
`2026-09-14T21:38:50.2558502Z`, and exited `1`. Raw stdout is 7,441 bytes
with SHA-256
`db57bb87452c1ed6f89f2503ef787180bc0788627cb994dde6d9625efe2946c1`.
Raw stderr is 310 bytes with SHA-256
`2149b4bb35ceb6462f02bf37627b19b8ea47cd9bc28152d9822c9cbcaf072de3`.

The runner reached all preceding suites: UP1-01 G1 `47/47` and `21/21`,
UP1-02 G2 `57/57`, `59/59`, and `8/8`, UP1-03 G3 `49/49`, `35/35`, and
`23/23`; H0-A constructor dispatch `9/9`, fixture and contract schema `10/10`,
and contradiction/absent/exception taxonomy `4/4`.

The first failing H0-A suite was `actual-A source binding remains deferred`
at test line 198. It reported `1 pass, 2 fail, 4 error, 7 total`. The first
two failures were `result.status == :terminal_deferred` evaluating
`program_exception == terminal_deferred` at line 201 and
`result.declaration isa G.N06H0ATypedAbsentV1` evaluating
`nothing isa ...` at line 202. Lines 203-205 then errored on `gap_code`,
`binding.package_hash`, and `binding.e0_bound_input_hash` because the
declaration was `nothing`; line 207 errored with
`n06_h0a_validate(::Nothing)`. stderr records the final summary as `1 passed,
2 failed, 4 errored, 0 broken`.

Preflight and postflight Julia/DESC process snapshots were both empty. Dirty
rows were 303 before and after. All four R11 target hashes and byte counts
were identical before and after, and no source, test, fixture, or runner file
was changed. The complete R11 manifest identities, including the 64-character
runner SHA, are copied into `input_manifest.json` from the manifest and
verified against the live files before launch.

This is a preserved software test failure. It grants no physical,
engineering, provider, mesh, B04, or R01-R10 credit and does not establish
H0-A acceptance. A third-party postrun review is required before any further
decision; no rerun was made in this lane.

## Frozen R11 input identities

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38431 | `eadd8c19344a117edeaa5ffad4fbe6f9e1300d3c81388918b00c63876efa10e5` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

