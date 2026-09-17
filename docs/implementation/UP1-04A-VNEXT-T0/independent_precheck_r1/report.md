# UP1-04A-VNEXT-T0 independent static precheck R1

## Verdict

`changes_requested`; `review_pending=true`; `accepted=false`.

This is a source/test/static review only. No Julia, DESC, provider, mesh, or
physical command was run. T1 is blocked. The new file boundary is preserved and
the current synthetic tests do not claim an actual candidate, but the T0 API
currently permits an untrusted G2 mapping and untrusted axis records to be
presented as source-bound, and it does not enforce the AD-30 G3 unattested
authority rule. The focused tests also do not exercise the required negative
controls and hash invalidation paths.

## Inputs and static receipts

Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`; observed HEAD:
`4b69f55f7f80240147a65a22809dc1207824dde2`.

The AD-30 R2 review and T0 readiness audit were read together with AGENTS, the
v4 README, the common contract, the execution work order, and the current T0
source, test, static QA, acceptance record, and manifest. Current SHA-256 values
were recomputed directly from the files:

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `fa093c4ba87c27ab528fd9c3582c377545193212de8198b19bff976bf3947f2b` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `01aaf8f14311bd9ec9915dabe99bddcf4882cceaae2c0a2ce946c64fafe12413` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `b200571dc4b0913a9a40cee51ed31612cd1f4487aeb2f258bfad20fe96706cc5` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

`python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` exited `0`, with
`julia_executed=false`, `desc_executed=false`, legacy-source-edit guard false,
and its required token checks passing. `python -m json.tool` on the current T0
manifest exited `0`; `git diff --check -- docs/implementation/UP1-04A-VNEXT-T0`
exited `0`. These are static receipts only.

## What passed

The source is additive and does not include the old package, shared entry, or
registry. `VNextDeclarationTransportV1` retains the full G1/G2/G3 declaration
objects, the G2 `GenomeContractRef` and explicit `QualifiedRefV1` envelope, the
four axis records, G3 feedback/authority, typed-absent children, body hashes,
available source hashes, and a bundle hash over the full payload. The G1, G2,
and G3 body recipes match the current declaration constructors, and G3 source
content remains `nothing` rather than being renamed from its declaration hash.

The current synthetic fixture deliberately uses `resolution=:terminal_deferred`
and `accepted=false`; it does not falsely join the three existing fixture
candidate identities. The tests call the production transport function for the
normal and contradiction cases. `status=:valid` with
`resolution=:terminal_deferred` is consistent with the project's split between
structural validity and unresolved authority, as used by existing G1/G2
contracts; it must not be read as resolved or physically authoritative.

The old V5 package, old integration boundary, and registry are not entered by
the new source. No source edit to the three upstream V1 declarations was
observed in this precheck.

## Blocking findings

### 1. G2 `:mapped` is not source-bound or attested

`VNextG2CandidateEnvelopeV1` accepts any `Digest256`, non-empty `source_uri`, and
non-empty `source_path` when `mapping_status=:mapped` (source lines 91-106).
`vnext_declaration_transport_v1` then checks only equality between the envelope
`source_candidate_ref` and `g2.source.candidate_ref` and does not inspect the
mapping receipt body, its candidate binding, its URI/path identity, or its
schema/canonical/profile values (lines 293-298). An arbitrary digest and two
strings can therefore clear the mapping gap. A consistent present-axis input
could reach `resolution=:resolved` without a trusted same-candidate mapping
receipt.

Required repair: represent the mapping receipt as an explicit typed,
candidate-bound source record whose canonical body and hash are checked by the
transport, or keep the mapping `typed_absent`/`terminal_deferred` until such a
record exists. A bare digest/URI/path tuple must never be enough for
`:mapped`. Add negative controls for wrong URI, version, schema hash,
canonicalization hash, profile token, and candidate identity.

### 2. `source_bound` axis provenance is self-attested

`VNextAxisProvenanceV1` accepts `provenance=:source_bound` with any non-empty
string `source_uri`/`source_path` and any string or digest value (lines 52-67).
`_vnext_t0_axis_checks` treats this as present and checks only value equality
across layers; it does not validate a candidate-bound receipt or an axis-source
content hash (lines 189-205). Thus three synthetic records can be made
consistent and remove all axis gaps without real provenance. The current test
uses only typed-absent axes, so this bypass is not currently exercised.

Required repair: use a typed axis receipt/source object with candidate,
field/path, exact value, content hash, and attestation/profile, and require its
canonical hash to verify. Until supplied, use typed absence and
`terminal_deferred`. Add a negative control showing synthetic or stale axis
receipts cannot reach `resolved`.

### 3. G3 unattested actual feedback authority is not fail-closed

The AD-30 contract requires a bare `actual` authority without a trusted receipt
to be `fail_closed:unattested_authority`. The transport checks feedback target
candidate equality and only adds a gap for `status=:missing` (lines 320-326).
It does not reject `status=:actual, attestation=:unattested`, nor does it check
`stale`/`contradictory` target authority states. The current G3 constructor
allows such a raw declaration and the T0 function does not call
`g3_sf_validate_v1`, whose existing validator contains the relevant
`unattested_authority` rule (G3 source lines 409-420). A caller can therefore
provide a body-consistent but unattested `actual` target and receive
`status=:valid`.

Required repair: invoke or reproduce the G3 authority validation at T0 and
classify `actual` without `trusted_receipt`, and any contradictory authority,
as fail-closed with an explicit error. Keep same-candidate and trusted receipt
requirements separate; same-candidate equality alone is not authority.
Add tests for foreign, unattested actual, trusted-looking missing receipt, and
contradictory/stale feedback authority.

### 4. Required hash and negative-control tests are missing

The focused test has three testsets. It covers one normal deferred path, one
candidate/axis contradiction, and one stale G3 declaration hash. It does not
test the required production paths for:

* G2 mapped-envelope URI/version/schema/canonical/profile/candidate mismatch;
* G1 or G2 source-field edits changing source hash, declaration hash, and
  bundle hash together;
* G3 ledger/feedback/authority edits changing the complete-body hash and then
  failing closed with a stale declaration hash;
* foreign or unattested G3 actual authority;
* supplied G3 child identity without same-candidate source identity; or
* a consistent present-axis record being rejected/deferred when its source
  receipt is synthetic or stale.

The existing fixture builders are clearly marked synthetic/oracle-only and the
normal assertion retains `terminal_deferred`; this is safe, but it cannot
substitute for the missing controls.

## Required bounded follow-up

The implementer should make the smallest additive repair within the existing T0
file ownership, then obtain a different-Luna static review. After that review
passes, one serial focused Julia process may run with this command:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

Freeze the repaired source/test/static-QA bytes before launch; capture the raw
stdout and stderr bytes, their SHA-256 values, exit code, and the actual Julia
process identity. Required exits include the synthetic deferred path,
fail-closed candidate/axis/mapping/authority/hash controls, and the complete
source/declaration/bundle invalidation assertions. A passing Julia test remains
contract-only and grants no T1, provider, mesh, physical, B00/B04, or R01-R10
credit.

