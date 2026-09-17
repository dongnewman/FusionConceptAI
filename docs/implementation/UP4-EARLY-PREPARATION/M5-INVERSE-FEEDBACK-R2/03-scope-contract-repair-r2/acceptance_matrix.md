# Static acceptance matrix — repair R2

| ID | Finding | Static contract closure | Runtime status |
|---|---|---|---|
| F7 | Complete canonical join | typed refs, parent body, bundle/binding equality and digest checker contract | deferred; no execution |
| F8 | valid_screen replay gate | schema branch requires exactly two unique attempts, `[0,0]`, semantic/byte equality, authority and raw/process refs | deferred; no replay |
| F9 | external `$ref` | absolute URN IDs plus frozen local registry, dependency hashes, unknown/network URI rejection | resolver static audit only |
| F10 | feedback CAS/history | immutable identity, CAS pointers, append-only sequence, before/after digest, UTC-Z and negative controls | deferred; no state transition |
| F11 | dependency/dirty closure | source/test/oracle/composition + Project/Manifest snapshots; per-path baseline and additive review-end rule | inventory capture contract only |
| F12 | failure taxonomy | exact code/class/resolution set equality and one mapping per code | static set audit only |

## Required negative controls

`foreign_join`, `canonical_digest_mismatch`, `unknown_resolver_uri`, `registry_hash_drift`, `zero_replay`, `one_replay`, `duplicate_attempt`, `nonzero_exit`, `semantic_byte_mismatch`, `stale_cas`, `duplicate_history_sequence`, `foreign_owner`, `wrong_direction`, `dynamic_insert`, `non_utc_recorded_at`, `unknown_failure_code`, `resolution_mismatch`, `dirty_path_not_in_baseline_or_package` must all be rejected deterministically.

## Acceptance boundary

The package remains `review_pending` and `not_implemented`. No source/test file, historical package, registry, solver, provider or hardware was touched. Independent review and root acceptance are still required.
