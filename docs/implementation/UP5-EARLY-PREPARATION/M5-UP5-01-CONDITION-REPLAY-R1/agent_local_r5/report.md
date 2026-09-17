# UP5-01 condition/replay R5 test-macro repair

Date: 2026-09-18 (Asia/Shanghai).

## Result and boundary

R5 is a minimal test-only macro compatibility repair plus static coverage
hardening. The source contract remains unchanged from R4. The state remains
`contract_only / screen_only / accepted=false / no_publish=true`; no UP5,
runtime, numerical, physical, provider, solver, search, or R01--R10 credit is
claimed. Julia and DESC were not run and no commit was created.

## Repair

The R4 focused run parsed the source but stopped at the test macro:
`@testset String(vector)` is rejected by Julia 1.10 with `Unexpected argument
String(vector) to @testset`. The dynamic testset now uses a supported string
interpolation name while preserving the vector identity:

```julia
@testset "$(String(vector))" begin
```

The test also records every vector in `exercised_vectors` and asserts exact
set equality with the frozen vector tuple plus `length(exercised_vectors) ==
18`. Static QA rejects expression-style `@testset` names and checks every
fixture vector appears in the executable loop source.

## Static QA

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
{"accepted": false, "claim_ceiling": "screen_only", "desc_executed": false, "formal_credit": "none", "julia_executed": false, "negative_vector_count": 18, "record_kind": "UP5-01-condition-replay-static-qa", "status": "pass"}
```

The command was run once without Julia/DESC. Raw stdout/stderr are archived
under this directory.

## R4 failure receipt and hashes

The R4 failure remains preserved at
`runs/agent_local_up5_condition_replay_contract_matrix_20260918_r4/`:

- exit code `1`, `hashes_unchanged=true`, pre/post input hashes equal;
- source parse succeeded, then Julia 1.10 rejected
  `@testset String(vector)` at test line 105;
- raw stderr records `Unexpected argument String(vector) to @testset`.

Current R5 input hashes are:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20453 | `b0edd4d90fd38f38c9f13d7035b99cbdfec150ac6c97baf78bd1f3aa5835372c` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 10484 | `a0d337c8ec00a1b74bb2cdc7dd79c1353c4bcf2962c84370526c814273ee2fe7` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 5824 | `a842ce6f5628071ba341d0f851dc17de7ed6d9ec44295416f8ff25751b2eaf50` |

Observed HEAD: `34100427f1114771dd86a875f45afd81a66e0208`.

## Next gate

R5 is ready for a different agent's independent static review, followed by one
serialized focused Julia run. This package does not promote runtime or formal
evidence.
