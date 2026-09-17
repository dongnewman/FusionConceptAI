# Independent postrun — parent LocalV1 R7 focused Julia

- `task_id`: `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`
- `credit`: `contract_only`
- `accepted`: `false`
- `scope`: `prepare-only`; no T0/T1/T2 integration attempted
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_status`: `command_failed`
- `wrapper_exit_code`: `1`
- `command`: `C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe --startup-file=no --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl`
- `started_utc`: `2026-09-17T13:20:12.166286+00:00`
- `finished_utc`: `2026-09-17T13:20:21.249307+00:00`
- `stdout_sha256`: `bb25567de7df7d6eb7fb0907d5ec4b7117bf062f524317d412792c2f3a9582db`
- `stderr_sha256`: `ba9cd545e98116cac6c47ddb35dfc4cf6910dea94a9ad04669947c53fcbd46c3`

## Independently parsed test result

The focused Julia run reached the contract body and produced the outer summary:

- group: `local parent-baseline binding V1 R3`
- passed: `75`
- failed: `1`
- errored: `1`
- total: `77`
- nested negative-control group: `empty_factory_identity and empty_factory_version fail closed`, `2/2`

Two independent defects remain in this replay:

1. At test line `174`, the expression uses `in` against a `Symbol`, yielding `MethodError: no method matching iterate(::Symbol)`.
2. At test line `333`, `tamper_receipt.prior_canonical_bytes == tampered_bytes` fails; the recorded prior canonical bytes remain different from the tampered bytes.

The raw `run.json`, `stdout.txt`, and `stderr.txt` are retained unchanged. No retry, source/test repair, or status update was performed.

## Process boundary

Pre-run and post-run inventories contained no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper does not expose a child Julia PID, so `julia_pid` is `not_captured`. The recorded wrapper interval is retained above.

This is a failed independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
