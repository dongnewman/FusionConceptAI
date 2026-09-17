# UP1 R4 witness / proof-input recheck

## Verdict

`found_usable=0`; `found_untrusted=9` representative local-only artifact
records; external
required inputs remain `typed_absent`.  This is a recheck against the frozen
R4 material, not a new external proof and not a promotion decision.

The fixed checkout is `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`.
R01–R10, the 39-node DAG, and all existing gates were treated as immutable.
No Julia, DESC, S3, search, solver, network request, certificate-store
mutation, source/test edit, or existing-document edit was performed.  The
only files written are the files in this `witness/` directory.

## Scan boundary and raw receipts

The external-path scan covered both `D:/006-Programing/LMC` and
`D:/006-Programing/LMC/FusionConceptAI`, each at the seven frozen intake
locations: `local_spool`, `local_spool/incoming`, `response`, `anchors`,
`local_receipts`, `incoming`, and `intake`.  All 14 locations were absent or
empty (`file_count=0`).  PID, UTC interval, HEAD, exit code, and the exact
read-only JSON output are in `raw/path_scan.raw.json`.

The R4 baseline was independently parsed and hashed from
`00-external-delta-scan/external_material_inventory.json`,
`01-external-input-contract/external_input_contract_r4.json`, and
`21-root-acceptance/decision.json`; see `raw/r4_baseline.raw.json`.  It still
reports `26/26 typed_absent`, `usable_count=0`, `terminal_deferred`,
`formal_credit=none`, `new_ad=false`, and `s3_rerun=false`.

## Classification of workspace observations

`found_usable` is zero.  No externally delivered canonical response, witness
identity, proof declaration, leaf certificate, pinned root, verifiable
signature, trusted-time token, revocation receipt, authenticated ACK, or
independent-review receipt was found.

The following are `found_untrusted`, because they are local software
contracts, typed-absence products, fixtures, or local test receipts.  They
must not be promoted to external authority:

| Observation | Why it is not usable external input |
|---|---|
| `AD-40/.../candidate_declaration_payload.json` (G1/G2) | `AbsentDeclarationSourceV1`, `terminal_deferred`; local authoring only |
| `AD-47/.../source_authority_record_v1.json` | `AbsentG3SourceAuthorityRecordV1`; source identity and trusted attestation absent |
| `AD-48/S3-TRUSTED-SOURCE-IDENTITY/...` | `typed_absent`, `trusted_attestation_created=false`, `no_publish=true` |
| `AD-49/G1-TRUSTED-SOURCE-IDENTITY/...` and `G2-...` | `Absent...TrustedSourceIdentity...`, no candidate identity or attestation |
| `AD-52/.../up2_external_authority.receipt.json` | local Julia test receipt (`9/9`), not an external signature/authority receipt |
| `src/RuntimeV4/DESCGeometryCompatibilityProofV4.jl` | source proof/compatibility code, not an externally issued witness package |

These observations are recorded verbatim as a bounded local scan in
`raw/local_artifact_scan.raw.txt`.  A local declaration, proof implementation,
hash, test exit, reviewer name, or generated receipt cannot establish an
independent witness identity or a verifiable signature.

## Remaining external responsibility and exact recovery input

All 26 R4 records remain absent.  The witness/proof subset is explicit below;
the paths and field requirements are copied from the R4 contract and are not
invented by this recheck.

| Owner / packet | Required files and fields | Authoritative acceptance condition |
|---|---|---|
| Independent witness/intake owner, EHP-01 | `response/ehp01.json` or `local_spool/incoming/ehp01.json`; stable person/org identity, qualification/validity, issuer/registry ref, identity digest, exact candidate/request scope; external signature and issuer/reviewer receipts | Named external witness signs the exact canonical identity/scope package; independent reviewer binds identity, scope, and validity |
| Witness + governance owner, EHP-01 | Same `ehp01.json`; independence basis, conflict disclosure, relationship boundary, effective interval, signed scope preimage | Distinct witness and governance/reviewer signatures; no source/PKI/environment/reviewer role conflict |
| Witness + PKI/TSA/revocation authorities, EHP-01 | `response/ehp01.json`, `response/leaf.pem`; canonical preimage digest, signature bytes, algorithm/key ID, candidate/source/layer/axis/evidence scope, issued/expiry, trusted-time and revocation refs | Valid leaf and ordered chain under the pinned root, trusted time and fresh CRL/OCSP, signature over exact bytes |
| Contract/verifier owner and external attestor, EHP-02 | `anchors/profile.json`, `anchors/project-root.pem` or `trust_anchor.json`, `response/chain.pem`, `response/ehp02.json`; profile/canonicalization/algorithm constraints, root/chain, signed receipt preimage and digest, candidate/source/axis/G2 refs, trusted time/revocation/replay | Versioned hash-pinned profile/root, valid chain/signature, fresh time/revocation/replay evidence; local store or local hash is insufficient |
| Source authority + independent attestor, EHP-03 | `response/ehp03-source.json`; same-candidate identity, HEAD/tree/source bytes and digest, G1/G2/G3 refs, four-axis refs, forward/reverse graph, signed lineage and source receipts | Complete same-candidate lineage is externally signed and independently recomputed; any source drift rebuilds downstream identity |
| G2 authority + axis owners, EHP-03 | `response/ehp03-g2.json` and `response/ehp03-four-axis.json`; complete forward/reverse mapping rows, namespace/version/effective interval, candidate/source/G2 IDs, four named axis bytes/digests, per-axis signatures, independent set receipt | Fresh bijective G2 mapping and all four axis materials arrive as one candidate-bound set with external signatures and trusted/revocation/replay receipts |
| Channel owner / intake operator, EHP-01 | `anchors/expected_context.json`, `local_receipts/ehp01.witness.receipt.json`; owner, endpoint, transport/authentication contract, request/bundle digest, idempotency key, trusted receive time | Authenticated transport ACK or rejection over exact request; retain raw response; no local spool/CAS receipt alone |
| Independent environment/SBOM provider, EHP-04 | `response/ehp04.json`; expected-context digest, Julia/Python runtime paths/version/hash, full imports and lock identities, locale/timezone/redaction ledger | Complete candidate-bound closure with provider and independent recomputation signatures |
| Binary publisher/distributor + provenance reviewer, EHP-04 | `response/ehp04.json`; every binary path/version/hash, publisher key/signature, signed download receipt, build/container recipe, SPDX/CycloneDX edges, license/supplier and candidate binding | Signed origin/build/SBOM provenance and independent review; Authenticode/store observation cannot substitute |

The authoritative receiver must accept the ordered atomic EHP-01..04 set only
when every packet has exact canonical bytes and SHA-256, shared candidate and
source binding, G1/G2/G3 and four-axis references, pinned trust/profile
digests, trusted time/expiry, nonce/sequence/idempotency, valid chain and
signature, revocation status, replay protection, and reviewer separation.
Partial delivery is rejected; malformed or contradictory material is
`fail_closed`, while missing owner/channel/material remains `typed_absent`.

## Recovery gates and disposition

No recovery gate is open in this recheck.  The next permitted transition is
only after a real external owner delivers the complete bundle through the
authoritative channel: freeze and hash the exact received bytes, rebuild
candidate/source/G2/axis identities and dependent receipts, then perform one
fresh authority recheck.  Until G7–G9 are satisfied, `T1_go=false`,
`T2_go=false`, no publication or formal credit is allowed, and the parent
goal remains active.  Therefore:

```text
new_ad=false
s3_rerun=false
formal_credit=none
authority_credit=false
publish=false
R01_R10_changed=false
DAG_39_changed=false
```
