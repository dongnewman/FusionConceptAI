# UP5-01 condition/replay R7 evaluation-binding repair

Date: 2026-09-18 (Asia/Shanghai).

## Result and boundary

R7 repairs the test/product seam exposed by the R6 focused receipt. The state
remains `contract_only / screen_only / accepted=false / no_publish=true`.
Julia/DESC were not run, no recomputation was performed, and no commit was
created; therefore no runtime, numerical, physical, UP5, or R01--R10 credit is
claimed.

## R6 failure and repair

R6 reached `91/107` with 16 failures in the eight missing/mismatched semantic
vectors because the test helper reused a `RewriteTraceStepV1` whose
`evaluation_hash` belonged to the `conditions_met` evaluation. `replay_merge`
correctly treated that stale join as `:fail_closed` before it could return the
intended `:equality_unknown` or `:condition_unmet` status.

R7 adds a dedicated `RewriteTraceStepV1(step, evaluation)` clone constructor.
It preserves step index, source/target/rule/registry/budget hashes, and the
receipt token while rebinding `evaluation_hash` and `condition_status` to the
supplied evaluation. The test helper now uses this exact-binding clone by
default before calling `replay_merge`. The independent
`evaluation_hash_mismatch` vector passes `bind_evaluation=false`, explicitly
joining the original step with a different evaluation and retaining the
expected `:fail_closed` result.

The test asserts the clone's evaluation hash and all preserved identity/token
fields. The eight missing/mismatched branches continue to call the real
`evaluate_conditions` and `replay_merge` seams, so their intended statuses are
now wired for the next runtime check; this static lane does not claim that
runtime result.

## Static QA

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
{"accepted": false, "claim_ceiling": "screen_only", "desc_executed": false, "formal_credit": "none", "julia_executed": false, "negative_vector_count": 18, "record_kind": "UP5-01-condition-replay-static-qa", "status": "pass"}
```

Static QA checks the clone seam, exact identity preservation markers, default
binding, explicit `bind_evaluation=false` mismatch path, and the existing 18
vector/real-seam coverage. No Julia parser or runtime was invoked.

## R6 receipt and current hashes

The R6 receipt remains preserved at
`runs/agent_local_up5_condition_replay_contract_matrix_20260918_r6/`:

- exit code `1`, summary `91 passed / 16 failed / 0 errored / 0 broken`;
- elapsed `6.9s`, `hashes_unchanged=true`;
- eight missing/mismatched semantic vectors failed because the step/evaluation
  hashes were not rebound; the explicit evaluation-hash mismatch negative
  remained fail-closed.

Current R7 hashes:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20815 | `729c112438032b4345d2cca00fb7f46530d54c1cb7b49aab44b7b8cba68e9a64` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 11880 | `efcc5e4240e12b1d363e7c829a8b5ca8db8d8397c5a4abd6a31291ec52560372` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 7283 | `40018b241bfa5f783cbc1866678138f01e796aa1566d8b7abda72dc0a73252a7` |

Observed HEAD: `a6b9de90143dd46cbfc81243735e1d2ba7eb6bf6`.

## Next gate

R7 is ready for independent static review and then one serialized focused
Julia run. Runtime status/hash/zero-merge outcomes remain unmeasured.
