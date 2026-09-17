# M5 core performance R3 diagnostic Julia run R7

This is a single diagnostic-only, screen-only run. It is not an acceptance
receipt and carries no performance or R01--R10 credit. The factorial
performance issue remains unresolved; an independent postrun review is still
required.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T13:12:52.7394795Z`
- Ended: `2026-09-17T13:13:11.0639758Z`
- PID: `38648`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `50 passed, 0 failed, 1 errored, 51 total`

Failure: `invoke: argument type error` in
`_ceg_query_result_top_bytes` at
`src/Canonical/ConditionalEGraphCanonical.jl:223`, reached from
`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:244`. The complete Julia
output is in `stdout.txt` and `stderr.txt`. No source, test, or manifest was
changed, the command was not repeated, and no two-process run was performed.
The before/after process checks found no Julia or DESC process. The existing
`phase5_remote_session.py` process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
