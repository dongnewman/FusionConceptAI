# AD-30 status repair R4

- `status`: `changes_requested` (documentation synchronization only)
- `decision_id`: `AD-30`
- `base_head`: `4b69f55f7f80240147a65a22809dc1207824dde2`
- `scope`: core planning/index wording; no task manifest or source change

## Repairs

1. Core `18_sources_and_architecture_decisions.md` now labels the direct VNEXT chain in AD-28 and AD-29 as the historical AD-28 base schedule. It points to the current AD-30 formal VNEXT DAG: `UP1-04A + G1/G2/G3 → T0 → T1 → T2 → UP1-04A-VNEXT → UP2-00`. The historical AD-28/AD-29 statements remain present and are not rewritten as current execution authority.
2. Core `README.md` now labels the early AD-28/AD-20 direct chains as historical and points readers to the same AD-30 formal DAG. The later AD-30 section remains the current T2-after-aggregate gate description.
3. `docs/implementation/README.md` now links G-I1B to its local `acceptance.md` and independent R3 report, with scope limited to accepted_limited actual-A source-envelope software behavior and typed authority-gap handling.

## Boundary

This repair does not alter `task_manifest.json`, work orders, source, old V5/package/registry, receipts, or other evidence. It grants no implementation, UP2, B00/B04, provider, mesh, engineering, physical, search, or R01–R10 credit. No Julia or DESC command was run. A different Luna should review this synchronization before treating the index wording as closed.

## Validation

`python -m json.tool` on the new manifest and `python docs/v4_multitopology_generation/validate_plan.py` are required static checks; their actual exits and the dirty-worktree snapshot are recorded in `evidence_manifest.json`.
