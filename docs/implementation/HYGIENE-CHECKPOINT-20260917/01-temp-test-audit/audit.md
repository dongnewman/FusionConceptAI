# Temporary-test audit (read-only)

**Captured:** 2026-09-17T05:23:27.5830775Z
**Checkout:** `D:/006-Programing/LMC/FusionConceptAI`
**HEAD:** `b2c04d8339774635aaecd73651efcdb101e01b5d`
**Audit PID:** `63992` (`pwsh`)
**Git status rows at capture:** `385` (already-dirty worktree; no reset/checkout/delete performed)
**Julia:** no Julia process observed; Julia was not run.
**Audit exit:** `0`

This is an inventory and disposition record only. The only write made by this audit is this file under `01-temp-test-audit/`.

## Decision rule

1. `test/**/*.jl|py|json` is the formal test/fixture namespace. A filename containing `probe`, `adversarial`, `profile`, or `run` does not make it disposable when it lives in that namespace.
2. A path is a cleanup candidate only when it is outside the formal test namespace, has no current manifest/active-doc/source include, and is not the raw failure evidence needed to explain a failed run.
3. Historical dirty snapshots (for example AD-54 `baseline.json`, AD-55/AD-56 dirty inventories) are recorded as provenance, but are not treated as current authority receipts by themselves. The sibling `00-temp-file-inventory` contains the per-file hashes for the cache/root sweep.
4. Active reports/manifests and run source/hash manifests take precedence over a name such as `focused` or `runner`.

## Formal test tree: keep

Static inventory found **270** files under `test/` with extensions `.jl`, `.py`, or `.json`, excluding only generated `__pycache__` files. The whole set is classified `keep` by namespace. This includes the following name-looking temporary files:

