# Independent agent_local replay R3 — G3 source/feedback V1

- `credit`: `contract_only`
- `accepted`: `false`
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_exit_code`: `0`
- `command`: `julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl`
- `started_utc`: `2026-09-17T11:58:47.214162+00:00`
- `finished_utc`: `2026-09-17T11:58:55.157583+00:00`
- `stderr`: empty (`sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
- `stdout_sha256`: `49e44ef89e869be23666f05715cb6ca455e54dd251b8f72749fe41c0fc892b82`

## Independently parsed test totals

The four Julia `Test Summary` rows in the immutable wrapper log are:

| group | pass | total |
|---|---:|---:|
| source/feedback typed law | 9 | 9 |
| external authority and resolution ceiling | 9 | 9 |
| typed contradiction and edit identity | 27 | 27 |
| duplicate and pairing rejection | 18 | 18 |
| **total** | **63** | **63** |

## Process boundary

The pre-run and post-run process inventories found no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper's `run.json` does not expose the child Julia PID, so `julia_pid` is explicitly `not_captured` rather than inferred. The time interval above is the wrapper's recorded process interval.

This is an independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
