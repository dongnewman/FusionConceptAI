# H0-A R17 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only audit of the R17 source-role occurrence repair,
  occurrence architecture record, tests, frozen inputs, and protected R6
  receipt. This reviewer did not run Julia, DESC, or the focused runner and
  did not modify source, tests, fixtures, runner, or prior evidence.

## Frozen inputs and protected evidence

The live four input files are:

| artifact | bytes | SHA-256 | disposition |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 58976 | `e7f18c58834cfcb2eeaef813656525e16d3ea8ae1dd9df19277f08b57aaf949c` | R17 source |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 44400 | `d717b99fc349eafc38d0f2810f0316bdafcb1333e711febede73b8944038309c` | R17 test |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The R17 evidence manifest and live hashes agree. The R17 `repair_r17/report.md`
still displays a runner SHA with one omitted `b` (`...9e2450af223...`); its
static QA and evidence manifest carry the correct value shown above. This
documentation inconsistency must be fixed before archival.

R6 remains the only focused runtime receipt: PID `48048`, real exit `1`, 46
assertion-group summaries, raw stdout 8091 bytes/SHA
`7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b`, and raw
stderr 311 bytes/SHA
`71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565`. R17 has
no runtime receipt. The focused gate therefore remains closed. No Julia or
DESC process was present during this read-only check.

## Source contract review

The production change correctly removes the prior whole-tuple source match at
`N06DimensionedLedgerLawV1.jl:641` and routes law validation through
`_n06_h0a_source_role_match`. The matcher at lines 522–540:

- obtains `_N06_G1_ROLE_SELECTORS[:source]` without positional fallback;
- requires all four fields `ledger_id`, `equation_id`, `port_side`, and
  `port_index`, preserving exact typed field equality;
- filters the complete endpoint tuple independently of tuple order;
- returns `:missing`, `:single`, or `:ambiguous` through the existing cardinality
  helper; and
- returns `:registry_missing` when the registry is unavailable, malformed, or
  lacks a complete source selector.

The call site at lines 641–645 maps registry unavailable and zero source-role
matches to gaps, one match to the source-derived sign check, and multiple exact
matches to `g1_occurrence_source_ambiguous` in `errors`. It does not synthesize
a coefficient, source row, authority, or physical value.

The four-row endpoint contract remains intact at lines 93–119, including
exactly four rows and unique selectors. `_n06_h0a_endpoint_set` still checks
the four authored role selectors and all package/G1/G2/G3 joins. The matcher
does not replace endpoint identity, candidate/package/ref/component-hash,
version-axis, or source-provenance checks. The endpoint semantic validator
continues to reject stale source hashes and edited source units at lines
398–414, so a selector match cannot turn copied data into authority.

The source-role registry is still a static module registry from
`N06SourceFieldLedgerMappingV1.jl:46–53`; R17 correctly does not silently
promote it to a universal VNEXT candidate mapping. A future candidate path
must transport and hash the role map as candidate-owned input.

## Test and negative-control review

R17 preserves the R16 controls: the dimensionless trusted equation expects
`fail_closed` and checks `law_input_unit_equation_mismatch`; four-argument
admission checks the typed absent `gap_code == :external_ref_required`;
fixture and runner are unchanged; and the R15 zero/multiple/unknown-exception
controls remain present.

The new controls cover the source-role matcher and retain the correct
classification intent:

| case | current control | static judgment |
|---|---|---|
| reorder | `_n06_h0a_source_role_match(reverse(...))` | exact/order-independent, but private seam only |
| missing/replaced selector | matcher plus direct `_n06_h0a_validate_law` | source-role gap is exercised; public endpoint path is not |
| duplicate exact selector | `_n06_h0a_source_role_match((row,row))` | correct private cardinality seam; a valid endpoint constructor rejects this shape before the matcher |
| sign edit | direct `_n06_h0a_validate_law` | source-derived error is checked; no public `n06_h0a_validate` status assertion |
| input-unit edit | direct law validator plus public admission status | source error is checked privately; public admission can short-circuit on the independent external gap |
| source-unit/hash edit | `_n06_h0a_validate_endpoint_semantics` | source hash rejection is checked privately; no public declaration status assertion |

This distinction matters under the requested evidence contract. Several
controls are production functions, but they do not traverse the public
`n06_h0a_validate(declaration, package, e0)` or public admission result. The
private duplicate seam is appropriate for proving the helper's multiple-match
branch, and a selector replacement with a stale provenance hash is correctly a
fail-closed source-identity contradiction rather than a clean terminal gap.
Nevertheless, R17's claim of complete production-path negative coverage is too
strong. At minimum, the source-derived sign and unit controls need public
wrapper assertions once a locally consistent declaration is available; the
report must clearly label the private seam controls that cannot be public
without introducing an unrelated external-authority short circuit. Registry
unavailable also has a source branch but no explicit executable control in the
current test file.

## Required follow-up before focused execution

R17 cannot receive `pass_limited` yet. The author must:

1. correct the runner SHA typo in `repair_r17/report.md`;
2. either add public-wrapper assertions for the feasible sign/unit/hash
   controls, or amend the repair contract to state precisely why each remains
   private and add a public status/declaration assertion where it is feasible;
3. add a deterministic registry-unavailable control without mutating the
   production registry or falling back to fixture labels; and
4. preserve the current source selector and four-endpoint semantics while
   recording updated hashes and static QA.

The next source/test task should retain the exact selector contract, typed
error taxonomy, R16 contradiction and authority-gap assertions, and all
candidate/package/ref/hash/provenance checks. It must not weaken endpoint
cardinality, turn stale source identity into a gap, or use a documentation,
test count, or runner exit as physical evidence.

After a corrected independent precheck, and only after any T0 focused process
has ended, one serialized focused run may be scheduled with fresh source,
test, fixture, and runner hashes, fresh dirty/process snapshots, PID, UTC
interval, raw output hashes, actual-A status/declaration type, and zero
compile/provider/solver counters. A successful software run remains contract
evidence only; H0-A stays `accepted=false` and no UP2-total, B00/B04,
provider, mesh, engineering, physical, or R01–R10 credit is granted.