| path | tracked at capture | reference result | disposition | SHA-256 |
|---|---:|---|---|---|
| `test/GenomeV5/UP2/up2_module_entry_failure_probe.jl` | no | no current ref outside implementation receipts; formal test location | keep | `59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591` |
| `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | no | no current ref outside implementation receipts; formal M4 test location | keep | `7ea02e3d4ea313cdce5723150674a4c8b1440cb846faa3189535397471e56522` |
| `test/up1_external_closure_r4/g2_mapping/adversarial_probe.py` | no | imported by `test/up1_external_closure_r4/g2_mapping/serial_run.py` | keep | `1d9811180c5c45490c890c0684643195fd894fbd32f98d452c60861c3cb66e27` |

The remaining 267 formal files are covered by the exact `test/**/*.jl|py|json` namespace rule; no Julia execution was needed to make this classification. Do not remove or rename this set during the cleanup pass.

## Root temporary-looking files

The following are untracked root-level outputs/scratch files. Their exact bytes and SHA-256 are recorded in `../00-temp-file-inventory/inventory.tsv`. The successful/empty receipts have no current active report/source reference; the failed/convergence-failed receipts are retained as failure evidence.

| path(s) | content/result | current ref search | delete candidate | risk / action |
|---|---|---|---:|---|
| `0`, `1` | one-line pointers to historical `exit.txt` files | no current active ref | yes | disposable path-pointer scratch; historical docs remain immutable |
| `candidate_validation_focused.exit`, `candidate_validation_focused.log` | `31/31`, exit `0` | no current active ref | yes | duplicate root receipt; formal report/run evidence is elsewhere |
| `focused_ecf_vuq.log` | focused pass receipt, exit `0` | no current active ref | yes | duplicate root receipt |
| `q4_final_focused.exit`, `q4_final_focused.log` | focused pass receipt, exit `0` | no current active ref | yes | duplicate root receipt |
| `q4_package_regression.exit`-like outputs: `q4_package_regression.err.log`, `q4_package_regression.log`, `q4_package_regression_retry.exit`, `q4_package_regression_retry.log` | pass/retry output, exit `0` | no current active ref | yes | duplicate root receipt; preserve only if parent elects to retain all historical output |
| `probe.tmp.err`, `probe.tmp.out`, `test_tmp.out` | empty/one-line temporary probe output | no current active ref | yes | rebuildable temporary output; no formal test source |
| `independent_cubature_focused.exit`, `independent_cubature_focused.log` | exit `1`; `DESCFieldSamplePointV4` load failure | historical receipts plus failure content | no | retain failure evidence until the parent audit explicitly archives it |
| `q4_final_standalone.log` | `q4_convergence_status=fail` despite process exit `0` | historical receipts plus failure content | no | retain numerical/convergence failure evidence |
| `tmp/integration_duplicate.json`, `tmp/integration_missing.json` | 13/68-byte malformed/missing-field probe fixtures | only historical dirty inventories; no active manifest/hash receipt | yes | one-off fixtures; formal fixtures remain under `test/` |

The old AD-54 baseline does mention many of these paths and hashes as a dirty-worktree snapshot. That is provenance only under this audit rule, not a current authority/hash receipt. If the parent elects to preserve historical snapshots byte-for-byte, change the `yes` rows to `no` before deletion.

## Generated Python/test caches

Generated `__pycache__/` and `.pytest_cache/` trees outside the historical evidence archive are untracked, rebuildable, and have no source/authority reference. They are `delete candidate=yes`; their per-file hashes and sizes are already listed in `../00-temp-file-inventory/inventory.tsv`. This includes caches under `benchmarks/`, `scripts/`, `test/`, and `tools/`. Do not confuse cache entries with their corresponding `.py` source files. The six `docs/implementation/**/__pycache__/` trees are historical review/raw-artifact material and are **not** included in this delete recommendation; retain them unless a separate evidence-archive decision explicitly covers them.

## `runs/` focused/probe/runner directories

These directories contain generated provider adapters and TSV request/result files. Each row was checked for current references outside historical dirty/status snapshots. The small adapter runs below have no current active docs/source/manifest reference and are cleanup candidates; the two active run trees are retained.

| path | files / bytes | current ref result | delete candidate | risk / action |
|---|---:|---|---:|---|
| `runs/drstp_focused` | 3 / 6,746 | historical snapshots only | yes | repeated rho-surface provider probe |
| `runs/drstp_focused_basis` | 3 / 5,725 | historical snapshots only | yes | repeated field-basis probe |
| `runs/drstp_focused_field` | 3 / 4,697 | historical snapshots only | yes | repeated field probe |
| `runs/drstp_focused2` | 3 / 6,859 | historical snapshots only | yes | repeated rho-surface probe |
| `runs/drstp_focused2_basis` | 3 / 5,725 | historical snapshots only | yes | repeated field-basis probe |
| `runs/drstp_focused2_field` | 3 / 4,697 | historical snapshots only | yes | repeated field probe |
| `runs/drstp_focused3` | 3 / 7,509 | historical snapshots only | yes | repeated rho-surface probe |
| `runs/drstp_focused3_basis` | 3 / 5,725 | historical snapshots only | yes | repeated field-basis probe |
| `runs/drstp_focused3_field` | 3 / 4,697 | historical snapshots only | yes | repeated field probe |
| `runs/drstp_focused4` | 3 / 7,509 | historical snapshots only | yes | repeated rho-surface probe |
| `runs/drstp_focused4_basis` | 3 / 5,725 | historical snapshots only | yes | repeated field-basis probe |
| `runs/drstp_focused4_field` | 3 / 4,697 | historical snapshots only | yes | repeated field probe |
| `runs/drstp_probe` | 3 / 6,746 | historical snapshots only | yes | one-off provider probe |
| `runs/drstp_probe_basis` | 3 / 5,725 | historical snapshots only | yes | one-off provider probe |
| `runs/drstp_probe_field` | 3 / 4,697 | historical snapshots only | yes | one-off provider probe |
| `runs/drstp_runner` | 3 / 7,509 | historical snapshots only | yes | one-off provider runner |
| `runs/drstp_runner_basis` | 3 / 5,725 | historical snapshots only | yes | one-off provider runner |
| `runs/drstp_runner_field` | 3 / 4,697 | historical snapshots only | yes | one-off provider runner |
| `runs/imit_focused_pressure` | 3 / 4,687 | historical snapshots only | yes | repeated pressure probe |
| `runs/imit_focused_pressure2` | 3 / 4,687 | historical snapshots only | yes | repeated pressure probe |
| `runs/imit_focused_surface` | 3 / 7,509 | historical snapshots only | yes | repeated surface probe |
| `runs/imit_focused_surface2` | 3 / 7,509 | historical snapshots only | yes | repeated surface probe |
| `runs/imit_reg_surface_retry` | 13 / 129,731 | historical snapshots only | yes | retry bundle; no current consumer found |
| `runs/imit_runner_pressure` | 3 / 4,878 | historical snapshots only | yes | one-off pressure runner |
| `runs/imit_runner_surface` | 3 / 7,509 | historical snapshots only | yes | one-off surface runner |
| `runs/dsmb_runner_20260911_150816` | 19 / 137,068 | historical snapshots only | yes | one-off DSMB provider runner |
| `runs/imirj_runner_20260911_144057` | 16 / 134,609 | historical snapshots only | yes | one-off IMIRJ provider runner |
| `runs/revised_chain_20260912_audit` | active report references and frozen source/hash manifest | current docs/reports consume it | no | retain complete evidence tree |
| `runs/spatial_chain_20260912_audit` | active handoff references `closeout_source_manifest.json` and focused results | current docs/reports consume it | no | retain complete evidence tree |
| `runs/spatial_chain_20260912_staging` | source/test/scripts mirror | current spatial handoff and implementation docs consume it | no | active source/evidence boundary; do not delete |

The `runs/` rows are all untracked at capture. The historical AD-54 baseline may list their individual files, but that snapshot alone does not promote a disposable run into current evidence. Conversely, the three retained trees have direct active references and must stay intact.

## Other one-off scratch paths

| path | reference/hash result | delete candidate | risk / action |
|---|---|---:|---|
| `independent_precheck_r9/report.json` | root copy; only dirty/status snapshots, no current manifest or hash receipt; canonical implementation report is under `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/` | yes | duplicate report from an older HEAD; remove only the root copy |
| `independent_postrun_r5/report.json` | root copy; only dirty/status snapshots, no current manifest or hash receipt; canonical implementation report is under `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/` | yes | duplicate report from an older HEAD; remove only the root copy |
| `M4-SCOPE-DECISION-R1/` | root scratch failure-history copy; no current manifest/hash receipt | yes | preserve the canonical `docs/implementation/UP2-01-PREPARATION/M4-SCOPE-DECISION-R1/` tree |
| `FusionConceptAI/docs/implementation/UP5-EARLY-PREPARATION/M5-EGRAPH-R1/test_execution_r2/replay2/run_ledger.json` | nested duplicate; only dirty inventories, no current consumer | yes | accidental nested checkout/artifact; canonical docs tree is at repository root |

## Handoff

No deletion was performed. For the parent cleanup/commit lane:

- Keep all 270 formal test/fixture files, the three named formal probes, the two failure/convergence root logs, and the three actively referenced run trees.
- The rows marked `yes` are the proposed deletion scope after a final pre-delete exact-path/hash check. Prefer recoverable move-to-trash where available.
- Do not stage the whole repository. Re-read `git status --short`, verify the parent agent's intended commit scope, then selectively stage the approved cleanup and implementation files.
- No test was run by this audit; deleting caches/output must not be reported as a test or physics validation.
