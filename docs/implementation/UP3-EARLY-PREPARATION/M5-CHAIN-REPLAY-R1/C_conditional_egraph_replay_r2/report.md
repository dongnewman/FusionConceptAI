# C conditional-egraph replay R2

Python oracle PID 108936 passed (exit 0) at
`2026-09-16T22:42:12.8316925+08:00`–`22:42:13.8724490+08:00`. Julia PID
60876 started `2026-09-16T22:42:25+08:00`, remained responsive but exceeded
the 20-minute preparation/test-only ceiling; it was terminated at
`2026-09-16T23:03:04.3776958+08:00` with `Stop-Process -Id 60876 -Force`.
Exit is unknown and raw stdout/stderr are empty; this is not a pass.

The positive C tests use bounded budget `(max_programs=8,
max_rewrite_attempts=16,max_rounds=4,max_trace_steps=8)` and retain at least
one trace/query/replay assertion. The prior default-budget interruption is
preserved; the remaining issue is deferred performance, not an unbounded
loop. Claim ceiling is screen-only manufactured equality; no formal credit.
