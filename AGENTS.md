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

The user-directed execution setup is `gpt-5.6-sol` with `high` for top-level architecture,
planning, delegation and acceptance decisions. Delegate bounded implementation, tests,
integration, documentation maintenance and independent reviews to `gpt-5.6-luna` with
`high`, following `14_agent_orchestration.md`. Record actual model availability/settings;
do not silently substitute models. Use explicit file ownership, different implementer and
reviewer agents, and one serialized lane for heavy Julia/DESC/mesh/regression execution.

Preserve unrelated dirty work and historical artifacts. Audit current source and run
evidence before editing. Keep execution failures, numerical failures, physical failures,
missing capabilities and evidence ceilings separate. Neither a document nor a passing
test completes the unchanged parent R01–R10 goal. The September 14, 2026 user instruction
authorizes versioned Genome upgrades; do not reinterpret old candidate hashes or receipts.
