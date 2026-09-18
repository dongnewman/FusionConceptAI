# EngineeringFeedback R14 focused Julia rerun — agent_local_r15_runtime

## Run receipt

- Exactly one foreground invocation was executed from `D:\006-Programing\LMC\FusionConceptAI`:
  `julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP4/engineering_feedback_execution_v1_tests.jl`
- `JULIA_NUM_THREADS=1`.
- No `$PID` variable/name was used.
- Pre-run and post-run process listings for `julia`, `juliaup`, and `desc` were empty.
- Julia exit code: `0`.
- Test summary: `UP4-02B reduced engineering-feedback execution V1 R14 | Pass 77  Total 77`.
- `stderr.txt` is empty; no Julia/DESC/provider/hardware execution was started beyond this one Julia test process.

Raw evidence is in `stdout.txt`, `stderr.txt`, `exit.txt`, `process_pre.txt`, and `process_post.txt`.

## Exact four-file hash gate

The pre-run and post-run SHA-256 files are identical:

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/EngineeringFeedbackExecutionV1.jl` | `67486a8ffb7a1c4d289df14f6858eb2a8b9cdcd79e75a8b0a6711c1a1c9e74de` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_tests.jl` | `a3081fb8702f99449e2ab30f450efb9b87d5bfcb7ca364fcb152c123548db3ab` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_fixture.json` | `105fc870d0764f87c05332a5d46233b3c30e706a0213427a9d76bd04600f9369` |
| `test/RuntimeV4/UP4/engineering_feedback_execution_v1_oracle.py` | `13dfb36857f655f2e8720b147c54e48cc6db2ddea8429125bf8e93606d4bcb27` |

## Positive path actually tested

The product entry returned `status=:pass`, `accepted=false`, and
`claim_ceiling=:screen_only`; all positive assertions passed. The returned
iteration trace converges in 6 iterations. The frozen R14 residual replay
(maximum residual per iteration) is:

`[4.901960784313815e-1, 8.864998051194561e-3, 1.607833320717338e-4, 2.916101948358118e-6, 5.288893589749932e-8, 9.592326932761353e-10]`

Thus the final maximum residual is `9.592326932761353e-10`, below the
`1e-8` tolerance. The Julia test also checked that at least one force
residual is non-zero, the result hash validates, and the residual validator
replays the execution hash.

## 20 negative dispatches actually tested

All 20 fixture dispatches reached the product entry or typed residual
validator and passed their status/reason assertions:

| # | dispatch | observed status | observed typed reason |
|---:|---|---|---|
| 1 | `forged_identity` | `fail_closed` | `forged_identity` |
| 2 | `scenario_mismatch` | `fail_closed` | `scenario_mismatch` |
| 3 | `g3_mismatch` | `fail_closed` | `g3_mismatch` |
| 4 | `upstream_execution_hash_mismatch` | `fail_closed` | `upstream_execution_hash_mismatch` |
| 5 | `load_sample_hash_mismatch` | `fail_closed` | `load_sample_hash_mismatch` |
| 6 | `foreign_sample` | `fail_closed` | `load_sample_membership_mismatch` |
| 7 | `negative_stored_difference` | `fail_closed` | `independent_traction_difference_mismatch` |
| 8 | `missing_source` | `fail_closed` | `missing_source` |
| 9 | `missing_return` | `fail_closed` | `missing_return` |
| 10 | `missing_heat_sink` | `fail_closed` | `missing_heat_sink` |
| 11 | `missing_cooling` | `fail_closed` | `missing_cooling` |
| 12 | `unit_mismatch` | `fail_closed` | `unit_mismatch` |
| 13 | `owner_mismatch` | `fail_closed` | `owner_mismatch` |
| 14 | `direction_mismatch` | `fail_closed` | `direction_mismatch` |
| 15 | `capacity_exceeded` | `physical_fail` | `capacity_exceeded` |
| 16 | `yield_exceeded` | `physical_fail` | `yield_exceeded` |
| 17 | `nonfinite` | `numerical_fail` | `nonfinite` |
| 18 | `iteration_limit` | `numerical_fail` | `iteration_limit` |
| 19 | `forged_residual` | `fail_closed` | `forged_residual` |
| 20 | `double_counted_heat` | `fail_closed` | `double_counted_heat` |

The Julia test completed `length(observed) == 20`; no negative dispatch was
left at fixture-only status.

## Ledgers and declared boundary

The positive result returned exactly four ledgers, with kinds:

`energy`, `thermal`, `mechanical`, `material`.

The tested boundary remains:

- `accepted=false`
- `claim_ceiling=screen_only`
- `engineering_credit=none`
- `physical_credit=none`
- `r01_r10_credit=none`
- `component_load=false`
- `component_load_admitted=false`
- limitation includes `component_load=false`

This is a candidate-bound reduced-SI engineering-feedback screen only. It is
not a component-solid solve and does not promote the upstream plasma sample
to a component load. The fixture/source boundary also records that no
provider, solver, checker, DESC, hardware, or real component-load authority
was executed; those remain explicit residual gaps.

No source/test/fixture/oracle code was modified and no commit was created.
