# UP5-01 ConditionalEGraphConditionEnvelope R8 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R8 static contract handoff; NO-GO for formal acceptance and for
runtime claims until the serialized Julia gate.** R8 repairs the R7 identity
ordering defect: `_validate_replay_identity` checks evaluation hash,
`condition_status`, token owner/scope/generation/content, source/target, and
rule/registry/budget before `replay_merge` can return any non-`:conditions_met`
semantic status. The six new bound-unmet foreign-identity vectors each call
the real `replay_merge` seam and assert exact `:fail_closed`, zero merge, no
receipt, and recomputed result hash. Exact-identity missing/unmet paths retain
their semantic `:equality_unknown`/`:condition_unmet` statuses.

The R7 NO-GO finding is explicitly retained as lineage and is closed only at
the static-contract level. The ceiling remains `contract_only / screen_only`,
with `accepted=false` and `no_publish=true`. No UP5, numerical, physical,
provider, solver, search, or R01-R10 credit is issued.

## Scope and R7 lineage

Reviewed read-only:

- `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json`
- `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py`
- R8 `agent_local_r8/report.md`, `manifest.json`, and raw QA output
- R7 independent NO-GO archive under
  `docs/implementation/UP5-EARLY-PREPARATION/M5-UP5-01-CONDITION-REPLAY-R1/independent_r7/`

R7 found that a bound-unmet evaluation could return before identity checks.
R8's helper is called before the semantic branch and maps `ArgumentError` to
the fail-closed zero-merge result. No product or test file was changed by this
review; only this independent archive is added. Julia/DESC were not run. No
commit was created.

## Static findings

### Replay validation order and bound semantics

`replay_merge` first calls `_validate_replay_identity`. That helper checks:

1. `step.evaluation_hash == evaluation.evaluation_hash`;
2. `step.condition_status === evaluation.status`;
3. token owner, scope, generation, and content hash;
4. source/target hashes;
5. rule/registry/budget hashes.

Only after the helper succeeds does the function return
`:equality_unknown`/`:condition_unmet` for a non-`:conditions_met` evaluation.
Any `ArgumentError` produces `MergeReplayResultV1(false, :fail_closed, nothing)`
and the result validator recomputes the canonical result hash.

### Six bound-unmet foreign cases

The fixture and frozen test tuple contain exactly 24 vectors, including:

- `foreign_token_bound_unmet`
- `foreign_source_bound_unmet`
- `foreign_target_bound_unmet`
- `foreign_rule_bound_unmet`
- `foreign_registry_bound_unmet`
- `foreign_budget_bound_unmet`

Each branch obtains a real `:condition_unmet` evaluation from
`_unmet_evaluation`, constructs a bound step through
`RewriteTraceStepV1(base, evaluation)`, corrupts one identity class, calls
`replay_merge(bound_step, evaluation; ...)`, and invokes `_assert_rejected`.
That helper asserts `!merged`, `receipt === nothing`, exact `:fail_closed`,
`validate_replay_result(result)`, and the recomputed `result_hash`. The cases
are therefore not marker-only vectors.

### Valid semantic paths and remaining coverage

The missing-condition branch still calls `_replay(step, evaluation)` and
expects `:equality_unknown`; the seven typed-axis mismatch branches similarly
expect `:condition_unmet`. Their bound steps have matching token and all step
identities, so the helper permits the semantic early return. The explicit
`evaluation_hash_mismatch` branch retains `bind_evaluation=false`, so the
identity helper rejects the stale pairing as `:fail_closed`. The fixture labels
remain `contract_only`, `screen_only`, `accepted=false`, and `no_publish=true`.

## Evidence and next gate

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
status=pass, negative_vector_count=24
Julia/DESC: not run
```

The next gate is one serialized fresh-process focused Julia run that records
actual statuses, result hashes, zero-merge/no-receipt behavior, and replay
determinism. Static QA does not substitute for that runtime evidence.

## Current SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 21485 | `6d1076cd2d755932d6ecf0e016e188cc8b4f5471af10f1f6029f36379953586a` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 15664 | `1468a3b0f1304540e0acc748e3308c777cef960ffb7b8ceec61da70946ccd242` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1558 | `245fb79a7f08fb6b509bf32186a56defd1a4f9cfd8be93f47bbbc56a83890a48` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 8345 | `c4d5e29dfd60cd0ac7a160f65abb231e3974bcacabf75f11b2fafbd61fec1678` |
