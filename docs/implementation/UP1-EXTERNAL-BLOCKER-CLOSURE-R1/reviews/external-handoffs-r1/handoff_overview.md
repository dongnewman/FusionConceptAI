# UP1 external responsibility handoff package (R1)

## Boundary

This is a receipt-driven request package, not an external submission. It is derived from the `pass_limited` W1/W2/W3/W4 reviews and their main packages. All unresolved external facts remain typed absence. No endpoint, person, organization, credential, trust root, signature, acknowledgement, S3 object, or new AD is invented.

The four packets are intentionally separable: an intake owner must not also be the independent witness, PKI authority, source owner, or environment provider. Each recipient must return a signed, candidate-bound package through a channel whose real owner and endpoint are still absent. `not_sent=true`, `external_mutation=false`, and `credentials_requested=false` are hard controls.

## Required response discipline

Recipients must return either a complete package or an explicit signed rejection. A partial, placeholder, stale, foreign, unsigned, unbound, or unverifiable response is `fail_closed`; channel unavailability is `typed_absence_terminal_deferred`. The request digest, candidate ID, source revision/version, G1/G2/G3 references and hashes, four-axis references and hashes, nonce, trusted request time, and idempotency key must bind every response. Retry is permitted only under the declared idempotency key and channel policy; unchanged inputs do not justify a new AD or repeated acceptance.

## Conditional progression

No calendar dates are assigned. Progression is conditional on receipts: `inputs_received` → independent `intake_verified` → fresh S3 trust-root/attestation receipt → **T0 → authority_recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01**. Every adjacent transition requires its predecessor receipt, canonical digest/hash bindings, independent review, and no unresolved typed absence for that transition. Any missing, expired, revoked, conflicting, replayed, or mismatched receipt returns to the responsible packet and leaves the parent goal open. W1–W4 `pass_limited` evidence supports preparation only and does not open UP1 or any formal gate.

## Packet ownership

1. Independent witness and authority intake owner: identity, independence, scope, channel and acknowledgement contract.
2. PKI/security authority: trust root, certificate path, revocation, trusted time, signature and replay policy.
3. Source/four-axis/G2 authority: exact candidate lineage, source revision and all axis/G2 bindings.
4. Environment/provenance provider: import closure, runtimes, binaries, SBOM, origin, build and license evidence.

Unknown names, endpoint URIs, authority references and delivery channels are represented as typed absence in `request_packets.json`; this package is `not_sent` and must not be mistaken for an external receipt.
