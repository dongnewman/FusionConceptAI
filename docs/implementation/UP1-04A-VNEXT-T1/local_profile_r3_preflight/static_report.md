# UP1-04A VNext T1 local profile R3 preflight

## Scope

This append-only profile freezes the post-R2 factory-contract projection fix
and adds only `runner.ps1`, `manifest.json`, this report, and the durable
`runtime.lock` placeholder. It does not invoke Julia, does not reuse or alter
R1/R2 locks or receipts, and does not modify source or test inputs. The frozen
child command is:

```text
julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl
```

The operator command is:

```powershell
pwsh -NoProfile -File .\docs\implementation\UP1-04A-VNEXT-T1\local_profile_r3_preflight\runner.ps1
```

## Evidence contract

- The launch process assigns `JULIA_NUM_THREADS=1` and permits one bounded
  `Process.WaitForExit(milliseconds)` call with a default 300 second limit.
- `runtime.lock` is acquired atomically with `FileMode.CreateNew`; an existing
  lock or any existing `run_*` receipt refuses overwrite. There is one
  `Process.Start()` site and no retry.
- `startCount` and `startedOnce` become true only after `Start()` succeeds.
  A failed start remains `0/false`.
- Preflight requires zero Julia/DESC processes. Postflight records two
  consecutive zero observations 250 ms apart. Timeout termination kills the
  started Julia PID and discovered descendants; `timeout_kill.json` is
  conditional and exists only if timeout termination is attempted.
- All 15 manifest paths are checked against frozen SHA-256 values before and
  after execution. Any missing, unexpected, or changed path fails closed.
- Runtime metadata and capture receipts carry `accepted=false` and
  `claimCeiling=contract_only`. A runtime exit of zero is not by itself T1,
  T2, UP1, authority, provider, mesh, solver, physical, engineering, or
  search credit.

## R3 freeze

R3 is based on `61ec91e` (`fix: correct T1 factory contract projection`). The
`CandidateStatePackageV5Next.jl` validator now reads the factory contract from
`declaration.factory_receipt.factory_result.contract_ref`; the focused test
and static QA assert this required path and reject the former T0 declaration
path. R1 and R2 remain immutable historical receipts.

## Static checks

| Check | Result |
|---|---|
| PowerShell parser reports zero errors | PASS (preflight) |
| Manifest JSON parses; protected paths are unique | PASS (preflight) |
| Frozen command and `JULIA_NUM_THREADS=1` are present | PASS |
| Default timeout is 300 seconds and bounded `WaitForExit` is present | PASS |
| Atomic `FileMode.CreateNew` lock and receipt refusal are present | PASS |
| One `Start()` site and explicit no-retry policy are present | PASS |
| Start counters are committed only after successful `Start()` | PASS |
| Before/after hash comparison and fail-closed postflight are present | PASS |
| Two postflight process observations are present | PASS |
| Julia/DESC execution during R3 preparation | NOT PERFORMED |

The profile remains `status=preflight_only`, `accepted=false`, and
`claim_ceiling=contract_only`. No T1 runtime, T2, or UP1 credit is claimed.
