# M5-SEARCH-R2 repair R2 acceptance matrix

This matrix is a static contract, not execution evidence. Every negative case
must be rejected by the future independent checker; it must not be repaired,
silently normalized or reclassified.

| ID | closure under test | positive condition | negative control | required result |
|---|---|---|---|---|
| A-01 | authority metadata | authoritative item has non-null path/content+canonical hashes, owner, source, freeze and receipt; all rehashed | any null field, changed bytes, stale version or foreign receipt | `identity_mismatch` / `fail_closed`; current package `typed_absent` |
| A-02 | typed absence | all current fixture/grammar/schema/source/interface records use typed_absent and all payload metadata is null | null interpreted as authority or inferred from source presence | `not_executed + terminal_deferred + no_publish` |
| A-03 | upstream provenance | review-00/review-02 paths, byte lengths and SHA-256 match manifest | changed report, receipt or source-hash snapshot | `provenance_changed` / `fail_closed` |
| A-04 | content receipt | canonical bytes recompute to `content_receipt_id`; strict fields contain no operational keys | PID/UTC/attempt/command/cwd/exit hidden in any nested content object; digest mismatch | `schema_malformed` or `replay_mismatch` |
| A-05 | operational envelope | envelope references exactly one content receipt and raw paths/hashes/bytes match | envelope payload differs, content hash differs, raw hash mismatch | `envelope_content_join_mismatch` / `fail_closed` |
| A-06 | fresh replay | two fresh content receipts have byte-identical canonical content/trace and exact authority/config joins | only envelopes exist; fresh content differs; cache-only comparison | `not_executed` or `replay_mismatch` |
| A-07 | accepted M5-C gate | accepted+authoritative gate has every non-empty identity, raw ref, threshold/config/caps join and gate digest | accepted with null owner/hash/raw, stale history or wrong config/source | `gate_missing_or_unbound` / `terminal_deferred` |
| A-08 | budget event arithmetic | increment has delta=1, `after=before+1`, `remaining=limit-after`, `after<=limit`; stop has delta=0 and repeats fold | overflow, underflow, skipped sequence, wrong stage/counter/scope or duplicate key | `budget_ledger_invalid` / `fail_closed` |
| A-09 | budget ledger fold | folded ordered events equal final counters and both fold hashes; config/seed/descriptor joins exact | final counters hand-entered, event list changed, cap mismatch or cross-seed event | `budget_fold_mismatch` / `fail_closed` |
| A-10 | descriptor identity | descriptor schema/hash/cell are identical in emitter config, receipt, ledger and stop; labels erased | changed descriptor, cell, axis order, label-dependent projection or replacement tie-break | `descriptor_identity_mismatch` / `fail_closed` |
| A-11 | failure precedence | checker derives one rank from fixed class order and retains secondary codes as metadata | caller-supplied arbitrary rank or two competing terminal statuses | highest precedence class only; deterministic code |
| A-12 | prohibited scan | token version/list/hash, scope boundary, excluded prose, input bundle/hash, algorithm/hash and scan receipt are all present | scan missing, wrong boundary/hash, or unscanned execution claim | `scan_incomplete` / `review_pending/no_publish` |
| A-13 | safety lanes | solver/provider/mesh/physical counters are exactly zero | any nonzero lane, even if other output is valid | immediate `fail_closed + no_publish` |
| A-14 | scope boundary | only this R2 repair directory changes; review00/01/02, source and tests unchanged | any write outside current root or any search/Julia start | `scope_violation`; package remains not executed |

The current package intentionally satisfies only the static shape and typed
absence rows. It contains no authoritative fixture, M5-C accepted gate,
execution receipt, replay pair, budget event stream or scan receipt.
