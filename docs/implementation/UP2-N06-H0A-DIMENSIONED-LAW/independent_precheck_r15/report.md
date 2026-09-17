# H0-A R15 independent static precheck

- **Verdict:** `pass_limited`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only review of R15 source/test/fixture/runner hashes, source
  branches, negative controls, and the append-only R14 receipt erratum. Julia,
  DESC, compiler, provider, mesh, solver, and focused execution were not run.

## Frozen identities

The live R15 files match the R15 repair record:

| path | bytes | SHA-256 | disposition |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` | R15 source after |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 40742 | `9c5ecf8f2f212b2298eff5a8129a618114185867c21b83dcd4e3ff1982b36599` | R15 test after |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected unchanged |

The source changed from the R14 after hash only in the two requested zero-match
classification branches. The test adds source-shaped controls and the
unexpected-exception taxonomy control. The R14 receipt erratum remains
append-only: its historical 48-character hash is preserved, alongside the
correct 64-character live source identity. No old receipt was overwritten.

## Exact-match and classification review

The private `_n06_h0a_exact_match` helper returns `(:missing, nothing)` for
zero items, `(:single, only(items))` for one item, and
`(:ambiguous, nothing)` for multiple items. All four former
`first(generator, nothing)` call sites are gone from the source.

The live callers now satisfy the required contract:

| join | zero match | multiple matches | one match |
|---|---|---|---|
| G3 flow entry | `power_flow_entry_missing` in `gaps` → terminal-deferred path | `power_flow_entry_ambiguous` in `errors` → fail-closed path | unit algebra uses the matched source entry |
| G1 source occurrence | `g1_occurrence_source_missing` in `gaps` | `g1_occurrence_source_ambiguous` in `errors` | sign check uses the matched occurrence |
| source-direction port | `law_direction_source_port_missing` in `gaps` | `law_direction_source_port_ambiguous` in `errors` | direction check uses the matched port |
| role port | `role_port_missing:<role>` in `gaps` | `role_port_ambiguous:<role>` in `errors` | role direction checks use the matched port |

The R15 source branches at lines 630 and 657 now route the two missing-port
tokens to `gaps`. Ambiguous matches remain errors, so the existing validator
and admission wrappers classify them as `fail_closed`. Single matches are
obtained only from the candidate's materialized G1/G3 tuples; no default,
synthetic port, entry, or authority is introduced.

Unknown `ErrorException` values still pass through `_n06_h0a_translate_upstream`
as `N06H0AProgramError(:source_projection_exception, ...)` and classify as
`program_exception`. There is no catch that changes an unknown exception into a
missing-source gap.

## Test review

The new R15 controls are source-shaped rather than label-only:

- a real G3 entry is created with a missing corresponding port, then passed to
  `_n06_h0a_validate_law`; both source-direction and role-port missing tokens
  are asserted in `gaps` and absent from `errors`;
- the same entry is paired with two identical source ports, and both
  source-direction and role-port ambiguous tokens are asserted in `errors`;
- direct helper controls cover missing, single, and ambiguous outcomes;
- the G1 source occurrence controls cover missing gap and ambiguous error;
- an `ErrorException` translation control asserts the typed program exception,
  its `:source_projection_exception` code, and that it is not a known gap.

The source-shaped controls call the production validator and use real typed
tuple fields. They do not copy fixture expected labels into classification or
reimplement the production join. Existing public validation/admission controls
continue to exercise the wrapper taxonomy. No mirror implementation or error
swallowing was found.

R15 remains contract-only. It does not prove actual authority, provider,
compiler, mesh, engineering, physical, B00/B04, or R01–R10 completion.

## Single focused-run gate

After this static review, one different Luna may run the focused suite in a
serialized lane using exactly:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

Inputs must be frozen immediately before launch to the four live hashes listed
above. The receipt must capture the fresh process/dirty snapshots, PID, UTC
interval, raw stdout/stderr bytes and SHA-256, and the real exit code. The
fixture and runner hashes must remain unchanged before and after the run.

The software exit gate is a complete suite receipt: all upstream suites pass,
the actual-A result preserves typed status/declaration semantics, zero-match
paths remain terminal-deferred, ambiguous paths remain fail-closed, unknown
exceptions remain program exceptions, and compile/provider/solver counters are
reported. Even an exit `0` remains limited software evidence; H0-A stays
`accepted=false` and no B00/B04, provider, mesh, engineering, physical, or
R01–R10 credit is granted.
