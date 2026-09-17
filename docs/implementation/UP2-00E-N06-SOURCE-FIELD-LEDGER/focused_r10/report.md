# N06 focused R10 receipt

This is the single serial focused run authorized after the R12 independent static precheck. It used the frozen N06 source, test, fixture, runner, G1/G2/G3, E0, and integration inputs recorded in `input_hashes_before.json`. No source or test repair was made.

Command: `julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl`

- UTC start: `2026-09-14T06:17:04.9578748Z`
- UTC end: `2026-09-14T06:19:52.5473688Z`
- main PID: `33836`; child Julia PID was observed in `process_snapshots.json`
- real process exit: `0`
- stdout: 3852 bytes, SHA256 `d6975da0772b9945c73aa70e46237c4ce27372cb02e20d9419b50ac7c5e9bec3`
- stderr: 0 bytes, SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- postflight Julia/DESC process count: `0`

The focused summaries were: G1 `47/47`, `21/21`; G2 `57/57`, `59/59`, `8/8`; G3 `49/49`, `35/35`, `23/23`; N06 actual-A `28/28`, typed occurrence index `3/3`, source-derived mutation controls `31/31`, and shared-owner/E0 identity boundary `40/40`.

The five mutation controls reached the unconditional fixture loop (`31/31`). The two selector controls are the real `missing_source_selector` and `wrong_source_selector` paths at test lines 342-381; they call `G.n06_projection_from_a(package,e0)`, assert targeted errors, and restore the selector in `finally`. Their reachability is included in the completed `40/40` boundary group and in `run_summary.json`.

`protected_hash_comparison.json` shows all 11 frozen N06/G1/G2/G3/E0/integration inputs unchanged before versus after. The earlier R9 exit-1 evidence remains immutable in `focused_r9/`; this R10 receipt is a separate successful focused run.

This receipt supports only the executed software/contract test slice. It does not establish formal B04, provider resolution, mesh, engineering, physical, or R01-R10 credit.

