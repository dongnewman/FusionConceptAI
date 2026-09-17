# H0-A repair R10 empty NamedTuple syntax repair

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

The preserved focused R3 run exited `1` with five passes and one error before
later testsets. Its first error was `MethodError: no method matching
@NamedTuple{}()` in `_h0a_equation`. The independent postrun R3 review found
the same invalid zero-argument expression at four owned locations: two source
defaults/storage values and two test defaults.

The narrow repair replaces all four
`NamedTuple{(),Tuple{}}()` calls with the callable empty value
`NamedTuple{(),Tuple{}}(())`. The declared empty `NamedTuple` type, role map
semantics, unit/ledger checks, typed error classification and all assertions
are unchanged. No guard was weakened and no test was removed.

## Static QA

- Empty NamedTuple constructor scan: pass; no `NamedTuple{(),Tuple{}}()` remains
  in the H0-A source or test.
- Reserved-key assignment scan for source and test: pass.
- Digest helper scan retains `digest256_text`/`canonical_hash`; no raw fixed
  digest helper was introduced.
- Fixture and runner were not modified.
- Julia and DESC were not run for R10.

## Before/after identity

| path | before SHA-256 | after SHA-256 |
|---|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | `03aa28636626efa4a5fdcb2f806e23bfc3e166f0d6fcabe72ebb0e7c6001e8dc` | `02a53521aaa85f7880448da60c924b0afd548f55d87d0490fcf17bb727f0f18e` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | `1c2066a0fad0a324db263619d822e0e2d0422f73b23f6b702d74686a46383fdb` | `51d5a34b7da01b5f2e8c757939c1ba391306b08b9aaa1b62eb0fcc4b6dea302a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | unchanged | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | unchanged | `da4c41517badd8c99f5f10e55c9219e2450af223798eb7f7b4db2048ce293dc` |

Focused R3 raw evidence remains immutable: exit `1`, stdout SHA
`2c2440192446c975acd05859413361a3d568d048d8f530be379d31ef82678bd3`, stderr
SHA `a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`.
This R10 archive requests a different-Luna static review before the unique
serial focused R4 lane. Actual A remains deferred; no B00, B04, provider,
mesh, engineering, physical or R credit is claimed.

