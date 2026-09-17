# UP5-01 ConditionalEGraphConditionEnvelope R4 parse repair

Date: 2026-09-18 (Asia/Shanghai).

## Result and boundary

R4 is a minimal source parse repair plus static-only QA hardening. The
intended source and static-QA files were changed; no unrelated test, fixture,
shared entry, registry, manifest, or run receipt was changed. The contract
ceiling remains `contract_only / screen_only / accepted=false /
no_publish=true`; no UP5, numerical, physical, provider, solver, search, or
R01--R10 credit is claimed. Julia and DESC were not run and no commit was
created.

## Repair

The parent R3 lane failed before the test body with a Julia `ParseError` at
source line 423: `join(_encode(y) for y in x, ";")` used a generator followed
by an extra separator argument without parenthesizing the generator. The
source now uses the valid form:

```julia
join((_encode(y) for y in x), ";")
```

No other product semantics or test vectors were changed.

## Static QA

Command executed once, without Julia/DESC:

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
{"accepted": false, "claim_ceiling": "screen_only", "desc_executed": false, "formal_credit": "none", "julia_executed": false, "negative_vector_count": 18, "record_kind": "UP5-01-condition-replay-static-qa", "status": "pass"}
```

The QA now audits the complete source boundary with a conservative
string/comment-aware delimiter balance check, module-name and terminal-module
`end` checks, and a source-wide scan for unparenthesized generator expressions
with extra call arguments. It also asserts the corrected canonical tuple join
and retains the prior contract markers, JSON schema, 18 negative vectors, and
real seam calls. The raw result is in `static_qa.stdout.raw`; stderr is empty.

## R3 failure receipt and hashes

The failed parent receipt remains preserved at
`runs/agent_local_up5_condition_replay_contract_matrix_20260918_r3/`:

- exit code `1`, `hashes_unchanged=true`;
- ParseError at line 423: `join(_encode(y) for y in x, ";")`;
- pre/post hashes were equal for the R3 source/test/fixture/QA inputs.

Current R4 input hashes after the minimal repair are recorded in
`manifest.json`:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20453 | `b0edd4d90fd38f38c9f13d7035b99cbdfec150ac6c97baf78bd1f3aa5835372c` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 10272 | `a650f192a9ec172ff807118f85e7c32bf3a7fa1f97468203939760b207ebce70` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 5036 | `6a1c4368fb3101d07217df354341a48a45ceb90370f57e524a4385f58c1f16fd` |

The observed HEAD was `34100427f1114771dd86a875f45afd81a66e0208`.

## Next gate

R4 is ready for independent static review and then one serialized focused
Julia run. Runtime acceptance remains pending; no evidence is promoted by
this static repair.
