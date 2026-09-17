# UP1 external-blocker closure R2 — G2 independent review R1

## Scope and identity

- Group: `R2-G2`; component: isolated Python G2 mapping validator.
- Reviewer task: `/root/up1r2_g2_review`; model/effort: `gpt-5.6-luna` / `high`.
- Source revision: `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- Frozen protocol: `UP1-EXTERNAL-BLOCKER-CLOSURE-R2-REVIEW-V1`.
- Every output and fixture from this review is labelled `TEST_ONLY=true`,
  `non_evidence=true`.

## Commands and fresh-process proof

1. `python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r1/matrix_driver.py`
   (fresh process A, PID `53032`).
2. The identical command again (fresh process B, PID `61824`). Semantic JSON
   rows and hashes are byte-equal after excluding timestamps/PIDs.
3. Fresh wrapped CLI child processes for TEST_ONLY and typed_absent fixtures;
   child PIDs, parent PIDs, UTC intervals, numeric exit codes and child raw
   stream hashes are in `raw/cli_wrapper_*.receipt.raw`.
4. `python -B .../verification.py` independently checked source/fixture and
   component-manifest hashes, raw stream byte/hash pairs, replay equality,
   labels, frozen revision, PID/UTC/exit fields, and heavy-lane absence.

No Julia, DESC, solver, provider, mesh, external operation, or heavy lane was
run.

## Coverage and outcomes

The independent matrix contains 34 cases: 32 classified pass and 2 findings.
There were 27 deterministic rejections plus TEST_ONLY, typed-absence,
production-structural, and array-permutation positive observations. Coverage
included duplicate JSON keys, unknown fields, repeated/missing axes,
bidirectional edge asymmetry, foreign candidate/source (both inconsistent and
self-consistent), issuer/key/policy/name/EKU/keyUsage, revocation/freshness,
nonce/sequence/idempotency/replay, TEST_ONLY escalation, and production with
unverifiable signature bytes.

The two findings are fully described in `findings.md`: self-consistent foreign
ownership is accepted, and canonical/source digest output/recomputation is
missing. Therefore the group verdict is `rework`, not `pass_limited`.

## Evidence and claim ceiling

`verification.json` reports 50/50 integrity checks passed. Existing component
manifest and run receipt hashes were independently recomputed and matched,
including focused-test and CLI raw streams. The existing component receipt is
historical component evidence; this review does not promote it. External G2
authority remains unavailable/typed_absent and all formal and physical gates
remain locked.

## Cleanup

Only review-owned files under this directory were retained. The disposable
unreferenced `raw/replay_a.stdout.raw` and `raw/replay_a.stderr.raw` from an
initial harness probe were removed and recorded in `cleanup_inventory.json`.
