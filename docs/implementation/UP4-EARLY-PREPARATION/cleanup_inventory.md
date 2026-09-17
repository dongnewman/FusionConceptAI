# UP4 early preparation cleanup inventory

Status: `review_pending`; cleanup scope is limited to this task's own scratch,
cache and accidental files. Existing dirty work, historical failures and runs
are protected. No repository-wide cleanup was authorized or performed.

## Inventory result

| Scope | Observation | Action |
|---|---|---|
| `docs/implementation/UP4-EARLY-PREPARATION/` before work | Directory absent | Created only this deliverable directory |
| Task-local scratch/cache | None created; no Julia/DESC/provider/solver run | Nothing to remove |
| Task-local unrelated code | None created | Nothing to remove |
| `src/`, `test/`, `scripts/`, `runs/`, `benchmarks/` | Existing dirty and historical artifacts observed | Preserved; not searched for deletion candidates beyond read-only inspection |
| `docs/implementation/` outside this directory | Existing implementation records and snapshots | Preserved |
| v4 docs, `task_manifest.json`, shared/default registry, final package | Protected by task scope | Preserved |

## Protected evidence

The checkout already contains tracked and untracked changes, spatial-chain
failures, interrupted/resumed runs, source/provider fixtures and prior
implementation packages. They belong to the user's workspace and are not
task-local scratch. No reset, checkout, recursive delete, archive rewrite, or
wholesale staging was used.

## Post-write scope check

The expected core paths are the eight deliverables listed in `manifest.json`,
with the two Repair R1 files and three accepted-limited status records listed in
the manifest's package-local path sections.
The final validation must confirm that the diff contains no path outside this
directory and that no protected file hash changed. If that check fails, the
package is `review_pending` and the offending path must be reported rather than
cleaned automatically.

## Decision

There was no safe task-owned material to delete. The package retains all dirty
and historical evidence and leaves cleanup of unrelated workspace material to a
separate explicitly scoped task.

## Repair R1 cleanup and ownership

Independent review identified one malformed package-local observed digest. The
source artifact was only read and rehashed; no source/run artifact was deleted or
changed. The exact files owned by this repair are:

- `reference_data_catalog_template.json`
- `manifest.json`
- `validation_report.md`
- `cleanup_inventory.md`
- `repair_r1/report.md`
- `repair_r1/manifest.json`

No other path is part of Repair R1. The pre-existing `independent_review_r1/`
directory is not owned by this repair and was left untouched.

## Accepted-limited status sync R1

Independent R2 `pass_limited` supports acceptance of the early-preparation
template only. The additional package-local status files are:

- `acceptance.md`
- `status_sync_r1/report.md`
- `status_sync_r1/manifest.json`

They record `accepted_limited_scope=early_preparation_template_only` while the
machine/package status remains `review_pending`, all formal gates remain
`pending`, and no data, inverse, engineering, physical, B07 or R credit is
granted. No cleanup deletion or protected-path mutation was performed.
