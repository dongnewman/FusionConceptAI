# FusionConceptAI project guidance

For this project's architecture, planning, implementation and acceptance work, start at
`docs/v4_multitopology_generation/README.md` and follow its reading order. The common
contract is `00_normative_contracts_and_state_model.md`; active work orders and dependencies
are in `16_execution_work_orders.md` and `task_manifest.json` in the same directory.

Use this directory as the current source of project guidance. `docs/implementation/`
contains implementation records and explicitly labelled historical planning snapshots;
older plans do not override the current roadmap. Store accepted implementation details
there and retain their acceptance scope and links in the active index. Do not classify
unfinished work, a historical plan or a failed physical run as accepted implementation.

The 2026-09-23 user-directed requested configuration was `gpt-6-sol / high`
for the root main thread and `gpt-6-luna / max` for delegated implementation, tests,
integration, independent acceptance reviews and reports. The 2026-09-28 user request
supersedes the delegated setting with `gpt-6-luna / high`; at most nine child agents are
active at once. This documentation records requested settings; it does not switch the
running model. Record host-visible actual settings separately. Apply the current user override to
stale model/effort fields in older prompts and `execution_assignment` while retaining each
task's scope, dependencies, ownership and acceptance gates; keep historical review models
unchanged and label them as historical. Keep implementation, testing and review with
different agents; the root main thread makes final project decisions. Do not reduce the
mathematics, scientific coverage or R01–R10 scope because of the requested worker model.
Use explicit file ownership, one owner for each shared entry point, and one serialized lane
for heavy Julia/DESC/mesh/regression execution.

Preserve unrelated dirty work. The October 19, 2026 user instruction authorizes
summarizing and deleting bulky historical raw results/logs and retiring unused code.
The exact boundary and SHA manifests are in
`docs/implementation/WORKSPACE-CONSOLIDATION-20261019/README.md`. Preserve current
reference inputs, explicit paused-work inputs, receipts and source/input pins; do not
recreate deleted raw bytes or claim a summary is an executable replay. This cleanup
does not authorize resuming the paused experimental Goal. Audit current source and run
evidence before editing. Keep execution failures, numerical failures, physical failures,
missing capabilities and evidence ceilings separate. Neither a document nor a passing
test completes the unchanged parent R01–R10 goal. The September 14, 2026 user instruction
authorizes versioned Genome upgrades; do not reinterpret old candidate hashes or receipts.

The September 17, 2026 user decision makes `agent_local` the default execution
profile. Read `docs/v4_multitopology_generation/22_agent_local_execution.md` and
`execution_policy.json` before applying historical authority gates. Mainline and worker
agents own project roles; do not request external people, CA/OCSP/CRL/TSA,
witness signatures, channel ACKs, publisher proofs or EHP bundles to authorize
local development, candidate construction, numerical execution or search.
Retain actual source/content binding, typed and numerical checks, and scientific
requirements. Legacy external-certification modules and receipts are optional
compatibility artifacts, not default execution prerequisites. DAG dependencies
may be revised with synchronized work orders; 39 nodes is not an invariant.
Do not treat local command success, a candidate ID or agent agreement as physics
acceptance. A side-conversation prohibition on delegation takes precedence over
this project's default multi-agent workflow; report solo verification honestly.
