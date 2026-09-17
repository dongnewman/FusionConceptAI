# Independent Luna review R1 — UP5-01 condition/replay envelope

Date: 2026-09-17 (Asia/Shanghai). Read-only static review only. No Julia,
DESC, provider, solver, mesh, or physical execution was performed, and no
product/test file was modified.

## Verdict

**NO-GO for acceptance.** The additive slice remains bounded to
`screen_only/contract_only`, `accepted=false`, and `no_publish=true`. It must
not transfer UP5, solver, search, physical, or R01–R10 credit.

## Boundary and structural checks

The new module is isolated and is not included by the shared RuntimeV4 entry.
The scoped working-tree query shows only the new module, test, fixture, static
QA, and evidence directory. Existing `ManufacturedConditionalEGraphV1.jl`,
registries, task manifest, and legacy/M5 files were not modified by this slice.

The source structurally represents all seven typed condition axes: unit, rank,
domain, boundary, time, effect, and conservation. It has deterministic
required/available catalog ordering, condition hash construction, missing vs
mismatched vs contradictory classification, merge trace fields for source,
target, rule, registry, budget, and evaluation, replay token checks, and the
incomplete-saturation guard that rejects `not_equivalent` when incomplete.
Cold/hot cache byte/hash helpers and foreign/stale token error paths are also
present structurally.

## Blocking findings

1. **P1 — the 17 negative vectors are not executable tests.**
   `conditional_egraph_condition_envelope_v1_tests.jl` contains a
   `negative_vectors` tuple and comments describing seven cases, but only
   three metadata `@test` assertions exist. There are no calls to
   `evaluate_conditions`, `replay_merge`, `cache_put!`, `cache_get`, or
   `make_saturation_receipt`. The static QA only checks marker strings and the
   fixture count. Therefore no runtime evidence exists for any requested
   negative, replay, stale/foreign, cold/hot, or incomplete case.

2. **P1 — replay does not bind the evaluation receipt.**
   `RewriteTraceStepV1` stores `evaluation_hash`, but `replay_merge` validates
   token and source/target/rule/registry/budget identities without checking
   `step.evaluation_hash == evaluation.evaluation_hash`. A forged or stale
   `ConditionEvaluationV1` with `status=:conditions_met` can therefore be
   replayed if its token/other identities match.

3. **P1 — evaluation status is not internally closed.**
   `ConditionEvaluationV1` accepts arbitrary missing/unmet/contradiction refs
   for every allowed status. It does not enforce that `conditions_met` has no
   refs, `condition_unmet` has an unmet ref, `equality_unknown` has a missing
   ref, or `fail_closed` has a contradiction. This permits a contradictory
   status/receipt combination to reach `RewriteTraceStepV1`.

4. **P2 — token generation is dead in stale validation.**
   `ReceiptTokenV1` carries `generation`, but `validate_token` compares only
   owner, scope, and content hash. `cache_get` likewise never checks the
   cache generation. A stale generation can remain acceptable after cache
   generation changes.

5. **P2 — receipt constructors are not independently sealed/validated.**
   `MergeReplayReceiptV1` and `MergeReplayResultV1` have no constructor-level
   identity validation. The only trustworthy path is the unexecuted
   `replay_merge` builder, so this cannot be accepted without runtime negative
   coverage and an explicit receipt validator or sealed constructor policy.

## Evidence ceiling and required repair

The existing static QA replay returned exit `0`, `negative_vector_count=17`,
`julia_executed=false`, `desc_executed=false`, and `formal_credit=none`. This
is a static schema/marker result, not test execution. The status ceiling is
`contract_only`, with `changes_requested/review_pending`.

Before re-review: implement actual 17 negative runtime vectors plus positive
met/replay and cold/hot checks; bind and validate evaluation hashes; close the
status/ref consistency matrix; include token generation in stale validation;
and archive a real Julia exit code with deterministic replay receipts. Keep
incomplete saturation from implying inequality and preserve all no-publish
boundaries.

## Hashes reviewed

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `4c79d375c0be7fcc48db54909de0dc56c9ca40be83d460fb7822fb4a9fe1164e` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `87ceb645f371ed92f5ab8023c16d5b3c27caf079979f85399d45db4e2cabaf45` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `8dbcb99acde4c1b7c19c9633dd30f295ffb82946a2415e3538d64f6599b0d9a7` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `ed6e3c090d7c7c95ebfe63236e87347f5c00710008c86195956f299e6cd2b064` |
