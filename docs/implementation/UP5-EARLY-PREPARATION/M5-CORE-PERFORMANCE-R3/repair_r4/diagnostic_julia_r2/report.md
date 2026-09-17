# M5 core performance R3 diagnostic Julia run R4

This is a single diagnostic-only, screen-only run after the R4 static review
GO. It is not an acceptance receipt and carries no performance or R01--R10
credit. The factorial performance issue remains unresolved.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T12:45:39.8373504Z`
- Ended: `2026-09-17T12:45:45.3954348Z`
- PID: `26872`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: unavailable; Julia failed before the Test summary

Failure: `syntax: ":owner_token" is not a valid function argument name` at
`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:137`. The complete error
is in `stderr.txt`; `stdout.txt` is empty. No source, test, or manifest was
changed, the command was not repeated, and no two-process run was performed.
The before/after process checks found no Julia or DESC process. The existing
`phase5_remote_session.py` process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
