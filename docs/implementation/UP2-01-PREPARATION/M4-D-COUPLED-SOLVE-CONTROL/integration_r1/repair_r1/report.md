# M4-D coupled-solve control repair integration R1

Status: `integration_complete_review_pending`  
Owner: integration-validation Luna (`gpt-5.6-luna`, high)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Repair decision and scope

The M4-D source and test were repaired by their separate owners before this
integration pass. The repair closes a validation bypass in which a foreign
nested right-hand M4-C control could avoid the top-level binding checks, and
adds typed-failure coverage for invalid nested C input, control grid counts,
interface grid counts, pair ordering, missing pairs, duplicate pairs, and
non-identity correspondence. This record only integrates and replays those
current artifacts. It does not modify them.

The bounded result remains
`manufactured_coupled_solve_control` / `screen_only`. The exact manufactured
block is `[2 -1; -1 2] * [a,b] = [1,0]`, with determinant `3`, solution
`(2/3,1/3)`, zero block residual, and eight identity-mapped cells on the
2x2x2 grid. No candidate, provider, mesh, physics, engineering, production,
iterative, PDE, UP2, B00, B04, R01-R10, L4, or parent claim is made.

## Frozen repaired inputs

| input | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` | `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57` |
| `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl` | `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c` |
| `src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl` | `20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa` |
| `src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl` | `ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785` |
| `test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | `1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686` |
| `test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3` |

The previous integration record is retained unchanged as the historical
`110/110` run with source hash `a26d8d…` and test hash `92cd40…`. It is not
silently relabeled as evidence for the repaired source.

## Strict serial replay

Python was run first twice. Julia was then run serially. The first Julia repair
run and the third launcher attempt have complete PID/UTC/exit receipts and are
the two authoritative Julia runs below. A second Julia attempt completed and
produced a `158/158` raw stream, but the outer observation window lost its PID
and exit metadata; its raw is retained as non-authoritative capture history.
This additional attempt is disclosed rather than used to fabricate a receipt.

| sequence | command | PID | UTC interval | exit | combined SHA-256 | semantic result |
|---:|---|---:|---|---:|---|---|
| 1 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 100124 | `09:40:36.3703950Z–09:40:36.5083517Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | canonical exact payload |
| 2 | `python test/RuntimeV4/M4Isolated/oracles/coupled_solve_oracle_v1.py` | 58752 | `09:40:55.2830566Z–09:40:55.3729588Z` | 0 | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` | canonical exact payload |
| 3 | `julia --startup-file=no --history-file=no --color=no test/RuntimeV4/M4Isolated/manufactured_coupled_solve_control_v1_tests.jl` | 33500 | `09:41:14.3629787Z–09:41:39.8972878Z` | 0 | `82f8dad7421cef2695c9c70e8ed5c574ab01b572c418044e35acb2813fb8b043` | `158/158` |
| 4 | same Julia command (capture-timeout history) | unavailable | raw completed at `09:42:27Z`; PID/exit not observed | unknown | `9d47819a8fcc8c76eb6f426f6a87437104999573924076159c60ec9a52cd3007` | `158/158`, non-authoritative |
| 5 | same Julia command (metadata-safe authoritative replay) | 88136 | `09:44:02.5848603Z–09:44:25.5910459Z` | 0 | `4a1bc927c3b6d3c854d8741c8dbce47d9fcd1b7d4367a25b27448df067fbb9a5` | `158/158` |

Both authoritative Julia receipts report `158/158`; all four authoritative
Python/Julia runs have empty stderr. The Python canonical payloads are
byte-identical and independently state determinant `3`, solution `(2/3,1/3)`,
zero residual, and eight identity cells. Julia summaries are semantically
equal; only the duration line differs (`24.4s` versus `22.0s`).

## Repair-specific controls

The current Julia test exercises the former bypass and the new malformed-input
controls as typed `ManufacturedCoupledSolveControlResultV1` failures, without
uncaught exceptions:

- foreign `right.source_owner` and foreign `right.conservation_owner` nested
  C controls;
- invalid nested right C equation/source binding;
- top-level `grid_counts` mismatch and left/right interface grid-count mismatch;
- swapped, missing, duplicate, non-identity, and solution/interface pair-order
  correspondence failures.

The repair therefore has observed test coverage for the stated probe boundary;
it does not promote that coverage to a formal solver or parent gate.

## Historical failures and exact preservation

The prior integration's `110/110` raw, the initial M4-D harness-macro failure,
the `106 pass / 4 fail / 1 error` expectation failure, and the superseded
`111/111` run remain under the parent integration and upstream
`test_execution_r1/archive/raw/` directories. The earlier PowerShell `$args`
capture-wrapper failure also remains untouched. The repair pass adds the
capture-timeout Julia raw and its explicit metadata status under
`archive/raw/`.

## Isolation and protected shared tree

The repaired D source retains only its guarded isolated C include. The test
includes isolated A/B/C/D sources. The shared module and registries
(`src/FusionConceptAI.jl`, `src/RuntimeV4/FusionRuntimeV4.jl`,
`src/IR/OperatorRegistry.jl`, and
`src/RuntimeV4/TrustedProviderRegistryV4.jl`), `Project.toml`, and
`Manifest.toml` have no diff. The pre-existing dirty
`src/RuntimeV4/SpatialRuntimeV4.jl` change remains present and was not touched.
No broad cleanup, staging, revert, or deletion was performed.

## Handoff and gates

This repair record is `integration_complete_review_pending`, requiring a
distinct independent Luna review and separate Sol limited-acceptance decision.
The claim ceiling remains `manufactured_coupled_solve_control` /
`screen_only`; no UP2/B00/B04/R01-R10/L4/parent credit is granted. The 39-node
DAG and all formal gates remain open.
