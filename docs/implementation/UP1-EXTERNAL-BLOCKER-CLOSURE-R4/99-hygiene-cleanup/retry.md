# UP1 External Closure R4 hygiene cleanup retry

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Requested method: one PowerShell execution only; four allowed roots were prepared for `Resolve-Path`/`StartsWith` validation, explicit `Remove-Item -LiteralPath -Force` file deletion, empty-directory deletion, and post-check.
- Execution result: **not executed**. The single PowerShell process was rejected before creation; no files or directories were deleted.

## Exact tool error

```text
exec_command failed: CreateProcess { message: "Rejected(\"... pwsh.exe ... -Command ...\") ... rejected: blocked by policy" }
```

The tool returned `Script failed` with `CreateProcess ... Rejected ... blocked by policy`. The rejection occurred before PowerShell started, so there is no cleanup output, no post-cleanup inventory, and no alternative shell was attempted.

## Scope prepared for the rejected execution

- `D:\006-Programing\LMC\FusionConceptAI\tools\up1_external_closure_r3\atomic_bundle`
- `D:\006-Programing\LMC\FusionConceptAI\test\up1_external_closure_r3\atomic_bundle`
- `D:\006-Programing\LMC\FusionConceptAI\tools\up1_external_closure_r4`
- `D:\006-Programing\LMC\FusionConceptAI\test\up1_external_closure_r4`

The separately authorized misplaced directory was also prepared for an exact-path, empty-only check:

`D:\006-Programing\LMC\docs\implementation\UP1-EXTERNAL-BLOCKER-CLOSURE-R4\99-hygiene-cleanup`
