# Independent agent_local replay R3 — G2 metric boundary V1

- `credit`: `contract_only`
- `accepted`: `false`
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_exit_code`: `0`
- `command`: `julia --startup-file=no --project=. test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl`
- `started_utc`: `2026-09-17T11:56:48.049607+00:00`
- `finished_utc`: `2026-09-17T11:56:57.526839+00:00`
- `stderr`: empty (`sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
- `stdout_sha256`: `275f6ffb447513e88454643ba68da7cf0dd72e8947e9ec15d74c7ee45e264c71`

## Independently parsed test totals

The seven Julia `Test Summary` rows in the immutable wrapper log are:

| group | pass | total |
|---|---:|---:|
| executable chart metric and determinant orientation | 20 | 20 |
| candidate-owned mesh and face declarations | 10 | 10 |
| mesh guards, chart binding, canonical ordering and classification | 16 | 16 |
| editing source fields rebuilds identity | 5 | 5 |
| contradictions fail closed and missing authority is deferred | 14 | 14 |
| unit exponent algebra and derived measures | 15 | 15 |
| label erasure boundary | 5 | 5 |
| **total** | **85** | **85** |

## Process boundary

The pre-run and post-run process inventories found no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper's `run.json` does not expose the child Julia PID, so `julia_pid` is explicitly `not_captured` rather than inferred. The time interval above is the wrapper's recorded process interval.

This is an independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
