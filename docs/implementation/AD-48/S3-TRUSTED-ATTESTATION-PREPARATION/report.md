# AD48-S3 trusted G3 source identity / attestation preparation audit

## Decision and boundary

`status: pending`; `accepted: false`; `claim_ceiling: preparation_and_static_readiness_only`.
This is a read-only preparation audit. It does not create, sign, publish, or materialize
any `G3TrustedSourceIdentityV1`, trusted receipt, source identity hash, declaration hash,
`CandidateIdentityV1`, package, T0/T1/T2 product, or physical/provider evidence.

The only files written by this task are this report, `manifest.json`,
`cleanup_inventory.md`, and raw static-audit receipts under `archive/`. No Julia,
DESC, provider, mesh, solver, engineering, physical, or search execution was run.

## Read sources and frozen upstream boundaries

The current planning contract was read from the project README and
`docs/v4_multitopology_generation/{README.md,14_agent_orchestration.md,16_execution_work_orders.md,18_sources_and_architecture_decisions.md}`.
The AD48 gap decomposition, AD48-S1 acceptance, old AD48-S2 acceptance, F0 R3
root/reviewer records, fresh S2 records, AD45 envelope acceptance, and AD46
identity-owner contract were also read.

Observed repository root is `D:/006-Programing/LMC/FusionConceptAI`; observed HEAD is
`4b69f55f7f80240147a65a22809dc1207824dde2`; the worktree is dirty. The existing
S1 result is `accepted_limited` for repository-local working-tree locators only.
F0 R3 is `accepted_limited` for a software source-stage factory only. AD45 is an
accepted temporary `QualifiedRefV1/v5` common binding handle, not a source or final
identity authority. The only fresh S2 exact products are under
`docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2/`; their manifest and
acceptance explicitly say `review_pending`, `accepted=false`, and
`trusted_attestation=false`. They are therefore ineligible as an S3 input at this
time and are recorded below only as future inputs.

## Attestor and trust-mechanism inventory

The static probe used Python `3.13.5` at `D:/Users/Newman/anaconda3/python.exe`.
Available libraries were `cryptography 44.0.1`, `PyNaCl 1.5.0`, `PyJWT 2.10.1`,
and `pyOpenSSL 25.0.0`; `jose`, `securesystemslib`, `sigstore`, and `signify`
were not installed. These are generic libraries, not an attestor identity or a
repository trust policy.

Available command-line tools were OpenSSL `3.0.18`, GnuPG `2.4.8`, and Windows
OpenSSH `ssh-keygen`; `cosign`, `minisign`, `sigstore`, and `signtool` were absent.
Repository Git signing configuration (`commit.gpgsign`, `gpg.format`,
`user.signingkey`, SSH allowed-signers file/program) was not configured. No
repository key, certificate, detached signature, public-key manifest, or trust-root
file was found by suffix inventory (`.pem`, `.key`, `.crt`, `.cer`, `.der`, `.p12`,
`.pfx`, `.sig`, `.asc`, `.pub`) outside historical/raw evidence paths.

Windows certificate stores exist, but are generic OS stores rather than an AD48
attestor binding: `CurrentUser\\My` count 2, `CurrentUser\\Root` count 280,
`LocalMachine\\My` count 0, and `LocalMachine\\Root` count 280. No store entry was
used as an S3 signer, certificate chain, or trust root, and no certificate/key
contents were read or printed.

The repository's `G3SourceFeedbackLawV1` and integration contracts expose the
symbols `:unattested` and `:trusted_receipt`. F0 and fresh S2 explicitly set
`trusted_attestation_created=false`; their SHA-256 digests, factory receipts,
reviewer names, test exits, and runner exits are software provenance metadata only.
They do not implement a cryptographic signer, detached-signature verifier, signer
identity binding, trust root, revocation, replay protection, or freshness policy.
Consequently, no real independent attestor mechanism is currently available for a
Present S3 result.

## Formal S3 product paths reserved for a future accepted run

The formal S3 gate owns exactly two JSON products for each of four scopes. These
paths are defined here but are intentionally not created by this preparation audit.

