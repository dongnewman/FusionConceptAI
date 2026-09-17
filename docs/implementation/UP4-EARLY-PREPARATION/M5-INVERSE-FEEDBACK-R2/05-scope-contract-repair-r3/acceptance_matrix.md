# R3 static acceptance matrix

| Gate | Required machine condition | Current state |
|---|---|---|
| canonical join | all canonical/binding/result pointers equal; every digest recomputed | contract closed; execution deferred |
| valid screen | authority, join, refs, CAS, taxonomy, replay and raw/process implications all true | impossible until fresh freeze and replay |
| resolver | exact local URN registry, path/bytes/hash match; no network or unknown URI | static registry only |
| dependency | complete transitive include closure plus environment files | frozen in manifest |
| failure mapping | one concrete class/resolution row for all 33 codes | static mapping |
| dirty closure | review-end equals unchanged baseline plus this package | end receipt pending independent handoff |
| CAS/history | full immutable tuple, version arithmetic, sequence, state-hash and fail-atomic controls | typed checker contract |

Required negative vectors are included in `fixtures/negative_vectors.json`:
foreign join, canonical digest mismatch, binding digest mismatch, unknown or
drifted resolver, zero/one/duplicate replay, nonzero exit, semantic/byte
mismatch, unknown authority, false join/CAS/identity/owner/direction, stale
CAS, duplicate/skipped/dynamic history, foreign owner, wrong direction,
non-UTC timestamp, unknown failure code, resolution mismatch and dirty-path
escape.  No vector is runtime evidence.
