# M5 core performance R3 diagnostic Julia run R10

This is a single diagnostic-only, screen-only focused run. It is not an
acceptance receipt and carries no performance or R01--R10 credit. Although the
focused tests passed, factorial performance remains unresolved; postrun review
and the next factorial optimization slice are still required.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T13:40:02.6890680Z`
- Ended: `2026-09-17T13:40:13.2324791Z`
- PID: `41280`
- Exit code: `0`
- HEAD: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- Test totals: `57 passed, 0 failed, 0 errored, 57 total`
- stderr: empty

The complete raw output is in `stdout.txt` and `stderr.txt`. No source, test,
or manifest was changed, the command was not repeated, and no two-process run
was performed. The before/after process checks found no Julia or DESC process.
The existing `phase5_remote_session.py` process was retained untouched. The
five input hashes were identical before and after the run.

`git diff --check` completed without whitespace errors; only Git's existing
LF-to-CRLF warnings were emitted.
