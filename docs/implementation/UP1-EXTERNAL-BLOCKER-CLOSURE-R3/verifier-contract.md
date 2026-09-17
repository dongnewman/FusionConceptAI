# Verifier contract and derived semantics

## Inputs and outputs

Input is exact received UTF-8 bytes plus a caller-frozen `FrozenContext`:
`expected_request_id`, expected candidate/source/context/trust/profile digests,
replay-ledger view, current trusted-time policy, and pinned schema/profile
digests. The verifier performs no network access and never consults ambient
system trust stores.

`validate_bundle` returns a closed result with: `schema_ok`, `raw_sha256`,
`bundle_canonical_sha256`, ordered `packet_digests`, `completeness`,
`fixture_status`, `decision`, `failure_codes`, `recovery_of_bundle_id` and
`raw_receipt_refs`. `decision` is derived and is one of
`accepted_all`, `rejected_all`, or `terminal_deferred`. `formal_credit` is
always `none` in this not-implemented contract.

## Algorithm

1. Hash and durably quarantine the exact raw bytes. Reject invalid UTF-8,
   duplicate keys, non-finite numbers, unsupported number forms and unknown
   keys. Validate `bundle.schema.json` and each position-specific EHP schema.
2. Require `bundle_version=v1`, exactly four `packets` and exactly four
   `packet_digests`, with both arrays equal to the fixed sequence
   `EHP-01,EHP-02,EHP-03,EHP-04`. Require unique packet IDs, unique owner
   signature IDs, and exact digest equality between payload, packet digest
   entries and all receipt references.
3. Recompute the JCS bundle digest after removing only the declared bundle
   self/signature exclusions. Compare it to the declared digest. Compute the
   packet-owner preimage for each packet using domain
   `.../packet-owner`; verify one signature, role, certificate scope and
   preimage digest per packet.
4. Compare all four `shared_binding` objects byte-for-byte after JCS. Compare
   each against `FrozenContext`; require EHP-03 full source closure to hash to
   `source_identity_digest`. Require exact four axis identities and G1/G2/G3
   references; reject orphan, duplicate, foreign or ambiguous graph edges.
5. Verify EHP-02 trust root against the caller-pinned digest, build the full
   certificate path, check profile and EKU/key usage, validate signed CRL/OCSP
   responses and trusted-time tokens, and evaluate the authenticated replay
   ledger. Any unknown, stale, revoked, expired, scope-incompatible or
   unavailable security result is `fail_closed`.
6. Evaluate EHP-04 fixture. `executed` requires exact owner/ACL/command/
   exit/UTC/stdout+stderr hash receipt; `not_executed` yields
   `terminal_deferred` regardless of every other result.
7. Verify the set receipt's signature over its set-receipt preimage. Require
   receiver durability evidence, one `accepted_all` or `rejected_all`
   decision, matching bundle/packet digests, and no partial decision. Verify
   the independent review signature over its review preimage, reviewer
   separation, verifier/profile hash and all recomputed outcomes.
8. Derive the result; never trust a submitted `complete` or decision field:

   ```text
   security_ok = schema_ok && binding_ok && all_packet_signatures_ok
                 && trust_ok && time_ok && revocation_ok && replay_ok
                 && set_receipt_ok && independent_review_ok
   complete = exact_four && all_payloads_closed && security_ok
   decision = terminal_deferred                  if fixture_status=not_executed
              accepted_all                       if complete
              rejected_all (fail_closed)         otherwise
   ```

   If no owner/channel/material exists, classify as `terminal_deferred` with
   `typed_absence` rather than `rejected_all`; this is a pre-delivery state,
   not evidence of acceptance. No result other than `accepted_all` with an
   executed fixture is publishable, and this draft still grants no authority
   credit.

## Preimages

For every packet, construct `P_owner` from the packet object with
`signature`, `signature_digest`, and `owner_preimage_sha256` removed, and with
`payload_digest` recomputed rather than trusted. Sign/hash:

```text
JCS( "UP1.external-handoff.atomic-response-bundle.v1/packet-owner\n" || P_owner )
```

The notation means ASCII domain bytes concatenated with one LF and JCS bytes;
the resulting SHA-256 is the preimage digest, and the signature covers those
same bytes.

For the set receiver, construct `P_set` from ordered packet IDs/digests,
shared binding, bundle digest and channel transaction fields, remove
`set_signature`, `set_signature_digest` and `set_preimage_sha256`, and hash/sign
`domain/set-receipt + LF + JCS(P_set)`. For the independent reviewer, construct
`P_review` from all four recomputed packet digests, bundle digest, set-receipt
digest, verifier/profile outcomes and decision, remove review signature fields,
and hash/sign `domain/independent-review + LF + JCS(P_review)`.

No self-reference is permitted. The `bundle_canonical_sha256` itself is
computed over the whole bundle with bundle digest, all signature bytes,
signature digests, and preimage-digest fields removed; packet payload bytes
remain included. The set receipt is then bound to that resulting digest.

## Recovery and state transitions

`quarantine_raw` is entered before any parsing result is acted upon. A failed
verification transitions atomically to `rejected_all/fail_closed` and retains
raw bytes. Missing authority transitions to `terminal_deferred/typed_absence`.
Only a fresh recovery identity tuple may re-enter quarantine. A stale or
replayed tuple cannot be repaired in place.

