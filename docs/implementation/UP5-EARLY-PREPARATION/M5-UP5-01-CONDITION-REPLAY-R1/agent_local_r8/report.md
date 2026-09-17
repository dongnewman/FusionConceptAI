# UP5-01 condition/replay R8 identity-ordering repair

Date: 2026-09-18 (Asia/Shanghai).

## Result and boundary

R8 addresses the independent R7 security NO-GO. The state remains
`contract_only / screen_only / accepted=false / no_publish=true`; Julia/DESC
and all heavy execution were prohibited and not run. No runtime, numerical,
physical, UP5, or R01--R10 credit is claimed, and no commit was created.

## Identity ordering repair

R7 found that a bound unmet evaluation could return `:condition_unmet` before
checking a foreign token or source/target/rule/registry/budget identity. R8
adds `_validate_replay_identity`, which checks in this order:

1. exact `step.evaluation_hash == evaluation.evaluation_hash`;
2. exact `step.condition_status === evaluation.status`;
3. token owner/scope/generation/content identity;
4. source/target identity;
5. rule/registry/budget identity.

`replay_merge` invokes this helper before any non-`:conditions_met` semantic
return. Any `ArgumentError` is normalized to a zero-merge,
no-receipt `:fail_closed` result. Exact-identity bound missing/unmet cases can
therefore return `:equality_unknown`/`:condition_unmet`; self-consistent or
foreign identities cannot bypass the fail-closed gate.

## Bound-unmet negative controls

The frozen vector set is expanded from 18 to 24. Six real loop branches bind a
`:condition_unmet` evaluation and independently corrupt each identity class:

- foreign token;
- foreign source;
- foreign target;
- foreign rule;
- foreign registry;
- foreign budget.

Each calls the actual `replay_merge` seam and `_assert_rejected`, which checks
zero merge, no receipt, exact `:fail_closed`, validator success, and the
canonical result hash. The fixture explicitly lists these six vectors and the
required `bound_unmet_identity_fail_closed` evidence obligation.

## Static QA

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
{"accepted": false, "claim_ceiling": "screen_only", "desc_executed": false, "formal_credit": "none", "julia_executed": false, "negative_vector_count": 24, "record_kind": "UP5-01-condition-replay-static-qa", "status": "pass"}
```

Static QA verifies identity helper ordering, condition-status binding, all six
bound-unmet branches, fixture set equality, 24 frozen-vector coverage, and
the existing explicit evaluation-hash mismatch path. This is Python-only
static evidence; no Julia parser or runtime was invoked.

## R7 NO-GO lineage and current hashes

The preserved independent R7 review is
`docs/implementation/UP5-EARLY-PREPARATION/M5-UP5-01-CONDITION-REPLAY-R1/independent_r7/`.
Its blocker was identity validation bypass on bound-unmet evaluation. R6's
`91/107` runtime failure remains preserved under
`runs/agent_local_up5_condition_replay_contract_matrix_20260918_r6/`.

Current R8 hashes:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 21485 | `6d1076cd2d755932d6ecf0e016e188cc8b4f5471af10f1f6029f36379953586a` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 15664 | `1468a3b0f1304540e0acc748e3308c777cef960ffb7b8ceec61da70946ccd242` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1558 | `245fb79a7f08fb6b509bf32186a56defd1a4f9cfd8be93f47bbbc56a83890a48` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 8345 | `c4d5e29dfd60cd0ac7a160f65abb231e3974bcacabf75f11b2fafbd61fec1678` |

Observed HEAD: `a6b9de90143dd46cbfc81243735e1d2ba7eb6bf6`.

## Next gate

R8 is ready for independent static review. A focused serialized Julia run is
still required to establish actual statuses, identity rejection, result
hashes, and zero-merge/no-receipt behavior.
