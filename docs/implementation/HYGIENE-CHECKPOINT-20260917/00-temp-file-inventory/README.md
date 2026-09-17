# Temporary-file inventory (read-only checkpoint)

审计范围：`D:\006-Programing\LMC\FusionConceptAI`。本次只读扫描未删除、未修改既有文件；本目录是本次唯一新增写入位置。

## Provenance

- UTC: `2026-09-17T05:20:37.5673507Z`
- HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- `git status --short` entries: `384`
- status snapshot SHA-256 (UTF-8 joined by LF): `0fef4ec2312efa18d87e278502d92dbf6a6d20e814a1d895058fec97bda0cffe`
- inventory scan process PID: `45160`; scan exit: `0`; git-status exit: `0`
- observed active Python PID `85880`: `python -u tmp/phase5_remote_session.py`; working directory could not be established from `Win32_Process`, so it was not touched.

## Result

- 89 file entries are listed in `inventory.tsv`; all were untracked at the snapshot.
- Recommended delete: 83 entries (63 `*.pyc`, 6 `.pytest_cache` files, 2 `tmp/` JSON fixtures, 2 `probe.tmp.*` outputs, and 10 unreferenced root-level success/empty logs/exits).
- Keep: 3 failure-evidence files (`independent_cubature_focused.exit/.log`, `q4_final_standalone.log`) and 3 test-source probes (`test/GenomeV5/UP2/up2_module_entry_failure_probe.jl`, `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl`, `test/up1_external_closure_r4/g2_mapping/adversarial_probe.py`).
- Aggregate rebuildable cache bytes: `981133` (`941569` bytecode + `39564` pytest cache). `tmp/` is `81` bytes; root standalone exit/log/test_tmp set is `19559` bytes; probe outputs are `21` bytes.
- Scan found no `*.pyo`, `.mypy_cache`, or `.ruff_cache` outside the explicit exclusions.

## Exclusions and boundaries

- `docs/implementation/**` was deliberately excluded, including nested `__pycache__`; these are raw implementation artifacts and were not classified as temporary.
- `runs/**` was deliberately excluded, including logs, failure receipts, formal evidence, and nested caches; these remain evidence until an owner performs a separate retention decision.
- Test source files matching `probe` were listed as `keep`, not temporary deletion targets.
- `manifest`/`hash` files and all other test/source files were not classified as temporary.

## File format

`inventory.tsv` has one row per scanned file and includes relative path, absolute path, type, byte size, tracked state, recommendation, SHA-256, and rationale. `directory-inventory.tsv` records every matching cache/temp directory with aggregate size and file count. Hashes are observational only; this checkpoint does not authorize deletion. The parent cleanup/commit step must re-check active processes, re-hash kept failure evidence, and selectively stage only reviewed paths.
