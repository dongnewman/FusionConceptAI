# UP2-CROSS-MESH-CONSERVATIVE-TRANSFER-V1 — local profile R1 preflight

## Boundary

This directory is a static/preflight package for current HEAD
`3b4b6f8864bdcb003f814635821225ad7f0ce0d7`. The hardened runner is prepared
for one exact focused Julia command, but this preflight did not invoke Julia or
DESC and did not create `runtime.lock` or a `run_*` receipt directory. No
source, test, fixture, dependency, dirty file, manifest, or repository index
was modified by the preflight.

The runtime command, if separately authorized, is exactly:

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2CrossMeshConservativeTransfer/cross_mesh_conservative_transfer_v1_tests.jl
```

The runner sets `JULIA_NUM_THREADS=1`, defaults to a 300-second bounded wait,
starts at most one child, has no retry/relaunch path, refuses an existing
`runtime.lock` or `run_*` directory using atomic `FileMode.CreateNew`, and on
timeout kills only the started process and descendants discovered by parent
process IDs. Runtime postflight requires two consecutive empty Julia/DESC
observations separated by 250 ms. It hashes six slice files, six dirty
protection files, and eight declared dependencies before and after execution;
any missing, changed, or non-comparable hash fails the receipt. The runner also
verifies its own SHA-256 against `manifest.json`.

## Preflight checks

| Check | Result |
|---|---|
| HEAD / manifest base commit | PASS; `3b4b6f8864bdcb003f814635821225ad7f0ce0d7` |
| PowerShell parser AST for `runner.ps1` | PASS; 0 parser errors |
| `manifest.json` JSON parse / round-trip | PASS |
| runner self-hash matches manifest | PASS; `fccafc17d66025c287d44013f139d1a8dc12adca4b7a0720b4679fa41e15c5f9` |
| protected file count | PASS; 20 entries (6 slice + 6 dirty protection + 8 dependency) |
| protected SHA-256 comparison | PASS; 0 mismatches |
| exact Julia command and `JULIA_NUM_THREADS=1` schema | PASS |
| timeout 300 / single start / no retry / CreateNew / unique run policy | PASS |
| own-tree timeout kill and two-zero postflight policy | PASS |
| Python static QA | PASS; `DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_STATIC_QA=PASS` |
| Python independent oracle | PASS; status `pass`, `julia_executed=false`, `product_code_imported=false` |
| `runner.ps1 -PreflightOnly` | PASS; exit code 0 and `UP2_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_PREFLIGHT=PASS` |
| Julia/DESC execution in this receipt | NOT PERFORMED |
| `runtime.lock` / `run_*` created in this directory | NO |

## Frozen slice files

| Relative path | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredCrossMeshConservativeTransferExecutionV1.jl` | `ed7e839b22156d46c1b19770e72cb4dfcafc37d2ba631458d17cc8b6865a6a9e` |
| `test/RuntimeV4/UP2CrossMeshConservativeTransfer/cross_mesh_conservative_transfer_v1_tests.jl` | `60df60b2e1f4c60283cae44613d0934b812109a25f4bd196b39d7db2ade50a58` |
| `test/RuntimeV4/UP2CrossMeshConservativeTransfer/fixture.json` | `dbe20ac4453a6d311e79089344fb1504ee9d74b39ddfcd5ee29ceb502dd3aafa` |
| `test/RuntimeV4/UP2CrossMeshConservativeTransfer/static_qa_declared_cross_mesh_v1.py` | `61ca0829a140693719e789b05eea51c8775649ebb34560ee215378ab1d6d65a3` |
| `test/RuntimeV4/UP2CrossMeshConservativeTransfer/independent_oracle_declared_cross_mesh_v1.py` | `b7fb93046f5ac35fcb0ba095f44124b8aacc64920e1111209e24efa69c1fed93` |
| `docs/implementation/UP2-CROSS-MESH-CONSERVATIVE-TRANSFER-V1/README.md` | `cf19c4bc2899c82ea76841c13e97d0c9c51de2fe1f302d72de155c45ef5fa54d` |

