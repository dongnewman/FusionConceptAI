# M5 core performance R3 diagnostic Julia run

This is a single diagnostic-only, screen-only run. It is not an acceptance
receipt and carries no performance or R01--R10 credit.

- Command: `julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
- Started: `2026-09-17T12:07:23.3736514Z`
- Ended: `2026-09-17T12:07:33.6329754Z`
- PID: `42288`
- Exit code: `1`
- HEAD: `8dbbb68b065c3ccd9a9f0f97a879aae8665eb2e9`
- Result: `10 passed, 0 failed, 1 errored, 11 total`

The error is an interface mismatch: the test reads
`_CEGDerivationCacheV1.program_bytes`, but that field does not exist in the
loaded implementation. The full Julia output is in `stdout.txt` and
`stderr.txt`. No product source, test, or manifest was changed, and the run
was not repeated. The post-run process check found no Julia or DESC process;
the pre-existing `phase5_remote_session.py` process was left untouched.

`git diff --check` completed without whitespace errors (only Git's existing
LF-to-CRLF warnings were emitted).
