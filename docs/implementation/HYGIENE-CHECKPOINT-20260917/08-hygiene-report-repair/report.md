# Hygiene report repair — 2026-09-17

## Scope

This repair is limited to the current `HYGIENE-CHECKPOINT-20260917` checkpoint. No historical evidence directory, source file, test file, quarantine item, staging state, or commit was changed.

## Repair basis

- `00-temp-file-inventory/inventory.tsv` retains its 89 data rows, paths, recommendations, byte counts, and SHA-256 values. Only its final blank line was removed.
- `00-temp-file-inventory/directory-inventory.tsv` was rebuilt because the prior file contained 29 PowerShell `InvalidOperation` error blocks and no usable directory rows. The replacement has 29 data rows and 8 tab-separated columns. It is derived from the 00 file rows: 25 `__pycache__` directories, `.pytest_cache`, `.pytest_cache/v`, `.pytest_cache/v/cache`, and `tmp`.
- Directory byte totals and child counts are aggregates of the 00 file rows. No directory digest was invented; `sha256_or_scope` explicitly records that the row is an inventory-derived scope and that no directory hash was captured.
- `03-deletion-risk-review/exact_delete_paths.txt` and `keep_paths.txt` retain their non-empty path lines; only trailing EOF blank lines were removed. The 04 cleanup JSON and its quarantine root were used as cross-check inputs, not modified.
- `01-temp-test-audit/audit.md`, `02-commit-scope-audit/README.md`, and `03-deletion-risk-review/README.md` received only formatting cleanup (Markdown line-end spaces and EOF blank lines).

## Scoped diagnostics

The pre-repair scoped check was run as:

```text
git diff --check --cached -- docs/implementation/HYGIENE-CHECKPOINT-20260917
```

It reported the malformed directory error lines, the six Markdown line-end spaces, and EOF blank lines; exit `2`. The unstaged worktree check before repair was exit `0` because the checkpoint files were already staged and the defects were in the index snapshot.

After repair:

```text
git diff --check -- docs/implementation/HYGIENE-CHECKPOINT-20260917
```

returns exit `0` with no diagnostics. The cached check was intentionally not repaired by this worker because staging is outside scope; it still reports the pre-repair index snapshot until the parent selectively stages the reviewed files.

Validation after repair: `inventory.tsv` parses as 89 data rows; `directory-inventory.tsv` parses as 29 data rows, every row has 8 columns, and all directory absolute paths correspond to their relative paths. No tests or runtime/physics executions were performed.
