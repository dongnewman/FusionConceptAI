# UP5-01 condition/replay R6 generator-sort repair

Date: 2026-09-18 (Asia/Shanghai).

## Result and boundary

R6 is a minimal source canonical-ordering repair plus static/test coverage
hardening. The state remains `contract_only / screen_only / accepted=false /
no_publish=true`; no UP5, runtime, numerical, physical, provider, solver,
search, or R01--R10 credit is claimed. Julia and DESC were not run and no
commit was created.

## Repair and ordering coverage

The R5 focused run reached the source and failed with `MethodError` because
`sort(String(x) for x in ...)` passed a `Base.Generator` directly to `sort`.
All three evaluation reference collections now use typed materialized vectors
before sorting:

```julia
Tuple(sort!(String[String(x) for x in missing_refs]))
Tuple(sort!(String[String(x) for x in unmet_refs]))
Tuple(sort!(String[String(x) for x in contradiction_refs]))
```

The complete source was audited for `sort`/`sort!` generator calls; no direct
`sort(generator)` remains. Tests now pass multiple out-of-order values through
missing, unmet, and contradiction states and assert canonical ordering. An
overlap between missing and contradiction references is still rejected with
`ArgumentError`.

## Static QA

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
{"accepted": false, "claim_ceiling": "screen_only", "desc_executed": false, "formal_credit": "none", "julia_executed": false, "negative_vector_count": 18, "record_kind": "UP5-01-condition-replay-static-qa", "status": "pass"}
```

Static QA rejects direct `sort/sort!` generators, requires the three typed
vector forms, requires the multi-item canonical-order assertions and overlap
negative case, and retains the 18-vector real-loop coverage checks. Julia/DESC
were not invoked. Raw stdout/stderr are archived in this directory.

## R5 failure receipt and current hashes

The R5 failure remains preserved at
`runs/agent_local_up5_condition_replay_contract_matrix_20260918_r5/`:

- exit code `1`, `3 passed / 1 errored`, `1.0s`, `hashes_unchanged=true`;
- `MethodError: no method matching sort(::Base.Generator...)` at source lines
  134--136;
- R5 pre/post input hashes were equal.

Current R6 hashes:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20480 | `b45ee915ebfe643c9116a631deb90a8c0693304b515dea552b89bdcd31c5ef89` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 11119 | `0ec87c707823b737c40daa2c9c40f74b90d602222b287d3c9ea9beabff9c6fd3` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 6801 | `4e46e1ecb3933710766a095476a8823f96f41db95e7d0e87cbc056bbe32d7ef5` |

Observed HEAD: `a6b9de90143dd46cbfc81243735e1d2ba7eb6bf6`.

## Next gate

R6 is ready for independent static review, followed by one serialized focused
Julia run. Runtime and formal acceptance remain pending.
