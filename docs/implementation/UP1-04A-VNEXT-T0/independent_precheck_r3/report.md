# UP1-04A-VNEXT-T0 independent static precheck R3

## Verdict

`changes_requested`; `review_pending=true`; `accepted=false`.

R3 closes the R2 identity-hash and trusted-label resolution bypasses at the
contract-only level. T0 now recomputes a canonical axis identity hash, checks
candidate/source-body/identity hashes, and forces both mapped G2 receipts and
source-bound axes to `external_verification_pending`. Therefore a self-selected
trusted marker cannot produce `resolution=:resolved`; the mandatory G3 source
content and child gaps also remain deferred. G3 contradictory authority is
now fail-closed.

T0 still needs a small repair before the focused Julia gate: G3 `:stale`
authority is not fail-closed, the external mapping/axis receipt remains an
opaque self-attested digest (safe only because resolution is unconditionally
deferred), and the production test does not cover all requested mapping field
mismatches or an edited G3 body whose old declaration hash must fail. No Julia,
DESC, provider, mesh, or physical command was run; T1 remains no-go.

## Static evidence and hashes

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

Current bytes were rehashed directly:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `f4d0992fecd0c145734eadf50625789d8bdb6298fa1ffdd38a5b3a4624c53fcf` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `015b7117f9c541edd3a4fc79982835b0ba6fc7ca10f5113525891f9acbf801f7` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `381682b1fbc525df042257a3e1733a54e5d803210a90e7de1e47d9e58d669c2f` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

`python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` exited `0` with
`julia_executed=false`, `desc_executed=false`, and the legacy-source guard
false. JSON parsing of the R3 manifest exited `0`, and the scoped diff check
exited `0`. These are static receipts only.

The protected upstream hashes are unchanged. The new source remains outside
the legacy V5 package, shared integration loader, and operator registry; no
upstream V1 source was edited by this review.

## R2 repair assessment

The new `vnext_axis_identity_hash_v1` recipe includes the T0 identity schema
and version, candidate, layer, axis, value, source URI/path, source-record hash,
and attestation. `_vnext_t0_axis_checks` recomputes it and rejects a mismatch.
Present source-bound axes require candidate/source-record/identity digests and
the only accepted verification state is `external_verification_pending`.
Missing axes remain typed absent with `not_applicable` and
`terminal_deferred`. The tests exercise stale source-record, wrong identity,
foreign candidate, and synthetic-oracle cases.

The G2 mapping receipt now carries a fixed
`verification_status=:external_verification_pending`; its source ref/version,
source candidate, joined candidate, complete source-body hash, stored source
hash, attestation, and mapping fields are checked by the production transport.
The mapped branch always appends
`G2_mapping_external_receipt_verification_pending:terminal_deferred`. A valid
receipt constructed with an arbitrary evidence digest therefore remains
deferred; it cannot be promoted by its own trusted label. This correctly
preserves the current absence of independently readable mapping evidence, but
the opaque evidence digest is not itself evidence authority.

The transport now rejects G3 actual authority without trusted attestation and
rejects contradictory upstream and feedback authority. The tests call the
production transport for these cases and for G1/G2 source edits, which verify
source, declaration/body and bundle hash changes.

## Remaining blocking findings

### 1. G3 stale authority is still not fail-closed

At source lines 430-450, upstream and feedback loops branch on `:actual` and
`:contradictory`, but omit `:stale`. A declaration with
`authority.status=:stale` can avoid both the actual-unattested error and the
contradictory error. The existing G3 status vocabulary includes `:stale`, and
the R3 work order explicitly requires stale upstream/feedback authority to be
fail-closed. Add production checks and negative controls for both loops.

### 2. External receipt fields remain self-attested and opaque

The mapping constructor accepts an arbitrary `evidence_ref::Digest256` and
trusted marker, and axis construction accepts arbitrary source URI/path and
identity/source-record digests. R3 correctly prevents these values from
reaching resolved status by forcing external verification pending, so this is
not a resolution bypass. It remains a provenance ceiling: no independently
readable receipt payload or external content hash is checked. Keep these states
deferred until an external receipt/authority object can be loaded and verified;
do not call the current marker an actual source or provider receipt.

### 3. Focused negative controls are still incomplete

The test now covers mapping candidate mismatch and stale body hash, but not
mapping source ref, source version, source candidate ref, stored source hash,
verification status, or field-path mismatch. It covers axis identity mismatch,
but does not assert the external-verification pending state for a present axis.
It edits a G3 ledger entry, feedback target, and authority while preserving the
old declaration hash, which is the correct production path, but those checks
should be explicitly retained in the next receipt and accompanied by a bundle
hash difference assertion for edited G3 content. The static token checker does
not execute these paths.

## Required bounded follow-up

Repair only the T0 source/test/archive ownership, obtain a different-Luna
static review, and leave T1 `no-go`. After that review passes and the H0 serial
lane is idle, run exactly one focused Julia process:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

Freeze repaired source/test/static-QA bytes before launch and capture raw
stdout/stderr bytes, both SHA-256 values, exit code, and actual Julia process
identity. A passing test remains contract-only and grants no T1, provider,
mesh, engineering, physical, B00/B04, search, or R01-R10 credit.

