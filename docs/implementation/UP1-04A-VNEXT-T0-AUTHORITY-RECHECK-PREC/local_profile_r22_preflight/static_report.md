# T0 authority recheck R22 local preflight runner

## Scope and execution boundary

This append-only package adds only `runner.ps1`, `manifest.json`, and this
`static_report.md` below `local_profile_r22_preflight`. It does not reuse,
open, remove, or modify the R21 `runtime.lock` or any older profile lock.
Preparation and static verification did not invoke Julia, DESC, the runner, or
the authority test, and did not edit source/test inputs.

The eventual operator command is:

```powershell
pwsh -NoProfile -File .\docs\implementation\UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC\local_profile_r22_preflight\runner.ps1
```

The child command is exactly:

```text
julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .
```

## Safety contract

- `JULIA_NUM_THREADS=1` is assigned in the launch process.
- The default `WaitForExit(milliseconds)` budget is 300 seconds.
- A timeout records the reason, kills only the started Julia PID and descendants
  discovered through parent-process IDs, drains redirected streams, and emits a
  timeout receipt. There is no automatic retry.
- A new atomic `FileMode.CreateNew` `runtime.lock` is acquired only in this
  new profile directory. An existing lock or any existing `run_*` directory
  refuses overwrite; the durable lock remains after an attempt.
- The wrapper requires zero Julia/DESC processes before launch and two
  consecutive zero observations after launch, separated by 250 ms.
- Every protected path in the manifest is hashed before and after execution.
  Both maps must contain the same complete set of valid SHA-256 values and no
  value may change.
- The receipt retains process snapshots, frozen/postflight hashes and changes,
  raw stdout/stderr, exit code, thread/environment data, UTC timing, timeout
  kill data when applicable, run metadata, and capture-failure classification.

## Frozen current inputs

`manifest.json` freezes **74** exact relative paths:

- 48 package source files reachable from `src/FusionConceptAI.jl`;
- 20 explicit GenomeV5 loader/direct integration source files;
- 4 authority/transport test inputs (two Julia tests, static QA, local fixture);
- `Project.toml` and `Manifest.toml` dependency declarations.

Each entry records current byte length and lowercase SHA-256. The set includes
the local transport helper and authority adapter, all source files loaded by
the package entry point and GenomeV5 loader, the direct G1/G2/G3 authority
helpers, both focused test files, static QA, local fixture, and Julia project
locks. It is a content-integrity gate, not a proof of semantic or physical
correctness.

## Static-only checks

These checks are performed with PowerShell and file/hash inspection only; the
runner itself remains uninvoked:

| Check | Result |
|---|---|
| PowerShell parser reports zero errors | PASS |
| Manifest JSON parses and protected paths are unique | PASS |
| Manifest protected-file count is 74 and every current path/hash matches | PASS |
| Exact command text and `JULIA_NUM_THREADS=1` are present | PASS |
| Default timeout is 300 seconds and `WaitForExit($timeoutMs)` is present | PASS |
| Atomic `FileMode.CreateNew` lock and fresh `run_*` refusal are present | PASS |
| Timeout reason plus owned PID-tree kill are present | PASS |
| Before/after hash comparison is complete and fail-closed | PASS |
| One `Start()` site and explicit `autoRetry = $false`; no retry loop | PASS |
| Two postflight process observations are present | PASS |
| Full receipt artifact names are present | PASS |
| Julia/DESC execution during preparation | NOT PERFORMED |

The package remains `status=preflight_only`, `accepted=false`, and
`claim_ceiling=contract_only`. No runtime result or authority credit is
claimed.
