# UP1 R3 collection-readiness audit of R2 `19-external-handoff`

## Decision

`not_ready_for_one_shot_external_delivery`.

R2 losslessly assigns 26 absence IDs to four packets (`26/26`, unique), but
the package is only a preparation contract. It does not yet define one atomic
response bundle that an external responsibility chain can deliver and a
reviewer can accept in one transaction. Every owner and endpoint remains
`typed_absence`; no external request was sent and no authority material was
created or inferred.

The detailed per-ID owner, fields, verification and recovery requirements are
in `field_matrix.json`. This audit is read-only over R2. It proposes contract
changes only; it does not edit R2, source, tests, registries, AD records or
receipts.

## Frozen audit inputs and execution receipt

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Reviewed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- R2 package manifest: `19-external-handoff/manifest.json`, SHA-256
  `1be882c364b4e584df9bfdb5247779739f33d96500d695c57037a0b3307bc3f`
- R2 request packet SHA-256:
  `e446748234423626303e1eaac5970a86b10a74069cd03b7e115e398eead8a536`
- R2 responsibility matrix SHA-256:
  `3e2f7a9e7fbb2c8e48b3728447f024f74f243e0118b30037e27da2d7391c978c`
- R2 recovery matrix SHA-256:
  `110f41f2765e7973690c8f879d47620ec0cc8d94cbaafdabb9b3f358728d642c`
- R2 templates SHA-256: common `49a590baae26c714c4731fdd19873769bf87c3e26df0a44bdf5a375c42bfd724`, EHP-01 `88883ca954a770ee68131445b36e07156f0134e4626d0d29ead0befacda9af6e`, EHP-02 `9fd594bab2f9b338b5ae6956a00f1526b7eac5d9d94a4c08f724eb51aaf88281`, EHP-03 `c0c5f45b4f2aa099a0929ce7cfdfc96d37b9a1ce3f5640843b3784a6fdcb6445`, EHP-04 `852957d1979437ba32941fbc6d7a26b92603c2a563d7f4739bb69dc27a2f8915`.
- Static audit command: `python -B -` (in-memory JSON/field/count/hash check only)
- PID: `93748`; UTC: `2026-09-16T21:49:31.654679Z`; exit: `0`
- Raw stdout, PID, UTC and exit evidence: `raw/collection_readiness.*`

The command confirmed `crosswalk_count=26`, `crosswalk_unique=26`,
`assigned_count=26`, `assigned_unique=26`, four packets, no R2 atomic-bundle
field, and all five channel endpoints represented as typed absence. It found
one direct template omission against the component contract: EHP-02 has no
`verifier` object. Additional semantic gaps below concern fields that exist
only as scalar `typed_absence` placeholders or are required in component prose
but are not represented as a closed response structure.

## Why four packets are not one-shot ready

1. **No atomic bundle envelope.** `request_packets.json` defines four
   independent packets and a common binding, but no `bundle_id`, ordered
   packet-set manifest, packet-set digest, all-four completeness predicate,
   cross-packet digest equality, or atomic accept/reject receipt. A channel
   could acknowledge each packet while the set is mixed, partial or rebound.

2. **No cross-packet identity binding.** The common request has placeholders
   for candidate/source/context/trust/replay values, but EHP-01 through EHP-04
   do not require one response envelope to repeat and sign the same
   `candidate_id`, source identity, expected-context digest, trust-anchor
   digest, nonce, sequence and idempotency key. EHP-02's signed receipt and
   EHP-03/EHP-04 receipts therefore lack a declared set-level preimage.

3. **Responsibility and channel are still absent.** The responsibility matrix
   intentionally uses typed absence for every owner. Endpoint placeholders do
   not specify transport, owner identity, authentication/pinning, retention,
   allowed packet set, or acknowledgement SLA. Thus the package can describe
   who must answer, but cannot route or prove receipt of a one-shot delivery.

4. **EHP-01 under-specifies witness closure.** The R2 witness component
   requires complete G1/G2/G3 rows, four-axis rows, evidence rows, candidate
   digest repetition, signature-material binding and acknowledgement binding.
   The EHP-01 template has identity/scope/attestation/ack only; it has no
   closed layer/axis/evidence arrays or explicit leaf certificate/trust-chain
   reference. These must be part of the response or an explicitly referenced
   EHP-03 object.

