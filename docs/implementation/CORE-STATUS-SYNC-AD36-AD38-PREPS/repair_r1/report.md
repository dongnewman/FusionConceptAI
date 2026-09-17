# CORE-STATUS-SYNC-AD36-AD38-PREPS repair R1

Date: 2026-09-15  
Decision: `accepted_limited` for this documentation/status repair only.

The independent R1 review requested four corrections. They are now closed within the authorized scope:

1. The v4 README records the current validator result of 485 relative links. This is static planning evidence only; it is not provider, mesh, solver, physical, engineering, search, L4, or R01-R10 evidence.
2. The UP4 early-preparation root manifest is synchronized to `status=accepted_limited`, `accepted=true`, and `review_status=accepted_limited`. The prior `review_pending`/`accepted=false` root hash and old review receipts remain append-only history in [UP4 status sync R2](../../UP4-EARLY-PREPARATION/status_sync_r2/report.md). UP4 remains a template/contract preparation package; formal inverse realization and all execution conclusions remain pending.
3. AD-38 now treats AD-36's mandatory evidence-sidecar policy gate as satisfied by `accepted_limited`. This does not unlock checked-present/T1/UP2, provider, mesh, solver, engineering, physical, or search authority. The repaired [AD-38 acceptance](../../AD-38/acceptance/acceptance.md) and its [status sync R2](../../AD-38/acceptance/status_sync_r2/report.md) retain those gates.
4. The retained `task_manifest.json` field `environment_gate.task_count_unchanged=false` is documented as an AD-29 comparison with the earlier 31-task baseline. It was not rewritten. The current manifest SHA256 is unchanged, the live DAG has 39 tasks and is acyclic, and the current synchronization therefore has no task/DAG drift.

The core narrative is in [README](../../../v4_multitopology_generation/README.md) and [AD/source decisions](../../../v4_multitopology_generation/18_sources_and_architecture_decisions.md). The task manifest was not modified. No AD-36/37/38 or UP3-UP6 preparation machine node was added. All implementation, inverse, engineering, provider, mesh, solver, physical, B07A/B07B, search, L4 and R01-R10 credits remain false or pending. No Julia/DESC/physical solve ran.

Validation is planning/status validation only: 31 markdown files, 485 relative links, 39 tasks, acyclic DAG, validator exit 0. The task-manifest SHA256 is `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`. Raw stdout/stderr and command metadata are under `raw/`; the manifest records bytes and SHA256 for each receipt and the output files. The LF/CRLF warning from scoped diff checking is non-fatal; exit was 0. No task-local temporary or unrelated dirty/history path was removed.

This repair closes the R1 documentation/status inconsistencies. It does not constitute physical or engineering acceptance and does not reduce parent R01-R10 obligations.
