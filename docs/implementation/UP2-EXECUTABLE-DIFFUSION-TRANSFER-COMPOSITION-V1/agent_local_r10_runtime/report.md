# UP2-EXEC-01 — ExecutableDiffusionTransferCompositionV1 serialized Julia R10

R10 was the sole direct foreground Julia run after the independent R9 GO. The
R9 frozen inputs were verified against all five recorded SHA-256 values before
execution. No source or test files were edited, no DESC process was launched,
and no retry or relaunch occurred.

## Runtime evidence

Working directory: `D:\006-Programing\LMC\FusionConceptAI`

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/up2_executable_diffusion_transfer_composition_v1_tests.jl .
```

- Julia: `1.10.5`
- UTC start: `2026-09-18T04:32:19.8653267Z`
- UTC end: `2026-09-18T04:32:24.0019170Z`
- Host PowerShell PID/session: `45980/1`
- Julia PID: unavailable from direct foreground invocation
- Actual exit code: `0`
- Test summary: `68 passed, 0 failed, 0 errored, 0 broken; Total 68`
- Pre/post process guard: `0 Julia, 0 DESC`

The raw stdout is archived as `stdout.raw` and raw stderr as `stderr.raw`.
stdout is 172 bytes (`c15a892675b5c56627e43ad715cdb8e6dd2f33ed3ba12f25ec8fce665b0f5e6c`);
stderr is empty (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).

## Frozen hashes

All five R9 hashes matched before and after the run; see `pre_run.json`,
`post_run.json`, and `manifest.json` for the complete mapping. No file changed.

## Preserved failure lineage and claim boundary

The prior R8 raw runtime evidence remains unchanged: `32 passed, 16 failed,
7 errored, 0 broken, exit 1`. R10 is a corrected runtime screen only and does
not erase or rewrite that failure lineage.

The result remains `claim_ceiling=manufactured_numerical_screen`,
`evidence_scope=screen_only`, and `accepted=false`. It provides no UP/R/L4,
candidate, physical, engineering, or deployability credit.
