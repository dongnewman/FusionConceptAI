# M4-D coupled-solve control integration verification R1

Status: `integration_complete_review_pending`  
Owner: integration-validation Luna (`gpt-5.6-luna`, high)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Decision and scope

This record verifies the existing isolated M4-D manufactured coupled-solve
control and its A/B/C upstream include chain. It is a bounded
`manufactured_coupled_solve_control` / `screen_only` result. It is not Sol
acceptance and grants no UP2-01, UP2, B00, B04, provider, mesh, engineering,
physical, R01-R10, L4, or parent credit. No production entrypoint, candidate,
provider, topology transfer, iterative solver, PDE solver, or engineering
execution was used.

The frozen exact algebra is the symmetric block
`[2 -1; -1 2] * [a,b] = [1,0]`, with determinant `3`, solution `(2/3, 1/3)`,
and zero residual. The identity interface has eight cells for the 2x2x2
manufactured grid. The independent Python oracle checks this with
`fractions.Fraction`; the Julia test checks the isolated A/B/C/D API and typed
negative controls.

## Frozen inputs and ownership

The integration owner did not modify any source, test, oracle, shared module,
registry, project file, or manifest. The exact inputs used by the four fresh
processes are:

| input | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` | `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57` |
| `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl` | `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c` |
| `src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl` | `20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa` |
| `src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl` | `a26d8dd66ed8d639fddac16590ee398c6a6ff32847f5020ec7c322bdb853b465` |
| `test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | `92cd4069d97c54a297dd00ab3a85a4fc9a0fc39458b744d57bb046e76dc75d88` |
| `test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3` |

The test hash is the current deduplicated test artifact. The upstream test
execution archive retains the earlier `111/111` run and its superseding
authoritative receipt; this integration uses the current file and therefore
reports the measured `110/110` result without hiding that historical change.

## Fresh serial replay

Four fresh child processes were run strictly in this order: Python oracle,
Python oracle, Julia D tests, Julia D tests. Each command receipt records the
exact command, absolute working directory, PID, UTC start/end, exit code, raw
stdout/stderr/combined paths, SHA-256 values, and input/output/artifact maps.

| sequence | command | PID | UTC interval | exit | combined SHA-256 | semantic result |
|---:|---|---:|---|---:|---|---|
| 1 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 39276 | `08:55:47.3920366Z–08:55:47.4835220Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | canonical exact payload |
| 2 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 7252 | `08:56:04.2854948Z–08:56:04.3611627Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | canonical exact payload |
| 3 | `julia --startup-file=no --history-file=no --color=no test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | 110988 | `08:56:25.9369653Z–08:56:43.4757038Z` | 0 | `0dd3699bd0e9673292b0a3a3d7e2b16b7d576f41d5fddc033efba1531ffaf444` | `110/110` |
| 4 | `julia --startup-file=no --history-file=no --color=no test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | 21024 | `08:57:03.3505908Z–08:57:22.1187591Z` | 0 | `f9a5d275db6b48b0b9387c9c654eae13bd696aeafe34dd6554e07ef7cdf8be73` | `110/110` |

The Python payload bytes are identical across both runs and state determinant
`3`, solution `(2/3,1/3)`, residual `(0,0)`, and eight identity-mapped cells.
The Julia summaries are semantically equal; only the human-readable duration
line differs (`16.5s` versus `17.8s`), so duration bytes are not treated as a
semantic mismatch. All four stderr streams are empty and all four exits are
zero.

## Historical failures and superseded results

The upstream M4-D test execution record remains authoritative for causal
history and is not rewritten. It retains the initial Julia harness-macro
failure (PID 86500, exit 1), the subsequent `106 pass / 4 fail / 1 error`
expectation run (PID 80804, exit 1), the intermediate `111/111` run (PID
63524), and the later authoritative upstream run after test-only
deduplication. These raw streams remain under
`../test_execution_r1/archive/raw/`.

This integration launcher also had an early capture-wrapper preflight error:
an initial PowerShell helper accidentally bound the automatic `$args` variable,
so two child launches received no script arguments and were stopped before
they could produce a valid result. It is non-counted, not an implementation
failure, and is documented with its observed PIDs and no fabricated child
output under `archive/failure_history/`. The corrected four-process replay
above is the only authoritative integration result.

## Isolation and protected shared tree

The D source uses only its guarded include of the isolated C source. Static
inspection confirms that D contains no `Gridap`, `solve_pde`, production
provider, candidate package, or default-registry call. The Julia test includes
only isolated A/B/C/D sources. The shared module
`src/FusionConceptAI.jl`, shared RuntimeV4 entry `src/RuntimeV4/FusionRuntimeV4.jl`,
registries `src/IR/OperatorRegistry.jl` and
`src/RuntimeV4/TrustedProviderRegistryV4.jl`, `Project.toml`, and
`Manifest.toml` have no diff. The pre-existing dirty
`src/RuntimeV4/SpatialRuntimeV4.jl` change remains present and was not touched;
its current hash is recorded in `manifest.json` as protected dirty state.

No broad cleanup, staging, revert, or deletion was performed. Raw streams are
live under `raw/` and copied byte-for-byte under `archive/raw/`.

## Handoff and gates

This work order is `integration_complete_review_pending`. A distinct Luna
review and a separate Sol limited-acceptance decision are required. The claim
ceiling remains `manufactured_coupled_solve_control` / `screen_only`; D does
not authorize a formal solver or any parent transition. The 39-node DAG,
R01-R10, B00/B04, and all formal gates remain open. Formal re-entry remains
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

## Current-state index after repair

The current repaired source/test state supersedes the prior integration inputs
for any future review, while the prior `110/110` record and all failure
history remain immutable evidence. The repair integration record is
`integration_r1/repair_r1/`. Its authoritative result is two Python oracle
runs followed by two complete Julia runs, both `158/158`; the additional raw
Julia capture-timeout attempt is explicitly non-authoritative and retained.
The top-level manifest and validation receipt point to this repair record.
