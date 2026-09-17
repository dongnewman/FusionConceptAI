# H0-A repair R17: source-role occurrence join

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

R16 independent precheck and the occurrence architecture audit identified a
production defect: the law validator applied a cardinality helper to all four
G1 occurrences, making every legal endpoint set appear ambiguous. R17 adds a
private source-role matcher that obtains the candidate/source-owned
`_N06_G1_ROLE_SELECTORS[:source]` key, normalizes its complete
`ledger_id/equation_id/port_side/port_index` fields, and filters the complete
endpoint tuple by exact selector equality.

The matcher is independent of tuple order, occurrence effect, fixture labels,
or a positional first row. Its outcomes are preserved as follows:

- unavailable or malformed registry: `:registry_missing`, surfaced as the
  typed `source_binding_missing` gap;
- zero exact source matches: `g1_occurrence_source_missing` gap;
- one exact source match: only that source-derived coefficient supplies the
  sign check;
- multiple exact source matches: `g1_occurrence_source_ambiguous` error and
  fail-closed classification.

The existing endpoint/package/ref/hash/provenance checks remain outside this
matcher. Four-occurrence cardinality and unique-selector validation remain
unchanged. No static mapping is promoted to a universal VNEXT mapping.

Tests cover reordered actual candidate-bound occurrences, replacement of the
authored source selector, duplicate exact source rows at the private matcher
seam, source sign edit, input-unit edit without the old ambiguity token, and
source occurrence unit edit with source-hash rejection. R16's dimensionless
unit contradiction and typed `external_ref_required` admission assertions
remain in place. The protected fixture and runner and all earlier receipts are
unchanged. No Julia, DESC, focused, or full runtime was run.

The current actual A still lacks authoritative candidate-owned law,
calibration, coefficient, and feedback evidence. This repair grants no
physical, provider, mesh, engineering, B00, B04, or R credit.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` | 58976 | `e7f18c58834cfcb2eeaef813656525e16d3ea8ae1dd9df19277f08b57aaf949c` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 40947 | `6572b1e56e41065f84d4587616d8efa3e353166e8d929ff82e8e8afb4e0cc976` | 44400 | `d717b99fc349eafc38d0f2810f0316bdafcb1333e711febede73b8944038309c` |

Protected inputs remain unchanged:

- fixture: 1451 bytes, SHA-256
  `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256
  `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

Static QA checked the four hashes, fixture and R17 JSON parsing, complete
selector-field matching, absence of the old whole-tuple source matcher, the
zero/one/multiple controls, source unit/hash controls, and R16 assertion
preservation. `accepted=false` and `review_pending=true` remain mandatory
pending a different Luna R17 independent precheck.
