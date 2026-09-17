# Repaired verifier contract R1

`verifier.py` is the executable offline predicate reference. It accepts exact
raw UTF-8 bytes and an optional frozen security outcome; it never trusts a
submitted completeness or decision field.

## Derivation

1. Decode strict UTF-8 and reject duplicate object keys and non-finite JSON
   constants before schema validation.
2. Validate `bundle.schema.json` and its four position schemas. Every packet
   position is `allOf` composed with `unevaluatedProperties=false`; every
   payload object is closed by its referenced schema.
3. Require the exact packet order and digest order. Recompute packet/payload
   and signature digest equalities, and compare every repeated binding by
   deterministic canonical JSON bytes.
4. Require set receipt `bundle_id`, `request_id`, packet digests, and binding to
   equal the envelope. The equality predicates are `SET_BUNDLE_ID_MISMATCH`,
   `SET_REQUEST_ID_MISMATCH`, `SET_PACKET_DIGESTS_MISMATCH`, and
   `SET_SHARED_BINDING_MISMATCH`.
5. Require the quarantine receipt's raw object/blob SHA-256, byte size,
   immutable locator, CAS transaction ID, durable commit UTC, receiver
   signature, receipt digest, and `quarantine_raw` state. Require
   `durable_commit_utc <= verification_started_utc <= decision_utc`; no
   decision is valid without this receipt binding.
6. Check EHP-03 candidate/source/axis/G2 and forward/reverse graph relations;
   check EHP-04 context, runtime set, identity uniqueness, SBOM endpoints,
   binary subject binding, and fixture outcome. Each check has one stable code
   in `verifier-predicates.json` and one or more R-series vectors.

## Canonical field table

| preimage | fields removed exactly | fields retained/recomputed |
|---|---|---|
| packet-owner | `signature`, `signature_sha256`, `owner_preimage_sha256`, `payload_sha256` | payload bytes; `payload_sha256` is recomputed |
| set-receipt | `set_signature`, `set_preimage_sha256` | ordered packet IDs/digests, full binding, bundle digest and channel transaction fields |
| independent-review | `review_signature`, `review_preimage_sha256` | recomputed packet/bundle/set-receipt digests and security outcomes |
| bundle | `bundle_canonical_sha256`, all signature bytes/digests/preimages | packet payloads and the set/review receipt data required by the bundle contract |

The table is exact and uses no alternate field names. JCS/domain-separated
cryptographic verification remains a future pinned implementation input; an
absent or unknown security outcome derives `terminal_deferred`, never
`accepted_all`.

## Result boundary

`not_executed` derives `terminal_deferred` with no publish and
`formal_credit=none`. Malformed, mismatched, replay-conflicting, or incomplete
material derives `rejected_all` with the listed failure codes. Only an
executed fixture, zero predicate/schema failures, and caller-supplied pinned
`security_ok=true` can derive `accepted_all`; this repair itself grants no
authority, UP1, B00, B04, physical, engineering, or publication credit.

