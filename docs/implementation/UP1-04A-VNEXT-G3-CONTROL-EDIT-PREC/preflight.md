# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC static preflight

Date: 2026-09-15

The implementation was checked against AD-32 independent status review R1
(`pass_limited`), the AD-31 R7 proposal/review, the current G3
SourceFeedback V1 contract, the old ControlGenomeV5 semantics, and the AD-31
realization sibling. The only implementation paths are the new control source,
the new focused test, and this archive directory. No shared entry point,
registry, package, T0, old source/test/receipt, or core planning file was
edited.

The static audit found the required closed signal/controller/fault/plan body,
candidate-parent-child key, derived parent/source-record/payload refs, source
record/content/initial/current/operation hash layers, typed absence, separate
contract/physical statuses, immutable source payload, one-fault mode-only
operation, closed operation history, duplicate ID and previous/last/current
chain checks, canonical bytes, and positive/negative test cases. No Julia or
DESC command was run during this preflight.

## Frozen inputs and pre-run environment

| item | SHA-256 or observation |
|---|---|
| `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl` | `bf5d2b398798c72847364832be610fc1639882fdaf7258f9e73c04bf8e4409a6` |
| `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` | `333cc2e88deeb668301bc7eaa75257009151cb3c8c98e94c0cabb59f5fcbadbb` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |
| `src/GenomeV5/G3/ControlGenomeV5.jl` | `eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135` |
| `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl` | `01bdfd40f1a824b8530fc51f6ff319e40dda4edbce275c62276e5431f78f25bf` |
| `docs/implementation/AD-32/manifest.json` | `c160c6fe95cc427a2eb260f932ac88ec4661ed146b3593dac12b8fa9beec867e` |
| `Project.toml` | `923b78938e12c27e836b269d71a539ae7bb292c9fe9f8cb92f9f9a8cea1370e2` |
| dirty worktree rows before test | `4306` |
| Julia processes before test | `0` |
| DESC-named processes before test | `0` |
| Julia executable | `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe` |
| Julia version | `1.10.5.0` |

`git diff --check` exited `0` before the dedicated run; only existing
line-ending conversion warnings were emitted by Git.

## Planned execution gate

The only execution command authorized for this slice is:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl
```

The raw stdout/stderr, PID, UTC start/end, exit code, byte count, SHA-256,
post-run dirty/process observations, and any repair round will be recorded in
this archive. A passing focused test remains contract-only and leaves actual
control/source-backed T1, provider, mesh, engineering, physical, search,
B00/B04 and R01–R10 credit false.

