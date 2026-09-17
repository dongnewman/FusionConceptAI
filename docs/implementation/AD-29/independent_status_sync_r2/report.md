# AD-29 independent status sync R2

Verdict: `pass_limited`.

This read-only review verifies `docs/implementation/AD-29/status_sync_r2/`
against the current core README, execution work orders, architecture
decisions, task manifest and validator. It confirms AD-29 only as an
`accepted_limited` environment evidence gate and contract-only planning
boundary. It does not accept implementation, provider, mesh, physical,
engineering, B00, B04 or R01-R10 credit.

## Environment gate verified

Before any future UP2-01/provider, mesh, physical or related combination
execution, the status sync requires a fresh candidate-bound receipt covering
current source/input/candidate identity, interpreter and module paths with
SHA-256, complete dependency/build/channel metadata and hashes, command and
exit/output/artifact hashes, and the applicable profile. The role-specific
requirements are preserved:

- DESC fixed-boundary is missing `jax-finufft`; NUFFT remains
  `unsupported`/`terminal_deferred`, and AD-29 does not require installing it.
- FreeGS must record its `include-system-site-packages` inherited base
  packages.
- VMEX and Pleiades must bind their external source trees and complete digests.
- CQL3D must bind its C/Fortran/NetCDF/HDF5 toolchain rather than a Python
  identity.
- Historical provider/physical receipts remain limited to their original
  environment/source/input/run scope.

The status sync records `execution_authorized=false`, `up2_01_accepted=false`
and `provider_mesh_physical_accepted=false`; this matches the core boundary.

## DAG, requirements and validator

The current task manifest contains 31 tasks. Its environment gate records
`dag_unchanged=true`, `task_count_unchanged=31` and
`r01_r10_unchanged=true`; the ten requirements `R01` through `R10` are
retained. The preparation/execution nodes remain planned with acceptance
closed where applicable, including G1/G2/G3, UP1-04A-VNEXT, UP2-00 and
downstream UP1-04B/UP1-04/UP2-01.

The current validator command was run read-only:

```text
D:\Users\Newman\anaconda3\python.exe docs/v4_multitopology_generation/validate_plan.py
```

Exit: `0`. Output: `checks=pass`, `task_count=31`,
`task_dag_acyclic=true`, `markdown_files_checked=31`,
`relative_links_checked=355`, `snapshot_files_checked=16`, `errors=[]`.
Validator stdout was 401 bytes with SHA-256
`7a1feef63cc67e441444eb8bb792d668f828abff22985e6fc4f048a0620ebd94`;
stderr was 0 bytes with SHA-256
`e3b0c44298fc1c1499b934ca495991b7852b855`.

The prior R1 review's historical 354-link receipt is not overwritten; the
current 355-link validator result is the evidence for the current core bytes.

## Protected evidence and hashes

The status sync's original proposal and independent R1 review remain present
and unchanged at the following current hashes:

| path | bytes | SHA-256 |
|---|---:|---|
| `docs/implementation/AD-29/proposal.md` | 3473 | `fd0a9cdd85bd09ad39a48ceaa78490b7c2499bdc9affd2b22ea87b9af32b2ee6` |
| `docs/implementation/AD-29/independent_review_r1/report.json` | 3593 | `9af65a50ca55aa838669c135614d2d0ea7c8c69e708628ba0729494d3981e2a9` |

The current status-sync archive hashes are recorded in the evidence manifest
and match the files read during this review. No source, code, environment
prefix, historical receipt or run was changed.

## Dirty-state protection

Before writing this review, the full `git status --short
--untracked-files=all` snapshot had 3767 entries and UTF-8/LF SHA-256
`3c5723cd3f49903e79d6ab8bb1d70bfaee4ad75dd1cee7cc140751d42681cbc0`.
The post-write count and hash are recorded in
`independent_status_sync_r2/evidence_manifest.json`. The only intended files
under the AD-29 path are this review's new report, manifest and receipts.

## Claim boundary

No Julia, DESC, provider, mesh or physical command was run. This review grants
only `pass_limited` for the AD-29 status-sync evidence and architecture gate.
It preserves `accepted_limited` as the status-sync scope, with execution and
all implementation/physical credit still closed.
