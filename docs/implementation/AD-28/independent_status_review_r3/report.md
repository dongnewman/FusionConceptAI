# AD-28 status_sync_r3 independent review

Verdict: `pass_limited` for the accepted architecture, acyclic DAG and evidence-boundary scope only.

The status synchronization is internally consistent with the prior independent
R2 review and the Sol `accepted_limited` decision. The status archive records
`accepted=true` only for architecture, scheduling and evidence semantics;
runtime remains unexecuted. The four new preparation/rebinding nodes remain
`planned`/`proposal` with `accepted=false`, and the task manifest has 31 tasks
with an acyclic dependency graph.

The status-sync manifest's `README.md` entry is the repository-root README;
its current 6235-byte hash matches the recorded after hash. The planning README
under `docs/v4_multitopology_generation/` remains a separate full document and
contains the AD-28 historical-receipt and new-candidate boundary. Current
core16, core18, task manifest and AD-28 archive hashes match the status-sync
capture where applicable. The root README, core work orders, architecture
decision record and task manifest changes are narrow status/link/pointer or
AD-28 declaration updates; no source or old evidence was rewritten.

AD-28's accepted scope does not promote the three upstream declarations,
`UP1-04A-VNEXT`, UP2-00 total, formal B00/B04, complete UP1-04, UP2-01
compiler/provider/mesh/physical execution, engineering evidence or R01-R10.
The task manifest confirms the new nodes remain unaccepted; UP2-00's local
actual-A N01/N02 `accepted_limited` slice remains separate from its total gate.
Old UP1-04A, G-I1A, N05, N06 and UP2 local receipts remain historical and are
explicitly barred from reuse for the new candidate.

The actual-A boundary is unchanged: no candidate-owned G1 `u/K(x)/f`, no
executable G2 metric/mesh/face ownership and no external G3 source/feedback
authority. Missing authority remains `terminal_deferred`, contradictions remain
`fail_closed`, and the V4 manufactured screen is not promoted. Fresh candidate
identity, all refs/hashes/axes, E0/G-I1A/E1/E2/UP2 receipts, B00/B04 and later
gates remain future obligations.

This was a read-only static review at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, with 295 existing
status rows. Julia and DESC were not run. Only the four files in this
`independent_status_review_r3/` directory were written.

Claim ceiling:
`architecture_and_preparation_boundary_only_no_execution_no_provider_mesh_physical_or_R01-R10_credit`.
