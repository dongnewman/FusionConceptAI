# UP5-01 ConditionalEGraphConditionEnvelope R7 — independent static review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**NO-GO.** R7's static QA and 18-vector/evaluation-hash coverage are present,
but the new `RewriteTraceStepV1(step, evaluation)` inner constructor accepts a
non-`:conditions_met` evaluation while copying all step identities and the
receipt token. `replay_merge` then checks only the evaluation hash and returns
the semantic status before validating token, source/target, rule, registry, or
budget identity. A foreign or tampered step can therefore be rebound to a
bound-unmet evaluation and avoid the identity checks. This is not a safe
fail-closed boundary even though the returned result is non-merged.

The ceiling remains `contract_only / screen_only`, with `accepted=false` and
`no_publish=true`. No UP5, numerical, physical, provider, solver, search, or
R01-R10 credit is issued. The R7 static QA pass cannot advance the next Julia
gate until the identity-ordering defect is repaired and independently
reviewed.

## Scope and R6 lineage

Reviewed read-only:

- `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl`
- `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json`
- `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py`
- R7 `agent_local_r7/report.md`, `manifest.json`, and raw QA output
- R6 receipt under
  `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r6/`

R6 was a preserved runtime failure (`91 passed / 16 failed / 0 errored / 0
broken`, exit `1`) from the pre-rebinding helper. R7's current hashes match
its manifest and the R6 receipt's pre/post hashes are equal. No product or
test file was changed by this review; only this independent archive is added.
Julia/DESC were not run. No commit was created.

## Blocking security finding

The original public constructor enforces:

```julia
evaluation.status === :conditions_met ||
    throw(ArgumentError("a merge trace requires conditions_met"))
```

R7 adds this unrestricted inner seam:

```julia
RewriteTraceStepV1(step::RewriteTraceStepV1,
                  evaluation::ConditionEvaluationV1)
```

It copies `step_index`, source/target/rule/registry/budget hashes, and
`step.token`, but replaces `evaluation_hash` and `condition_status` with the
supplied evaluation. The seam is used to make semantic unmet probes possible,
but it also permits a foreign/tampered identity to be rebound.

The `replay_merge` order is:

1. evaluation-hash comparison;
2. `evaluation.status !== :conditions_met` early return;
3. only then `validate_token` and source/target/rule/registry/budget checks.

### Required counterexample (static construction)

Let `met = evaluate_conditions(REQUIRED, _available())`, let `unmet` be the
real evaluation returned by `_available` with one altered typed axis, and let
`foreign_step` be a validly constructed step carrying
`ReceiptTokenV1("foreign-owner", 7, :rewrite_trace, TOKEN_CONTENT_HASH)`.
Then:

```julia
bound_foreign = RewriteTraceStepV1(foreign_step, unmet)
replay_merge(bound_foreign, unmet; owner="owner",
    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
    expected_generation=7)
```

The first comparison passes because the clone binds `unmet.evaluation_hash`;
the second branch returns `MergeReplayResultV1(false, :condition_unmet,
nothing)` before `validate_token`. No `foreign receipt token` error is
generated and owner/generation/content identity is never checked.

The same construction with a step whose `target_hash` (or source, rule,
registry, or budget hash) is foreign/tampered also returns `:condition_unmet`
before the corresponding identity check. The existing test covers foreign
token/source only with a `:conditions_met` evaluation and therefore does not
close this bound-unmet path.

## Minimal repair required

Keep a restricted rebind seam only if semantic probes require it, but make
`replay_merge` validate step identity and token against the supplied owner and
all expected source/target/rule/registry/budget hashes before returning any
non-`:conditions_met` semantic status. A small shared identity-validation
helper called before the status branch is sufficient; identity failures must
return `:fail_closed`. Add real negative vectors for foreign token and foreign
source (at minimum) with a bound unmet evaluation, asserting `:fail_closed`,
zero merge, no receipt, and recomputed result hash. Do not fix this by merely
accepting the expected semantic status or by moving identity checks after the
early return.

## Static evidence and boundary

```text
python -B test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py
exit=0
status=pass, negative_vector_count=18
Julia/DESC: not run
```

The QA pass confirms the clone markers, explicit `evaluation_hash_mismatch`
vector, and 18-vector coverage, but does not test the missing foreign-bound-
unmet identity cases. Formal/runtime acceptance is blocked by the finding.

## Current SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | 20815 | `729c112438032b4345d2cca00fb7f46530d54c1cb7b49aab44b7b8cba68e9a64` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | 11880 | `efcc5e4240e12b1d363e7c829a8b5ca8db8d8397c5a4abd6a31291ec52560372` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | 1096 | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | 7283 | `40018b241bfa5f783cbc1866678138f01e796aa1566d8b7abda72dc0a73252a7` |
