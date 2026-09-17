# UP1 external responsibility handoff (R2)

## Status and boundary

This directory is a preparation-only, receipt-driven handoff package. It is
derived from the frozen R2 contract (`00-contract-freeze`), local discovery
(`09-local-discovery`), environment capture (`10-environment-capture`), source
capture (`11-source-capture`), and system trust inventory
(`12-system-trust-inventory`). The R1 four registers remain the formal source
of the 26 absence IDs. Every one is still `typed_absent`; no local metadata,
fixture, historical AD, system certificate, test result, or self-reported
field is an external authority receipt.

The four packets are executable requests for a future named external party,
not submissions. Real names, organizations, endpoints, credentials, trust
anchors, keys, signatures, timestamps, certificates and acknowledgements are
not invented. They are represented as `typed_absence` in the templates and
matrices. `not_sent=true`, `external_mutation=false`, `new_ad=false`,
`credentials_requested=false`, and `s3_run=false` are hard controls.

## Four independent packets

1. **EHP-01 — independent witness and authoritative intake.** Supplies
   identity, qualification, independence/conflict disclosure, scope, channel
   contract and a signed acknowledgement.
2. **EHP-02 — project trust root, certificate chain, revocation, trusted time
   and replay.** Supplies the project anchor and profile, chain/path proof,
   signed receipt, CRL/OCSP and trusted-time evidence, and nonce/sequence/
   idempotency policy. A system-store certificate is not a project anchor.
3. **EHP-03 — source, four axes and G2 authority mapping.** Supplies exact
   candidate/source/G1/G2/G3/axis/evidence closure and a signed mapping.
4. **EHP-04 — environment, SBOM and binary provenance.** Supplies frozen
   runtime/import/package/build/binary/SBOM/license/origin closure, including a
   foreign-owner privileged test fixture or an explicit `not_executed` receipt.

The packet owner must be independent from the source implementer, PKI owner,
environment provider and final reviewer. Unknown owner and authoritative
channel remain typed absence until an external party supplies them.

## Required response discipline

Each response is either a complete, canonical, externally signed package or a
signed rejection. The request digest, candidate ID, source revision/version,
four-axis and G2 references, trusted request time, nonce, sequence and
idempotency key must bind the response. A partial, placeholder, `TEST_ONLY`,
stale, revoked, replayed, foreign, ambiguous, unbound or unverifiable response
is `fail_closed`; missing channel or owner is
`typed_absence/terminal_deferred`. The local intake CLI proves only local
spooling and never promotes a response to authority.

## Formal sequence (preserved)

Parallel preparation of these packets does not unlock a successor. The frozen
sequence remains:

`T0 -> authority_recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`

Every transition requires its predecessor receipt, exact canonical hashes,
fresh revocation/time/replay checks, independent review, and no unresolved
typed absence for that transition. Even a verified external package only
reaches the R2 preparation boundary `eligible_for_authority_recheck`; it does
not itself grant T0/T1/T2, B00/B04, UP1, R01–R10, or parent completion.

## Provenance and validation

The baseline is frozen at HEAD
`b2c04d8339774635aaecd73651efcdb101e01b5d`; the R2 local discovery reports
`usable_production_count=0`, and the system trust inventory reports all
observed certificates nonusable without project binding. `commands.ps1` only
prints offline intake/verification commands and runs no network operation.
The raw receipt files record the Python `-B` static check, process ID, UTC,
exit code, and deterministic SHA-256 checks for this package.
