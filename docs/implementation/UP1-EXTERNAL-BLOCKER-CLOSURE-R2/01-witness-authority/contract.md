# UP1 External Blocker Closure R2 — witness / authority seam

Status: `implementation_complete_limited`, `accepted=false`,
`resolution=typed_absence`, `no_publish=true`.

This directory records a local, stdlib-only validator for the missing
independent witness and authority-receipt boundary. It is a software contract
slice, not an external attestation, authority decision, trust root, endpoint,
signature, or source-closure result. It cannot close UP1, T0/T1/T2, B00/B04,
or any R01–R10 gate.

## CLI contract

```text
python -B tools/up1_external_closure_r2/witness_authority/cli.py < request.json
```

The process reads exactly one JSON value from stdin and emits exactly one
compact JSON object on stdout. JSON object keys are unique; non-standard
constants (`NaN`, `Infinity`) and malformed/trailing input are rejected. A
batch may be supplied as `{"requests":[...]}` to exercise replay checks in one
process. No network, endpoint, credential, clock trust, key store, or signing
operation is used.

Every root, candidate, layer/axis binding, witness, identity, independence
attestation, evidence row, signature-material, authority, endpoint, and ack
object has an explicit allow-list. Unknown keys are `ERR_UNKNOWN_FIELD` and
cannot be treated as an extension without a future schema version. Witness
scope is an exact canonical candidate identifier; substring or attacker-owned
scope strings are rejected.

The schema has one representation for each semantic field. In particular,
`canonical_object_sha256`, `signature_material`, and `ack` are the only
accepted canonical names. Legacy `object_sha256`, `signature_material_ref`,
and `receipt` are never preferred: alone they are `ERR_UNKNOWN_FIELD`, and
alongside the canonical field they are `ERR_ALIAS_CONFLICT`.

Required local bindings are the request idempotency key, nonce, attestation
digest, exact candidate id/object digest/source revision/locator/version, all
three layer rows (`G1`, `G2`, `G3`), and all four axis rows (`schema`,
`canonical`, `profile`, `candidate_binding`). Every layer and axis row carries
the same candidate id; each layer also carries a frozen version. Witness
evidence rows must repeat the candidate digest and source coordinates. An
independence declaration must include statement, exact candidate scope, and a
clear conflict disclosure plus an externally verifiable attestation bound to
the candidate digest. A self-certified declaration is
`typed_absence/terminal_deferred`. Evidence must repeat the complete layer and
four-axis refs, hashes, and versions exactly. Signature material must cite a
64-hex digest of the canonical payload containing candidate, source, every
layer/axis binding, and every evidence row. Authority acknowledgements must
bind request id, idempotency key, and accepted object digest; all signature
and ack scalar fields are type-checked.

## Outcome taxonomy

| condition | status | resolution | publish |
| --- | --- | --- | --- |
| real witness identity/signature, endpoint, or acknowledgement is absent | `typed_absence` | `typed_absence` | no |
| malformed, missing structural field, duplicate, conflict, foreign candidate/axis, or mismatched digest | `fail_closed` | `fail_closed` | no |
| `mode=TEST_ONLY` (including complete-looking fixtures) | `non_evidence` | `typed_absence` or `fail_closed` for the exercised branch | no |
| locally admissible complete shape | `present_admissible_shape` | `typed_absence` | no |

`TEST_ONLY`, `TEST/`, `PLACEHOLDER`, and equivalent marker material is never
accepted in production. The validator never reads fixture `expected` fields.
An in-memory ledger records the canonical full request digest before any
typed-absence return. Repeated idempotency keys are duplicate only when the
complete canonical request is unchanged; any source/axis/witness/authority
change is `ERR_IDEMPOTENCY_CONFLICT`. Duplicate ack ids are rejected. The
ledger is not a persistent authority log and its result is not a receipt.

## Evidence boundary

The fresh run records command, PID, UTC start/end, exit code, stdout/stderr and
SHA-256 values below. A passing test demonstrates only this bounded local
software behavior. No real person, institution, endpoint, signature, trust
root, revocation status, trusted time source, or authority owner was supplied.
The parent external blocker therefore remains `typed_absence` /
`terminal_deferred`; R01–R10 remain open and unchanged.
