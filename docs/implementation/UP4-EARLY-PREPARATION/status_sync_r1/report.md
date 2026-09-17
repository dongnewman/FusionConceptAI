# UP4-EARLY-PREPARATION status sync R1

Status: `review_pending`; decision scope: `accepted_limited` for the early-
preparation template only; formal execution and scientific gates remain pending.

## Upstream review

The package-local independent review record
`independent_review_r2/manifest.json` reports `verdict=pass_limited` for the
repaired preparation templates and provenance checks. Its R1 audit confirms:

- source artifact length: `7849` bytes;
- source SHA-256:
  `2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25`;
- catalog and repair values match at 64 hexadecimal characters;
- core JSON `5/5`, repair manifest valid, core deliverables `8/8`, writable paths
  `10/10`, input paths `30/30`, and repair-owned paths `6/6`;
- no download, inverse run, Julia, DESC, physical run, temporary deletion or
  task-local cleanup was performed.

## Synchronized machine status

The parent `manifest.json` now records:

- `resolution=accepted_limited_early_preparation_template_only`;
- `accepted_limited_scope=early_preparation_template_only`;
- `review_status=review_pending`;
- `accepted=false`, `claim_ceiling=contract_only`;
- independent R2 `pass_limited` as a scope-limited review record;
- `acceptance.md` and this status-sync pair as package-local records.

The machine-level status remains `review_pending` because no formal UP4 gate is
closed. The limited decision accepts only the template package and its static
provenance/repair records.

## Formal gates and credit boundary

UP3-02, T1, T2, UP2-05/provider, engineering evidence, B07A, B07B and UP4-01
through UP4-04 remain `pending`. No data, inverse, engineering, mesh, solver,
physical, B07, R02, R04, R05 or R01-R10 credit is granted. No provider or final
authority state is emitted.

## Cleanup and protection

The only new status-sync files are this report and `status_sync_r1/manifest.json`,
plus the package-local `acceptance.md`. Existing dirty work, historical failure
evidence, source/run artifacts, independent review directories, core/index files,
shared registry and final package remain protected. No cleanup deletion was
performed.
