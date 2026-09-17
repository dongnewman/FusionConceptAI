# Focused R2 first-failure receipt

The single authorized command was:

`julia --startup-file=no --project=. test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl`

The launcher PID was `52016`; it exited `1`. Julia reported three passed
assertions, zero failed assertions, one error, and four total test expressions.
The first and only observed error occurred while constructing the valid source
payload: `UndefVarError: record not defined` at
`src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl:487`, in the
`G3RealizationSourcePayloadV1` constructor's source-record validation path.
The complete raw streams are preserved in `stdout.raw` and `stderr.raw`; byte
counts and SHA256 values are in `run_manifest.json`.

This receipt records the first real failure only. No source, test or contract
repair was made and the command was not retried. The focused run grants no
implementation acceptance, physical resolution, provider, engineering, mesh,
T0/T1 or R01–R10 credit. The implementation node remains `accepted=false`.

