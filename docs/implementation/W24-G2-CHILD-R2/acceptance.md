# W24-G2-CHILD-R2 acceptance record

status: `review_pending`
accepted: `true` (limited to `sealed_execution_status_snapshot`)
comparability_status: `changes_requested`

Sol ruling: accept the independent limited single-run snapshot only. The paired
source-set comparison remains `changes_requested`; this ruling grants no
provider, engineering, physical, discovery, credible-candidate, or R01-R10
credit.

This record covers one fresh sibling replay of the existing W24 spatial G2 child. The run started from HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, used the frozen runner and pair-plan inputs, and did not use `--resume`. The original parent and child r1 directories were not modified.

The frozen command was:

```text
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2 --g2-child > runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2.stdout.log 2> runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2.stderr.log
```

The PowerShell wrapper observed process exit `0` and elapsed `4775.824 s` (about 79.6 minutes). Julia/DESC processes were absent after termination. The run recorded Julia `1.10.5`, Julia threads `24`, BLAS threads `12`, and 24 logical CPUs. The provider receipt recorded DESC execution and inspection exit `0`, with schema validation true.

Stage evidence is preserved with separate status dimensions:

| stage | program exit | solver exit | scientific status | elapsed seconds |
|---|---:|---:|---|---:|
| candidate | 0 | n/a | completed | 881.559 |
| upstream_DESC | 0 | 0 | observed | 824.798 |
| physics | 0 | 4 | fail | 446.498 |
| engineering | 0 | 0 | fail | 61.880 |
| verification | 0 | 0 | fail | 468.957 |
| whole | 0 | 0 | deferred | 81.742 |
| manifest | 0 | 0 | deferred | 0 |

The sealed manifest reports `outcome=deferred`, `physical_validation=unsupported`, `p5_ready=false`, and `credible_device_count=0`. The physics solver failure and downstream scientific failures remain scientific evidence; the runner exit does not promote them.

The fresh child identity is candidate hash `7214413813420fdc494ef96dfb1de7fe7de38db5a1489e574dfbe25890842a55`, context hash `9f408a27de5a6206c2d046d8d6e6a577f9b1641b11a3c308ef4730b2ff24f582`, and parent hash `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`. G1 remained `8f3049841f15797beb91fbac410a578221d12330b626a41d00a5b53ace20fd92`; G2 changed from parent `96089d1e1b3c6379b6dad366886e6ab9089b594c92ea9d804361020b27d690ec` to child `9c35419afb4ba5f4c9f78058079fa0ba012de1dd5a465a355629c9f03a548ae1`; G3 remained `d8d1e0a4157336a63d39c43566630d2f16b60b0c5b8318cca7d640b1f6d9b50a`. No checkpoint was reused.

The independent pair audit was run only after the complete r2 run:

```text
python scripts/audit_v4_spatial_g2_pair.py runs/goal_recovery_20260913_012528_cst/w24_spatial_parent_r1 runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2 runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/w24_spatial_g2_pair_audit.json
```

It returned exit `1` before writing the requested result because the immutable parent manifest has 433 source records while the fresh child has 449. The child includes 16 files created or present after the parent sealed its source set, and `scripts/verify_v4_spatial_manifest.py` also differs because the accepted checker fix changed its sealed SHA. The exact attempt and diff are recorded in `w24_spatial_g2_child_r2/w24_spatial_g2_pair_audit_attempt.json`. This is an audit comparability failure, not a physical pass and not a reason to alter or rerun the immutable parent.

The post-run single-run checker was also executed against r2 and returned exit `1`. Its identity, process semantics, four scenario list, authority ceiling, ledger completion, and initial HEAD checks all passed. It found five source byte mismatches in the current shared worktree (`src/GenomeV5/G2/FieldGeometryGenomeV5.jl`, `FieldSpacePlanV2.jl`, `RegionInterfaceContractV2.jl`, `SpatialGrammarProfileV2.jl`, and `test/GenomeV5/G2/up1_g2_contract_tests.jl`), whose bytes changed after the runner sealed its manifest while UP1 work was active. The full report is `w24_spatial_g2_child_r2/w24_spatial_manifest_audit.json`; this report is retained as evidence of the shared-worktree byte boundary and is not treated as a physical or execution failure.

This record requests independent Luna review. It carries no physical, engineering, discovery, platform, or R01–R10 credit and does not accept W24 or B00.

## Independent limited evidence snapshot

A different Luna completed a read-only limited snapshot and returned `pass` for the single-run software evidence boundary: terminal process/ledger state, result and manifest binding, candidate/context identity, four-case presence, claim ceiling, and the 14 SHA-256 artifact hashes recorded in `evidence_manifest.json`. This is a limited evidence result only; it grants no pair-comparability, provider, physical, engineering, discovery, credible-candidate, or R01–R10 credit.

The paired audit remains `changes_requested`. It ran only after r2 reached terminal state, returned exit `1` before producing the requested pair result, and preserved its attempt artifact. The immutable parent has 433 source records while the fresh child has 449, including 16 child-only records; the verifier hash also differs because the shared checker changed after the parent was sealed. The parent is protected and must not be rewritten or rerun for this archive decision.

The single-run manifest audit also returned exit `1` because five shared-worktree source/test bytes differed from the bytes sealed by the runner after the run completed. Identity, result binding, process semantics, four scenarios, authority ceiling, ledger recovery history, and initial HEAD checks passed. This is a byte-boundary audit finding and does not convert the scientific result into a pass.

The raw physics solver exit is `4` with `iteration_limit`; the archive classification is `scientific_fail`. Downstream engineering and verification retain their raw `fail` statuses and are classified as scientific failures; whole-device assessment remains `deferred`. The sealed result reports `physical_validation=unsupported`, `p5_ready=false`, and `credible_device_count=0`. Runner exit `0` is process evidence only and cannot promote the scientific or physical status.

The 14 artifact SHA-256 values and their exact run paths are recorded in the manifest. No run artifact, old sealed source set, parent, r1, queue, or core document was modified by this archive update. Status remains `review_pending`; a fresh independent review is requested.
