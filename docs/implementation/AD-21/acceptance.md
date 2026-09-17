# AD-21 UP2-00 typed mutation and B04 receipt boundary

Status: `accepted_limited`  
Accepted: `true`  
Scope: current AD-21 architecture consistency and provenance only

AD-21 records Sol's boundary for the UP2-00 partial slice. Typed-wrapper mutations are `schema_validation_only`; only an A factory projection generated from an actual `CandidateStatePackageV5` is source-backed. The low-level `UP2PrecompilerInputV1(...)` constructor is synthetic/unverified and is not B04-admissible. Partial software acceptance requires an independent Luna review and actual A per-mutation source-derived error code, path, mutated value/hash, and invocation counters. `expected_error` may be asserted but cannot drive classification or routing.

UP2-00 total acceptance still requires all 50 N01-N10 mutations bound to real source fields and classifications. Missing authoritative port, unit, time, account, source, or receipt joins remain independent gaps with `terminal_deferred`. UP1-04B must freeze candidate-bound mutation envelopes before first execution, binding the baseline package hash, exact source ref/hash/path/type, original and mutated typed values, mutation/schema/canonical hashes, and source/invariant-derived classification. Constructor rejection does not remove the receipt requirement for the attempted value. No copied labels, synthetic low-level inputs, reused evidence, archive pollution, or physical/B00/B04/R01-R10 credit is authorized.

The bounded before/after snapshots and validation evidence are in this directory. `validate_plan.py` exited `0` with checks pass; `git diff --check` exited `0` for the current worktree. The no-index bounded diff exits `1` because the before and after files differ, as expected. AD-21 does not change the execution DAG, task status, README, task manifest, source/tests, or parent R01-R10 scope.

The different Luna independent review in
[`independent_review/report.md`](independent_review/report.md) passed with
`pass_limited`; its manifest is
[`independent_review/manifest.json`](independent_review/manifest.json). Sol
accepts only the current AD-21 architecture consistency and the preserved
before/after/bounded-diff provenance. This decision grants no UP2-00
implementation, provider, B00/B04, mesh, engineering, physical, or R01-R10
credit.
