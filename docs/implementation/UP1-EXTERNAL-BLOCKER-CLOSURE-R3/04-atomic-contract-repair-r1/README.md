# UP1 R3 atomic contract repair R1

Status remains `review_pending`; `implementation_status=not_implemented`;
`formal_credit=none`. This is an additive repair artifact. It does not alter
`03-atomic-response-bundle-contract`, any review, production source/test,
registry, endpoint, credential, AD/S3 material, or runtime execution.

The repaired schemas are closed under Draft 2020-12. The packet-position
schemas use `allOf` plus `unevaluatedProperties=false`, so closure is literal
at the composition boundary as well as in the referenced packet base. EHP-03
and EHP-04 are tightened for unique identities, exact axis/runtime sets, and
SBOM endpoint shape. The bundle schema requires a durable quarantine receipt
with the raw object/blob digest and size, immutable locator, CAS transaction,
durable UTC commit, and receiver signature.

JSON Schema expresses fixed constants and object shape. Equality to the
received envelope, canonical exclusion spelling, durable-before-verify order,
graph bijection, and EHP-03/EHP-04 cross-field relationships are explicit
machine predicates in `verifier.py` and `verifier-predicates.json`; each has a
stable error code and a negative test vector. No prose-only obligation remains.

Canonical exclusions use exactly these wire names: `signature`,
`signature_sha256`, `owner_preimage_sha256`, `set_signature`,
`set_preimage_sha256`, `review_signature`, `review_preimage_sha256`, and
`bundle_canonical_sha256`. `signature_digest` and `payload_digest` are not
accepted aliases; payload digest is spelled `payload_sha256` everywhere.

The verifier is deterministic and offline. It validates raw UTF-8 parsing,
duplicate-key/non-finite rejection, schema shape, envelope/set identity,
quarantine ordering and receipt binding, packet digest order, EHP-03 graph
relations, EHP-04 runtime/import/SBOM relations, and the derived decision.
Cryptographic trust-chain verification remains an input outcome supplied by a
future implementation; this repair does not claim external authority or
execution evidence.

