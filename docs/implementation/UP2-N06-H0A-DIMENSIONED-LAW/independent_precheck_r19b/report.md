# H0-A R19b independent precheck under clarified architecture ruling

- **Verdict:** `pass_limited`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only recheck of R18/R19 evidence, current source lines
  `751-770`, source-shaped tests, protected input hashes, and lightweight JSON
  parsing. This reviewer did not run Julia, DESC, or the focused runner and
  did not modify the old R19 report, source, test, fixture, runner, or prior
  evidence.

## Ruling applied

The architectural ruling narrows the required public selector evidence:

1. a declaration endpoint reorder or unit/hash mutation must be rejected by
   the source-owned endpoint identity gate; it is not required to send the
   mutated declaration endpoints through the source-role selector;
2. a legal source-owned expected four-endpoint set must reach public
   `validate` and `admit` law checks; sign and input-unit edits must produce
   their source-derived error tokens and no
   `g1_occurrence_source_ambiguous`; and
3. the public reorder result must remain an identity failure, never a claimed
   successful reorder.

Under this contract, the prior R19 concern about proving selector dispatch on
mutated declaration endpoint rows is resolved as a deliberately rejected
stronger requirement. The original R19 report remains unchanged and is
retained as historical review context.

## Hash and implementation audit

The current protected inputs are unchanged from R19/R18 where required:

| artifact | bytes | SHA-256 | result |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` | protected unchanged |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` | R19 test input |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The R19 repair JSON records parse successfully. R18's append-only receipt
erratum and the protected R6 failure receipt remain present. No Julia/DESC
process was present in the final read-only snapshot.

The production selector remains source-owned and unchanged: the private
matcher keys all four selector fields and classifies zero/one/multiple as
typed gap/source-derived result/typed ambiguity. The explicit registry
injection remains a private seam; R18's `:registry_missing` and
`source_binding_missing` controls remain in the test file. No fixture or
positional fallback is introduced.

## Public expected-endpoint path

The source at `N06DimensionedLedgerLawV1.jl:751-754` reconstructs the
candidate-owned `expected` endpoint set and records
`source_endpoint_identity_mismatch` when a declaration endpoint card differs.
Lines `755-770` then validate endpoint semantics and law semantics using that
source-owned `expected` set; line `764` calls `_n06_h0a_validate_law`, whose
source-role match is therefore observable on the legal expected four-row set.
The declaration overload of `n06_h0a_admit_present` delegates to this public
validator at lines `803-810`, preserving its status/errors/gaps.

The R19 tests use `_h0a_actual_package()` (actual child fixtures integrated
through `integrate_genome_v5`) and derive `endpoints` from
`n06_projection_from_a` plus `_n06_h0a_endpoint_set`. Thus the following
controls are on the source-owned expected endpoint set, rather than a copied
schema-only mirror:

- lines `564-573`: sign edit reaches both public entry points and asserts
  `fail_closed`, `law_sign_source_mismatch`, and no
  `g1_occurrence_source_ambiguous`;
- lines `644-656`: input-unit edit reaches both public entry points and
  asserts `fail_closed`, `law_input_unit_equation_mismatch`, and no source
  ambiguity;
- lines `433-446`: constructor-valid reverse-order endpoint card is sent to
  both public entry points and correctly asserts
  `source_endpoint_identity_mismatch`, `fail_closed`, and no source
  ambiguity; it is not treated as a successful reorder;
- lines `407-427` and `450-468`: source unit/hash mutations retain private
  `g1_occurrence_source_hash_mismatch` semantics while public validate/admit
  expose the earlier identity failure, as required by the source-identity
  boundary.

The sign token is emitted only by the source-derived sign comparison in the
law validator. The input-unit token is emitted by the typed effort/flow unit
comparison; the source-role matcher continues over the same expected endpoint
set and the no-ambiguity assertion protects its classification. These public
controls satisfy the clarified contract without claiming that mutated
declaration endpoints were source-matched.

R16's dimensionless contradiction remains `fail_closed` with
`law_input_unit_equation_mismatch`, the typed external feedback gap remains
`external_ref_required`, and registry-unavailable remains a typed
`source_binding_missing` gap. No authority, physical evidence, provider,
mesh, engineering, B00, B04, or R01-R10 credit is inferred.

## Gate decision

The clarified static contract is **`pass_limited`**. This permits exactly one
serialized focused run after T0 completion and a fresh four-input hash freeze:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The run must capture PID, real process exit code, UTC interval, raw stdout and
stderr bytes plus SHA-256, pre/post dirty and process snapshots, actual-A
status/declaration type, 46 group summaries, and compile/provider/solver
counters. Its result remains software contract evidence only. H0-A remains
`accepted=false`; no parent R01-R10 or physical/engineering acceptance is
granted by this precheck.
