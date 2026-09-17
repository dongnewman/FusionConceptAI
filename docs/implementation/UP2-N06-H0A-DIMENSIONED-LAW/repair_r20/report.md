# H0-A repair R20: role-sign projection correction

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

The R7 focused receipt identified a production defect in the G3 role contract:
actual source/load/return/heat coefficients are `10/-8/-2/-1`, while the role
rules carry sign sentinels `+1/-1`. The old comparison at the role loop compared
the full rational coefficient to that sentinel and rejected the valid magnitudes
for source, load, and return. R20 changes exactly that projection to
`_n06_h0a_sign(row.coefficient)==expected_rule.sign`.

The full coefficient equality at the preceding line remains intact, so the
source-owned magnitudes must still match the authored role coefficients. The
existing zero-coefficient rejection remains intact. Source-role exact selector
joining, direction, endpoint provenance, unit/closure checks, and typed error
classification are untouched. A static scan found no other role magnitude to
sign-sentinel comparison requiring expansion this round.

The existing R7 test, fixture, runner, and old failure receipt were not changed.
No Julia, DESC, or focused run was performed for R20. The actual-A result remains
bounded by the prior receipt: its group printed 7/7, while structured status,
declaration type, and compile/provider/solver counters were not printed. No
authority or physical positive is inferred.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |

Protected inputs remain unchanged:

- fixture: 1451 bytes, SHA-256 `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256 `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

The old R7 nonzero exit and raw output hashes remain in
`focused_r7/`; they were not overwritten. The next gate is a different Luna
R20 independent precheck. H0-A remains `accepted=false`, with no UP2-total,
B00/B04, provider, mesh, physical, engineering, or R credit.