| scope | source closure anchor | future identity product | future receipt product |
|---|---|---|---|
| `realization` | `src/GenomeV5/G3/RealizationGenomeV5.jl` plus S1 child/test closure | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/realization/trusted_source_identity_v1.json` | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/realization/trusted_source_identity_receipt.json` |
| `control` | `src/GenomeV5/G3/ControlGenomeV5.jl` plus S1 child/test closure | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/control/trusted_source_identity_v1.json` | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/control/trusted_source_identity_receipt.json` |
| `binding` | `src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl` plus S1 child/test/static-QA closure | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/binding/trusted_source_identity_v1.json` | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/binding/trusted_source_identity_receipt.json` |
| `bundle` | `src/GenomeV5/G3/RealizationControlGenomeV5.jl` and the complete five-source bundle closure from S1 | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/bundle/trusted_source_identity_v1.json` | `docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/bundle/trusted_source_identity_receipt.json` |

The future identity product result union is exactly
`PresentG3TrustedSourceIdentityV1 | AbsentG3TrustedSourceIdentityV1 | FailedG3TrustedSourceIdentityV1`.
The future receipt product result union is exactly
`PresentG3TrustedSourceIdentityReceiptV1 | AbsentG3TrustedSourceIdentityReceiptV1 | FailedG3TrustedSourceIdentityReceiptV1`.
Each scope must emit one identity and one receipt from its respective union; a
receipt cannot promote a different scope or a different identity product.

## Future S3 contract

Inputs are limited to: (1) future accepted, independently reviewed, exact fresh S2
identity and construction-receipt products for the same scope; (2) accepted S1
locator and locator receipt for that scope; (3) the exact accepted AD45 common
handle/envelope; (4) accepted F0 source-factory product and root/reviewer scope; and
(5) an independent attestor with an externally verifiable identity, public key or
certificate, signing interface, verifier, trust-root binding, and documented
replay/revocation/freshness policy. AD46 is a contract boundary consulted by this
preparation audit, not an additional S3 input. A fresh S2 `review_pending` product
cannot satisfy item (1).

A future Present identity must bind exact source bytes/path/HEAD/status and full S1
closure; exact S2 product bytes and hashes; exact AD45 and F0 refs/hashes; source
semantic/content/declaration digests; scope and version axes; and a detached
attestation over a canonical preimage. The attestation metadata must identify the
independent signer, algorithm/profile, public-key or certificate fingerprint,
trust-root reference/fingerprint, signature encoding, signed-preimage digest,
issuance time, freshness window, nonce/replay token, revocation status, and verifier
version. The receipt must replay the same verification in a separate process and
record PID/UTC/exit/raw hashes without using the runner exit as authority.

`Present...` is allowed only when all exact inputs are accepted and current, the
signature verifies under the declared algorithm/profile and trusted root, signer
identity is independent of the authoring/factory/root decision, and replay,
revocation, freshness, scope, path, HEAD, source, S1, S2, AD45, and F0 checks pass.

`Absent...` with `terminal_deferred` and `no_publish=true` is required when any
required signer, key/certificate, verifier, trust root, revocation/freshness policy,
accepted fresh S2 input, or candidate-bound source input is unavailable. In the
current repository this is the expected result for all four scopes because the
independent cryptographic attestor mechanism is absent and fresh S2 is not accepted.

`Failed...` with `fail_closed=true` is required when an attestation exists but is
invalid, tampered, stale, replayed, revoked, foreign, wrongly scoped, signed under
the wrong algorithm/profile/root, or mismatched against any exact upstream bytes,
path, HEAD, scope, version, S1, S2, AD45, F0, or canonical preimage. A failure must
not rewrite or partially publish a prior product.

## Required negative controls

The future independent reviewer must execute and retain raw evidence for at least:

1. unsigned self-authored JSON, `:trusted_receipt` enum-only data, factory receipt,
   reviewer name, test exit, or runner exit presented as attestation → `Absent...` /
   `terminal_deferred`;
2. missing signer, private-key access, public key/certificate, verifier, trust root,
   revocation source, or trusted time/freshness source → `Absent...` /
   `terminal_deferred`;
3. changed source bytes, source hash, path/status, HEAD, S1 locator/receipt,
   accepted S2 product/hash, AD45 envelope/handle, F0 product/hash, scope or axes →
   `Failed...` / `fail_closed`;
4. signature-bit, canonical-preimage, algorithm, profile, certificate-chain,
   signer-identity, or trust-root tampering → `Failed...` / `fail_closed`;
5. foreign signer, wrong scope, wrong candidate handle, wrong version, revoked key,
   expired/future/untrusted timestamp, nonce reuse, duplicate receipt, or replayed
   signed bytes → `Failed...` / `fail_closed`;
6. attempted self-reference through the S3 product hash, final declaration hash,
   candidate hash, URI, seed, fixture, or test/runner result → `Failed...` /
   `fail_closed` and no identity materialization.

## Review separation and exit gates

The source identity reviewer must be a different Luna/process from the factory
author and must independently read the exact source bytes, S1, accepted fresh S2,
AD45, F0, canonicalization/profile, attestation and verifier outputs. The root Sol
may accept the review scope but cannot be the sole source attestor. The reviewer
must record its identity as task/reviewer/model/PID/UTC plus detached receipt hash;
these fields identify the review and do not substitute for a signature or trust root.

The future S3 exit gate is: all eight products exist at their exact paths; every
product and receipt parses canonically and has exact bytes/SHA closure; each scope's
Present/Absent/Failed result is replayable in two independent processes; negative
controls produce the declared union member; signer, verifier, trust-root,
revocation, replay and freshness metadata are independently checked; accepted fresh
S2 is used; no source/core/test/task-manifest/registry file is changed; and a
different Luna review plus root scope decision is complete. Until then S3 remains
`pending`.

## Cleanup and forbidden actions

This preparation task owns only the three documents and `archive/**` listed above.
No planned S3 scope directory or formal product is materialized. Existing AD48-S1,
old S2, fresh S2, F0, AD45, AD46, AD42–AD47 products, source, tests, fixtures,
registry, core README/planning, task manifest, and unrelated dirty work are
protected and remain untouched. Any future scratch/process/raw artifact must be
recorded in the task-owned archive; ambiguous ownership is retained and marked
`cleanup_deferred_ambiguous`, never broadly deleted.

## Conclusion

This is a complete S3 preparation boundary only. The expected formal result for all
four scopes is `AbsentG3TrustedSourceIdentityV1` plus
`AbsentG3TrustedSourceIdentityReceiptV1` with `terminal_deferred`, once a future
independent review is dispatched and the exact accepted fresh S2 products exist.
No trusted attestation is currently available, and no formal S3 identity or receipt
has been issued.
