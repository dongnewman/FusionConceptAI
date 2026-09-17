# M5 core performance R3 diagnostic Julia run R9

This is a single diagnostic-only, screen-only run. It is not an acceptance
receipt and carries no performance or R01--R10 credit. The factorial
performance issue remains unresolved; postrun review is pending.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T13:35:15.2442324Z`
- Ended: `2026-09-17T13:35:26.1291271Z`
- PID: `14304`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `58 passed, 1 failed, 0 errored, 59 total`

The only failure is at test line 270: the test required
`!(equivalent_external_rule === artifact_rule)`, but the external rule and
artifact rule were identical by object identity. The complete Julia output is
in `stdout.txt` and `stderr.txt`. No source, test, or manifest was changed,
the command was not repeated, and no two-process run was performed. The
before/after process checks found no Julia or DESC process. The existing
`phase5_remote_session.py` process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
