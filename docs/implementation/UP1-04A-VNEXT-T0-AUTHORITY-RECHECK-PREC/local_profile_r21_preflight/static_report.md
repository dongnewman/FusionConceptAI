# T0 authority recheck R21 one-shot runner preflight

This directory adds only a future runtime wrapper, its frozen-input manifest,
and this static report. Preparation did not invoke Julia or DESC and did not
modify the authority test, local adapter, transport test, or fixture.

The eventual operator command is:

```powershell
pwsh -NoProfile -File .\docs\implementation\UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC\local_profile_r21_preflight\runner.ps1
```

The command passed to the child is exactly:

```text
julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .
```

The default `WaitForExit` budget is 600 seconds. `JULIA_NUM_THREADS=1` is set
in the same launch process. A timeout records a concrete timeout reason and
kills only the launched Julia PID and descendants discovered through their
parent-process IDs. Redirected stdout/stderr, true child exit code, PID,
UTC start/end, duration, and launch OS thread count are retained in the new
receipt directory.

The durable `runtime.lock` and refusal of any existing `run_*` directory make
the wrapper exactly-once: there is one `Start()` site, no retry, and no
overwrite path. Before launch, exactly six protected files are checked against
the hashes frozen in `manifest.json`. After launch, the same six paths are
re-hashed and the receipt fails unless the maps are exactly six valid SHA-256
values with no changes. Postflight requires two consecutive empty Julia/DESC
process observations. DESC is never launched by this wrapper.

## Static-only self-test

PowerShell parser and text checks passed without invoking the runner:

| Check | Result |
|---|---|
| `[System.Management.Automation.Language.Parser]::ParseFile` | PASS; 0 errors |
| Manifest has six unique protected paths and current SHA-256 values | PASS; 0 mismatches |
| Default timeout is 600 seconds | PASS |
| `WaitForExit($timeoutMs)` and timeout reason are present | PASS |
| Owned PID-tree kill is present | PASS |
| Atomic `FileMode.CreateNew` lock and fresh `run_*` directory | PASS |
| Strict six-before/six-after hash gate | PASS |
| Two postflight zero observations | PASS |
| Exactly one `Start()` and explicit `autoRetry=$false` | PASS |
| Test/adapter/fixture files changed by preparation | PASS; none |
| Julia/DESC execution during self-test | NOT PERFORMED |

The runtime remains unexecuted, `accepted=false`, and `claim_ceiling=contract_only`.
