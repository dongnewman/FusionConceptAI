# M5-SEARCH-R2 machine-checker scope contract R2 acceptance matrix

Static contract only. A future implementation must reject every listed mutation
without repair, normalization, inferred authority, or caller-supplied rank.
No row is execution, search, fixture, M5-C, physical, or formal evidence.

| principal relation | required sub-relations | vector IDs | expected failure family |
|---|---|---|---|
| P1-01 authority metadata / typed absence | typed-absent child; foreign owner; stale version; null authority; authoritative bytes | P1-01-01..05 | `identity_mismatch` or `provenance_changed` |
| P1-02 content / operational / replay separation | content digest; raw length; raw hash; same attempt; changed trace; changed config/authority | P1-02-01..06 | `schema_malformed`, `envelope_content_join_mismatch`, or `replay_mismatch` |
| P1-03 accepted M5-C gate identity | pseudo digest; null raw; stale history; wrong config | P1-03-01..04 | `gate_missing_or_unbound` |
| P1-04 budget arithmetic / fold | arithmetic; sequence; stage; scope; seed; cap; final fold | P1-04-01..07 | `budget_ledger_invalid` or `budget_fold_mismatch` |
| P1-05 descriptor identity | axis; label erasure; tie-break; full-chain join | P1-05-01..04 | `descriptor_identity_mismatch` |
| P2-01 failure precedence | caller rank; competing terminal observations; contradiction/numerical precedence | P2-01-01..03 | `failure_mapping_invalid` |
| P2-02 prohibited scan | empty refs; token order; algorithm; unscanned claim; wrong scan binding | P2-02-01..05 | `scan_incomplete` or `provenance_changed` |
| P2-03 upstream provenance | path; bytes; declared hash; review path; duplicate/unexpected path; manifest self-hash exclusion; hash-manifest self-hash exclusion | P2-03-01..09 | `provenance_changed` |

## Required invariant

For P2-03, the checker must compare the exact upstream closure listed in the R2
manifest. The R1 package's `manifest.json` and `hash_manifest.json` self-hashes
are excluded by policy and must not be silently synthesized. Attempting to add
either self-hash is a negative mutation and must return
`fail_closed/provenance_changed`.

## Claim ceiling

Every vector is a future-checker control. A checker pass may only report the
frozen machine relation result; it must retain `claim_ceiling=screen_only`,
`implementation_credit=none`, `formal_credit=none`, and `no_publish=true`.
