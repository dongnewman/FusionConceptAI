# N06 test-only focused R9

Verdict: `runtime_failed`. One serial frozen runner invocation was performed.

Input hashes matched. Main PID `33600`; UTC `2026-09-14T05:51:13.909664Z`–`2026-09-14T05:53:15.179636Z`; real exit `1`. Observed child PIDs `[13708, 54652, 55796, 72544, 73372, 77544, 79896, 80456, 80604]`. stdout/stderr bytes and SHA-256 are in `receipt.json`. Postflight Julia/DESC sweep: `empty`. Protected before/after SHA+mtime match: `True`.

N06 execution evidence is in `test_groups.json`; the actual-A group passed `28/28`, typed occurrence identity passed `3/3`, and all five source-derived mutations passed in `31/31`. The run then failed at test line 263 because the fixture contains `14` static negative controls while the test asserts `12`; the shared owner/E0 group ended `37 passed, 1 failed, 38 total`. R1-R8 raw evidence remains immutable. No repair or retry was performed, and no physical/engineering/B04/R credit is granted.
