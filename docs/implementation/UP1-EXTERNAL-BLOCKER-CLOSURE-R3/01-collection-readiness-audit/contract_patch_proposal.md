# Proposed additive contract: `UP1.external-handoff.atomic-response-bundle.v1`

This is a proposal only. R2 is frozen and unchanged.

## Required envelope

The response must contain `bundle_id`, `request_id`, `bundle_version`, the
ordered set `EHP-01`, `EHP-02`, `EHP-03`, `EHP-04`, one digest for each packet,
`bundle_canonical_sha256`, and an all-four completeness predicate. The
canonical bundle digest must be computed over exact UTF-8 JSON bytes with
duplicate-key/non-finite rejection and no hidden or optional packet.

## Shared authenticated binding

Every packet response and the set-level receipt must repeat the exact
`candidate_id`, source revision/version/identity digest, HEAD/tree and dirty
closure, G1/G2/G3 refs and versions, four-axis material set, expected-context
digest, trust-anchor digest, verifier/profile digest, nonce, strict sequence,
idempotency key, and trusted request/receipt times. Any disagreement is
`fail_closed`; a missing external value is
`typed_absent/terminal_deferred`.

## Packet payload closure

- EHP-01 must carry stable witness identity evidence, signed independence and
  conflict scope, leaf certificate reference, complete layer/axis/evidence
  scope, and signed attestation/ack binding.
- EHP-02 must carry the per-certificate chain, closed signature profile,
  verifier release/hash, signed CRL/OCSP issuer/serial response, signed TSA
  token/imprint, and authenticated replay-ledger/key policy.
- EHP-03 must carry complete source identity (HEAD/tree/dirty/untracked/
  submodule), per-axis objects/signatures, and forward/reverse edge arrays for
  source-candidate-axis-evidence and G2 mapping, including graph digest.
- EHP-04 must carry named Julia/Python runtime and import/lock maps, every
  binary's download receipt/build recipe/SBOM references/license, exact SBOM
  component edges, outer authority proof, and a structured foreign-owner
  fixture receipt or explicit `not_executed` deferral.

## Channel, review and recovery

The channel contract must identify owner, endpoint, transport/pin,
authentication, retention and ack SLA. The signed ack must contain receipt ID,
set digest, replay fields, trusted receive time, retry/duplicate behavior and
an atomic decision: `accepted_all` or `rejected_all`; partial acceptance is
forbidden. An independent reviewer must record identity/separation,
verifier/hash, recomputed packet and bundle hashes, chain/revocation/time/
replay outcomes, and raw receipt paths.

Missing owner/channel/material is typed absence and terminal deferred. Partial,
stale, revoked, replayed, foreign, ambiguous, malformed or mismatched sets are
fail closed and retain all raw bytes. Repair requires a fresh complete signed
set; unchanged frozen inputs forbid a new AD or S3 rerun. No local spool,
TEST_ONLY fixture or system-store observation can satisfy this contract.
