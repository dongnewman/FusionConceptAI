# H0-A independent static precheck R10

Verdict: `pass_limited`; serial focused R4 may be queued. `accepted=false` and
`review_pending=true` remain in force.

This review is frozen at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` with
3,695 porcelain entries and no matching Julia process. It read the preserved
focused-R3 failure, independent postrun-R3 diagnosis, repair-R10 report,
acceptance, command receipts, and protected hashes. Julia/DESC were not run.

## Repair verification

The invalid zero-argument `NamedTuple{(),Tuple{}}()` form is absent from both
owned code files. The source now has four callable empty values
`NamedTuple{(),Tuple{}}(())`: two role-map values in the inner constructor and
two keyword defaults. The test helper has two corresponding callable defaults.
Thus all six syntactic call sites identified by the source/test scan are fixed;
the repair-R10 prose calls these “four” forms because it counts the two source
and two test default groups. This counting wording does not leave an unfixed
expression.

The replacement changes only constructor syntax. The declared `NamedTuple`
types, role maps, validation paths, assertions, and test structure remain
unchanged by inspection. The fixture and runner hashes exactly match the
repair-R10 before/after records. No reserved-word keyword assignment or raw
`Digest256(...)` constructor was introduced. The fixture parses as JSON.

The narrow static QA from repair-R9 still exits 0, and the additional R10 scan
reports zero invalid empty constructors, zero reserved assignments, and zero
raw `Digest256(` calls in the source/test pair. The preserved focused-R3 run
remains exit 1 with its original stdout/stderr hashes; it was not overwritten
or rerun here. Its five partial passes are not a suite pass.

## Frozen identity

| path | current bytes | current SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 56221 | `02a53521aaa85f7880448da60c924b0afd548f55d87d0490fcf17bb727f0f18e` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 37457 | `51d5a34b7da01b5f2e8c757939c1ba391306b08b9aaa1b62eb0fcc4b6dea302a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450af223798eb7f7b4db2048ce293dc` |

The R10 source/test after hashes match these current values; fixture and runner
remain unchanged. The focused-R3 raw evidence and protected before/after
records remain outside this new review directory and were not modified.

## Boundary

This is syntax/schema-only evidence. It grants no H0-A actual-A, B00, B04,
provider, mesh, engineering, physical, or R01-R10 credit. The separately
serialized focused R4 run is the next validation step; its exit code and full
test coverage must be recorded before any stronger claim.

