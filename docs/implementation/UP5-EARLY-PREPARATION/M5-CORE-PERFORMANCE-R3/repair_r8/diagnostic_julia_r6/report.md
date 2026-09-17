# M5 core performance R3 diagnostic Julia run R8

This is a single diagnostic-only, screen-only run. It is not an acceptance
receipt and carries no performance or R01--R10 credit. The factorial
performance issue remains unresolved; postrun review and the next performance
slice remain pending.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T13:27:26.4288986Z`
- Ended: `2026-09-17T13:27:36.7809211Z`
- PID: `37112`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `55 passed, 1 failed, 0 errored, 56 total`

The only failure is at test line 259: the test expected
`FusionConceptAI._ceg_attempt_bytes(artifact, receipt_cache)` to throw
`ArgumentError`, but no exception was thrown. The complete Julia output is in
`stdout.txt` and `stderr.txt`. No source, test, or manifest was changed, the
command was not repeated, and no two-process run was performed. The
before/after process checks found no Julia or DESC process. The existing
`phase5_remote_session.py` process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
