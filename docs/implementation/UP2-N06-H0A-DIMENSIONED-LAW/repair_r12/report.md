# H0-A repair R12: preserve primary actual-A classification failure

Status: `repair_static_complete_diagnostic_inconclusive`; `accepted=false`; `review_pending=true`.

The R5 independent postrun required two narrow actions: preserve the primary `n06_h0a_bind_actual_a` status assertion while guarding declaration field access when `declaration === nothing`, and capture the first wrapped `result.errors` before choosing a production classification repair. The test now keeps `@test result.status == :terminal_deferred` and guards the typed-absent fields and validation call behind `result.declaration isa G.N06H0ATypedAbsentV1`. This removes the four cascade errors without downgrading `program_exception`.

A single minimal diagnostic was attempted in `diagnostic_r12/`, reusing the actual-A layer fixture and constructor path. It did not reach `n06_h0a_bind_actual_a`: the diagnostic harness omitted the runner's `G.load_genome_v5_up2_components!()` setup before deserializing the shared fixture, so Julia exited `1` with `UndefVarError: MechanismGenomeV5 not defined`. The raw stdout/stderr and exact launcher metadata are preserved. This is a diagnostic harness failure, not evidence of an authority gap, and no production classification change is inferred or made.

## Static and hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38431 | `eadd8c19344a117edeaa5ffad4fbe6f9e1300d3c81388918b00c63876efa10e5` | 38512 | `809a745ab0af4add6ba8f33d7f273f4573fe8bbc98ce64e9400d9edf113d667d` |

Protected fixture and runner were unchanged: fixture `1451` bytes, SHA `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`; runner `299` bytes, SHA `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

The diagnostic command ran once, PID `23916`, exit `1`, UTC `2026-09-14T21:53:26.7808964Z` to `2026-09-14T21:53:38.0702554Z`, dirty `303→303`, Julia/DESC `0→0`. stdout is `272` bytes, SHA `58ec17309e64723b09d28749543d3a78c526c853b2677cf88aa207c199f03d4e`; stderr is `2455` bytes, SHA `d34d59ba7298d335f3141247a2038ce6c9ac461dfa79dcdc88097b7376d8240e`.

Static JSON/fixture parsing and hash checks pass. Julia/DESC was not run again and the focused suite was not rerun. The next gate needs a separately authorized corrected diagnostic or a different Luna review; actual-A remains unresolved and `accepted=false`.
