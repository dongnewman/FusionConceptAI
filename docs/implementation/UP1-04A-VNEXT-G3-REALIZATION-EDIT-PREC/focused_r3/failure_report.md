# focused_r3 failure report

The single authorized focused run exited with code `1` at PID `39296`.
The raw receipt is preserved in `run_manifest.json`, `stdout.raw`, and
`stderr.raw`; focused_r1 and focused_r2 remain untouched.

The test summary was `35 passed, 1 failed, 1 errored, 0 broken, 37 total`.
The first assertion failure was at
`test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl:83`:
`state.initial_state_hash == state.state_hash` evaluated false. The first
production runtime error was then at
`src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl:429`, where
`reason_for(kind)` invokes `first(..., nothing)` on an empty generator. This
is recorded for independent postrun classification only.

No repair or focused rerun was performed. The result remains software
contract/editability evidence only: `accepted=false`, with no provider,
mesh, engineering, physical, T0/T1, or R01-R10 completion credit.
