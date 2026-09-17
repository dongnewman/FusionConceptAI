# H0-A R16 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only review of the R16 test-only repair, live hashes, R6
  postrun contract, source classification, and the claimed authority-only
  construction blocker. Julia, DESC, the focused runner, and the full suite
  were not run; no implementation or test files were changed by this review.

## Frozen input audit

The R16 repair changed only the test file. Current bytes and SHA-256 values
are:

| artifact | bytes | SHA-256 | result |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` | unchanged from R15/R6 |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 40947 | `6572b1e56e41065f84d4587616d8efa3e353166e8d929ff82e8e8afb4e0cc976` | R16 after |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The R16 `evidence_manifest.json` has the correct runner hash. Its companion
`repair_r16/report.md` contains a one-character omission in the displayed
runner SHA (`...9e2450af223...` instead of `...9e2450afb223...`); the live
hash and manifest are authoritative enough to identify the file, but the
report should be corrected before archival.

The R6 postrun receipt remains unchanged: PID `48048`, exit `1`, raw stdout
8091 bytes/SHA `7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b`,
raw stderr 311 bytes/SHA
`71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565`, and 46
assertion-group summaries. R16 has no new runtime receipt, so it cannot yet
be admitted to the single serial focused-run gate.

## R6 contract correction review

The R16 test edits correctly preserve the R6 source-derived contradiction:
`_h0a_equation()` is dimensionless, actual G3 effort/flow units are typed, and
`_n06_h0a_validate_law` appends `law_input_unit_equation_mismatch` at
`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl:566-567`. The trusted public
validation now expects `:fail_closed` and checks that error token. This matches
the production error-over-gap precedence and does not hide the authority gap.

The four-argument admission now checks the typed absent declaration's
`gap_code == :external_ref_required`. This is the correct stable check for the
decorated `showerror` reason emitted by the admission wrapper. The R15 missing,
ambiguous, and unexpected-exception controls remain source-shaped in the live
test, and the production source hash is unchanged.

These changes repair the two R6 assertion contracts, but they do not make R16
runtime-ready. A later testset already contains a latent source contradiction
that the R6 run never reached because the earlier trusted testset failed and
terminated the top-level runner.

## Authority-only construction blocker

The R16 author correctly identified the production blocker, and it is more
specific than a general inability to create a test fixture. The endpoint
constructor deliberately requires exactly four G1 occurrences at
`N06DimensionedLedgerLawV1.jl:98-119`; `_n06_h0a_endpoint_set` also enforces
the four role selectors at lines 358–361. However, `_n06_h0a_validate_law`
then calls `_n06_h0a_exact_match(endpoints.g1_occurrences)` over that complete
four-item tuple at lines 621–624. The helper's contract is zero → `:missing`,
one → `:single`, and more than one → `:ambiguous` (lines 517–520). Therefore
every legal four-role endpoint set produces the error
`g1_occurrence_source_ambiguous` before missing law authority can be returned
as a gap.

This is observable in the current source-shaped test that R16 will expose
next: `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:422-463` builds a fully
typed, unit-compatible `good` equation and asserts
`isempty(G._n06_h0a_validate_law(good, endpoints; law_id=law_id).errors)` at
line 463. The `endpoints` value has four G1 occurrences (line 368), so the
global exact-match call necessarily contributes the error. R16's static QA
does not inspect this later testset; its claim that no authority-only positive
was constructed does not remove this already-authored source-derived positive
control.

The blocker is a real production semantic gap, not a reason to weaken R16 or
to reduce the four-selector contract. The current focused suite must remain
`not yet runnable for acceptance` until this latent failure is repaired.

## Recommended next work order

Issue a separate R17 source task with explicit ownership:

1. Modify only the N06 production source initially. In
   `_n06_h0a_validate_law`, filter the endpoint occurrences by the authored
   `:source` selector from `_N06_G1_ROLE_SELECTORS`, then apply the existing
   exact-match helper to that filtered tuple. Preserve zero as
   `g1_occurrence_source_missing` in `gaps`, one as source-derived sign input,
   and multiple as `g1_occurrence_source_ambiguous` in `errors`. Do not use
   positional `first`, discard the other three role occurrences, or fabricate
   authority.
2. A separate test owner may then add or revise a public source-shaped
   authority-only case: all local unit, owner, role, and closure joins must be
   consistent, while calibration/closure/law authority remains absent. It must
   return typed `terminal_deferred` with an explicit gap. Keep a duplicate
   source-selector negative control that remains `fail_closed`.
3. Recompute source/test/fixture/runner hashes, run one serialized focused
   suite only after the independent source review, and preserve raw output,
   process/dirty snapshots, PID, exit code, and all group summaries. The run
   must reach and pass the existing line 463 control as well as the corrected
   R16 trusted controls.

R16 itself is therefore `changes_requested`, and no focused execution is
authorized by this precheck. The production source, fixture, runner, R6 raw
outputs, and prior receipts remain protected. H0-A remains `accepted=false`;
there is no UP2-total, provider, mesh, engineering, physical, B00/B04, or
R01–R10 credit.

