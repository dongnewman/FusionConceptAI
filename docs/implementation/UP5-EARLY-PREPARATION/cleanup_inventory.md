# UP5 early preparation cleanup inventory

Status: `accepted_limited` for the early-preparation template; independentR1 repair and
status_sync_r1 cleanup scope was limited to this task's own scratch/cache and
accidental files. The existing dirty worktree, historical failures, source/test changes,
archives and run artifacts were protected.

| path/scope | before | after | action | reason |
|---|---|---|---|---|
| `docs/implementation/UP5-EARLY-PREPARATION/` | absent or existing directory state checked before writing | deliverables present | retained | exact writable scope |
| task-local scratch/cache | none created | none | no action | no execution or temporary campaign was run |
| task-local unrelated code | none created | none | no action | no source/test/registry edits |
| `src/`, `test/`, `scripts/`, `runs/`, `benchmarks/` | dirty and historical artifacts present | preserved | no action | protected workspace evidence |
| `docs/implementation/` outside this directory | existing archives and snapshots | preserved | no action | historical implementation records are read-only inputs |
| `docs/implementation/UP5-EARLY-PREPARATION/repair_r1/` | absent before repair | `report.md`, `manifest.json` only | retained | exact repair scope; no scratch/cache created |
| `docs/implementation/UP5-EARLY-PREPARATION/status_sync_r1/` | absent before status sync | `report.md`, `manifest.json` only | retained | exact status-sync scope; no scratch/cache created |
| `docs/implementation/UP5-EARLY-PREPARATION/acceptance.md` | absent before limited acceptance | present | retained | explicit accepted-limited record |
| v4 docs, `task_manifest.json`, README, package/registry | existing | preserved | no action | explicitly protected by task contract |

No deletion, reset, checkout, recursive cleanup, archive rewrite, or broad glob was used.
There is no task-owned material safe to remove. If final scope validation finds a path
outside this directory changed, that path must be reported and left intact for review.
