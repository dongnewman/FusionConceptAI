# UP1-04A VNext T1 local profile R2 preflight

## Scope

This append-only profile adds only `runner.ps1`, `manifest.json`, and this
static report. It does not invoke Julia, does not reuse or remove any older
profile lock or receipt, and does not modify source or test inputs. The T1
child command is frozen as:

```text
julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl
```

The operator command is:

```powershell
pwsh -NoProfile -File .\docs\implementation\UP1-04A-VNEXT-T1\local_profile_r2_preflight\runner.ps1
```

## Safety and evidence contract

- `JULIA_NUM_THREADS=1` is assigned in the launch process.
- The default timeout is 300 seconds. Timeout classification kills only the
  started Julia PID and discovered descendants, drains redirected streams,
  and never retries. `timeout_kill.json` is conditional and is emitted only
  when timeout termination is attempted.
- `runtime.lock` is acquired atomically with `FileMode.CreateNew` and remains
  after an attempt. An existing lock or receipt directory refuses overwrite.
- `startCount` and `startedOnce` are assigned only after `Process.Start()`
  returns successfully. A failed start therefore remains `0` and `false`.
- The wrapper requires no Julia/DESC process before launch and two consecutive
  zero observations after launch, separated by 250 ms.
- All 15 manifest paths are SHA-256 checked before and after execution. Any
  missing, unexpected, or changed path fails closed. The manifest freezes the
  current T1 test bytes/hash and the five tracked dirty protection targets;
  the unrelated dirty root README is also retained in the protected set.
- The receipt stores process snapshots, before/after hashes and changes,
  stdout/stderr, exit code, thread data, UTC timing, metadata, and timeout
  details when applicable. Every runtime metadata/capture receipt explicitly
  carries `accepted=false` and `claimCeiling=contract_only`.

## Static checks

| Check | Result |
|---|---|
| PowerShell parser reports zero errors | PASS (preflight) |
| Manifest JSON parses and protected paths are unique | PASS (preflight) |
| Frozen command and `JULIA_NUM_THREADS=1` are present | PASS |
| Default timeout is 300 seconds and bounded `WaitForExit` is present | PASS |
| Atomic `FileMode.CreateNew` lock and receipt refusal are present | PASS |
| One `Start()` site and explicit no-retry policy are present | PASS |
| Start counters are committed only after successful `Start()` | PASS |
| Before/after hash comparison and fail-closed postflight are present | PASS |
| Two postflight process observations are present | PASS |
| Julia/DESC execution during preparation | NOT PERFORMED |

The profile remains `status=preflight_only`, `accepted=false`, and
`claim_ceiling=contract_only`. No T1 runtime or T2 credit is claimed.
