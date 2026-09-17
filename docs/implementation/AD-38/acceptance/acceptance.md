# AD-38 UP2 compile/discretization gap audit — Sol acceptance

Date: 2026-09-15  
Decision: `accepted_limited`  
Accepted: `true`  
Accepted scope: static compile/discretization readiness audit and future finite work-order boundary only  
Independent review: `pass_limited` (different Luna/high, independent review R3)

Sol accepts AD-38 as a bounded architecture record. The reviewed audit establishes the present UP2 compile, chart/metric/mesh, topology/exterior and coupled-solve gaps, records the future product ownership and exit gates, and preserves the typed-absence no-execution boundary. It does not implement or open any UP2 work order.

The following remain unchanged and explicitly unaccepted: machine nodes, the UP2-01 through UP2-04 execution chain, `PhysicsCompilerV5`, EquationIR/WeakResidualIR/DiscreteResidual/SolverPlan products, T0/T1/T2 authority, checked-present parent or child declarations, provider/backend admission, mesh, solver, numerical, engineering, physical, B00/B04, and R01–R10 credit. No source, test, launcher, runner, core index, task manifest, or machine node was created or modified by this acceptance record.

Execution remains blocked by the absence of a checked-present same-candidate T0 authority recheck and the resulting T1/T2 identity chain. It also remains blocked on fresh candidate-bound G1/G2/G3 declarations, accepted upstream stage receipts, provider/backend and environment receipts, and independent replay evidence. AD-36 is now `accepted_limited`/`accepted=true` for its mandatory evidence-sidecar policy gate; satisfying that policy gate does not unlock checked-present authority, T1, UP2, provider, mesh, solver or physical execution.

The accepted claim ceiling is `static_readiness_architecture_work_order_boundary_only`. The reviewed RuntimeV4 field paths remain limited to fixed/manufactured/screen/deferred slices. Existing declarations, fixtures, legacy receipts, ref-only adapters, `bridge_ready`, and old spatial runs remain non-authoritative for UP2 execution and physical claims.

This was a documentation/architecture acceptance task. `code_tests=not_applicable`; applicable validation was run directly against the final acceptance products and their task-owned evidence sidecars: JSON parsing, SHA/byte closure, UTF-8/control-character checks, exact path-scope checks, and `git diff --check`. No Julia, DESC, provider, mesh, solver, heavy Python, or physical run was performed.

Owned write scope is exactly this directory: `docs/implementation/AD-38/acceptance/acceptance.md`, `manifest.json`, and the explicitly listed `status_sync_r1/**` evidence sidecars. Cleanup is read-only: no pre-existing dirty path, historical receipt, reviewed input, source, test, run, or artifact was removed or rewritten; no temporary launcher was created.
