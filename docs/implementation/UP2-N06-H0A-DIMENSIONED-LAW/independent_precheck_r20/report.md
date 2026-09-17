# H0-A R20 independent static precheck

- **Verdict:** `pass_limited`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only source/test/fixture/runner hash audit, targeted source
  inspection, R7 receipt rehash, and JSON parsing. This reviewer did not run
  Julia/DESC or the focused runner and did not modify implementation, tests,
  fixtures, runner, or historical receipts.

## Change scope and hashes

R20 is limited to the production source file. The test, fixture, and runner
are unchanged from R19:

| artifact | bytes | SHA-256 | finding |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` | R20 source |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` | unchanged |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The R20 before hash matches the R19 after hash (`9bdf...ee4c`), and the
current source contains exactly the intended role-sign projection at line
688:

```text
_n06_h0a_sign(row.coefficient)==expected_rule.sign ||
    push!(errors,"role_sign_mismatch:$(role)")
```

The preceding full coefficient equality at line 687 remains in place. The
existing zero rejection at line 694 remains in place. The source-role exact
selector join, direction checks, endpoint provenance, unit/closure checks,
and typed error taxonomy are unchanged in the inspected surrounding code.
The static scan finds no remaining direct comparison of a non-unit role
coefficient to a `±1` sign sentinel.

## R7 failure consistency

The protected R7 `execution_receipt.json` was parsed and the raw artifacts
were rehashed. It records PID `41736`, UTC interval
`2026-09-14T23:43:38.2366289Z`–`2026-09-14T23:48:36.0156943Z`, and real exit
code `1`. The raw streams remain:

- `stdout.raw`: 9857 bytes, SHA-256
  `c114cc2c4fced2acadbb5c822227daf1fff954e4e784150e0c213dafec5320bc`;
- `stderr.raw`: 311 bytes, SHA-256
  `73824bf33e176701c1e568a6af07c77665bad3bc89f6d60125ffc493efa8de45`.

The receipt reports 65 Test Summary blocks and first failure line 551 with
`role_sign_mismatch:source`, `role_sign_mismatch:load`, and
`role_sign_mismatch:return`. The actual G3 fixture rows are source/load/
return/heat coefficients `10/-8/-2/-1`, while the role rules are sign
sentinels `+1/-1/-1/-1`. R20's sign projection is therefore the minimal
source correction: it accepts the signed magnitudes while retaining exact
coefficient equality against the authored role table.

The R7 actual-A group remains only `7 passed, 7 total`. Structured actual-A
status, declaration type, and compile/provider/solver counters were not
printed by the runner and remain `not_printed`; no authority or physical
claim follows from the group summary.

## Preserved contracts

R20 does not alter the source-role selector, private registry injection seam,
four endpoint contract, source hash/provenance verification, direction or
unit/closure validation, zero/missing/ambiguous classification, or typed
`terminal_deferred`/`fail_closed`/`program_exception` taxonomy. R16's
dimension contradiction and typed `external_ref_required` controls remain in
the unchanged test file. The old R7 exit-1 receipt and all raw evidence remain
append-only and protected.

No Julia/DESC process was present in the final static snapshot. JSON parsing
of the R20 repair records succeeded. These facts establish static repair
scope only; they do not substitute for the required rerun.

## Gate decision

R20 is `pass_limited`. One serialized focused run may proceed after a fresh
freeze of all four input hashes and a confirmed empty T0 process snapshot:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The rerun must preserve PID, real exit code, UTC interval, raw stdout/stderr
bytes and hashes, dirty/process snapshots, 65 summary accounting, and the
runner's explicit `not_printed` boundary for actual-A status/declaration/
counters. The line-551 trusted semantic group must pass with no new failures.
This precheck keeps H0-A `accepted=false` and grants no UP2-total, B00/B04,
provider, mesh, engineering, physical, or R01-R10 credit.
