# UP2-EXEC-DECLARED-G123-DIFFUSION-V1 — R22 preflight wrapper

## Scope and execution boundary

This is a read-only preparation package. During its preparation and static
self-test, `runner.ps1` was not invoked and no Julia or DESC process was
started. No product or test file was edited. Only the three files in this
directory were added.

The runtime operator may invoke the wrapper once with:

```powershell
pwsh -NoProfile -File .\docs\implementation\UP2-EXEC-DECLARED-G123-DIFFUSION-V1\agent_local_r22_preflight\runner.ps1
```

The default timeout is 300 seconds. A timeout uses `WaitForExit(milliseconds)`
and kills only the started `$processId` plus descendants discovered through
their parent-process IDs. Redirected stdout/stderr are then drained and the
receipt is classified as `timeout`; there is no retry.

## Exactly-once receipt policy

Before any child start, the wrapper acquires `runtime.lock` with atomic
`FileMode.CreateNew`. It refuses an existing lock and refuses any existing
`run_*` receipt directory, then creates a new UTC timestamp/GUID run directory.
The durable lock is intentionally retained after completion, so the same
preflight directory cannot overwrite or repeat a runtime receipt. All runtime
artifacts are written below that new directory.

## Strict evidence invariants

The wrapper freezes exactly six protected files before the child start and
re-hashes them after the child finishes. `hashesComparable` is true only when
both maps contain exactly the same six paths and six valid 64-hex SHA-256
values. Otherwise `ownedFilesUnchanged=false` and the receipt fails. A change
in any of the six files also fails the receipt.

Postflight process evidence requires two consecutive empty
`Get-CimInstance Win32_Process` observations, separated by 250 ms. The two
snapshots are stored separately. `run_metadata.json` and `capture_failure.json`
always carry the same `status`; the latter therefore cannot silently describe
a different failure state.

## Static PowerShell/AST self-test

The following checks were run with PowerShell only, without invoking the
runner:

| Check | Result |
|---|---|
| `runner.ps1` parsed by `[System.Management.Automation.Language.Parser]::ParseFile` | PASS; 0 parser errors |
| Six distinct manifest protected files and current SHA-256 values | PASS; 0 mismatches |
| Default timeout is 300 seconds | PASS |
| `WaitForExit($timeoutMs)` is present | PASS |
| Timeout classification and process-tree kill are present | PASS |
| Atomic `FileMode.CreateNew` lock and unique `run_*` directory | PASS |
| Existing lock/receipt refusal and no overwrite path | PASS |
| Strict `hashesComparable` six-before/six-after gate | PASS |
| `$processId` used; `$PID` absent | PASS |
| One child `Start()` site and no retry path | PASS |
| Two postflight process observations | PASS |
| stdout/stderr, exit, time, thread, hash and failure artifacts | PASS |
| Julia/DESC execution during this self-test | NOT PERFORMED |

## Frozen six-file set

The exact values are recorded in `manifest.json` and are verified read-only
by the static self-test:

| Relative path | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl` | `45e9fee04bebe7a62ee07456acee42834da7b8c9a8ca5bce95fdf2fe90013bef` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.jl` | `e57e3d1060b1ea3e86c7d9ff6b2ae73f41ce9275f105c0e10482703095029eda` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/focused_tests.jl` | `b68c39a986beb21187bc737cbae02f97d7ee52b73b536fc53431bdf664aa90f3` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.json` | `bcb56c536e90f0643fb7e7abdfd3441110e573327ec993421b022211a7cb9d2e` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/independent_oracle.py` | `eb1f17556b4fd664391e1fb3f2cac06295c167b1be47a8f7447c63434c9134cf` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/static_qa.py` | `4135b46d46fe9b12c590f6ad2637981b5124f08c5886e4be1d49471b0ed16e2e` |

R22 remains a preflight package with `claim_ceiling=screen_only`; it does not
provide a positive Julia execution result until a separate, approved runtime
operator consumes the one-shot receipt.
