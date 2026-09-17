# E1 N05 R5 stable negative-control capture precheck

Verdict: **ready_for_serial_focused_r5** (static readiness only; no runtime acceptance).

## Static closure

The current E1 test writes the positive `n05_receipts.json` and the seven
forged files below `N05_RECEIPT_OUTPUT_DIR/forged_negative_controls/` when the
focused recipe supplies that environment variable (`n05_flux_receipt_export_tests.jl:141–177`).
It emits `negative_control_manifest.json` in the same stable root and records
for each control: absolute path, byte count, SHA256, changed field, expected
targeted rejection and observed `ArgumentError` text (`:207–237`). The positive
envelope path/bytes/SHA is recorded in the same manifest. The manifest schema
is archived in `repair_r5/negative_control_manifest_schema.json`.

All seven controls are separately written and passed through the five-argument
trusted file overload:

| id | file mutation | expected targeted error |
|---|---|---|
| `source_hash` | `authored_receipts[0].source_locator.source_hash` | actual source recomputation mismatch |
| `absent_mutation_hash` | `absent_authority_receipts[0].mutation_hash` | mutation hash mismatch |
| `candidate_ref` | `candidate_ref.id` | candidate ref mismatch |
| `package_hash` | `package_hash` | package hash mismatch |
| `e0_binding_hash` | `e0.binding_hash` | E0 binding hash mismatch |
| `declaration_hash` | `declaration.authored_hash` | declaration hash mismatch |
| `missing_authored_row` | authored rows 5→4 | authored receipt count is not five |

`_n05e_expect_file_rejection` calls
`n05_check_receipt_file(path, package, e0, authored, absent, specs)` at
`:27–40`, so these are trusted file-read checks rather than schema-only checks.
The checker overload rebuilds expected rows from actual A/E0/authority/spec
inputs at `n05_flux_receipt_checker.jl:98–120`. The runner includes exporter,
checker and test in dependency order and does not modify production N05 or the
fixture. The focused capture must set `N05_RECEIPT_OUTPUT_DIR` to a new archive
directory; the test's no-environment fallback remains temporary and is not
acceptable as a focused evidence archive.

## Runtime boundary

No R5 focused runtime has been executed, so there are currently no actual R5
forged JSON bytes or observed rejection messages to independently re-hash. The
static closure is ready for exactly one serialized focused run. That run must
preserve `n05_receipts.json`, the seven files, `negative_control_manifest.json`,
the manifest SHA, process/exit/stdout/stderr receipts, and protected before/after
hashes. The R5 repair archive records two unrelated/concurrent Julia processes
in its historical sweep; R5 did not start or terminate them. The current sweep
is empty.

The checker and exporter still share `_n05e_row`, so formal B04 independent
checker/two-process replay remains open. No B04, provider, mesh, engineering,
physical or R01–R10 credit is granted.
