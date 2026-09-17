# M5 core performance R3 diagnostic Julia run R6

This is a single diagnostic-only, screen-only run after the R6 static PASS.
It is not an acceptance receipt and carries no performance or R01--R10
credit. The factorial performance issue remains unresolved.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T12:59:48.1567857Z`
- Ended: `2026-09-17T12:59:58.6301042Z`
- PID: `36620`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `40 passed, 1 failed, 0 errored, 41 total`

The only failure is at test line 209: `artifact !== nothing` evaluated as
`nothing !== nothing`. The complete Julia output is in `stdout.txt` and
`stderr.txt`. No source, test, or manifest was changed, the command was not
repeated, and no two-process run was performed. The before/after process checks
found no Julia or DESC process. The existing `phase5_remote_session.py`
process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
