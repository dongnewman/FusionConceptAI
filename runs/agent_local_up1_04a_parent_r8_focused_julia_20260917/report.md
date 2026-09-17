# Independent postrun — parent LocalV1 R8 focused Julia

- `task_id`: `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`
- `credit`: `contract_only`
- `accepted`: `false`
- `scope`: `prepare-only`; no T0/T1/T2 integration attempted
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_status`: `command_completed`
- `wrapper_exit_code`: `0`
- `command`: `C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe --startup-file=no --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl`
- `started_utc`: `2026-09-17T13:30:50.876063+00:00`
- `finished_utc`: `2026-09-17T13:30:54.990973+00:00`
- `postrun_head`: `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`
- `stdout_sha256`: `70c2336067db6b6f1fbabae55e1fef4393bf917e11bca51abeab741f2779fb51`
- `stderr`: empty (`sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)

## Independently parsed test result

The focused Julia run passed its complete contract group:

- group: `local parent-baseline binding V1 R3`
- pass: `82`
- total: `82`
- fail/error: `0/0`

Runtime markers were present and preserved:

```text
VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined
VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true
VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false
```

The raw `run.json`, `stdout.txt`, and `stderr.txt` are retained unchanged. This is a clean focused contract replay, not parent authority or formal stage acceptance.

## Process boundary

Pre-run and post-run inventories contained no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper does not expose a child Julia PID, so `julia_pid` is `not_captured`. The recorded wrapper interval is retained above.

This receipt remains `prepare-only`, `accepted=false`, and grants no T0/T1/T2, provider, mesh, engineering, physical, search, B00/B04, or R01–R10 credit.
