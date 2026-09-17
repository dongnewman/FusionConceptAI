# H0-A repair R14: bounded exact-match source joins

Status: repair_static_complete; accepted=false; review_pending=true.

The R13 diagnostic showed a real production `program_exception` from `first(generator, ::Nothing)` in the actual-A bind path. R14 adds one private `_n06_h0a_exact_match` helper with three bounded outcomes: missing, single, and ambiguous. The four affected callers now use it:

- power flow entry: zero match remains `power_flow_entry_missing` gap; multiple matches produce `power_flow_entry_ambiguous` error; one match alone reaches unit algebra.
- role contract port lookup: zero remains missing/unknown and the validator emits `role_port_missing`; multiple emits `role_port_ambiguous`; one port supplies direction.
- law source occurrence: zero emits `g1_occurrence_source_missing` gap; multiple emits `g1_occurrence_source_ambiguous`; one occurrence supplies the sign check.
- source-direction port and role port lookups: zero/multiple are explicit missing/ambiguous errors; only one source-derived port is used.

No authority, entry, port, or source item is fabricated. Existing caller classification remains intact: known source absence is a terminal-deferred gap, contradictory multiplicity is a fail-closed error, and unrelated exceptions remain program_exception. R14 adds direct helper single/zero/multiple negative controls plus source-occurrence zero/multiple validator controls. Fixture and runner are unchanged. Julia/DESC and focused execution were not run.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` | 57924 | `2d38d9fc7ae42c8bf7a77bea7ad99557e390a321e26f5d918be1996443a629ff` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38567 | `b262eb32818666abf1a5a070ddd543d47078fadb7763b29e5f1b16659192a144` | 39270 | `b0e626d73c7246c9308c1ff8b315866e9c95dea4dd50aba796959d4092b31756` |

Protected unchanged inputs: fixture 1451 bytes, `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`; runner 299 bytes, `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

Static validation checks the fixture and new JSON manifests parse, all protected hashes match, no `first(generator, ..., nothing)` pattern remains in the source, and the negative controls are present. No focused/full Julia or DESC execution was performed. Actual-A remains subject to the existing evidence ceiling; `accepted=false`, no B00/B04 or physical/provider/engineering/R credit.
