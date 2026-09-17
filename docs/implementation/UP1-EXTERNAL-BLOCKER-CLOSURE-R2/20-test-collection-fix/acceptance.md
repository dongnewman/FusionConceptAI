# Acceptance: UP1 R2 collection fix

- [x] Original 18 regression raw stdout/stderr/process evidence retained as `raw/prior_failure_fresh_r1.*` and `raw/prior_failure_fresh_r2.*`.
- [x] Only `test/up1_external_closure_r2/witness_authority/test_witness_authority.py` changed; no production validator changed.
- [x] Serial fresh top-level run 1: exit 0, 148 passed, 3 skipped.
- [x] Serial fresh top-level run 2: exit 0, 148 passed, 3 skipped.
- [x] All 10 component directories exit 0: 148 passed, 3 skipped total.
- [x] All runs use `python -B`; stdout/stderr bytes and SHA-256 are recorded.
- [x] No `PYTHONPATH`, `--import-mode`, network, Julia, S3, DESC, solver, or external authority was used.
- [x] Evidence manifest excludes itself and records exact bytes/SHA-256 for every evidence file.

The 3 skips are unchanged dynamic test-scope boundaries (foreign-owner and
symlink/Junction capability cases); they are not promoted to pass.
