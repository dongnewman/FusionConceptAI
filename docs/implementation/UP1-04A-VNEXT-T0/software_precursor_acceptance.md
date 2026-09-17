# AD-30 T0 software precursor acceptance

## Limited decision

`T0 software precursor accepted_limited` is recorded for the additive
declaration transport contract only. The accepted scope is complete G1/G2/G3
body transport, typed absence/terminal-deferred classification, exact hash
accounting, candidate/axis/authority negative controls, and the focused Julia
software test receipt.

The machine T0 main node remains `accepted=false`. Actual fresh same-candidate
exact join is `false`; T1 is `no-go`. G2 external candidate mapping, real
four-axis receipts, G3 source-content hash, G3 realization/control/binding
children, provider, mesh, engineering, physical, and R01-R10 credit remain
deferred or false. No software receipt is evidence of physical feasibility.

## Evidence chain

The chain is preserved without replacing earlier records:

1. [focused R1 launcher failure](focused_r1/report.md) records the first
   capture harness error and unknown Julia result.
2. [focused R2 failure](focused_r2/report.md) records the real Julia exit `1`
   and first assertion failure; it was not overwritten.
3. [focused R3 pass](focused_r3/report.md) records the successful serial Julia
   run with 79/79 assertions and raw stream hashes.
4. [focused R3 evidence manifest](focused_r3/evidence_manifest.json) binds the
   successful run to the six input hashes, PID/UTC, exit code, streams, and
   dirty/process state.

The existing [T0 main acceptance record](acceptance.md) remains
`review_pending`, `accepted=false`, and `claim_ceiling=contract_only`.

## Frozen hashes

These hashes were recomputed at archive time:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `5620b0f7fcb05575bafa34424fe8cc62dd02bd388f8e01eb193497f9d9268be6` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

The archive manifest also records the focused R3 stdout/stderr/metadata hashes
and the 304-item before/after dirty count.

## Acceptance boundary

This limited acceptance permits downstream architectural review of the T0
software precursor. It does not authorize T1, provider/mesh execution, claims
of real candidate authority, or physical/engineering validation. The unresolved
external receipt gaps must be closed with independently readable source-backed
records before any actual join or higher-stage credit can be considered.

