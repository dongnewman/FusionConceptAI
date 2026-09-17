# UP1-04A-VNEXT-T0 focused R3 independent postrun review

## Verdict

`pass_limited`; `review_pending=true`; `accepted=false`; `T1=no_go`.

focused_r3 is a complete, independently auditable software receipt. The
exact command ran once as PID `55428` from
`2026-09-14T23:26:25.9668343+00:00` through
`2026-09-14T23:26:41.6582139+00:00` and returned Julia exit code `0`. Raw
stdout and empty stderr are preserved with matching SHA-256 values. All seven
testsets passed, totaling `79/79`; the full focused file reached its terminal
markers. No later rerun or hidden execution is being inferred.

This receipt supports a limited T0 software-contract precursor only. It does
not complete the same-candidate join, external provenance, provider, mesh,
engineering, physical, B00/B04, search, or R01-R10 obligations. T0 remains
`accepted=false`; T1 remains `no_go`.

## Evidence and boundary review

The six frozen input hashes in the run manifest match current bytes on disk.
The pre/post worktree porcelain count is `304`/`304`, and a fresh process check
found no Julia, juliaup, or DESC process. The prior R1 launcher failure and R2
exit-1 receipt remain preserved and are not overwritten or reused.

Static inspection of the tested implementation confirms the remaining
evidence ceiling:

- mapped G2 and present axis provenance remain
  `external_verification_pending` with terminal-deferred gaps because the
  external receipt is opaque and not independently readable;
- G3 source-content hash is typed absent and G3 realization/control/binding
  children remain typed absent;
- the normal missing-authority gaps are explicitly terminal deferred;
- source/declaration/body/bundle hash and fail-closed negative controls remain
  exercised by the focused test.

The test's `VNEXT_T0_JULIA_OR_DESC_EXECUTED=false` marker is a scope marker for
the test file's own prohibition on nested Julia/DESC execution; it does not
contradict the outer Julia process receipt. No provider, mesh, physical, or
R01-R10 evidence is present.

## Rehashed artifacts

| artifact/input | SHA-256 |
|---|---|
| `focused_r3/stdout.bin` | `cdb905c18a2dc1ef68a76c6abb84edb6f329e22fbe76306b816cf12ed9cef9e2` |
| `focused_r3/stderr.bin` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `focused_r3/process_capture.json` | `17b51d6b9cb14dbd85c14c1bd4a777d12013e5b211b915ea1ef1d303ceba0536` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `5620b0f7fcb05575bafa34424fe8cc62dd02bd388f8e01eb193497f9d9268be6` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

Historical capture hashes retained for traceability:

| prior receipt | SHA-256 |
|---|---|
| `focused_r1/process_capture_error.txt` | `4457958a905b579dfacb7e16e2feecf8977b187dcdefb7e1f75fef6c7a627ec4` |
| `focused_r2/stdout.bin` | `4c16f41ff5e49859753a7491f61e4109bd590504108cd830b4737e8331081acc` |
| `focused_r2/stderr.bin` | `312005495a46b8448fd9d31071a642b9ad86edcb1be6b87ec4be3e11ae333289` |

## Acceptance boundary and next decision

The appropriate disposition is a software precursor with limited scope, not
T0 actual same-candidate join completion. Root may record this receipt as
`accepted_limited` only for the focused T0 transport software behavior if the
active work ledger uses that label; the R6 review and this postrun evidence do
not by themselves authorize T1. Any such record must preserve the explicit
external, typed-absent, terminal-deferred gaps and all `accepted=false` parent
boundaries.

Further work must first provide independently readable external mapping and
four-axis receipts, G3 source-content evidence, and typed child identities,
then obtain the required downstream reviews and freezes. No focused rerun is
needed for this receipt. No T1, provider, mesh, engineering, physical, B00/B04,
search, or R01-R10 credit is granted.
