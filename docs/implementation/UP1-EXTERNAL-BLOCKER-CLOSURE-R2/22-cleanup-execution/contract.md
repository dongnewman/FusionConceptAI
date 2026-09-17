# UP1 R2 cleanup execution contract

This package records execution of the read-only candidate list from `21-final-hygiene-audit/cleanup_candidates.json`.

- Allowed deletion roots are exactly `tools/up1_external_closure_r2/` and `test/up1_external_closure_r2/`.
- Each candidate had to be an existing non-reparse `.pyc` under a `__pycache__` parent, match listed bytes/SHA-256, and be absent from R2 manifests/receipts.
- Files were removed one at a time with PowerShell `Remove-Item -LiteralPath`; only already-empty `__pycache__` directories were then removed.
- No recursive directory deletion was used. Docs, raw/review/receipt evidence, temporary files, out-of-scope caches, and source files were not in scope.
- Deleted items are generated artifacts and are not recoverable from the workspace; Python can regenerate them from retained source.

The claim ceiling is cache cleanup only; this package makes no authority, readiness, or physical-evidence claim.


