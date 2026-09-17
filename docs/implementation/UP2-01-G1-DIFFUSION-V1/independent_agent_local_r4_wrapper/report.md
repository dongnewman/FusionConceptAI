# Independent agent_local replay R4 — G1 diffusion V1

- `credit`: `contract_only`
- `accepted`: `false`
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_exit_code`: `0`
- `command`: `julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl`
- `started_utc`: `2026-09-17T12:00:24.136441+00:00`
- `finished_utc`: `2026-09-17T12:00:30.382939+00:00`
- `stderr`: empty (`sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
- `stdout_sha256`: `d42a20cb648a8ea55d58d59e1b55044efde2103b9faccc63e0504c8d37e71ca1`

## Independently parsed test totals

The three Julia `Test Summary` rows in the immutable wrapper log are:

| group | pass | total |
|---|---:|---:|
| positive declaration and typed receipt | 41 | 41 |
| fail-closed negative controls | 42 | 42 |
| source edit changes identity | 5 | 5 |
| **total** | **88** | **88** |

## Process boundary

The pre-run and post-run process inventories found no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper's `run.json` does not expose the child Julia PID, so `julia_pid` is explicitly `not_captured` rather than inferred. The time interval above is the wrapper's recorded process interval.

This is an independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
