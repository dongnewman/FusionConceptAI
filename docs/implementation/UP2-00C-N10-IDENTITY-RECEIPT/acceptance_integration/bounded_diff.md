# N10 bounded integration diff and provenance

Before freeze: `before_freeze.json` records the exact bytes/hash/mtime of the owned acceptance, manifest, implementation README, core README, and 16 work orders, plus the immutable independent r1 artifacts and the aborted `acceptance_integration/x.txt`. The x artifact hash and removal reason are in `aborted_artifact_removal.json`.

After state: `after_hashes_final.json` records current hashes for the two N10 state files, three index/work-order files, and all integration artifacts. `protected_source_test_review_check.json` confirms the implementation source/fixture/test/runner and independent r1 files remained unchanged. `control_scan.json` reports no U+0000-U+001F characters other than permitted CR/LF/TAB.

Owned semantic changes are limited to the N10 accepted_limited state, the independent r1/Sol limited integration record, and matching index pointers. The UP2 total remains review_pending; task_manifest, source, tests, runs, queue, and old independent evidence are outside this edit.
