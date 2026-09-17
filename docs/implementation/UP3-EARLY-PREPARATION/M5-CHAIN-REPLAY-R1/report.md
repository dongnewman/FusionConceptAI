# M5 A → B → C chain replay R1

Execution was strictly serial and gated. A auto-composition passed its
Python oracle (PID 44136, exit 0) and Julia tests (PID 69428, exit 0). B
inverse-feedback then passed Python (PID 70584, exit 0) and Julia (PID 13244,
exit 0). C Python oracle passed (PID 108936, exit 0), but C Julia exceeded
the 20-minute preparation/test-only ceiling and was human-interrupted at PID
60876; it is `deferred_performance_blocked`, not a pass.

The original C default-budget interruption (PID 94656) and all R1/R2 wrapper
collection failures remain preserved. The C positive test now uses bounded
`(8,16,4,8)` budget and removes the test-local canonical hash fallback; the
ambient A hash regression asserts product hash `722e...` and valid B inverse.

The old acceptance is invalidated by the new A→B→C identity chain. Current
claim ceiling is only `manufactured_conditional_egraph/screen_only`; no
UP5/B00/B04/R/L4, formal, semantic, physical, provider, evidence, search, or
parent-goal credit is granted.
