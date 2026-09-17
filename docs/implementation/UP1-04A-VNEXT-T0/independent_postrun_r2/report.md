# UP1-04A-VNEXT-T0 focused R2 independent postrun review

## Verdict

`julia_test_failed`; `production_gap_classification_missing`;
`accepted=false`; `T1=no_go`.

This was a real Julia invocation, not a launcher failure. PID `43044` started
at `2026-09-14T23:17:00.1036158+00:00`, ended at
`2026-09-14T23:17:10.3812580+00:00`, and returned exit code `1`. The raw
stdout/stderr streams are present and their hashes match the R2 manifest. The
first group stopped at test line 139 with `9 passed, 1 failed, 0 errored, 0
broken`; later groups have no execution credit. The failure is not physical
evidence and does not change the contract-only ceiling.

## First failure diagnosis

The failing predicate is:

```julia
all(occursin("terminal_deferred", gap) for gap in admission.gaps)
```

The predicate is appropriately strict for this test's contract: every emitted
gap is expected to carry an explicit terminal-deferred classification. Static
expansion of the production path and fixture shows the two emitted gaps that
do not contain that token are:

```text
G3_feedback_authority_missing:g1-residual
G3_feedback_authority_missing:g2-thermal
```

They come from the production branch at
`VNextDeclarationTransportV1.jl:456`, which appends the target ID without the
required `:terminal_deferred` suffix. The same fixture has `:missing` upstream
authorities, but the upstream loop currently emits no missing-authority gap at
all. Thus the failure exposes a production classification omission, not an
overly strict test and not a Julia/runtime defect. The structural result's
`status=:valid` versus `resolution=:terminal_deferred` split remains valid;
the missing authority gaps must be explicit.

## Capture and integrity checks

| artifact/input | SHA-256 |
|---|---|
| `focused_r2/stdout.bin` | `4c16f41ff5e49859753a7491f61e4109bd590504108cd830b4737e8331081acc` |
| `focused_r2/stderr.bin` | `312005495a46b8448fd9d31071a642b9ad86edcb1be6b87ec4be3e11ae333289` |
| `focused_r2/process_capture.json` | `680e6994064ee4a1b8f1dbc92ede38ae65e301ad8fe4af7bc6017a2819a85063` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `333ff3a2976736e13809b603cdcab61524658b7fb20d1b6506ccf188dea3b063` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

The attempt metadata records worktree porcelain `304` before and after the
run. A fresh process check found no Julia, juliaup, or DESC process, so no
orphan child remains. Static QA, JSON validation, and diff checks recorded by
the author passed, but they do not override the real Julia exit `1`.

## Minimal R6 repair ownership and exit gate

The bounded repair should be split as follows:

1. **Source owner**: modify only
   `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`. Emit explicit
   `terminal_deferred` gaps for feedback `:missing` authorities and for each
   upstream `:missing` authority. Preserve fail-closed handling for stale,
   contradictory, and unattested actual authorities.
2. **Test owner**: modify only
   `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl`.
   Assert the exact feedback and upstream missing gap names and retain the
   all-gaps terminal-deferred predicate. Do not weaken the predicate or use a
   static token-only substitute.
3. **R6 review/exit**: after a different Luna static review, freeze the six
   input hashes and dirty snapshot, confirm H0 is idle, then run exactly one
   focused Julia process with a launcher that uses `$childPid` rather than
   PowerShell's read-only `$PID`. Capture raw stdout/stderr bytes and hashes,
   real exit code, PID/UTC/process identity, and pre/post dirty/process state.
   The gate requires the first group to pass and the complete focused file to
   exit `0`; no later T0/T1 or physical claim follows automatically.

T0 remains `accepted=false`, contract-only, and terminal-deferred where
external receipts are absent. T1, provider, mesh, engineering, physical,
B00/B04, search, and R01-R10 credit remain blocked.
