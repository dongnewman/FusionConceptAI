# RegionalMHDWeakResidualV4 focused report

Focused test: `julia --project=. test/runtime_v4_RegionalMHDWeakResidualV4_tests.jl`.
The strict typed slice passed 16 assertions with exit code 0 after rechecking
all derived ledgers and the residual hash. The example/runner binds only a
missing DESC capability and therefore emits `deferred`; manufactured controls
remain separate and screen-only. No physical closure, solver convergence,
DESC weak-integral execution, or promotion authority is claimed.
The execution envelope additionally seals a replay hash and rejects a
tampered `provider_executed` flag; replay is independent of stored ledgers.
The production binder consumes the explicit committed upstream artifact set;
weak test integration, boundary trace, and residual Jacobian remain explicit
capability gaps. The test-only constructors cannot create production-bound
artifacts.
