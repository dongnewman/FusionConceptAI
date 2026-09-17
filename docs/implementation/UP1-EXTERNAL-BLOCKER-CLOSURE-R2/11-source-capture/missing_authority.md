# UP1 external closure R2 — source capture and true missing fields

Capture is read-only at HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`. The
machine-readable inventory is `snapshot.json` plus `source_axis_crosswalk.json`.
The current worktree is intentionally dirty; AD56's locator checks and its
source/factory declaration records are retained as bookkeeping references only.

## What is actually present

- G1 and G2 V1 source bytes resolve at HEAD and match the working tree. G3
  realization and control source bytes have a dirty working-tree delta; binding
  and bundle source bytes match HEAD.
- AD-43 provides four exact source-only contract products (shared schema, G1
  evidence, G2 applicability, G2 evidence). Their hashes, source types and axis
  refs are closed at the software-contract level, but `candidate_ref`,
  `source_record_hash`, `source_identity_hash`, `candidate_identity_hash`,
  `attestation_ref` and fresh W2R1 receipt are null/typed absent.
- AD-42 W0/W2R1 provides materialized or authored records and the explicit
  `fusionconceptai://candidate/AD42-W0/86767c9b45794e299b28bb026fa4aafa`
  declaration reference. The records say `candidate_identity_created=false`,
  `authority_status=not_source_backed_declaration_authority` or
  `source-authoring-only`, and W2R1 G2 leaves `mapping_hash=null/deferred`.
- AD-45 provides only the temporary common binding handle
  `fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`;
  it explicitly does not create candidate identity.
- AD-56 proves Git filtered-OID/source-locator mechanics and records G1/G2/G3
  axis declarations, but its `candidate_identity_created=false` and no external
  issuer is declared. It cannot promote its own bookkeeping to authority.

## True missing external closure

The following are not supplied by any inspected v4/UP1 artifact and therefore
remain `typed_absent` or `terminal_deferred`:

1. named independent issuer/attestor identity, organization, qualification,
   independence and conflict disclosure;
2. trust-root reference, public-key fingerprint, certificate chain and issuer
   linkage;
3. detached signature over the exact canonical source/axis/candidate object,
   with a verifiable signature policy and key usage;
4. trusted signing/receipt time, freshness window, trusted-time source, and
   independently checked revocation/OCSP/CRL status;
5. authoritative G2 mapping: namespace/version/effective interval, issuer and
   signature, ambiguity/conflict decision, anti-replay and revocation state;
6. same-candidate bidirectional source↔axis↔evidence edges, including a fresh
   candidate identity hash, source-record hash, identity hash and candidate-bound
   receipt digest;
7. candidate-bound source/factory receipt closure for the exact current source
   revision and dirty boundary; and
8. a channel acknowledgement/receipt binding request digest, object digest,
   nonce/idempotency key and decision.

An ordinary local hash, a passing test, AD43 product, AD45 handle, AD56 filtered
OID, user-relayed decision, or self-reported issuer field does not close any of
these gaps. No candidate, declaration, T0/T1/T2, provider, mesh, solver,
engineering, physical, B00/B04 or R01–R10 credit is inferred.
