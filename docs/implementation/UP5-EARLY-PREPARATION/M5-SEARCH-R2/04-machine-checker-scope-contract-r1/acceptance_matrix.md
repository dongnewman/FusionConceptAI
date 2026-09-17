# M5-SEARCH-R2 machine-checker contract R1 acceptance matrix

Static contract only. A future implementation must reject every negative
vector without repair, normalization, inferred authority, or caller-supplied
rank. No row is execution, search, fixture, M5-C, or formal evidence.

| ID | machine relation | positive condition | negative vector | required result |
|---|---|---|---|---|
| MC-01 | input closure | every bound path has exact `/` path, bytes, SHA-256 and package membership | changed byte, missing path, duplicate or unexpected path | `fail_closed/provenance_changed` |
| MC-02 | typed absence | closure and all dependent children are `typed_absent` with every payload field null | typed-absent parent with authoritative child or null interpreted as authority | `not_executed` for valid absence; otherwise `fail_closed` |
| MC-03 | authoritative join | path/content/canonical/metadata/receipt hashes and owner/source/version recompute and join | pseudo-digest, stale version, foreign owner, changed file | `fail_closed/identity_mismatch` |
| MC-04 | content canonicalization | strict canonical bytes recompute `content_receipt_id`; content has no operational fields | PID/UTC/command/raw path nested in content or digest mismatch | `fail_closed/schema_malformed` |
| MC-05 | operational/raw join | envelope binds one content ID and raw paths whose bytes/lengths/hashes match | wrong raw hash/length, two content IDs, content hash mismatch | `fail_closed/envelope_content_join_mismatch` |
| MC-06 | fresh replay | two distinct attempts have identical content/trace/config/authority bytes | envelope-only replay, same attempt twice, changed content | `not_executed` or `fail_closed/replay_mismatch` |
| MC-07 | M5-C gate | accepted+authoritative gate canonical digest and every closure join match | accepted pseudo-digest, null raw ref, stale historical gate, wrong config | `not_executed/terminal_deferred` or `fail_closed` |
| MC-08 | budget arithmetic | every event obeys delta/after/remaining/limit arithmetic and sequence rules | after=99 from before=0, underflow, skipped/duplicate sequence | `fail_closed/budget_ledger_invalid` |
| MC-09 | budget fold/scope | folded events equal final counters and both folds; config/seed/scope/stage joins match | hand-entered final counter, cross-seed/stage event, cap mismatch | `fail_closed/budget_fold_mismatch` |
| MC-10 | descriptor chain | descriptor hash/cell are recomputed and equal in config/receipt/ledger/stop/entry; tie-break fixed | label-dependent cell, changed axis/hash/cell, wrong tie-break | `fail_closed/descriptor_identity_mismatch` |
| MC-11 | failure rank | checker derives rank from fixed order and emits one winning mapping | caller rank=7 for `fail_closed`, competing terminal statuses | `fail_closed/failure_mapping_invalid` |
| MC-12 | prohibited registry | fixed token-list hash, input bundle, algorithm, matches and receipt are bound | empty refs, changed token ordering, unbound receipt, unscanned claim | `review_pending/no_publish` or `fail_closed` |
| MC-13 | safety lanes | solver/provider/mesh/physical counters are exactly zero | any nonzero lane | `fail_closed/scope_violation` |
| MC-14 | CLI/process receipt | required CLI args, raw files, PID, UTC `Z`, exit and hashes are recorded | missing raw, local time, wrong length/hash, unbound command | `fail_closed/schema_malformed` |
| MC-15 | owner boundary | only frozen future owner files may be created, evidence append-only | existing-path collision, source/test/review write, search/Julia start | `scope_violation`; contract stays `not_implemented` |
| MC-16 | claim ceiling | output status only describes machine closure | checker pass presented as fixture, M5-C, search, execution, or formal credit | reject claim; `no_publish` |
