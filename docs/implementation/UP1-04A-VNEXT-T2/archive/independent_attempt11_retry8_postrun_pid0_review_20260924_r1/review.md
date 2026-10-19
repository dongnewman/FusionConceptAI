# Independent retry8 postrun review: Windows PID 0 inventory sentinel

Reviewed read-only on 2026-09-24. No Julia, FreeGS, heavy computation, or source edits were performed.

## Verdict and classification

**NO-GO for the retry8 runtime result; the single retry8 invocation has been consumed.** The controller exited 1 in the baseline residual-process audit before its first child `run_phase`; this is a pre-Julia process-monitor `program_exception` / incomplete audit, not a scientific failure, numerical failure, resource interruption, or coverage result. The output directory exists but has zero files. `actual_source_site_hits` remains unavailable; no acceptance credit is possible. A retry requires a versioned controller/protocol repair, independent static review, and a fresh explicit runtime grant.

## Root cause

The preserved root invocation began at `2026-09-24T20:01:28.394033+08:00` and finished at `20:01:29.031147+08:00` (0.637114 s), exit 1. Stdout is empty (0 bytes); stderr is 1122 bytes, SHA-256 `361d5a0c0a0e7fd0c78c36e9795cf36af8aebe470563cbea2721f54bc9c10c1d`. The traceback reaches controller line 3149, where `main` fails `baseline_heavy = heavy_processes()` because `_process_table_snapshot` returned incomplete at `pid_inventory_before` with `RuntimeError: PID inventory contains invalid PID values`. The first Julia `run_phase("parse_gate", ...)` is later at line 3236, so no Julia child or formal phase began.

Controller r13 still has `_valid_pid(value) == type(value) is int and value > 0` at line 194. At line 374 it applies this process identity predicate to every `psutil.pids()` inventory element and aborts at lines 375–379 if any value fails. On this Windows host, the exact Python executable from the grant (`D:\Users\Newman\anaconda3\python.exe`, psutil 5.9.0) currently reports the reserved System Idle PID 0 in both APIs:

- The first `psutil.pids()` probe returned 548 entries; a sealing-time repeat returned 554. In both samples the only value failing the r13 `type(int) and >0` rule was built-in `int(0)`. The count varies as processes start and stop; the PID 0 sentinel is the stable defect.
- `psutil.process_iter(attrs=[pid,ppid,create_time,name])` returned the row `{pid: 0, ppid: 0, create_time: 0.0, name: "System Idle Process"}`.

The runtime stderr does not serialize the exact `pids()` array, so these are independent same-host reproductions of the generic runtime rejection, rather than a run-time dump of the offending element. The failure matches the frozen source's behavior with the observed Windows psutil sentinel.

## Independent reproductions

- Real psutil probe: Python `-B`, exit 0; observed the PID 0 inventory element and PID 0 process-table row above.
- R13 fake probe: Python `-B`, exit 0, 2/2 reproductions. With native inventory `[0,41001]`, `_process_table_snapshot()` exits incomplete at `pid_inventory_before`. If the inventory is prefiltered to `[41001]` but `process_iter` still includes its PID 0 row, the function exits incomplete at `process_identity_pid`. Filtering only one side is insufficient.
- Review-only proposed normalization policy probe: Python `-B`, exit 0, 9/9 checks. It illustrates a safe contract, but it is not a production test or controller patch.
- Postrun recheck: Python `-B`, exit 0; all 459 protocol input pins rehashed with zero mismatch/missing files, planned output directory remained empty, and no Julia or r13 controller process was present at that point-in-time scan.

## Exact source and QA gap

In [independent_negative_controller_r13.py](../../../../test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r13.py), the rejected surfaces are:

- line 194: `_valid_pid` remains correctly strict for actual process identities.
- lines 374–379: `psutil.pids()` before-scan inventory rejects the Windows sentinel.
- line 391: if before-scan normalization alone is changed, the PID 0 `process_iter` row is separately rejected.
- lines 418–425: the post-scan inventory also flags PID 0 as an error.
- lines 486–495: the generation-recheck final inventory also flags PID 0 as an error.
- line 3149: baseline heavy-process audit aborts before phase execution.

The previous 166-control static QA used `FakePsutil.pids()` that returns `sorted(self.processes)` (QA lines 359–362), while its fixtures create only PIDs 41001 and 41002 (lines 403–404). No fake returned native PID 0, and no `process_iter` fixture yielded the System Idle row. Existing PPID-zero coverage is not PID-zero coverage. Therefore 166/166 passed without exercising this Windows process-table behavior.

## Minimal repair contract for a new version

1. Keep `_valid_pid` strict (`type(value) is int` and `value > 0`) for launch roots, descendants, tracked identities, process rows, and every lookup or signal target. Do not make PID 0 a process identity and never call `psutil.Process(0)` or signal PID 0.
2. Add a separate global-inventory normalizer and use it at all three sites: before inventory (374–379), after inventory (418–425), and final generation inventory (486–495). On Windows it may ignore exactly one built-in integer 0 sentinel, then compare positive PID sets. Continue rejecting booleans, floats, negative values, strings, duplicate/inconsistent entries, or zero on unsupported platforms.
3. In `process_iter`, explicitly recognize and omit only the exact Windows System Idle row (`pid=0`, `ppid=0`, `create_time=0.0`, name `System Idle Process`) before applying positive process-identity validation. Treat any unexpected PID-zero row as incomplete. This keeps the real process table fail-closed while avoiding a false rejection of the OS sentinel.
4. Add synthetic tests with `[0, positive PIDs]` at before/after/final inventory and with the System Idle row present. The full snapshot should complete over the positive PIDs, never look up or signal zero, and still detect a residual Julia/Python child. Add negatives for PID `False`, `0.0`, `-1`, malformed sentinel fields, PID-zero root/tracked identities, and ensure each remains incomplete/rejected.
5. Preserve this retry8 runtime failure unchanged. Rebuild protocol and source pins; rerun static QA and independent review against the new freeze before seeking a fresh one-attempt grant.

## Preserved run evidence

The original root grant and failure remain under `archive/root_attempt11_retry8_runtime_grant_20260924/`. Root start/finish, invocation exit 1, raw stderr, and the empty output directory were checked. The earlier static GO review remains unchanged at SHA-256 `0915889499fee7714e8db951ef0af0f2ac331984acd9da3332e8c24b7ea46b81`.
