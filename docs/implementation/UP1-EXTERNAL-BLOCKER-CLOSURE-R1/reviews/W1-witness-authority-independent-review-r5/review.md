# W1 witness/authority independent review — round 5

## Decision

`rework_required` for hash-ledger closure; the R4 exact-set disposition is
correct and W1-R2-P2-001 remains closed.

Repair R4 correctly retained both previously unowned raw files because the
stdout bytes/hash differed from the authoritative run02 stream. Actual files
and cleanup ownership now both equal 51. PID34140 still proves
`ERR_FOREIGN_LAYER_CANDIDATE` and `ERR_FOREIGN_AXIS_CANDIDATE`, with
`EXPECTED_FIELDS_READ=0`.

The remaining defect is cross-file hash staleness: R4 changed
`validation_receipt.json`, but the implementer manifest and cleanup row still
record the old `570577...` hash. The current receipt hash is
`cf2254b4959406f94908fd0c9fce99270ce9c416023093b1b6a103263f901980`.
Therefore exact path closure passes, but manifest/cleanup/hash closure does
not.

Claim ceiling remains `preparation_only`; no formal gate or parent credit.

## Checks

- Actual recursive witness set: 51 files.
- Cleanup `final_exact_owned_set`: 51 rows; exact equality passes.
- Newly owned files are `repair_r3/raw/static_validator.stdout.raw` and
  `repair_r3/raw/static_validator.stderr.raw`; stdout differs from run02,
  stderr is empty/equal, and both are retained by the explicit paired-set
  rule. No deletion occurred.
- Cleanup hashes match all rows except the stale validation-receipt row.
- Manifest product hash map matches all checked products except
  `validation_receipt.json`.
- All JSON parsed uniquely.
- PID34140 raw/UTC/exit/hash and both foreign-binding decisions remain valid.

## Required recovery

Refresh the manifest and cleanup hash for the current validation receipt,
then independently recompute all 51 exact paths, hashes, self-exclusion rules,
and JSON uniqueness. Preserve both distinct raw files and PID34140 evidence;
do not delete by glob or create an AD.
