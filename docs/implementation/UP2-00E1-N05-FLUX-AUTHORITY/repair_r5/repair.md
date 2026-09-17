# E1 N05 stable serialized negative-control capture repair R5

R4's trusted file-read overload and targeted rejection checks remain intact.
R5 removes the remaining review gap: when `N05_RECEIPT_OUTPUT_DIR` is set,
the test writes `n05_receipts.json`, seven forged JSON files under
`forged_negative_controls/`, and `negative_control_manifest.json` beneath that
same stable directory. The manifest records every absolute path, byte count,
SHA-256, changed field, expected targeted rejection and observed error message,
plus the positive envelope path/bytes/SHA. With no environment override the
test still uses a temporary directory but prints the manifest path and SHA.

The focused capture must preserve the manifest and hash all seven files and
the positive envelope in its run receipt. This repair does not change the
exporter, N05 production source, checker, runner, core documents or historical
R1-R4/raw evidence. No Julia/DESC was run. Full receipt-export remains
`changes_requested`; no B04, provider, mesh, engineering, physical or R01-R10
credit is claimed. A static process sweep during archive QA observed two
unattributed Julia processes started by concurrent work; R5 did not start,
terminate, or use them, and the snapshot is preserved in `process_sweep.json`.
