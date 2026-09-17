# H0-A R18 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only source/test/receipt audit plus lightweight JSON parsing.
  Julia, DESC, and the focused runner were not run; no source, test, fixture,
  runner, or prior receipt was changed by this reviewer.

## Hash and receipt audit

The four live inputs were independently rehashed:

| artifact | bytes | SHA-256 | disposition |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` | R18 source |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 46087 | `cc8e8087d14fbf626b914972dcbe1e1633ed833af12288146e77c23a5405d4d2` | R18 test |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

R6 raw evidence was rehashed and remains unchanged: `stdout.raw` 8091 bytes,
SHA `7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b`, and
`stderr.raw` 311 bytes, SHA
`71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565`. The R6
receipt still records PID `48048`, exit code `1`, and 46 group summaries; no
historical failure was overwritten.

The R18 erratum is append-only and correctly records the complete R17 runner
hash in `receipt_erratum_r18/report.json` and `report.md`. It preserves the
old R17 human-readable typo and does not change the runner or any R6 artifact.
All three new R18 JSON records parsed successfully. This reviewer did not
start Julia or DESC. A final read-only process snapshot did find an external
`julia.exe` PID `55428` with no exposed command line; it was not interrupted.
Consequently, any concurrent T0 run remains an external dependency and must
finish before a focused gate is considered.

## Source-role matcher and registry seam

R18 keeps the default path source-owned. The no-argument
`_n06_h0a_source_role_match(occurrences)` reads the existing module registry;
the new two-argument overload accepts an explicit registry only through the
private test seam. Passing `nothing` returns `:registry_missing`, and the
`source_registry` keyword in `_n06_h0a_validate_law` maps this to the typed
`source_binding_missing` gap. The code performs no `const` rebinding,
deletion, mutation, or global replacement. The source-role registry remains
the default candidate/source mapping from
`N06SourceFieldLedgerMappingV1.jl`; the injected value cannot leak into the
default overload.

The source selector still requires all four fields
`ledger_id/equation_id/port_side/port_index`. The complete four-row
`N06H0AEndpointSetV1` contract and unique-selector check remain intact. The
matcher filters by exact selector equality and leaves package, candidate,
public ref, component hash, version-axis, endpoint provenance, and source
hash checks in their existing production paths. Zero, one, and multiple
source-selector matches map respectively to a typed gap, source-derived sign
input, and typed fail-closed ambiguity. No source value or authority is
fabricated.

The private injection controls are appropriate for an unavailable-registry
branch that the normal loaded module cannot reach without changing global
state. They assert `:registry_missing` and `source_binding_missing` while
leaving subsequent default registry use intact. This is a controlled seam,
not a production API or a global test override.

## Public controls and remaining evidence gap

R18 fixes the R17 test-path deficiency in part. The current test file now uses
public `n06_h0a_validate` for legal four-row endpoints, and the trusted,
sign-edit, input-unit-edit, and source-occurrence-unit/hash cases assert that
`g1_occurrence_source_ambiguous` is absent. Sign and input-unit errors are
also checked through public validation; the source-unit edit checks public
fail-closed endpoint identity. R16's dimensionless equation still asserts
`fail_closed` with `law_input_unit_equation_mismatch`, and four-argument
admission still asserts typed `external_ref_required`.

The R18 repair report nevertheless overstates public admission coverage:

- the legal four-row **public admission** path is only covered by the
  dimensionless contradiction's typed-deferred short circuit; there is no
  public admission assertion for a locally consistent four-row declaration
  that reaches the law validator before the independent external gap;
- sign edit and source-unit/hash edit use public validation but do not assert
  the corresponding declaration overload of `n06_h0a_admit_present` and its
  error tokens; and
- the reorder, missing, and duplicate cases remain private matcher/law
  controls. The duplicate seam is valid because the public endpoint
  constructor rejects duplicate selectors by design, but reorder should have
  at least one public validation assertion, while a replaced selector with a
  stale source hash is correctly a fail-closed identity contradiction rather
  than a clean public terminal gap.

This is a coverage/claim-boundary issue, not evidence that the R18 source
matcher contaminates global state. It is also why the requested phrase
“走公开验证/准入” is not fully satisfied by the current static record. The source
and test controls are structurally plausible, but there is no runtime proof
that the changed dispatch behaves as claimed.

## Gate decision and next action

R18 is `changes_requested`; a single serial focused run is not yet authorized
by this review. Before the next precheck, the author should:

1. add declaration-overload public admission assertions for sign and
   source-unit/hash controls where the existing external-gap short circuit
   does not erase the error evidence, or explicitly document the exact
   short-circuit and add a feasible public assertion;
2. add a public reorder validation control using the legal four-row endpoint,
   while retaining the private duplicate and registry-injection seams;
3. keep the private registry injection isolated and prove the default registry
   result before/after the injected call; and
4. retain the corrected append-only erratum and all R16/R17 classification,
   identity, source-hash, and four-endpoint contracts.

After an independent `pass_limited`, and only after any T0 focused process has
ended, the next gate may authorize one serialized focused run. It must freeze
the four input hashes anew and capture PID, real exit code, UTC interval, raw
stdout/stderr bytes and hashes, process/dirty snapshots, actual-A status and
declaration type, and zero compile/provider/solver counters. A successful
software run remains contract evidence only. H0-A stays `accepted=false`; no
UP2-total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit
is granted.
