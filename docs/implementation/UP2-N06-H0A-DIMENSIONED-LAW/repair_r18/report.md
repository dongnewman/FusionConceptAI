# H0-A repair R18: public source-role coverage

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

R17's source-role matcher was correct but its tests did not reach the public
wrappers. R18 adds a narrow private injection seam for the source registry and
extends public-path controls without changing the endpoint, package, or
source-authority contract.

The production matcher now has an overload accepting an explicit registry for
controlled testing. The normal overload still reads the loaded
candidate/source-owned registry. `_n06_h0a_validate_law` accepts the private
`source_registry` test keyword; its default path is unchanged. Passing an
unavailable registry returns `:registry_missing`, which the validator maps to
the typed `source_binding_missing` gap. No global constant is deleted,
rebound, or mutated.

Tests now exercise legal four-occurrence endpoints through public
`n06_h0a_validate(declaration, package, e0)` and `n06_h0a_admit_present` and
assert that `g1_occurrence_source_ambiguous` is absent. Public sign-edit and
input-unit-edit controls retain their source-derived fail-closed tokens and
also assert no source ambiguity. A source occurrence unit edit reaches public
validation and remains a source endpoint identity failure. Existing private
reorder, missing, duplicate, R15, and R16 controls remain intact.

The R17 human-readable runner SHA typo is intentionally preserved in its old
receipt. The corrected value is recorded append-only in
`receipt_erratum_r18/`; no prior evidence was overwritten.

Static QA and JSON/hash validation passed. Fixture, runner, mapping source,
core files, and older evidence remain unchanged. No Julia, DESC, or focused
run was performed. Actual A still lacks authoritative candidate-owned law,
coefficient, calibration, and feedback evidence; no physical, provider, mesh,
engineering, B00, B04, or R credit is claimed.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 58976 | `e7f18c58834cfcb2eeaef813656525e16d3ea8ae1dd9df19277f08b57aaf949c` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 44400 | `d717b99fc349eafc38d0f2810f0316bdafcb1333e711febede73b8944038309c` | 46087 | `cc8e8087d14fbf626b914972dcbe1e1633ed833af12288146e77c23a5405d4d2` |

Protected inputs remain unchanged:

- fixture: 1451 bytes, SHA-256
  `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256
  `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

`accepted=false` and `review_pending=true` remain mandatory pending a
different Luna R18 independent precheck.
