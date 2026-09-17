# UP1-04A-VNEXT-T0 independent static precheck R2

## Verdict

`changes_requested`; `review_pending=true`; `accepted=false`.

This review covers the repair R2 source and focused test statically. No Julia,
DESC, provider, mesh, or physical command was run. The repair closes the most
direct R1 bypasses: a mapped G2 envelope is typed, source/body/hash and
candidate fields are compared, source-bound axes require typed hash fields and
candidate equality, and bare G3 actual authority is rejected unless marked
trusted. Crucially, the mapped and source-bound paths always retain an
external-verification `terminal_deferred` gap, so self-selected trusted labels
cannot make the admission `resolution=:resolved`.

T0 is still not ready for the focused Julia gate because the axis identity hash
is stored but never independently checked, the mapping/axis evidence remains a
self-attested opaque digest rather than an independently readable receipt, G3
stale/contradictory authority is not fully fail-closed by T0, and the required
G3 body-edit invalidation and several mapping/authority negative controls are
absent from the production-path test.

## Static evidence and hashes

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

Current bytes were hashed directly:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30031df3aaf59165ece5e3b667cb93b30c31af1c84bbc9a0be9c39f8bb42838b` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `350bee3b0dbf31785e8adf8ef6e90219a2487ffef443a8a982509324af87f04a` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `3249587e2f9fbdfdff66981e1736e5e0a72fc1abbf075345d9f859f09907d80e` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

`python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` exited `0` and
reported `julia_executed=false`, `desc_executed=false`, and no forbidden legacy
source integration. JSON parsing of the R2 repair manifest exited `0`, and
`git diff --check -- docs/implementation/UP1-04A-VNEXT-T0` exited `0`. These
checks are static only.

The three upstream V1 source hashes are unchanged from R1. The T0 source does
not include the old package, shared loader, or registry mutation, and no edit
to the three upstream declarations was observed. Existing dirty files and old
receipts remain outside this review's write scope.

## R1 closure assessment

### G2 mapping: structurally bound, authority still deferred

The new `VNextG2CandidateMappingReceiptV1` carries source ref/version, the
`GenomeContractRef` source candidate, joined `QualifiedRefV1`, source-body hash,
stored source hash, evidence digest, field path and attestation. The transport
compares source ref/version/candidate, joined candidate, canonical source-body
hash and stored source hash, and rejects an unattested marker. The constructor
cannot be called with a bare digest as the envelope mapping anymore.

However, `evidence_ref` is only an arbitrary `Digest256`; there is no receipt
payload, external receipt locator, or independently checked evidence content.
The transport therefore unconditionally adds
`G2_mapping_external_receipt_verification_pending:terminal_deferred` for every
mapped receipt (source lines 108-121 and 348-359). This is conservative and
prevents `resolution=:resolved`, but a trusted label remains self-attested
until a future source-bound receipt check exists. The current repair is safe as
a deferred structural envelope, not as mapping authority.

### Four axes: candidate and declaration-body hash checked, identity hash not

For a present `source_bound` axis, the constructor requires a candidate ref,
source-record hash and identity hash. T0 checks candidate equality, compares
`source_record_hash` with the layer declaration-body hash, requires
`attestation=:trusted_receipt`, and unconditionally adds
`axis_external_receipt_verification_pending` (source lines 56-90 and 231-249).
Missing applicability/evidence axes stay typed absent with deferred gaps; no
default is used. Consistent synthetic axes therefore cannot resolve the
admission.

The `identity_hash` is never compared to a canonical identity recipe or to an
independently readable identity receipt. Any 256-bit value is accepted and
stored. Because the external-verification gap is unconditional, this does not
currently grant resolved status, but it fails the requested independent
candidate/source-record/identity hash check. T0 needs a typed identity recipe
and independently verifiable receipt, or must keep the axis typed absent until
one exists.

### G3 actual authority: bare actual is closed, other contradictions remain

The repair correctly rejects feedback and upstream `status=:actual` with any
attestation other than `:trusted_receipt`, and puts trusted actual authority
behind an explicit external-verification deferred gap (source lines 381-397).
The production path tests both feedback and upstream bare actual cases.

T0 still does not classify feedback target authority with
`status=:contradictory` or `:stale` as fail-closed, and it does not invoke the
existing `g3_sf_validate_v1` checks for those states. A raw declaration can
therefore carry such authority while avoiding the new actual/unattested branch.
Add explicit fail-closed handling and negative controls. Same-candidate
equality and a trusted marker must remain separate from authority verification.

## Test and evidence gaps

The R2 test calls the production transport for forged mapping, forged axes,
bare actual authority, candidate/axis contradictions, stale G3 declaration
hash, and G1/G2 edits. Those paths are useful and the synthetic normal case
remains explicitly `terminal_deferred`/`accepted=false`.

The focused test still lacks:

* mapped receipt source-ref, source-version, source-candidate,
  joined-candidate, stored-source-hash, evidence, and attestation mismatch
  controls beyond one stale body hash;
* a present-axis identity-hash mismatch or stale identity receipt control;
* G3 ledger, feedback, or authority body edits with the old declaration hash,
  proving complete-body hashing rather than only replacing the hash on an
  otherwise unchanged body;
* stale and contradictory G3 feedback/upstream authority controls; and
* an explicit assertion that a well-formed trusted mapping/axis input still
  has deferred resolution because external verification is pending.

The static QA token scan reports these categories as present, but it does not
execute them or prove their assertions. It is therefore not a substitute for
the focused receipt.

## Required bounded follow-up

Repair only the current T0 source/test/archive ownership, obtain another
different-Luna static review, and keep T1 `no-go`. After that review passes,
run exactly one serial focused process with:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

Before launch, freeze the repaired source/test/static-QA bytes. Capture raw
stdout/stderr bytes, both SHA-256 values, exit code and the actual Julia process
identity. The result remains contract-only: it grants no T1, provider, mesh,
physical, B00/B04, engineering, search, or R01-R10 credit.

