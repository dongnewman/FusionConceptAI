# R4 static acceptance matrix

| Gate | Required machine condition | Current state |
|---|---|---|
| canonical join | all canonical/binding/result pointers equal; every digest recomputed, including decoded `canonical_bytes` D12 | contract closed; execution deferred |
| valid screen | authority, join, refs, CAS, taxonomy, replay and raw/process implications all true | impossible until fresh freeze and replay |
| resolver | exact local URN registry, path/bytes/hash match; no network or unknown URI | static registry only |
| dependency | complete transitive include closure plus environment files | frozen in manifest |
| failure mapping | one concrete class/resolution row for all 33 codes | static mapping |
| dirty closure | fresh end UTC > start and every artifact; every baseline path unchanged; only this package is additive; per-path bytes/SHA closure | fresh static capture; independent review pending |
| CAS/history | non-empty exact `1..n` history, full immutable tuple, linked version arithmetic, state/operation bytes and fail-atomic controls | typed checker contract |

Required negative vectors are included in `fixtures/negative_vectors.json`:
foreign join, canonical payload/bytes digest mismatch, binding digest mismatch,
unknown or drifted resolver, zero/one/duplicate replay, nonzero exit,
semantic/byte mismatch, unknown authority, false join/CAS/identity/owner/
direction, stale CAS, foreign history identities, empty/duplicate/skipped/
version-gap history, missing state bytes, state-hash mismatch, fail-atomic
mutation, non-UTC timestamp, unknown failure code, resolution mismatch and
dirty-path escape/change.  No vector is runtime evidence.
