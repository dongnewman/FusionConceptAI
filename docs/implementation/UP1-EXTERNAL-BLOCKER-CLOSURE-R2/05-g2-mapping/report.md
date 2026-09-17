# UP1 external blocker closure R2 — G2 mapping

## Scope

This bounded component adds an isolated standard-library JSON validator under
`tools/up1_external_closure_r2/g2_mapping/`. It does not modify any existing
G2 factory, registry, Genome identity, source authority, candidate, physical
provider, or evidence authority.

The validator checks exact namespace/version and UTC-aware interval/time,
issuer, signature algorithm/key id/certificate chain, trust-root reference and
fingerprint, policy OID, EKU, key usage, name constraints, revocation and
freshness, nonce/sequence/idempotency/replay, uniqueness, conflict/ambiguity,
duplicate keys, unknown keys, and the bidirectional chain
`source <-> candidate <-> four-axis evidence <-> G2`.

## Evidence boundary

`typed_absent` is returned when the authoritative mapping/trust material is not
supplied. A complete `TEST_ONLY` profile is a positive schema control and is
returned as `non_evidence`; it cannot grant production or UP1 credit. Present
profiles require a separate frozen expected-binding input containing the
expected candidate ID, source identity and four axis material set. Local
self-consistent foreign candidate/source edits therefore fail closed. The
validator recomputes domain-separated source-identity, declaration and
signature-payload hashes and checks all declaration/receipt/signature payload
copies. A structurally complete `PRODUCTION` profile with no externally
verified signature authority remains `fail_closed`; no production or UP1 credit
is claimed.

## Fresh run

The focused parameterized suite was run with `python -B` in a fresh process.
Raw stdout/stderr, PID, UTC boundaries, exit code, and SHA-256 hashes are
recorded beside this report. The suite covers positive TEST_ONLY,
typed absence, structural production, all required security negatives,
duplicate/unknown keys, duplicate refs/axes, edge mismatches, and isolated CLI
JSON output. The R1 independent-review P1 findings are retained as historical
failure context in `run_receipt.json`; the rework receipt records two fresh
processes and byte-identical semantic CLI replay in
`run_receipt_r2_rework.json`.

## Receipt/hash audit

The four zero-byte streams in the R2 rework receipt were recomputed from the
raw files and corrected to the actual empty-file SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The isolated integrity validator rechecked both historical and rework
receipts, all 15 referenced raw streams, all four empty streams, and all 10
manifest input artifacts in a fresh `python -B` process. It returned
`all_true: true`, exit code 0, PID 102184, UTC
`2026-09-16T18:35:55.7614560Z` to `2026-09-16T18:35:56.7957258Z`; raw output and
hashes are recorded in `integrity_audit_receipt.json`. The cleanup inventory
retains every historical stream and makes no deletion.
