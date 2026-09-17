# W1 witness/authority independent review — round 7

## Decision

`pass_limited`. R6's single stale cleanup hash is closed. The witness tree has
actual=owned=51 files; manifest and cleanup current artifact maps each contain
49 keys after excluding only `manifest.json` and `cleanup_inventory.json`, and
all 49 hashes match the disk. `validation_receipt.json` is consistently
`cf2254b4959406f94908fd0f9cfe99270ce9c416023093b1b6a103263f901980`.

The old `570577...` value occurs only in explicitly historical R5 fields and
is not a current artifact hash. PID34140 still proves the independent foreign
layer/axis errors with zero `expected`-field reads. Prior W1-F001–F006 remain
closed without regression.

This is limited preparation evidence only: no external witness, trust root,
production authority, S3, or formal gate credit is granted.

## Checks

- Actual recursive set equals cleanup owned set: 51/51.
- Manifest/cleanup non-self key sets are equal: 49/49; self-exclusions are
  exactly manifest and cleanup.
- Manifest and cleanup disk hash comparisons: 49/49 pass.
- JSON unique parse: pass.
- R4 retained raw disposition remains intact and no deletion occurred.
- PID34140 exit 0, raw hashes match, and outputs include
  `ERR_FOREIGN_LAYER_CANDIDATE`, `ERR_FOREIGN_AXIS_CANDIDATE`, and
  `EXPECTED_FIELDS_READ=0`.

## Boundary

Claim ceiling is `preparation_only`; no UP1, T0/T1/T2, B00/B04, R01–R10, L4,
or parent-goal credit. No files outside this review directory were changed.
