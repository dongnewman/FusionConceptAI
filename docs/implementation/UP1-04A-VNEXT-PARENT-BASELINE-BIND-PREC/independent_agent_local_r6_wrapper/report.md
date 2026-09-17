# Independent agent_local replay R6 — parent LocalV1 (failed)

- `credit`: `contract_only`
- `accepted`: `false`
- `scope`: `prepare-only`; no T0/T1/T2 integration attempted
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_status`: `command_failed`
- `wrapper_exit_code`: `1`
- `command`: `julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl`
- `started_utc`: `2026-09-17T12:51:21.364991+00:00`
- `finished_utc`: `2026-09-17T12:51:23.634532+00:00`
- `stdout`: empty (`sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
- `stderr_sha256`: `fe6009d987bed400ac78cae61eeb427f8f179b747a59d40a3fa0d336b1382a4f`

## Failure

Julia stopped before executing any test group with a parse error in
`test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl:67:45`:

`identifier or parenthesized expression expected after $ in string`

The raw `stderr.txt`, `stdout.txt`, and `run.json` are retained unchanged. No retry or source/test repair was performed in this replay.

## Process boundary

The post-run inventory found no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper does not expose a child Julia PID, so `julia_pid` is `not_captured`. The recorded wrapper interval is retained above.

This is a failed independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
