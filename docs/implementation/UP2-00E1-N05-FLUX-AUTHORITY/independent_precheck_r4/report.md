# E1 N05 R4 trusted file-read negative-control precheck

Verdict: **changes_requested**. The code/test path statically exercises the new trusted overload for the positive receipt and seven negative envelopes, but the seven negative JSON files are written below a fresh `mktempdir()` and no stable output path/hash manifest records them. This is insufficient for a serial focused receipt and independent replay archive.

## What is closed by static inspection

- `n05_check_receipt_file(path, package, e0, authored, absent, specs)` at `test/GenomeV5/UP2/n05_flux_receipt_checker.jl:127–134` reads JSON and dispatches to the five-argument trusted source-bound checker.
- The positive exported path is checked through that same overload at `n05_flux_receipt_export_tests.jl:139–148`.
- Seven separate JSON files are constructed and written at `:154–185`; each is passed to `_n05e_expect_file_rejection`, which calls the trusted overload at `:27–38`:

| control | serialized file | expected targeted rejection |
|---|---|---|
| authored source hash | `forged_authored_source_hash.json` | actual source recomputation mismatch |
| absent mutation hash | `forged_absent_mutation_hash.json` | mutation hash mismatch |
| candidate ref | `forged_candidate_ref.json` | candidate ref mismatch |
| package hash | `forged_package_hash.json` | package hash mismatch |
| E0 binding hash | `forged_e0_binding_hash.json` | E0 binding hash mismatch |
| declaration hash | `forged_declaration_hash.json` | declaration hash mismatch |
| omitted authored row | `forged_missing_authored.json` | authored count is not five |

The rejection matrix agrees with these seven calls and marks each trusted path. The trusted checker rebuilds expected authored/absent rows using actual `package`, `e0`, `authored`, `absent`, and `specs` at checker lines `98–120`; this is source-bound logic rather than the one-argument schema-only file check.

## Blocking archive defect

`n05_flux_receipt_export_tests.jl:164` sets `negative_dir = joinpath(mktempdir(), "n05_forged_receipts")`. The seven files therefore disappear from the focused archive after the process exits. The test does not print their paths, compute their SHA256 values, or emit a per-file manifest. `N05_RECEIPT_OUTPUT_DIR` only controls the positive `n05_receipts.json` path at lines `132–138`; it does not control `negative_dir`. The R4 `rejection_matrix.json` lists names and expected messages but contains no actual output paths or hashes.

Consequently, the seven controls are statically proven to call the trusted overload, but their post-run serialized bytes are not independently reviewable. This is a concrete reproducibility gap, so this precheck is not `ready_for_serial_focused_r4`.

## Minimal correction before focused execution

Use the frozen `N05_RECEIPT_OUTPUT_DIR` as the parent of a deterministic `forged_negative_controls/` directory. Require that environment/output directory for this focused recipe, write all seven files there, compute each file's byte count and SHA256, and emit a stable `negative_control_manifest.json` containing id, path, hash, bytes, mutation, trusted overload, and expected rejection. The focused receipt must include that manifest hash; the repair matrix can remain the semantic matrix. The test should assert each path exists after writing and that the manifest covers exactly seven unique files.

The positive trusted file-read check and actual-A/E0/spec recomputation should remain unchanged. The exporter and checker still share `_n05e_row`; an independent checker and two-process replay remain formal B04 requirements. No local R4 result can grant physical, engineering, provider, mesh, B00/B04, or R01–R10 credit.

## Protected scope and limitations

Current hashes confirm the exporter, production N05 source, fixture, runner, focused R4 receipt, and R1–R3 raw archives were not edited by this review. No Julia/DESC was run. This is a static precheck only; R4's own runtime field is `not_run` in its repair manifest.
