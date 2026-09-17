# Focused R1 report correction

This correction supplements the original `report.md` without modifying the original report, raw stdout/stderr, receipt, process samples, or source/test files.

The original report contained the sentence:

> The runner's authorized fresh-process failure probe was included serially by the frozen runner.

That sentence is inaccurate for this failed run. The runner reached `UP2 additive module entry | 26/26`, then stopped at `test/GenomeV5/UP2/run_up2_module_entry.jl:28` with `UndefVarError: \`FAILURE_PROBE\` not defined`. The runner defines `_FAILURE_PROBE` but interpolates `FAILURE_PROBE`, so the fresh-process failure probe was **not started**.

The immutable evidence remains `stdout.log` (only the 26/26 summary), `stderr.log` (the exact `UndefVarError`), `receipt.json` (main PID `71384`, real exit `1`, empty post-process sweep), and `process_samples.json` (no probe child observed). No Julia rerun was performed. This correction file's SHA256 is recorded after creation in the parent handoff message.
