# H0-A repair R11: explicit base/full constructor dispatch

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

The focused-R4 independent postrun identified a production `StackOverflowError`: the public twelve-argument keyword constructor called `N06H0AUnitEquationV1(...)` with the same positional shape, redispatching itself before the original inner `new(...)` body. The R11 repair adds two private marker-dispatched inner constructors:

- `N06H0AUnitEquationV1(Val(:base), ...)` retains the original validation and creates the schema/base 21-field object with empty provenance fields.
- `N06H0AUnitEquationV1(Val(:full), ...)` is an explicit 21-field `new(...)` path for closure relation, typed source provenance, payloads, and role maps.

The public keyword constructor now calls the base marker, preserves the existing typed provenance guard, then calls the full marker. No validation, field, hash input, source provenance type, or public API was removed or weakened.

The test file adds a focused constructor-dispatch testset covering the default no-source path, the typed law-source path, all 21 fields, source identity/payload preservation, and closure-relation preservation. Completion of both constructor calls is the no-recursion regression control. Julia/DESC was not run for this static repair.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 56221 | `02a53521aaa85f7880448da60c924b0afd548f55d87d0490fcf17bb727f0f18e` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 37457 | `51d5a34b7da01b5f2e8c757939c1ba391306b08b9aaa1b62eb0fcc4b6dea302a` | 38431 | `eadd8c19344a117edeaa5ffad4fbe6f9e1300d3c81388918b00c63876efa10e5` |

Protected unchanged inputs:

| artifact | bytes | SHA-256 |
|---|---:|---|
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

Static checks completed: constructor call scan shows only `Val(:base)` and `Val(:full)` private calls from the public method; fixture JSON parses; no Julia/DESC/compiler/provider/mesh/solver/physical execution was performed. The parent H0-A remains `accepted=false`; actual-A and physical/B00/B04 claims remain unavailable. The next gate is a different Luna R11 static precheck, followed by a separately authorized serial focused run.
