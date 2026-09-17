# W1 witness-authority independent review

## Decision

`rework_required` (P1). This is an adversarial, read-only review of the W1 preparation package. The package correctly preserves `typed_absence`, `terminal_deferred`/`fail_closed`, `no_publish`, the preparation-only ceiling, and the distinction between AD55/AD56 historical software evidence and external authority. It is not sufficient for a checked-present witness or authority channel because several future-binding requirements are prose-only or inconsistent between the machine records.

## Scope and frozen inputs

Reviewed the specified README, midterm audit, next-batch, normative state, execution-work-order and task-manifest documents, plus the W1 package, AD55 decision/source-stage records, AD56 acceptance, and fresh-S3 validation receipt. HEAD was `b2c04d8339774635aaecd73651efcdb101e01b5d`. The local review identity/qualification and conflict attestation are intentionally not presented as an external witness. No source, test, AD, shared document or W1 input was changed; this directory is the only write scope.

## Adversarial findings

| ID | Severity | Finding | Required correction |
|---|---|---|---|
| W1-F001 | P1 | `external_input_register.json` leaves `provider`, `owner`, and `authority_source` as JSON null for every absence. The task contract requires an explicitly named or explicitly “unspecified” responsible party and authoritative source; `gap_matrix.json` has better `responsible_party` text but the two records are not machine-consistent. | Use explicit `unspecified` typed values (or a typed absence object) and make owner/source/recovery/expiry consistent across both registers. |
| W1-F002 | P1 | `witness_attestation_schema.json` lists `verifier_ref` and `idempotency_key` as required, but neither has a corresponding `field_contracts` entry. Required-field completeness cannot be mechanically checked. | Add field contracts and hash/type/absence semantics for both fields, or remove them from required fields with an explicit rationale. |
| W1-F003 | P1 | The witness schema requires a signature “over canonical payload” and the channel requires `attestation_sha256`, but no canonical preimage/schema hash or equality rule proves that the signature, attestation digest, request digest and subject object are the same bytes. | Add canonical serialization/hash rule and an explicit attestation-byte/digest equality and signature-scope rule. |
| W1-F004 | P1 | Future request binding has one `canonical_object_sha256`, revision and locator, but no explicit G1/G2/G3 declaration refs/hashes or four-axis refs/hashes. The gap is recorded as absent, but the future present contract does not enforce exact same-candidate layer/axis binding. | Add candidate, G1, G2, G3 and four-axis binding fields with exact equality and foreign/stale/alias rejection rules. |
| W1-F005 | P2 | Freshness/revocation is named and absent, but the schema has no explicit freshness-window duration, revocation-check timestamp/source, or trusted-time source field. `valid_until` alone is insufficient to independently replay the decision. | Add these fields as required for a future present attestation, retaining typed absence now. |
| W1-F006 | P2 | Retry budget/backoff are intentionally `TEST/PLACEHOLDER_POLICY_VALUE`; this is correctly non-evidence, but the receipt does not include a negative fixture proving placeholder substitution cannot pass. | Add a static negative fixture/test result before any present-channel claim. |

## Checks that passed at preparation level

- Identity/qualification, role separation, independence and conflict disclosure are required and currently typed absent; no implementer or local reviewer was promoted to witness.
- Signature, trusted time, certificate chain, revocation, freshness, nonce and verifier policy are absent and `no_publish` is preserved.
- Endpoint owner/authentication/ack, idempotency, duplicate/retry and reject codes are specified as contract-only; live behavior is not misrepresented as tested.
- Placeholder values are explicitly marked non-evidence in both schema and channel contract.
- AD55/AD56/fresh S3 references remain historical or software-limited; T0/T1/T2/B00/B04 and candidate G1/G2/G3 lineage remain closed.
- Existing raw stdout/stderr/combined hashes, in-process timing, exact cleanup set and self-hash exclusion are internally consistent; the review recomputed all listed non-self hashes.

## Ceiling

The W1 package must remain `review_pending`/`preparation_only`; this review grants no UP1, T0/T1/T2, B00, B04, provider, mesh, solver, engineering, physical, search, R01–R10 or L4 credit. Re-review is warranted only after a material input/package change; unchanged inputs do not justify a duplicate AD.
