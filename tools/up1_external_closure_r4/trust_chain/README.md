# UP1 external-closure R4 trust-chain prototype

This directory contains an offline, non-authoritative verifier.  Callers must
provide the root and every certificate as raw bytes (or a path/mapping that
resolves to those bytes); no official root, system trust store, network,
revocation service, trusted time service, or external authority is consulted.

`verify_request` and `verify_chain` hash exact raw certificate bytes, enforce
root → intermediate(s) → leaf order, issuer/signature and CA/key-usage/path
constraints, and apply a closed SHA-256 algorithm policy.  Missing material or
missing `cryptography` is `typed_absence`; malformed material is `invalid`.
Cryptographically consistent local material is `unverified`, always
`authoritative=false` and `no_publish=true`.

`TEST_ONLY` requests are explicitly marked `evidence_class=non_evidence`.
They are useful only for exercising software behavior and can never become a
formal external trust-root or S3/AD conclusion.
