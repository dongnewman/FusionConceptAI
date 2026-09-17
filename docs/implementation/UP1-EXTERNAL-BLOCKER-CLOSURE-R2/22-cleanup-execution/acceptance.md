# Acceptance

- [x] 32/32 listed candidates were validated by resolved absolute path, allowed-root containment, non-reparse status, `__pycache__` parent, `.pyc` suffix, manifest non-ownership, and exact bytes/SHA-256.
- [x] 32/32 candidate files are absent after execution; 447,664 bytes removed.
- [x] 12 empty `__pycache__` directories were removed; no non-empty directory was recursively deleted.
- [x] R2 tools/test cache count is zero after cleanup.
- [x] Fresh `python -B` AST validation parsed 54 Python files with exit code 0.
- [x] The collection-fix witness source hash matches the prior manifest, all R2 Python sources parse under `-B`, and the operation touched no test source.
- [x] HEAD is unchanged; the observed Python process was not terminated.
- [x] Only this `22-cleanup-execution/**` evidence directory was added by this operation.

Deleted generated caches are permanently removed from the workspace (no trash/backup was used), while retained source and evidence remain available.

