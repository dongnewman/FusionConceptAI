# M5 Conditional EGraph R1 test execution

Authoritative serial evidence: Python PID `56800`,
`2026-09-16T21:36:30.3101571+08:00` to `2026-09-16T21:36:30.4887711+08:00`;
Julia PID `104576`, `2026-09-16T21:36:41.7059884+08:00` to
`2026-09-16T21:36:45.5622681+08:00`.

The independent Python oracle completed with exit `0` and emitted
`CONDITIONAL-EGRAPH-ORACLE PASS`. It covers canonical JSON/hash stability,
the eight condition kinds (type/rank/domain/unit/port/owner/interface/conservation),
100% trace replay, unmet-condition zero merge, budget `terminal_deferred`,
mismatch rejection, and contradictory-condition fail-closed behavior.

The Julia test was then run serially (PID `104576`) and exited `1` before test
collection. The existing M5 adapter source has a parse error at lines 378--394:
`try without catch or finally` (the source is intentionally not modified by
this role). Therefore no Julia API result is claimed. Raw stdout/stderr and
the failure are retained below.

Scope remains `manufactured_conditional_egraph/screen_only`; this is not
UP5-01 and carries no formal credit. No G1/G2/G3 semantic/physical/provider/
evidence/search proof is claimed. Existing egraph files, shared registry,
M4/M5 sources, and task manifests were not changed by this test/oracle role.
