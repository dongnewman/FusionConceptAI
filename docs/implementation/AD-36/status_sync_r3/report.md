# AD-36 status sync R3

Date: 2026-09-15  
Decision: `accepted_limited`  
Scope: mandatory evidence-sidecar scope contract only

Sol/root accepted AD-36 after different-Luna independent review R3 `pass_limited`. The decision applies only to the exact-file-count and evidence-sidecar boundary. Product/contract deliverables alone count toward `exact_file_count`; append-only raw streams, process receipts, hashes, repairs, cleanup inventories, independent reviews and status syncs are evidence-only sidecars under the owning task directory and do not count. Source, test, fixture, static-QA, launcher or other product payloads in a sidecar remain `scope_violation`/`fail_closed`.

The current root manifest is accepted-limited and points to this append-only R3 receipt. R1 and R2 remain historical. AD-36 creates no task and leaves the 39-task acyclic DAG unchanged. It does not open AD-34 binding/recheck implementation and grants no provider, mesh, solver, engineering, physical, search, B00, B04 or R01–R10 credit.

The twelve-manifest JSON parse, plan validator and exact-path diff check were run directly from the repository. They exited `0`; raw stdout/stderr and PID/UTC records are retained in this directory. The final plan validator reported 31 markdown files, 485 relative links and 39 acyclic tasks. The diff check emitted only the recorded LF-to-CRLF working-copy warning. No Julia, DESC, mesh, provider or physical run was performed.

The receipt inputs and outputs are SHA/byte closed in `manifest.json`. Cleanup retained every task-owned evidence path and protected existing dirty files, historical failures and prior receipts; no ambiguous path was deleted or rewritten.
