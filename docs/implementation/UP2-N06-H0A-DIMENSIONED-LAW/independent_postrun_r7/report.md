# H0-A focused R7 independent postrun review

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only rehash and attribution of the completed R7 receipt.
  No Julia/DESC was run by this reviewer; no source, test, fixture, runner, or
  prior receipt was changed.

## Runtime receipt

The receipt is `focused_r7/execution_receipt.json` (there is no
`focused_r7/receipt.json`). It records one serialized command,

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

with PID `41736`, UTC interval
`2026-09-14T23:43:38.2366289Z`–`2026-09-14T23:48:36.0156943Z`, and real exit
code `1`. The four input hashes before and after are identical:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

The raw streams are preserved and independently rehashed:

- `stdout.raw`: 9857 bytes, SHA-256
  `c114cc2c4fced2acadbb5c822227daf1fff954e4e784150e0c213dafec5320bc`;
- `stderr.raw`: 311 bytes, SHA-256
  `73824bf33e176701c1e568a6af07c77665bad3bc89f6d60125ffc493efa8de45`.

`execution_receipt.json` SHA-256 is
`0a749eaedf89463f76b2c857e576cbf72003ba843de1f7726f4bb8a17bbf5ced` and
`group_summaries.txt` SHA-256 is
`650962754ee4772bcb4b33a088f6c155d7afa96d31e2f9891a56bbb0d98302fd`.
The raw summary contains 65 `Test Summary` blocks. Pre/post dirty snapshots
are both 14750 bytes with SHA-256
`d280467f0fab754c39bcfdc2754ee83fea6831a4dde8386b1a113baac0747ec0`.
Pre/post process snapshots are both the empty JSON array (4 bytes,
SHA-256 `a5338d955b09046ec0b16f3a9625b7955c763aae07dc722e474e6078745f932f`).

## First failure and attribution

The first failing assertion is test line 551 in `H0-A trusted semantic and G2
provenance controls`:

```text
isempty((G._n06_h0a_validate_law(good, endpoints; law_id = law_id)).errors)
evaluated errors = ("role_sign_mismatch:source",
                   "role_sign_mismatch:load",
                   "role_sign_mismatch:return")
group result = 38 passed, 1 failed, 39 total
```

The test builds `role_coefficients` directly from the actual `endpoints.g3`
entries at lines 513–518, so the sample is not a fabricated normalized role
table. The actual G3 fixture at `test/GenomeV5/G3/fixtures.json:59-63`
contains these energy/thermal entries:

| effect/role | actual coefficient | expected role sign |
|---|---:|---:|
| source power | `10/1` | `+1` |
| load | `-8/1` | `-1` |
| return | `-2/1` | `-1` |
| heat rejection | `-1/1` | `-1` |

The energy closure `10 - 8 - 2 = 0` at fixture line 69 confirms these are
meaningful magnitudes, not malformed sign-only coefficients. The failing
tuple therefore exactly matches the three rows whose magnitudes are not one;
heat passes because its magnitude happens to be one.

Production code constructs the role rules with signs `+1/-1` at
`N06DimensionedLedgerLawV1.jl:556-571`, but line 688 checks

```text
row.coefficient == expected_rule.sign
```

That compares a physical/source-owned rational magnitude to a sign sentinel.
The source-role matcher at lines 653–657 is a separate and correct sign check
using `_n06_h0a_sign(source.coefficient)`. The R7 failure occurs later in the
G3 role contract loop, where the analogous sign projection is missing.

This is a **production role-sign validation defect**, not a wrong test
expectation. Correct behavior is to retain the full coefficient equality at
line 687, then compare the coefficient's sign to the expected role sign, for
example `_n06_h0a_sign(row.coefficient) == expected_rule.sign`. This preserves
the actual magnitudes `10/-8/-2/-1`, rejects zero via the existing
`role_sign_zero` check, and does not fabricate a normalized coefficient.

## Actual-A evidence boundary

The actual-A group printed `H0-A actual-A source binding remains deferred: 7
passed, 7 total`. This is only the result of seven test assertions. The runner
did not print a structured actual-A result status, declaration type, or
compile/provider/solver counters; these fields remain `not_printed_by_runner`.
The 7/7 group cannot be promoted to authority, a positive declaration, or any
physical result. No such inference is made here.

## R20 minimum repair contract and ownership

R20 should be a narrow source repair with ownership limited to
`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`:

1. change only the role-sign comparison at the line-688 equivalent to compare
   `_n06_h0a_sign(row.coefficient)` with `expected_rule.sign`;
2. retain the existing exact effect/port role join, full role coefficient
   equality, role direction checks, zero-coefficient rejection, source-role
   selector, registry-gap, provenance, unit, authority, and error taxonomy;
3. do not alter the fixture, runner, public admission contract, old R7/R6
   receipts, or the parent acceptance state; and
4. use the existing line-551 trusted semantic test as the regression gate. A
   separate telemetry work order is needed if actual-A status/declaration or
   counters must become printable; R7 does not provide them.

R20 exits source review only when the source hash and protected test/fixture/
runner hashes are frozen, the static diff is limited to the sign projection,
and an independent reviewer confirms no magnitude normalization or contract
weakening. Then, after a fresh serialized focused run, the exit gate requires
line 551 and the full trusted semantic/G2 provenance group to pass, no new
failures, the real process exit code to be recorded, 65 summaries to be
accounted for, and all raw streams/snapshots/hashes preserved. Missing
actual-A status/declaration/counters remain explicitly `not_printed` and
prevent H0 acceptance.

Until that repair and rerun pass, R7 is `changes_requested`. H0-A remains
`accepted=false`; no UP2-total, B00/B04, provider, mesh, engineering,
physical, or R01-R10 credit is granted.
