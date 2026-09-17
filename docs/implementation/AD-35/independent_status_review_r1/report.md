# AD-35 status sync R1 independent review

## Decision

**changes_requested**. The accepted-limited contract boundary is internally consistent, but the status-sync receipt does not satisfy the requested frozen `39 tasks / 456 relative links` invariant: its own plan-validation raw output reports `457` relative links.

## Reviewed basis

I read the current AD-35 acceptance, manifest, status sync R2 report and manifest, the current core `README.md`, `docs/implementation/README.md`, `14_agent_orchestration.md`, `16_execution_work_orders.md`, `18_sources_and_architecture_decisions.md`, and `task_manifest.json`. I also checked the current hashes against the R2 `current_file_hashes` map. This review was read-only; no reviewed file was modified and no command was run.

The status fields are otherwise aligned: AD-35 is `accepted_limited`, `accepted=true`, `accepted_scope=collaboration_contract`, `claim_ceiling=collaboration_contract_only`, `sol_decision=accepted_limited`, `creates_mainline_task=false`, and the core task policy is also `accepted_limited` with `accepted=true`. The core and AD-35 records keep the parent count at 39, the DAG acyclic/unchanged, and physical/R01-R10 credit false. The documentation records provider, mesh, engineering, search, B00 and B04 as outside the accepted scope.

## Blocking discrepancy

The R2 `json_plan_link_format_static_validation` receipt has exit `0`, `checks=pass`, `task_count=39`, `task_dag_acyclic=true`, and `errors=[]`, but it reports:

`relative_links_checked=457`

The requested/frozen review criterion is 456 links, and the preceding R3 plan receipt recorded 456. Thus the R2 status sync cannot be accepted as satisfying the requested 39/456 invariant. The minimum repair is to explain and deliberately reconcile the one-link change: either restore the validated 456-link core state, or explicitly revise the frozen criterion and all status/index receipts to 457 under Sol's decision. A plan validator “pass” does not resolve this count mismatch.

## Receipts and cleanup

The R2 manifest records three static commands with exact commands, cwd, PID, UTC times, exit codes, stdout/stderr/combined hashes, input/output/artifact hashes, and no Julia/DESC/heavy recomputation. JSON parsing reports eight manifests and exit `0`; plan validation exits `0`; diff checking exits `0` with the recorded README line-ending warning. The current file hashes for the R2 protected inputs match its `current_file_hashes` records, with self-excluded manifest entries represented by the declared rule.

The R2 status-sync manifest has `self_hash_excluded=true` and an explicit self-hash rule. Its final exact-owned set contains exactly two R2 delivery paths, both retained. Removed and deferred paths are empty, cleanup is `none`, and the inventory has no aggregate all-other row. Existing repairs, raw receipts, dirty source/tests, failure evidence and accepted artifacts are protected. No scratch/cache/debug/unrelated file is declared.

## Boundary

This review does not question the accepted collaboration-contract ceiling itself. It records no implementation, runtime, engineering, physical, provider, mesh, search, B00, B04, or R01-R10 credit. After the 456/457 count is reconciled, a follow-up independent status review can re-evaluate the same accepted-limited boundary.
