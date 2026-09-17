# UP1 external witness and authority-channel closure (W1)

Status: `preparation_only`, `review_pending`, `accepted=false`.

This work order freezes an executable contract for an independent witness and an
authority receiving channel. It does not create an attestation, trust root,
certificate, signature, endpoint, acknowledgement, source authority, or checked-
present result. The current S3 state remains `typed_absence` with gate
`blocked_external_trust_root_and_source_closure`.

## Scope and separation

The implementer (this Luna) may define schemas, static binding checks, and
checklists only. An independent Luna must review this directory and the raw static
receipt. The Sol architect adjudicates scope and any later gate; an external
attestor supplies the identity, qualification, independence basis, conflict
disclosure, signed object, trust chain, and validity evidence. The channel owner
operates the receiving endpoint and issues an independently verifiable receipt.
No implementer, local test, fixture, local key, local hash, or runner exit may
stand in for either external role.

## Required binding

Every future request and acknowledgement must bind the exact candidate/source
object canonical bytes and SHA-256, revision/path or content locator, witness
scope, attestation digest, verifier policy/version, trusted-time and revocation
decision, replay nonce, and idempotency key. Any missing, stale, foreign,
replayed, unverifiable, or conflicting field is `fail_closed`/`no_publish`; an
unavailable external fact is `typed_absence`/`terminal_deferred`, not a guessed
value.

## Recovery and expiry

Recovery requires named external provider/owner inputs, an independently
verifiable trust root and key/certificate/signature chain, verifier and policy
versions, trusted time/revocation/freshness/replay evidence, source-closure
hashes, and a channel acknowledgement bound to the same object. Inputs unchanged
do not justify generating a duplicate AD or replaying the same acceptance. Any
certificate, policy, endpoint, acknowledgement, nonce, or source revision that
passes its validity/retention window is expired and requires a fresh bounded
request; source or policy change requires a new freeze and recheck.

## Acceptance ceiling

This directory is preparation evidence only. It grants no UP1, T0/T1/T2, B00,
B04, provider, mesh, solver, engineering, physical, search, R01-R10, or L4
credit. Existing AD54/AD55/AD56 records remain historical/read-only references;
their software-limited decisions cannot be back-filled into the missing external
facts, and this preparation cannot retroactively prove an old run's input
closure.

