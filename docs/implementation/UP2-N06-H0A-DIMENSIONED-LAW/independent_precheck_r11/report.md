# H0-A R11 independent static precheck

- **Verdict:** `pass_limited`
- **Serial focused_r5 readiness:** `ready_for_serial_focused`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** static source/test/fixture/runner and evidence review only. Julia and DESC were not run.

## Frozen workspace

The review was performed at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` on `main`. The current `git status --porcelain=v1` snapshot had 303 lines and UTF-8/LF SHA-256 `e372f472539f77536e07ea47a6d549931251bafa6894c3df77937e721fa6bc1a`. No `julia`, `julia-debug`, or `desc` process was present. The status snapshot is a workspace guard only; unrelated dirty entries remain outside this review's ownership.

## R11 repair checks

The production implementation at `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` now has separate private marker dispatches `N06H0AUnitEquationV1(Val(:base), ...)` and `N06H0AUnitEquationV1(Val(:full), ...)`. The public keyword constructor calls the base marker and then the full marker, so it no longer calls another constructor with the same public positional/keyword signature. The full marker uses an explicit `new(...)` containing all 21 struct fields, including `closure_relation`, all three typed source fields, all three payloads, and both role maps. The typed guard remains and rejects non-`nothing` provenance values that are not `N06H0ASourceProvenanceV1`. Existing defaults remain `nothing` for source/payload/closure relation and empty named tuples for role maps.

The added testset `H0-A unit equation constructor dispatch` covers a default no-source construction, `fieldcount == 21`, a typed law-source plus payload path, and closure relation retention. Existing semantic and mutation-control tests retain the negative fail-closed assertions (30 `status == :fail_closed` occurrences in the current test file), including calibration, closure, law, role, direction, unit, and typed-input controls. Static inspection found no replacement of these controls by message-only checks.

## Frozen target identities

The current four target files match the R11 repair manifest:

| target | bytes | SHA-256 | disposition |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` | intended R11 source change |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38431 | `eadd8c19344a117edeaa5ffad4fbe6f9e1300d3c81388918b00c63876efa10e5` | intended R11 test coverage |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | unchanged protected fixture |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | unchanged protected runner |

The fixture parses as JSON. The runner identity is the complete 64-character on-disk SHA. `dispatch_hash_erratum_r11` correctly records that an earlier dispatch/evidence string was only 63 characters and must not be used as the preflight identity; its correction does not overwrite R10 or focused-r4 evidence.

Focused-r4 remains historical exit `1` with the constructor recursion error and is not converted into a pass. Its original `report.json` SHA is `52e9729d47ed880ccfdef6947cdafecec5e2b95f46a609acca17e30f5d0c5b26`; the independent postrun report SHA is `0e1a0598bea0008b0b565713dfbf19ff7d48705558634d6594ff14dc879f651f`. No prior receipt is reused as an R11 execution result.

## Gate and ceiling

The static repair is sufficient to hand off one serialized focused-r5 run after a fresh process/dirty preflight against the four identities above. The focused run must preserve raw stdout/stderr, PID, UTC, exit code, before/after hashes, process snapshot, and dirty snapshot. This review grants no Julia/DESC result, positive or dimensioned-law acceptance, B00/B04 credit, physical/engineering credit, or parent-goal/R credit. A focused-r5 exit 0 would remain software-contract evidence with `accepted=false` and `review_pending=true` until the separate postrun review and all upstream gates are satisfied.

