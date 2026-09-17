# UP4 inverse-realization R5 — independent postrun review

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for limited runtime-evidence handoff; NO-GO for UP4/formal acceptance.**
The preserved R5 runtime receipt is internally consistent: the recorded run
HEAD is `70cded1ca1b64496bbee44ac0025659f446364ea`, the focused suite reports
`58/58` in `3.9s`, exits `0`, has empty stderr, and its pre/post input lists
are byte-identical and match the current protected source/test/fixture bytes.
The R4 exit-1 failure receipt remains intact.

The run proves only the bounded contract test. The archive remains
`contract_only / accepted=false`; provider, solver, hardware, numerical,
physical, engineering, and R01-R10 credit remain zero. The current checkout
HEAD is `34100427f1114771dd86a875f45afd81a66e0208`, not the run's recorded
`70cded1...`; therefore this review makes no claim that the current Git HEAD
is the executed commit. The protected input bytes do reconcile exactly.

## Receipt and byte/hash reconciliation

Reviewed:

- `runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r5/`
- R5 `agent_local_r5/manifest.json` and `report.md`
- current protected source, focused test, and fixture
- preserved R4 receipt under
  `runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r4/`

The R5 receipt states `exit_code=0` and `hashes_unchanged=true`. Its raw output
is 138 bytes with SHA-256
`9eec3aa1181af9550be66c8d2fcc6839ef9db1d66675081560e9fd9486b6c17c` and
contains the exact `58/58` and `3.9s` summary. Raw stderr is 0 bytes with SHA-
256 `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`.
`input_hashes_pre.json` and `input_hashes_post.json` are both 518 bytes with
SHA-256 `27b4b5b2f307b01b6ba1cdd2560bd29e47bf3ba40915c2ffbc0d7c3d5564fff8`;
the listed per-input hashes equal the current bytes.

The preserved R4 receipt still has exit `1`, `hashes_unchanged=true`, and the
old duplicate-provider-domain constructor error, with raw stdout/stderr and
pre/post hash files present. It was not overwritten by R5.

## Contract boundary

The R5 runtime manifest records `status=contract_only`, `accepted=false`,
`julia_executed=false` for the agent-local static lane, and zero provider and
solver calls. The focused postrun itself exercised only the isolated contract
test; it did not construct hardware or execute a provider/solver/physical
backend. No UP4 authority or R01-R10 credit is promoted.

## Next gate

Retain `accepted=false` and the contract-only ceiling. Any broader UP4 claim
requires the separately scoped inverse implementation, provider/hardware
execution, engineering feedback, and independent physical evidence; this
58/58 software run cannot substitute for those gates.

## Current protected input SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | 21079 | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | 9689 | `898bf30229a7254f3aaa5388253c959a51247d13bb66dc4afca999168aa2a2b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | 1909 | `51c025279dc514fc035366696ffa29387ffac5b68f9edfab9ceab43daab39fcd` |
