# local_profile_r2_diagnostic_preflight

## Scope and boundary

This is a dedicated, receipt-free R2 preflight package for the forged
no-legacy T1 diagnostic.  It is anchored to HEAD
`941f96bfe15e96661d62e5e9d8181bc90c171c22` and does not invoke the full
`vnext_t1_package_binding_adapter_v1_tests.jl` real-package test.  The new
entry point loads only the production declaration/transport/recheck/package
definitions needed for one typed fixture, plus
`vnext_t1_projection_diagnostic_v1.jl`; it does not include any focused test
file with top-level output.

## Probe contract

The probe builds a source-backed typed T0 input, forges a `legacy://` no-legacy
receipt, and checks the closed boundary.  It must assert and emit only:

`status`, `admission_errors`, `stage`, `exception_type`, and `message_digest`.

The expected values are admission `status=fail_closed` with
`errors=(t1_projection_invalid,)`, diagnostic `status=internal_failure`,
`stage=no_legacy`, `exception_type=ArgumentError`, and a digest computed from
the fixed `(status, stage, exception_type)` tuple.  Full exception text is not
part of the fixed tuple and is not recorded or printed.  The probe's only
`println` is the fixed, parseable five-
field `R2_DIAGNOSTIC` line; static QA rejects extra dependency stdout.

The historical R1 receipt remains weaker: its observed admission error is
`not_observed`, with stage, exception type, and message digest also
`not_observed`.  Static QA and the independent oracle assert that historical
boundary while keeping the new diagnostic expectation separate.

## Runner contract

`runner.ps1` is single-start, no-retry, `JULIA_NUM_THREADS=1`, with a default
120-second bounded wait (up to 300 seconds is allowed for a supervised retry
decision).  It refuses an existing `runtime.lock` or `run_*` receipt, performs
a zero-process Julia/DESC preflight, checks all protected byte/SHA-256 hashes,
and records two consecutive postflight zero observations plus postflight
protected hashes.  The protected set is 27 unique assets, including the
production declaration/factory definitions directly loaded by the probe;
the former full transport test is not a probe dependency.  Timeout
termination is restricted to the runner-owned process tree.  The runner has
its own canonical self-hash contract.

## Static-only status

No Julia process was started, no full real-package test was run, no provider,
registry, runtime, DESC, mesh, solver, physical, or authority evidence was
created, and no commit was made by this preparation.  Static QA completed
with 27/27 checks and the independent Python oracle completed with 17/17
checks.
Any future runtime receipt remains contract-only and cannot be promoted to
acceptance or physical evidence.
