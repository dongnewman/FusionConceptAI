# AD-36 mandatory evidence sidecar scope amendment

Date: 2026-09-15  
Decision: `accepted_limited`  
Accepted: `true`  
Reviewer: different Luna/high (`independent_review_r3`); Sol/root decision

AD-36 is a narrow contract amendment for exact deliverable counts. `exact_file_count` means only product/contract deliverables. Mandatory append-only evidence sidecars required by implementation or test closeout—raw stdout/stderr, exit, PID/UTC, interpreter identity, input/output/artifact hashes, repair reports, cleanup inventory, independent reviews and status sync—are permitted and required under the task-owned `docs/implementation/<task-id>/archive/**` or named `review/**` and `status_sync_*/**` subdirectories.

Sol/root accepts this amendment as `accepted_limited` for the evidence-sidecar scope contract only, based on independent R3 `pass_limited`. This decision does not accept any affected implementation work order or promote any execution, provider, mesh, engineering, physical, search, B00, B04 or R01–R10 evidence.

Sidecars do not count as additional product/contract files. They must stay inside the owning task directory, must not overwrite an earlier round, and are protected from cleanup. Temporary launchers remain forbidden; tests run as direct commands. This amendment applies to AD-34 binding6 (`exact_file_count=6` product/contract files), AD-34 recheck7 (`exact_file_count=7` product/contract files), and future exact-scope work orders.

Sidecars are evidence-only: they may contain metadata, raw command streams, receipts, reports, inventories and review/status records only. They must not contain or smuggle any product/contract deliverable, source, test, fixture, static-QA file or launcher to evade the exact scope. Any such path is `scope_violation`/`fail_closed`; the task must clean its own out-of-scope copy while preserving the evidence that records the violation. Protected prior evidence is never deleted.

The amendment does not create a task, change the 39-task DAG, authorize implementation, or grant physical, provider, mesh, engineering, search, B00, B04 or R01–R10 credit. AD-36 is now `accepted_limited`/`accepted=true` only for this contract; it remains an external policy boundary for future exact-scope work orders.

Status-sync lineage is append-only: `status_sync_r1/` remains historical, `status_sync_r2/` remains the prior refresh, and `status_sync_r3/` records this accepted-limited decision. No prior receipt is overwritten.

## Validation boundary

This is a documentation/contract task: `code_tests=not_applicable`. The required validation is explicit JSON parsing of the AD-36 and affected manifests, the repository plan/link/static validator, and an exact-path `git diff --check`. No Julia, DESC, mesh, full regression, or implementation test is run.

## Closeout boundary

The only new owned paths are the four AD-36 documents requested for this amendment. They are frozen delivery and retained. No scratch, cache, debug, unrelated code, launcher, source, test, run, old receipt or prior evidence path is created by AD-36. The status-sync manifest records each owned path and protected path explicitly, with self-hash exclusion for its own manifest.
