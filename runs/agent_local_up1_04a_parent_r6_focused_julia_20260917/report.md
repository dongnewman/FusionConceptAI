# Independent postrun — parent LocalV1 R6 focused Julia rerun

- `task_id`: `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`
- `credit`: `contract_only`
- `accepted`: `false`
- `scope`: `prepare-only`; no T0/T1/T2 integration attempted
- `R01-R10`: unchanged; no stage credit claimed
- `wrapper_status`: `command_failed`
- `wrapper_exit_code`: `1`
- `command`: `julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl`
- `started_utc`: `2026-09-17T13:03:27.051655+00:00`
- `finished_utc`: `2026-09-17T13:03:29.292356+00:00`
- `stdout_sha256`: `d20838342bd317a924b29bdd1ffe91d4b15c06bb912f6eb4a740f03a4bd0241c`
- `stderr_sha256`: `10bf605ee7454e1f5dd6d093071d294440e09863b293dc1bded6ab3cabe20959`

## Independently parsed test result

The focused Julia run reached the test body but errored while constructing the positive batch:

- group: `local parent-baseline binding V1 R3`
- passed: `0`
- failed: `0`
- errored: `1`
- total: `1`

Failure: `ArgumentError: factory identity required`, raised by `LocalFactoryReceiptV1` at `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl:184`, called from the test helper at `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl:72` and surfaced at line `88`.

The raw `run.json`, `stdout.txt`, and `stderr.txt` are retained unchanged. No retry, source/test repair, or status update was performed.

## Process boundary

Pre-run and post-run inventories contained no Julia or DESC process. The only matching processes were the pre-existing `phase5_remote_session.py` pair (PIDs `8636` and `36512`); they were not touched. The wrapper does not expose a child Julia PID, so `julia_pid` is `not_captured`. The recorded wrapper interval is retained above.

This is a failed independent local execution receipt only. It does not establish source authority, physical evidence, numerical acceptance, or any R01–R10 closure.
