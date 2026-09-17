# H0-A repair R16: focused test contract correction

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

R6 independent postrun attributed both focused failures without a production
source change. R16 therefore changes only the H0-A test file:

- the existing dimensionless `_h0a_equation()` remains a deliberate
  source-derived contradiction control;
- trusted public validation now expects `:fail_closed` and explicitly checks
  `law_input_unit_equation_mismatch` in `trusted.errors`;
- four-argument public admission still expects `:terminal_deferred`, and now
  checks the typed absent declaration's `gap_code == :external_ref_required`
  instead of applying a raw-token prefix test to a `showerror`-decorated gap.

An actual-A authority-only positive was assessed for construction. The current
public path cannot make that case independently within the test-only scope:
`N06H0AEndpointSetV1` requires exactly four G1 occurrences, while
`_n06_h0a_validate_law` applies the bounded exact-match helper to the whole
four-item occurrence tuple. That necessarily yields
`g1_occurrence_source_ambiguous` and a fail-closed result before missing
calibration/closure/law authority gaps can classify as terminal-deferred.
Creating a public authority-only positive would therefore require a production
source contract change outside R16. This limitation is recorded rather than
fabricating a one-occurrence endpoint or weakening the frozen four-selector
contract. Existing source-derived semantic controls remain unchanged.

The fixture, runner, production source, R1–R15 receipts, and focused R6 raw
outputs were not changed. No Julia, DESC, focused, or full runtime was run for
R16. Actual A remains without authoritative candidate-owned coefficient,
calibration, law, and feedback evidence; no physical, provider, mesh,
engineering, B00, B04, or R credit is claimed.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 40742 | `9c5ecf8f2f212b2298eff5a8129a618114185867c21b83dcd4e3ff1982b36599` | 40947 | `6572b1e56e41065f84d4587616d8efa3e353166e8d929ff82e8e8afb4e0cc976` |

Protected unchanged inputs:

- fixture: 1451 bytes, SHA-256
  `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256
  `da4c41517badd8c99f5f10e55c9219e2450af223798eb7f7b4db2048ce293dc`.

Static QA verifies source immutability, the corrected test predicates, fixture
and R16 JSON parsing, all four live hashes, absence of Julia/DESC processes,
and preservation of the R15 zero-match/ambiguous and typed-exception controls.
`accepted=false` and `review_pending=true` remain mandatory pending a
different Luna R16 precheck.
