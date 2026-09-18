# UP2-EXEC-01 — ExecutableDiffusionTransferCompositionV1 serialized Julia R6

R6 was the one allowed direct foreground Julia gate after the independent GO.
No product/test file was edited, no retry was launched, and no commit was
created by this run.

## Command and runtime evidence

Working directory: `D:\006-Programing\LMC\FusionConceptAI`

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/up2_executable_diffusion_transfer_composition_v1_tests.jl .
```

- Julia executable: `Julia-1.10.5` (`julia_pid` was unavailable from the direct foreground invocation).
- Start UTC: `2026-09-18T02:58:24.6871360Z`
- End UTC: `2026-09-18T02:58:26.8406584Z`
- Elapsed: `2.1535224` seconds
- Host PowerShell PID: `48428`
- Actual exit code: `1`
- Test summary: `0 passed, 0 failed, 1 errored, 0 broken`; `Total 1`

The sole testset errored during manufactured-case construction with
`StackOverflowError`. The exact recursive source frames are:

```text
[11] _edc_text(x::SubString{String}, field::String) ...\src\RuntimeV4\ExecutableDiffusionTransferCompositionV1.jl:28
[12] ExecutableTopologyTransferV1(..., transfer_ref::SubString{String}) ...\src\RuntimeV4\ExecutableDiffusionTransferCompositionV1.jl:206
[13] ExecutableTopologyTransferV1(..., transfer_ref::SubString{String}) (repeats 32528 times) ...\src\RuntimeV4\ExecutableDiffusionTransferCompositionV1.jl:207
[14] ExecutableTopologyTransferV1(..., transfer_ref::String) ...\src\RuntimeV4\ExecutableDiffusionTransferCompositionV1.jl:207
```

The raw Julia streams are archived beside this report as `stdout.raw` and
`stderr.raw`. They were copied from the retained temporary evidence directory
`C:\Users\Newman\AppData\Local\Temp\up2_exec_r6_fa1d9c3137b54089af0f94af848d2342`.
Archived raw SHA-256: `stdout.raw`
`58224523be6357ea1bd77cadaed88ad5b1f4d19ed051f6dbd19968bab74e1ad5`;
`stderr.raw`
`2eed8db2e3552272211aea75c38891c4b7e907d7d90fd75985c051b54ca5e00b`.

## Frozen inputs and hash audit

The five frozen source/test/fixture/oracle/static-QA SHA-256 values were
identical before and after the run:

| File | Preflight SHA-256 | Postflight SHA-256 |
|---|---|---|
| `src/RuntimeV4/ExecutableDiffusionTransferCompositionV1.jl` | `2b42a2673d03072d2fe0ff72a6110ea5881538500776bd1a916594e43056574f` | `2b42a2673d03072d2fe0ff72a6110ea5881538500776bd1a916594e43056574f` |
| `test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/up2_executable_diffusion_transfer_composition_v1_tests.jl` | `83977671e088bb2f68d45d2ec76eefda21b845356e1edac60605022dfc831d9f` | `83977671e088bb2f68d45d2ec76eefda21b845356e1edac60605022dfc831d9f` |
| `test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/up2_executable_diffusion_transfer_composition_v1_fixture.json` | `d4ff1a0add19451948973011341e3f3def13be5101e0c8150501d349438e8b17` | `d4ff1a0add19451948973011341e3f3def13be5101e0c8150501d349438e8b17` |
| `test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/up2_executable_diffusion_transfer_composition_v1_oracle.py` | `a7af9dcac99403767ebe5719c86b6e2e1e2d5789c16ae3dee495fd8039994f21` | `a7af9dcac99403767ebe5719c86b6e2e1e2d5789c16ae3dee495fd8039994f21` |
| `test/RuntimeV4/UP2ExecutableDiffusionTransferComposition/static_qa_up2_executable_diffusion_transfer_composition_v1.py` | `e308fd7346a2c55bba220c22e79f39338e95e592026db341755e2e93d6130c92` | `e308fd7346a2c55bba220c22e79f39338e95e592026db341755e2e93d6130c92` |

Before the Julia gate, the independent Python oracle and static QA each exited
`0`. Static QA reported `julia_executed=false`, `desc_executed=false`, zero
provider/mesh/solver calls, and the expected ten negative vectors.

## Process and claim boundary

Preflight and postflight process checks found zero Julia and zero DESC
processes. The run is a runtime-error evidence record only:

- `status=runtime_error`
- `claim_ceiling=manufactured_numerical_screen`
- `evidence_scope=screen_only`
- `accepted=false`
- no UP, R, L4, candidate, physics, engineering, provider, mesh, or authority credit
