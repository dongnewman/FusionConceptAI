# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC status sync R1

Date: 2026-09-15  
Decision source: Sol/root architecture decision after focused_r4 and the
different-Luna independent postrun R4.

This sync records `accepted_limited` for the local additive realization-only
software source/test slice and keeps the machine work-order node at
`planned` / `proposal` / `accepted=false` / `review_pending`. The accepted
local slice is documented in
[software_precursor_acceptance.md](../software_precursor_acceptance.md).

The sync is based on frozen-r4 only: PID `15468`, UTC
`2026-09-15T02:20:48.9783709Z`–`2026-09-15T02:20:59.4391247Z`, exit `0`, and
65/65 assertions. stdout is 130 bytes with SHA256
`3cb363b0e53ff26ca9a632a9838c394d95a97e65a6cad453c750a0dcc6803d3f`; stderr
is 0 bytes with SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. The
13-input frozen manifest, source/test hashes, dirty snapshots and empty
Julia/DESC process snapshots remain in
[focused_r4](../focused_r4/).

Concurrent planning-file drift observed after focused_r4 is retained as
postrun worktree state and is not attributed back to the R6 source/test slice.
No source, test, focused receipt, or independent review file is changed by
this documentation sync. AD-32 and the 36-task DAG are retained.

The following remain false: actual child authority, T0, T1, T2, provider,
mesh, engineering, physical, search, B00, B04, and R01–R10 credit. The
`physical_resolution` ceiling remains `unknown`.
