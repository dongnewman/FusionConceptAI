# UP1 R4 trust-chain external-input recheck

## Decision

`NO_NEW_EXTERNAL_TRUST_MATERIAL`. At the fixed checkout identity
`b2c04d8339774635aaecd73651efcdb101e01b5d`, no new project trust root,
ordered certificate chain, intermediate certificate, external signature
profile/usage policy, or externally verifiable chain-validation package was
observed. The external trust boundary remains `typed_absent`; local software
artifacts remain `untrusted` for authority purposes. Nothing is `usable`.

The disposition is unchanged:

```text
new_ad=false
s3_rerun=false
formal_credit=none
usable_external_inputs=0
external_inventory=26/26 typed_absent
```

This is a bounded offline observation. It does not query remote channels and
does not claim that an unlisted channel is globally empty.

## Read-only scope and raw evidence

The scan covered both `D:/006-Programing/LMC` and
`D:/006-Programing/LMC/FusionConceptAI`, using the seven frozen intake
relative paths `local_spool`, `local_spool/incoming`, `response`, `anchors`,
`local_receipts`, `incoming`, and `intake`. All 14 root/path pairs were
absent and contained zero files. A recursive working-tree scan excluding
`.git` and `__pycache__` found zero files with certificate-like extensions
(`.pem`, `.crt`, `.cer`, `.der`, `.p12`, `.pfx`, `.csr`, `.sig`, `.tsr`,
`.crl`, `.ocsp`). An extension-scoped PEM marker scan returned exit `1`,
which means no marker matched.

The authoritative raw record is `raw/recheck.raw.json`. The bounded scan ran
with PID `56748`, UTC `2026-09-17T04:02:27.5045664Z` to
`2026-09-17T04:02:29.2982589Z`, exit `0`. The explicit certificate-extension
marker scan ran with PID `2760` at
`2026-09-17T04:03:09.7402230Z`, exit `1` for no match. One discarded
option-sensitive exploratory marker invocation returned exit `2`; it is
recorded in the raw file and has no evidentiary effect. No network, certificate
store, private-key material, Julia, DESC, or S3 path was used.

The prior R4 inventory independently records every external trust-related
record as `typed_absent`, including `EXT-TRUST-ROOT`, `EXT-CERT-CHAIN`,
`trust_root`, `intermediate_chain`, `leaf_attestor`, `signature_profile`,
`signed_receipt`, `verifier`, `revocation_source`, and `trusted_time`.
The prior system-store fingerprint records 590 entries and 301 unique
thumbprints unchanged from baseline, but explicitly says
`project_trust_root=typed_absent`, with no certificate bytes exported and no
private-key material read. A generic Windows/user store is not a project root.

## Material classification

| Material | Status | Finding |
|---|---|---|
| Project trust root / pinned anchor | `typed_absent` | No `anchors/project-root.pem` or `anchors/trust_anchor.json`; no fresh scope/policy/fingerprint/validity/rotation/revocation provenance. |
| Root → intermediate → leaf chain | `typed_absent` | No `response/chain.pem`, `response/leaf.pem`, or intake response; no new intermediate bytes or issuer links. |
| Signed attestation / detached signature | `typed_absent` | No externally supplied signed receipt, signer identity, canonical payload binding, trusted time, or replay receipt. |
| Signature algorithm and usage constraints | `untrusted` | R4 verifier source and tests define local closed-enum SHA-256, algorithm, CA/key-usage/path, EKU and policy checks; these are software behavior, not an externally issued profile or authority receipt. |
| Chain-validation material | `untrusted` | R4 runs 08/11 are local generated-fixture tests and offline replay evidence. They establish only `authoritative=false`, `no_publish=true`; they do not establish production PKI trust. |
| Generic certificate stores | `untrusted` | Prior R4 store metadata is unchanged and explicitly non-project-authoritative. No store bytes were read in this recheck. |

## Responsibility and recovery conditions

The blocker owner is the external project PKI/trust administrator for the
root and profile; the attestor PKI/CA owner for ordered chain/intermediate,
issuer, constraints and revocation; the independent attestor for the leaf,
identity and signed receipt; and the independent verifier/policy owner for a
versioned hash-pinned verifier/profile and replay receipt.

Recovery requires one fresh, candidate-bound package through an authorized
channel. It must include public root bytes and SHA-256 fingerprint, ordered
root/intermediate/leaf bytes, issuer/signature and AKI/SKI links, validity,
Basic Constraints, key usage, EKU, exact algorithm/digest/encoding policy,
canonical payload digest, detached or receipt signature, trusted-time token,
fresh CRL/OCSP/revocation evidence, nonce/sequence/idempotency/replay
material, and the independent attestor/verifier scope. A local fixture,
reviewer identity, repository hash, URI, seed, test exit, provider root, or
system store cannot substitute for any of these.

## Validation-command contract for a future fresh bundle

These commands are a contract only; they were not run because no request
bundle exists:

```powershell
python -B -m tools.up1_external_closure_r4.trust_chain --request <request.json>
python -B -m unittest discover -s test/up1_external_closure_r4/trust_chain -p "test_*.py" -v
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/11-trust-chain-repair-independent-retest/static_attack_probe.py
```

The request verifier must receive raw root/intermediate/leaf bytes and a
versioned production profile; it must return a cryptographically consistent
result only with `authoritative=false` and `no_publish=true` until the
external authority, trusted time, revocation and replay inputs are independently
verified. Missing material must remain `typed_absent`/`terminal_deferred`.
Only after those checks pass may the root owner perform the separate authority
recheck; this report grants no AD, S3, T0/T1/T2, publication, or formal credit.
