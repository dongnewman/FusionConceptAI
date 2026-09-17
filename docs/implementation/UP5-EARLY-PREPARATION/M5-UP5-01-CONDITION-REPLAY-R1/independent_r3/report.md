# Independent Luna review R3 — UP5-01 condition/replay envelope

Date: 2026-09-17 (Asia/Shanghai). Read-only static review. No Julia, DESC,
provider, solver, mesh, physical, search, or runtime execution was performed;
this review added no product or test changes.

## Verdict

**GO for the R3 static contract review; NO-GO for formal/stage acceptance.**
The former R2 blockers are repaired in the inspected source and executable test
source. The status ceiling remains `screen_only/contract_only`, with
`accepted=false`, `formal_acceptance=false`, and no UP5 or R01–R10 credit until
the parent serializes the focused Julia run.

## Checks

- The slice remains additive and isolated. No shared runtime entry,
  manufactured adapter, registry, task manifest, or legacy/M5 file was changed
  by this review.
- `MergeReplayResultV1` and `validate_replay_result` now encode the exact
  invariant: `status == :replayed` iff `merged=true` and a receipt exists;
  every other status is zero-merge with no receipt. Canonical result hashes are
  recomputed before validation succeeds.
- The negative-vector loop contains 18 vectors (the seven typed axes plus the
  R2 vectors, a distinct `:evaluation_hash_mismatch`, and
  `:incomplete_not_inequality`). The mismatch constructs a different
  `ConditionEvaluationV1` and asserts a different evaluation hash before
  invoking `replay_merge` against the original step.
- The incomplete vector constructs `MergeReplayResultV1(false, :incomplete,
  nothing)`, runs the same zero-merge/status/hash validator helper, and then
  separately checks the saturation guard rejects `complete=false` with
  `equivalence=:not_equivalent`; incomplete state cannot be promoted to an
  inequality.
- R2 seam coverage remains present: real evaluator/replay/cache/saturation
  calls, receipt and result validators, stale-generation rejection, token and
  source/target/rule/registry/budget identity checks, and cold/hot bytes and
  hash comparisons. The static QA reports 18 vectors and real seam calls.

## Evidence and boundary

Both static QA commands exited `0`. This is source/static evidence only; no
runtime result, fresh-process determinism, numerical/physical proof, provider
call, UP5 gate, or R01–R10 evidence is claimed.

## Required next gate

Run the focused Julia suite in the parent serialized lane, archive the actual
exit code and per-vector status/hash/zero-merge receipt, and independently
verify fresh-process determinism and the cold/hot identity before any formal
UP5 or R01–R10 credit.

## Reviewed hashes

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `139d97781f2be8ec25184ed3472e96d39fea622db38d568f19f13fec48686945` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `a650f192a9ec172ff807118f85e7c32bf3a7fa1f97468203939760b207ebce70` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `cf713d9548bda1bfb99f7f5f68014a6a3d13d4c5563008f504307a9d14cafcc6` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `d0a019c85cecca2b1b12d2c5eab1a6dc688bad6f2b168fbe4dd2d272a9c7e332` |