## Dirty protection files

These six files were already modified in the shared worktree and are guarded
read-only by the runner; their bytes are not part of this slice.

| Relative path | SHA-256 |
|---|---|
| `README.md` | `619ae3106769130235dd83fc493a935f63010ad73a1eae867a8120698a4890f1` |
| `runs/goal_recovery_20260913_012528_cst/task_queue.json` | `dbc57e7e44677cfd4b5d950a37d3d9063fde61fc7e4cec9b8cc44c9a9c3c84c0` |
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | `0041e9041b7376b3127d80454f8ffa1f455ae488b667f326719d3a0f5adf3773` |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_local_v1.py` | `f4541787d4f6d13245a76aa565f5db93b6b3b9190cea950725a0d5b374239716` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl` | `e8b2f8d10ba18752d540553495dd732412a7ede7fa2ea78926a0acfa7ff399b0` |
| `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | `7d9a4452a10f726d547a61490974add77b4f14dc3db4df6b975be1e0edc18cb5` |

## Required dependency receipts

| Relative path | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl` | `45e9fee04bebe7a62ee07456acee42834da7b8c9a8ca5bce95fdf2fe90013bef` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | `b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `8bf9e1b428c98d144aa46ad7d09403680a7d4b44f7bd687dd4a6f68611f1a756` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `a52ea1a60a207027c9f8029f0928af2b8bcc543f0e9ae37b88b87c9767c337b3` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7` |
| `src/FusionConceptAI.jl` | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` |
| `Project.toml` | `e923c66b2d2ea42e79bec67efd7ee1f100ae092897363b4d49ed58984058ff4e` |
| `Manifest.toml` | `133de98e7862bf4486ed39a6f72a14c6a17bf2faf5622f3561f9e907badab91d` |

## Captured static/oracle outputs

Static output:

```text
DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_STATIC_QA=PASS
```

Independent-oracle output (Python-only; no Julia/product import):

```json
{"diffusion":{"matrix":[[8.0,-4.0,0.0,0.0],[-4.0,8.0,-4.0,0.0],[0.0,-4.0,8.0,-4.0],[0.0,0.0,-4.0,8.0]],"rhs":[0.25,0.25,0.75,4.75],"solution":[0.39999999999999997,0.7374999999999999,1.0125,1.1]},"fixtures":{"holdout":{"P":[[1.0,0.6666666666666667,0.0,0.0],[0.0,0.33333333333333326,1.0,1.0]],"global_defect":0.0,"interface_defects":[0.0],"local_defects":[0.0,0.0,0.0,0.0],"overlap_lengths":[[0.2,0.2,0.0,0.0],[0.0,0.09999999999999998,0.30000000000000004,0.19999999999999996]],"source_coverage":1.0,"source_mass":0.20000000000000007,"target_coverage":1.0,"target_mass":0.20000000000000007,"transferred_state":[2.0,1.0000000000000002,-1.0,-1.0]},"main":{"P":[[1.0,1.0,0.0,0.0],[0.0,0.0,1.0,1.0]],"global_defect":0.0,"interface_defects":[0],"local_defects":[0.0,0.0,0.0,0.0],"overlap_lengths":[[0.25,0.25,0.0,0.0],[0.0,0.0,0.25,0.25]],"source_coverage":1.0,"source_mass":0.5,"target_coverage":1.0,"target_mass":0.5,"transferred_state":[0.25,0.25,0.75,0.75]}},"julia_executed":false,"product_code_imported":false,"schema":"DeclaredCrossMeshConservativeTransferIndependentOracleV1","status":"pass"}
```

Claim ceiling remains `screen_only`; Python static/oracle PASS is not Julia
execution, provider/mesh/solver evidence, physical validation, acceptance, or
UP2/R credit.
