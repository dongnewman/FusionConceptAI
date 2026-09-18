# VNext T1 Candidate Binding V2

This additive slice defines an explicit candidate-binding contract without
connecting it to `FusionConceptAI.jl`, an operator registry, or production T1
admission. It never constructs the V1 giant-tuple package.

The contract compares an expected `QualifiedRefV1`, candidate `Digest256`,
source-package `Digest256`, and optional V2 canonical wire against explicit
observations. It does not infer identity from labels, URI components, order, or
payload contents. Missing evidence is `terminal_deferred`; foreign, tampered,
or duplicate evidence is `fail_closed`; exact equality is `bound`. Every result
remains `accepted=false` and `claim_ceiling=:contract_only`.

`wire_hash` authenticates exact wire bytes. `receipt_hash` authenticates the
binding decision and its separately domain-enveloped fields. The receipt's
sealed constructor recomputes this hash and validates domain, schema, version,
status/reason, duplicate count, and expected-wire presence. They are deliberately
separate. A future adapter may obtain the explicit input fields from an already
verified package, but that adapter and runtime integration are not part of this
slice.

Decision precedence is fixed: observation multiplicity first, then exact
reference/digest/package identity, then expected/observed wire presence and
wire integrity. A foreign identity carrying a missing wire therefore remains
`fail_closed`; it is not erased into `terminal_deferred`.

`QualifiedRefV1.id` and `.version` are compared as one exact pair. Path-like
ids are opaque identities: `/a/../b` is not normalized to `/b`. Combining an
id from one reference with a version from another is likewise rejected rather
than treated as a candidate alias.
