# `UP1.external-handoff.atomic-response-bundle.v1`

Status: `review_pending`; implementation status: `not_implemented`; `formal_credit=none`.

This directory is an additive, executable contract draft. It closes R3 collection-readiness findings P1-01 through P1-03 and P2-01 through P2-04. P2-05 is closed by carrying one exact `source_identity_digest` and `source_identity_ref` in the shared binding; only EHP-03 carries the full source closure. No R2 file, production/test source, registry, AD, external endpoint, credential, or runtime artifact is changed.

## Wire shape and closed schemas

`bundle.schema.json` is the wire-level schema. The four payload schemas are
`ehp-01.schema.json` through `ehp-04.schema.json`. Every JSON object in these
schemas has `additionalProperties=false`; unknown keys, duplicate JSON object
keys, non-finite numbers, and non-UTF-8 input are rejected before validation.
The bundle's `packets` and `packet_digests` are arrays, not maps, and are
exactly four items in this order:

```text
EHP-01, EHP-02, EHP-03, EHP-04
```

Each array position has a schema-level `const` packet ID. Each packet ID is
therefore unique by construction; the validator additionally checks set
equality and rejects duplicates, missing IDs, unknown IDs, extra items, and
digest disagreement. Completeness is never read from a caller boolean. It is
derived as `C = (four exact positions && all payload/schema/signature/binding/
security checks pass && fixture_status != not_executed)`.

## Canonical bytes and exclusions

The normative choice is RFC 8785 JSON Canonicalization Scheme (JCS), applied to
the parsed JSON data model, encoded as UTF-8, then SHA-256. A verifier must
reject duplicate keys before parsing, reject NaN/Infinity, and reject numbers
that cannot be represented by the RFC 8785/ECMAScript-compatible model. JCS
provides lexicographic property ordering and no insignificant whitespace; the
wire file itself must use UTF-8 and may use LF or CRLF, because line endings are
not part of the parsed canonical data model. The SHA-256 digest is lowercase
hex.

Domain separation is mandatory. The canonical preimage is the UTF-8 bytes of
the ASCII domain label, one LF, and canonical JSON bytes:

```text
UP1.external-handoff.atomic-response-bundle.v1/<preimage-kind>\n<JCS bytes>
```

`preimage-kind` is one of `packet-owner`, `set-receipt`, or `independent-review`.
The `signature`, `signature_digest`, `bundle_canonical_sha256`, and the
corresponding `*_preimage_sha256` fields are excluded from their own preimage.
For `packet-owner`, exclude only signature material and the packet envelope's
derived `payload_digest`; the payload bytes are included and its digest is
recomputed. For `set-receipt`, exclude the receipt signature and its own
preimage digest; include the fixed packet ID/digest array, full shared binding,
and `bundle_canonical_sha256` (the bundle digest is computed over the bundle
with the set receipt and review receipt signature material excluded). For
`independent-review`, exclude only the review signature and its own preimage
digest; include the recomputed packet and bundle digests and the set-receipt
digest. No field may be omitted by name aliasing, replaced by a path, or
canonicalized separately.

## Binding, trust, time, revocation and replay

Every packet repeats the byte-identical `shared_binding`, and its owner
signature covers that packet's complete payload plus binding. The binding
contains candidate identity, source identity digest/reference, exact G1/G2/G3
references, the four-axis digest set, expected-context digest, trust-anchor
digest, verifier/profile digest, request and expiry trusted-time references,
and replay tuple (`nonce`, strictly increasing `sequence`, `idempotency_key`,
authenticated ledger reference). EHP-03's full source object must hash exactly
to the shared source digest. EHP-02's trust root, certificate chain,
signature profile, revocation responses, trusted-time tokens and replay policy
must validate before any signature is accepted. OS clock, system certificate
store, local spool, unsigned paths, or a self-attested name is not authority.

Every packet has one and only one owner signature and one declared owner role;
the set receipt is signed by the authoritative channel receiver; the review
receipt is signed by a reviewer distinct from all packet owners, the receiver,
and the verifier publisher. Missing, duplicate, foreign, expired, revoked,
scope-incompatible, or cross-packet-inconsistent signatures fail closed.

## Atomic receive state machine

```text
quarantine_raw
  -> verify_all_four
       -> single_decision(accepted_all)
       -> single_decision(rejected_all/fail_closed)
       -> terminal_deferred (missing owner/channel/material or not_executed)
```

The receiver first durably retains the exact raw set and its byte hash in
quarantine. It then verifies all four packets, all cross-packet bindings,
trust/time/revocation/replay references, and the independent review. It emits
exactly one set decision after the complete verification pass. There is no
per-packet promotion, partial acknowledgement, or retry that mutates an
existing receipt. A timeout, partial set, digest mismatch, stale/revoked
material, malformed/foreign packet, replay conflict, or reviewer failure is
`rejected_all` with `fail_closed`; absent owner/channel/material is
`terminal_deferred`. Only a fresh complete set can be retried.

`not_executed` in EHP-04 is bookkeeping only and forces the derived outcome
`terminal_deferred`, `no_publish`, and `formal_credit=none`; it can never yield
`accepted_all`. An executed foreign-owner fixture must include owner/ACL,
command, UTC, exit code, and stdout/stderr hashes under the declared privilege
boundary.

## Recovery identity rules

For any rejected, partial, stale, revoked, replay-conflicting, or mismatched
set, preserve the old `bundle_id`, request ID, nonce, sequence and idempotency
key in the rejection receipt. A recovery request uses a fresh UUID
`request_id`, fresh UUID `bundle_id`, fresh cryptographic nonce, and a strictly
valid next sequence under the authenticated replay ledger. The new
`idempotency_key` is fresh unless the channel explicitly defines a safe
duplicate retry of the same bytes; a changed byte set always requires a new
key. `recovery_of_bundle_id` is a link only and never makes an old set valid.
Unchanged frozen inputs do not authorize a new AD, S3, Julia, DESC or solver
run.

## Derived results and validator interface

The executable semantics, including field-level predicates and result
taxonomy, are in `verifier-contract.md`. A future implementation shall expose
an interface equivalent to:

```text
validate_bundle(raw_utf8: bytes, context: FrozenContext) -> ValidationResult
```

`ValidationResult` returns `schema_ok`, `raw_sha256`, `bundle_digest`, ordered
packet digests, `completeness`, `fixture_status`, `trust/time/revocation/replay`
outcomes, one derived `decision`, failure codes, and retained raw receipt
references. It must not create credentials, contact an endpoint, mint AD/S3
credit, or execute a solver.

The test cases in `test-matrix.md` are acceptance criteria for the future
implementation and are not claimed as executed here.

