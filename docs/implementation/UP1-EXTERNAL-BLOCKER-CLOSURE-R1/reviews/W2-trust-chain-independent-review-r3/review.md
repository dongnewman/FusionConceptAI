# W2 trust-chain repair R1 — round-3 independent review

## Decision

`pass_limited`. Round2 finding `W2-R1-P2-001` is closed: the actual nine-file trust-chain set now exactly matches `manifest.outputs`, `manifest.owned_exact_set`, `cleanup_inventory.owned_products`, and `cleanup_inventory.final_exact_owned_set`. Both manifests explicitly exclude only their own self-referential files from non-self hashes. All non-excluded artifact hashes match, and the seven prior security findings remain closed with no regression.

This is preparation evidence only. It grants no T0, B00, B04, UP1, R01–R10, L4, trusted attestation, source authority, or parent-goal credit.

## Scope and boundary

Read-only review of `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/trust_chain/**` and prior W2 review conclusions. Only this r3 review directory is written. No trust-chain input, source, test, AD, registry, key, certificate, CRL/OCSP response, timestamp, or production trust material was changed.

## Evidence

- Actual recursive set is nine files and equals both manifest/cleanup exact sets. The previously omitted `raw/static_json_validation_r1_final.stdout.raw` is now listed everywhere required.
- `current_artifact_sha256_excluding_manifest_and_cleanup_self` in both manifest and cleanup has the same seven keys; every recorded SHA-256 recomputes exactly. The only excluded paths are `manifest.json` and `cleanup_inventory.json`; no hidden raw/ledger path exists.
- Every JSON parses with a duplicate-key rejecting hook. The retained raw receipts have their recorded byte counts and SHA-256 values.
- Independent regression checker PID 23572 ran 2026-09-16T15:40:05.045324+00:00–15:40:05.051428+00:00, exit 0, raw SHA `042937c39dfc5598bbc2bc94ab6fea8446e5b23ce13ba4b4dc564204ea3aff0d`.
- Spot checks still pass for all seven prior security findings: exact 11-ID lossless absence mapping; canonical register fingerprint/no-repeat rule; distinct unavailable versus fail-closed revocation semantics; Stage 0/1 digest and scope/source binding before path construction; six HEAD plus three AD56 dirty executor path/SHA/OID inventory; TEST_ONLY profile barred from production with production typed absent; and closed authority enum.

## Gate decision

The package is a limited preparation handoff only. Keep fresh S3 and synonymous AD blocked while the canonical fingerprint is unchanged. Sol/high retains all formal scope decisions; this review does not open any formal gate.
