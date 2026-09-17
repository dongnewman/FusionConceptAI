# UP1 R2 full lightweight regression

- Generated UTC: `2026-09-16T20:04:14.719156Z`
- Exact command, run serially twice: `python -B -m pytest -q test/up1_external_closure_r2`
- Scope: lightweight Python only; no Julia/S3/DESC/solver/network.
- Ownership: only `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/18-full-regression/**` was written.

## Result

Both runs reached collection and exited `2` (`test_failure`); no assertions ran. The same collection failure occurred in `test/up1_external_closure_r2/witness_authority/test_witness_authority.py`: pytest loads the test directory as top-level `up1_external_closure_r2`, then the test import cannot resolve `witness_authority.validator`. This was recorded, not bypassed by modifying tests.

## Audits

- Strict JSON: `226` prior R2 JSON files checked; `224` valid; `2` intentional duplicate-key negative controls; unexpected parse failures `0`.
- Component manifest/hash audit: `17` manifests; `192` declared path hash checks; `192` matches; missing/mismatched `0`. Full details are in `raw/strict_json_manifest_source_audit.json`.
- `review_crosswalk.json` preserves `pass_limited`, `review_pending`, and `test_scope_deferred`; it grants no parent UP1 or R01-R10 credit.

## Boundaries

- Foreign-owner and symlink/Junction dynamic fixtures remain `not_executed` / `test_scope_deferred`.
- No production authority, publish, external trust, UP1 credit, or physical/engineering readiness is inferred.
- See `test_receipt.json`, `review_crosswalk.json`, and raw PID/UTC/exit/hash records.

## Repaired full command and isolation matrix

- The explicit repaired command was run twice serially with `PYTHONPATH=tools` and `--import-mode=importlib`; both still exited `2` at the same witness collection import. Raw files are `raw/repaired_r2_1.*` and `raw/repaired_r2_2.*`.
- Serial component isolation matrix: `10/10` directories exit `0`, `148 passed`, `3 skipped`; this proves the failure is full-package collection/package-shadow interaction, not a broad component assertion failure.
- The 3 skips are retained as skips; foreign-owner and symlink/Junction dynamic cases remain `not_executed` / `test_scope_deferred`.
- Component matrix pass is diagnostic evidence only and does not convert the full-suite result into pass.
