# UP1-04A-VNEXT-T0 independent static precheck R4

## Verdict

`changes_requested`; `review_pending=true`; `accepted=false`.

R4 closes the R3 production-state defects: stale G3 upstream and feedback
authority now fail closed, locally checkable G2 mapping fields are checked by
the transport, and a present axis with a correct identity and trusted marker
still remains `external_verification_pending`/`terminal_deferred`. The opaque
external receipt remains conservatively deferred and cannot resolve an
admission.

One bounded evidence defect remains before the focused gate. The test named
`g2_mapping_source_hash_mismatch` changes the G2 source candidate through
`_g2_variant`, so its asserted source-hash error is coupled to
`G2_mapping_source_candidate_ref_mismatch` and a changed source. There is no
production-path negative control that keeps the G2 source and every other
receipt field valid while changing only the stored mapping `source_hash`.
Because R4 explicitly claims a negative control for every locally verifiable
mapping field, this is a blocking review gap rather than an implementation
failure. Add one receipt with `source_hash=Digest256(stale)` and the unchanged
G2 source, call `vnext_declaration_transport_v1`, and assert only the expected
source-hash mismatch (the constructor's strict verification-status check may
remain constructor-level, since invalid status cannot form a typed receipt).

## R4 closure assessment

- The transport branches on `:stale` for both upstream authorities and
  feedback targets and returns explicit `fail_closed` errors.
- The mapped G2 branch compares source ref, source version, source candidate
  ref, joined candidate ref, source-record/body hash, source hash, field path,
  attestation, and verification status. The mapped branch always adds
  `G2_mapping_external_receipt_verification_pending:terminal_deferred`.
- Source-bound axes recompute the canonical identity hash and require the
  matching candidate and declaration-body hash. A trusted marker does not
  remove `axis_external_receipt_verification_pending`.
- G3 declaration-body hash is recomputed from the complete body. Edited ledger,
  feedback, or authority content with an old declaration hash fails closed;
  G3 source content and realization/control/binding children remain typed
  absent and terminal deferred.
- A structurally valid result with gaps remains `status=:valid` but
  `resolution=:terminal_deferred`; it is not completion or acceptance.
- Actual but unattested G3 feedback/upstream authority fails closed. Trusted
  actual authority remains subject to external verification gap handling.

## Static evidence

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

Current bytes were rehashed directly:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `d0463fab22450199e9a84f58753fe1255bdda70962f766da751d85e54c4ddbf7` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |

Protected current bytes were also rehashed:

| protected file | SHA-256 |
|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |
| `src/Contracts/CandidateStatePackageV5.jl` | `c5c70e8798e0e12fa63ecbfc766079266e770735216c0e2724012d4c9527e620` |
| `src/GenomeV5/Integration/GenomeV5Integration.jl` | `391a7f32ce22c73244ac41f0d6e5c321e98931649491d3fd3a52f907ffaf44c4` |
| `src/IR/OperatorRegistry.jl` | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |

The static QA script exited `0` with `status=pass`,
`julia_executed=false`, and `desc_executed=false`. JSON parsing of the R4
manifest exited `0`. A scoped `git diff --check` exited `0`. No Julia, DESC,
focused, T1, provider, mesh, or physical command ran.

## Scope and next gate

This review wrote only the R4 report and manifest. The R4 implementation
remains additive and outside the legacy V5 package, shared integration entry,
and default operator registry; protected V1 sources and legacy files were not
edited by this review.

After the single source-hash negative control is added and independently
reviewed, the next permitted gate is one serial focused Julia process, only
when the H0 lane is idle:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

Freeze source/test/static-QA bytes before launch and retain raw stdout/stderr
bytes, their SHA-256 values, exit code, and actual process identity. That gate
would remain contract-only. T1 stays `no_go`; no provider, mesh, engineering,
physical, B00/B04, search, or R01-R10 credit is granted.
