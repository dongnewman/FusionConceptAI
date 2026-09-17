# UP1-04A-VNEXT-T0 independent static precheck R6

## Verdict

`pass_limited`; `review_pending=true`; `accepted=false`; `T1=no_go`.

R6 fixes the production gap classification exposed by focused_r2. The normal
typed-gap fixture now emits exactly these four missing-authority gaps:

```text
G3_upstream_authority_missing:G1:terminal_deferred
G3_upstream_authority_missing:G2:terminal_deferred
G3_feedback_authority_missing:g1-residual:terminal_deferred
G3_feedback_authority_missing:g2-thermal:terminal_deferred
```

The test asserts all four exact strings and retains
`all(occursin("terminal_deferred", gap) for gap in admission.gaps)`. Static
inspection confirms the gap tuple is passed into `_vnext_t0_build_bundle` and
included in its canonical hash body, so the corrected gap state participates in
bundle identity. The previous focused_r2 exit-1 receipt remains preserved and
is not reused as a passing result.

## Contract control review

- `:actual` with an unattested authority remains `fail_closed` for upstream
  and feedback paths.
- `:stale` and `:contradictory` upstream and feedback authorities remain
  `fail_closed`.
- Missing upstream and feedback authorities are now explicit
  `terminal_deferred` gaps, while a structurally `:valid` result remains
  `resolution=:terminal_deferred` and `accepted=false`.
- Trusted present axes remain identity-checked and externally pending. The
  opaque external receipt remains a provenance gap and cannot resolve.
- G1/G2 source edit hash-chain controls remain in the production test; no
  legacy package, shared integration entry, registry, or V1 source was changed
  by this review.

## Static evidence and hashes

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

| reviewed file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `5620b0f7fcb05575bafa34424fe8cc62dd02bd388f8e01eb193497f9d9268be6` |

Protected V1 hashes remain:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

Lightweight gates all exited `0`:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r6/evidence_manifest.json
python docs/v4_multitopology_generation/validate_plan.py
git diff --check -- docs/implementation/UP1-04A-VNEXT-T0
```

Static QA reported `status=pass`, `julia_executed=false`, and
`desc_executed=false`. No Julia, DESC, focused, T1, provider, mesh,
engineering, or physical command was run in this review.

## Next gate

After H0's independent static precheck is complete and the H0 serial lane is
idle, one focused Julia process may run against frozen R6 source, test, QA, and
protected input hashes:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

The launcher must use a task-specific child PID variable and capture raw
stdout/stderr bytes, both hashes, exit code, actual PID/UTC/process identity,
and pre/post dirty/process state. A successful focused run remains
contract-only; T0 remains `accepted=false`, T1 remains `no_go`, and no
provider, mesh, engineering, physical, B00/B04, search, or R01-R10 credit is
granted.