5. **EHP-02 omits verifier and detailed security objects.** The packet prose
   asks for a verifier release, but the template has no `verifier` field. Its
   certificate chain is not a per-certificate object set, and the
   trusted-time/revocation fields omit the signed token/issuer/serial/imprint
   structures required by the R2 component contracts. `signature_profile` is
   only a scalar receipt field rather than a closed profile object.

6. **EHP-03 is not a canonical graph response.** `evidence_edges` contains
   three scalar labels, not forward/reverse edge arrays with exact byte
   digests. Source identity lacks explicit HEAD/tree/dirty/untracked/submodule
   closure fields, and four-axis entries do not expose per-axis candidate,
   issuer, issued-at and signature references. `g2_mapping` has summary
   metadata but no mapping-row set, reverse-row set or graph digest input.

7. **EHP-04 does not close every binary/import record.** The binary template
   omits the component-contract fields `download_receipt` and `sbom_refs`;
   `runtime_and_imports.imports` and `lockfiles` are scalar placeholders, not
   complete named identity maps. The outer authority/expected-context
   closure, binary subject identity and per-component SBOM edge coverage are
   not represented as a closed response schema. A foreign-owner fixture has a
   safe `not_executed` state, but no explicit receipt shape for owner/ACL,
   command, exit, UTC and stream hashes.

8. **No set-level recovery semantics.** R2 has per-packet recovery, but not
   rules for partial delivery, packet-set digest mismatch, cross-packet nonce
   reuse, one packet expiring before the others, or an atomic rejection that
   prevents partial promotion. Those conditions must be fail-closed and retain
   the complete raw set.

## Typed absence and acceptance boundary

At this audit time the following are typed absence, not empty values:

- owner and authority identity for EHP-01 through EHP-04;
- all authoritative endpoints and transport/ack contracts;
- trust root, certificate chain, leaf, signatures and trusted time;
- CRL/OCSP/replay key and externally authenticated replay ledger;
- candidate/source/G1/G2/G3/four-axis authoritative materials;
- environment/binary/SBOM/provider receipts and foreign-owner fixture receipt.

`typed_absence` means `terminal_deferred` and no send, no authority credit. A
structurally malformed, contradictory, stale, revoked, replayed, foreign,
ambiguous or digest-mismatched response is `fail_closed`. A complete-looking
fixture or local spool receipt is `non_evidence`/bookkeeping only. A one-shot
package may be considered for `authority_recheck` only after a real owner,
verified channel, complete set-level envelope, and independent review exist;
that still does not grant T0/T1/T2, UP1, B00/B04 or parent credit.

## Proposed contract patch (not applied)

Define a future additive `UP1.external-handoff.atomic-response-bundle.v1`
(without changing R2 files) with:

- `bundle_id`, `request_id`, `bundle_version`, exact ordered packet IDs
  `EHP-01..EHP-04`, `packet_digests`, `bundle_canonical_sha256`, and an
  all-four completeness predicate;
- one repeated, signed binding tuple: candidate/source identity, source
  revision/version, four-axis set, G1/G2/G3 refs, expected-context digest,
  trust-anchor digest, verifier/profile digest, nonce, strict sequence,
  idempotency key and trusted request/receipt times;
- packet response objects that embed or hash-bind the closed EHP-01..04
  field sets, including EHP-02 verifier, detailed certificate/revocation/time
  objects, EHP-03 forward/reverse graph arrays, and EHP-04 complete import,
  binary, SBOM/license/provenance maps;
- channel contract and signed ack fields: owner identity, endpoint,
  transport/pin, receipt ID, decision, set digest, replay fields, trusted
  receive time, retry/duplicate semantics, and atomicity (`accepted_all` or
  `rejected_all`, never partial acceptance);
- a set-level independent-review receipt containing reviewer identity and
  separation, verifier version/hash, recomputed packet and bundle hashes,
  chain/revocation/time/replay outcomes, and raw receipt references;
- explicit recovery enum for missing channel/owner (`typed_absent`,
  `terminal_deferred`), partial/mismatched set (`fail_closed`), stale or
  revoked security material (`fail_closed`), and fresh complete response
  requirements. Recovery must not mint a new AD or rerun S3 when the frozen
  inputs are unchanged.

This is a proposed additive contract only. No R2 artifact or existing source,
test, registry, AD, S3/Julia/DESC/solver run was modified.
