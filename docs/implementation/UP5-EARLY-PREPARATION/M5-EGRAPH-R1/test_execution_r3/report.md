# M5 Conditional EGraph R3 test execution

R3 was prepared with explicit redirected raw paths and executed serially
Python → Julia. Python PID 98120 ran from `2026-09-16T21:52:55.6607804+08:00`
to `2026-09-16T21:52:56.7161441+08:00`, exit 0 (oracle PASS). Julia PID
75144 ran from `2026-09-16T21:53:16.0268370+08:00` to
`2026-09-16T21:54:48.1004551+08:00`, exit 1.

Julia reached test collection after the M5-C parse repair, but the test
fixture's `build_inverse(d, a)` returned invalid at test line 66, before the
conditional-e-graph assertions. This is classified as a test/fixture
integration failure, not an implementation repair. R1's original parse
failure and R2 wrapper collection failures remain preserved.

The permitted minimal diagnostic probe (PID 68264, exit 1) identified the
exact cause: `invalid_upstream` at `upstream`, with
`MethodError: no method matching canonical_hash(::NamedTuple)`. The e-graph
canonical include defines typed `canonical_hash` methods, while the existing
M5-A/M5-B standalone hash helper only checks whether the function name exists
and then calls it for a NamedTuple. The test now supplies a test-local
deterministic NamedTuple fallback; no implementation file was changed. The
probe's precise stdout/stderr and hashes are retained in `diagnostic_raw/`.

Claim ceiling remains `manufactured_conditional_egraph/screen_only`; no UP5,
B00/B04, R/L4, parent-goal, semantic, physical, provider, evidence, or search
credit is claimed. No implementation/shared files were modified in this role.
