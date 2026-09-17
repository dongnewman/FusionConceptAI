# G-I0 focused runtime R1

Status: **runtime_failed**. Command ran exactly once with the frozen runner; no concurrent Julia/DESC process was started.

The runner reached `UP2 additive module entry | 26/26`, then failed before the fresh probe launch with `ERROR: LoadError: UndefVarError: \`FAILURE_PROBE\` not defined` at `test/GenomeV5/UP2/run_up2_module_entry.jl:28`. The runner defines `const _FAILURE_PROBE` but interpolates `FAILURE_PROBE`; this is the exact author repair target. No rerun was attempted, and the original raw stderr/receipt remain immutable evidence.

Main PID: `71384`. UTC: `2026-09-14T04:41:15.125173+00:00` to `2026-09-14T04:41:19.539157+00:00`. Real exit: `1`. Raw stdout/stderr and their SHA256/byte counts are recorded in [receipt.json](receipt.json). The runner's authorized fresh-process failure probe was invoked serially by the frozen runner. Post-run process sweep empty: `True`.

Frozen entry/test/runner/probe/core18 hashes remained unchanged, and protected dirty-file hashes were recomputed before and after. The runtime status is bounded to G-I0 wiring behavior and does not grant UP2, B00, B04, provider, mesh, engineering, physical, or R01-R10 credit. Independent Luna R3 static review remains the prerequisite review gate.

All raw output is preserved in `stdout.log` and `stderr.log`; structured receipt, process samples, and artifact hashes are in `receipt.json`, `process_samples.json`, and `artifact_hashes.json`.
