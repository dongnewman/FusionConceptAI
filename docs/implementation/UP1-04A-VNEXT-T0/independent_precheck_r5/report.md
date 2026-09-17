# UP1-04A-VNEXT-T0 independent static precheck R5

## Verdict

`pass_limited`; `review_pending=true`; `accepted=false`.

R5 closes the sole R4 negative-control gap. The added test constructs a typed
G2 mapping receipt from the unchanged valid source and candidate, retains the
same candidate envelope, opaque evidence reference, canonical field path,
source-record/body hash, and trusted attestation, and changes only the stored
`receipt.source_hash`. The production transport is called and the asserted
error tuple is exactly:

```text
("G2_mapping_source_hash_mismatch",)
```

This is an isolated production-path control rather than the earlier coupled
source-candidate variant. The strict constructor-level
`verification_status=:external_verification_pending` guard remains intact.

## Boundary checks

- R4 stale and contradictory G3 upstream/feedback controls remain present;
  actual unattested authority remains fail closed.
- Present trusted axes remain identity-checked and
  `axis_external_receipt_verification_pending`; they cannot resolve.
- Mapped G2 receipts remain externally unverifiable because `evidence_ref` is
  opaque. The transport conservatively keeps the mapped result deferred.
- G3 declaration hash is recomputed from the complete body; G1/G2 source edits
  continue to change source/declaration/body/bundle hashes.
- `status=:valid` with unresolved gaps remains only a structural classification;
  `resolution=:terminal_deferred`, `accepted=false` and the contract-only
  claim ceiling remain in force.
- The T0 source and static QA bytes are unchanged in R5. The three V1 sources,
  legacy `CandidateStatePackageV5`, shared integration entry, and operator
  registry remain protected and unchanged by this review.

## Static evidence

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

Current bytes were rehashed directly:

| file | SHA-256 |
|---|---|
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `333ff3a2976736e13809b603cdcab61524658b7fb20d1b6506ccf188dea3b063` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |

Protected hashes:

| protected file | SHA-256 |
|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |
| `src/Contracts/CandidateStatePackageV5.jl` | `c5c70e8798e0e12fa63ecbfc766079266e770735216c0e2724012d4c9527e620` |
| `src/GenomeV5/Integration/GenomeV5Integration.jl` | `391a7f32ce22c73244ac41f0d6e5c321e98931649491d3fd3a52f907ffaf44c4` |
| `src/IR/OperatorRegistry.jl` | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |

The following lightweight gates all exited `0`:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r5/evidence_manifest.json
python docs/v4_multitopology_generation/validate_plan.py
git diff --check -- docs/implementation/UP1-04A-VNEXT-T0
```

Static QA reported `status=pass`, `julia_executed=false`, and
`desc_executed=false`. No Julia, DESC, focused, T1, provider, mesh,
engineering, or physical execution occurred.

## Next gate

Because the R5 isolated control is now statically complete, one focused Julia
process is permitted only after the H0 lane is confirmed idle and the repaired
source/test/static-QA bytes are frozen:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

The process must retain raw stdout/stderr bytes, both SHA-256 values, exit
code, and actual process identity. A passing focused test remains
contract-only. T1 stays `no_go`; no provider, mesh, engineering, physical,
B00/B04, search, or R01-R10 credit is granted.
