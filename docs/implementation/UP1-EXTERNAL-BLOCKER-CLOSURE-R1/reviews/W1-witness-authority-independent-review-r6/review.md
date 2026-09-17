# W1 witness/authority independent review — round 6

## Decision

`rework_required` for the final cleanup hash ledger; path exact-set closure and
W1-R2-P2-001 remain closed.

The witness tree has 51 actual files and 51 cleanup-owned files. The manifest
and cleanup current maps each contain 49 keys after excluding only
`manifest.json` and `cleanup_inventory.json`, and their key sets are equal.
The manifest correctly records the current `validation_receipt.json` hash
`cf2254b4959406f94908fd0c9fce99270ce9c416023093b1b6a103263f901980`; old
`570577...` is no longer in the manifest current map.

Cleanup still records the old `570577...` for `validation_receipt.json`, so the
49/49 current hash check has one mismatch. This is the only remaining closure
defect found. PID34140 and both foreign-layer/foreign-axis decisions have no
regression.

Claim ceiling remains `preparation_only`; no formal or parent-goal credit.

## Checks

- Actual=owned exact set: 51=51.
- Manifest/cleanup non-self key sets: 49=49, exact equality.
- JSON unique parse: pass.
- Manifest current hash: `cf2254...`; old `570577...` absent from manifest.
- Cleanup hash comparison: 48/49 pass; stale `validation_receipt.json` row is
  the sole mismatch.
- PID34140 raw confirms `ERR_FOREIGN_LAYER_CANDIDATE`,
  `ERR_FOREIGN_AXIS_CANDIDATE`, and `EXPECTED_FIELDS_READ=0`.

## Required recovery

Refresh the one cleanup row to the current validation-receipt hash, then rerun
the exact 49/49 map comparison and preserve both retained R4 raw files. No
deletion, witness edit, AD creation, or gate opening is authorized by this
review.
