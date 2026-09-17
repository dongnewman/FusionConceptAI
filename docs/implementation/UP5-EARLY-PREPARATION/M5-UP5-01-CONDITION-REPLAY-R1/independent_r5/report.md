# UP5-01 ConditionalEGraphConditionEnvelope R5 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for the R5 static contract handoff; NO-GO for the next runtime or formal
UP5 gate.** The R5 test uses the Julia 1.10-compatible interpolated testset
name `@testset "$(String(vector))" begin`; the rejected expression-style form
`@testset String(vector)` is absent. The executable loop records each vector,
asserts exact set equality with the frozen vector tuple, and asserts cardinality
18. Static QA also checks each fixture vector is present in the test source,
so the declared coverage set has not silently shrunk.

The ceiling remains `contract_only / screen_only`, with `accepted=false` and
`no_publish=true`. No UP5, numerical, physical, provider, solver, search, or
R01-R10 credit is issued.

## Scope and R4 lineage

Reviewed read-only:

- `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json`
- `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py`
- R5 `agent_local_r5/report.md`, `manifest.json`, and raw QA output
- R4 receipt under
  `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r4/`

The preserved R4 receipt is a real Julia 1.10 macro failure after source parse:
`@testset String(vector)` at test line 105 produced `Unexpected argument
String(vector) to @testset`, exit `1`, with `hashes_unchanged=true` and equal
pre/post inputs. R4 raw stderr and both hash files remain present. R5 keeps the
source and fixture hashes unchanged from R4 while changing only the focused
test and static-QA bytes required for the macro/coverage repair. No product or
test file was changed by this review; only this independent archive is added.
Julia/DESC were not run. No commit was created.

## Static findings

### Julia 1.10 testset syntax

The only dynamic testset is:

```julia
@testset "$(String(vector))" begin
```

This supplies a string literal with interpolation, which is accepted by the
Julia 1.10 `Test.@testset` macro. The old expression-style spelling is absent,
and the static-QA expression scan reports no remaining expression-style
`@testset` names.

### Complete 18-vector coverage wiring

The frozen tuple declares 18 unique symbols. The loop
`for vector in UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors` pushes every
iteration into `exercised_vectors`, dispatches a real branch, and closes with:

```julia
@test exercised_vectors == Set(UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors)
@test length(exercised_vectors) == 18
```

The branches cover all seven typed-axis mismatches plus missing condition,
contradictory availability, stale/foreign token, tampered trace, foreign
registry/rule/source, budget mismatch, evaluation-hash mismatch, and
incomplete-not-inequality. Static QA checks the loop, the set/cardinality
assertions, interpolation, and presence of every fixture vector. It also
retains the real evaluator/replay/cache/receipt/result/saturation seam checks.

### R4 receipt and current hashes

R4 pre/post hashes are equal and match the R4 source/fixture/QA bytes. Current
R5 hashes match `agent_local_r5/manifest.json`; the source and fixture remain
identical to R4, while the test and QA hashes reflect the R5 repair.

## Evidence and next gate

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
status=pass, negative_vector_count=18
Julia/DESC: not run
```

The next gate is one serialized fresh-process focused Julia run. Static QA and
the R4 failure receipt do not constitute runtime execution, fresh-process
determinism, numerical/physical evidence, or formal UP5 acceptance.

## Current SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20453 | `b0edd4d90fd38f38c9f13d7035b99cbdfec150ac6c97baf78bd1f3aa5835372c` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 10484 | `a0d337c8ec00a1b74bb2cdc7dd79c1353c4bcf2962c84370526c814273ee2fe7` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 5824 | `a842ce6f5628071ba341d0f851dc17de7ed6d9ec44295416f8ff25751b2eaf50` |
