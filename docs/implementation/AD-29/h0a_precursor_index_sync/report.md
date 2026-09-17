# AD-29 H0-A precursor index sync

- `status`: `changes_requested` (index synchronization only)
- `decision_id`: `AD-29 / H0-A`
- `base_head`: `4b69f55f7f80240147a65a22809dc1207824dde2`
- `scope`: core v4 README and implementation README index wording only

The two indexes now link `UP2-N06-H0A-DIMENSIONED-LAW/software_precursor_acceptance_r1.md` and its independent software acceptance R1 report. They record `accepted_limited` only for the local H0-A software contract and retain the 79/79 contract boundary.

The H0-A total gate and actual authority remain `accepted=false`. UP2 total, B00/B04, provider, mesh/DESC, physical, engineering, and R01–R10 credit remain false. Runner actual-A status, declaration type, and compile/provider/solver counters remain `not_printed_by_runner`; R6 and R7 exit-1 failures remain preserved historical evidence.

No changes were made to `16_execution_work_orders.md`, `18_sources_and_architecture_decisions.md`, `task_manifest.json`, source, tests, current H0 total acceptance, or old evidence. No Julia or DESC command was run. JSON validation exited 0. The plan validator exited 1 on the existing/concurrent missing link `docs\implementation\README.md: AD-31/status_repair_r2/report.md`; its counts and error are preserved in `evidence_manifest.json`. Hashes and the dirty-worktree snapshot are also recorded there; a different Luna should review this synchronization.
