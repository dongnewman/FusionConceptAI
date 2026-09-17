# AD-30 T0 R6 repair record

## Decision

`conditional_go` for another independent precheck only. T0 remains
`accepted=false`, contract-only, and T1 no-go. This repair records a gap-class
correction; it is not a focused runtime receipt or physical evidence.

## R5 postrun finding addressed

G3 `:missing` authority now emits independent typed gaps for both directions:

- `G3_upstream_authority_missing:G1:terminal_deferred`
- `G3_upstream_authority_missing:G2:terminal_deferred`
- `G3_feedback_authority_missing:g1-residual:terminal_deferred`
- `G3_feedback_authority_missing:g2-thermal:terminal_deferred`

The production result therefore preserves the existing all-gaps
`terminal_deferred` predicate. Actual plus unattested remains `fail_closed`, as
do stale and contradictory authorities. Bundle construction consumes the
updated errors/gaps tuple, so the affected bundle hash is recomputed from the
new semantic body; no old focused receipt was overwritten.

## Evidence and gates

Only static QA, JSON validation, and diff checking ran in R6. No Julia, DESC,
focused, T1, provider, mesh, or physical run was performed. The previous
focused R2 exit-1 receipt remains unchanged and is not reused as R6 evidence.

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
status=pass
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r6/evidence_manifest.json
exit=0
git diff --check
exit=0
```

## Hashes

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `5620b0f7fcb05575bafa34424fe8cc62dd02bd388f8e01eb193497f9d9268be6` |

