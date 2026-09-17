# Independent Luna review R2 — UP5-01 condition/replay envelope

Date: 2026-09-17 (Asia/Shanghai). Read-only static review only. No Julia,
DESC, provider, solver, mesh, or physical execution was performed, and no
product/test file was modified.

## Verdict

**NO-GO for acceptance.** R2 materially repairs the former marker-only test:
the source test now includes an actual loop over all 17 vectors and calls the
condition evaluator, replay path, cache functions, replay receipt/result
validators, and saturation constructor. Nevertheless, the result status
invariant is still open, and no runtime evidence exists. The ceiling remains
`screen_only/contract_only`, `accepted=false`, `no_publish=true`.

## Checks that pass statically

- The module remains isolated and additive; the shared entry, manufactured
  adapter, registry, task manifest, and legacy/M5 files are not modified by
  this slice.
- Seven axes are typed and compared through `ConditionSignatureV1`.
- `conditions_met`, `condition_unmet`, `equality_unknown`, and `fail_closed`
  are classified; status/reference consistency guards are present.
- `replay_merge` checks source/target/rule/registry/budget, token owner/scope/
  generation/content, and `step.evaluation_hash` against the supplied
  evaluation. Receipt and result validators recompute hashes. Cache generation
  participates in stale detection, and cold/hot bytes/hashes are compared.
- The test source has a real `for vector in ...negative_vectors` loop, calls
  all requested seams, and `_assert_rejected` checks zero merge, no receipt,
  status, validator success, and recomputed result hash for replay negatives.
- Static QA exits `0` with 17 vectors; Julia/DESC were not run.

## Blocking findings

1. **P1 — replay-result status invariant is too permissive.**
   `MergeReplayResultV1` and `validate_replay_result` use
   `(merged == (status === :replayed) && receipt !== nothing) ||
   (!merged && receipt === nothing)`. The second disjunct accepts
   `merged=false, status=:replayed, receipt=nothing`, because it does not
   require `status !== :replayed`. This contradicts the claimed
   status/receipt identity and allows an invalid result to pass its canonical
   hash validator.

2. **P2 — no actual evaluation-hash mismatch negative.**
   The implementation checks `step.evaluation_hash == evaluation.evaluation_hash`
   and the receipt validator repeats it, but the `:tampered_trace` test passes
   a newly constructed `:conditions_met` evaluation with the same empty refs,
   hence the same hash. The test does not exercise a distinct evaluation hash
   against the same step. Add a controlled forged/tampered receipt or a seam
   that can construct the mismatch without bypassing the public validator.

3. **P2 — saturation exception is outside the status/hash/zero-merge helper.**
   The `incomplete_not_inequality` vector correctly asserts a constructor
   exception, but unlike the other 16 replay vectors it does not produce a
   typed status/hash/zero-merge result. This is acceptable only if explicitly
   documented as a constructor-level guard and separately covered in the
   acceptance matrix.

4. **P2 — runtime evidence is still absent.** The test source is now
   substantive, but static QA and source inspection do not prove the Julia
   loop completed, the 17 branches returned the claimed status, or the
   canonical hashes remained deterministic in a fresh process.

## Required repair

Tighten the result invariant to require `status === :replayed` iff
`merged=true` and a receipt exists, add an executable evaluation-hash mismatch
negative and explicit saturation-guard evidence, then run the focused Julia
suite and archive exit code, per-vector status/hash/zero-merge results, cold/hot
identity, and fresh-process determinism. Obtain another independent review
before UP5 or R01–R10 credit.

## Hashes reviewed

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `7b0fb72f7652b2d82f39bf670abae14c3b06ddad63782ef7cd595b86109b4b91` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `93f931249a6858a999279b053979f59823008dc41f7540f92427fbed112980cb` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `8dbcb99acde4c1b7c19c9633dd30f295ffb82946a2415e3538d64f6599b0d9a7` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `5ede8ffd37c01c05876ac98fd5feb951a33fe6b23019b278ab9b1668be116451` |
