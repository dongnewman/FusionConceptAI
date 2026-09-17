# M5 core performance R3 diagnostic Julia run R5

This is a single diagnostic-only, screen-only run after the R5 static PASS.
It is not an acceptance receipt and carries no performance or R01--R10
credit. The factorial performance issue remains unresolved.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T12:53:37.6385179Z`
- Ended: `2026-09-17T12:53:45.4797412Z`
- PID: `36080`
- Exit code: `1`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `18 passed, 0 failed, 1 errored, 19 total`

Failure: `ArgumentError: invalid conditional proposal cache entry` from
`_ceg_cached_proposal_identity` at
`src/IR/ConditionalEGraphSaturation.jl:246`, reached by
`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:93`. The complete Julia
output is in `stdout.txt` and `stderr.txt`. No source, test, or manifest was
changed, the command was not repeated, and no two-process run was performed.
The before/after process checks found no Julia or DESC process. The existing
`phase5_remote_session.py` process was retained untouched.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
