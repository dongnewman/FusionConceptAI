# AD-32 independent postrun R2 status sync

This metadata-only sync corrects the stale `focused_test` receipt fields in
the parent implementation manifest. The synchronized record is
`test_r9.receipt.json`: PID `51564`, UTC
`2026-09-15T03:32:47.1548572Z` through
`2026-09-15T03:33:03.4679458Z`, exit `0`, summary `167/167`, stdout `138`
bytes with SHA256
`6c21dbb806fc5c200ea2f11d31c2b342e8fb6ac0c40d1336c50513bcb354455f`, stderr
`0` bytes with SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, dirty
rows `310` before and after, and zero Julia/DESC processes before and after.

The final source and test hashes remain the R9 values. Round history remains
R1–R9; R8 is explicitly recorded as `149 pass / 18 fail` from the snapshot
consumption helper bug, and R9 remains the final passing run. Independent
review remains pending with the prior disposition `changes_requested` until a
different Luna recheck. Machine acceptance and all actual, engineering,
physical, provider, mesh, search, B00, B04, and R01–R10 credits remain false.

No Julia/DESC command was run for this sync. Only JSON/hash/diff checks were
performed.
