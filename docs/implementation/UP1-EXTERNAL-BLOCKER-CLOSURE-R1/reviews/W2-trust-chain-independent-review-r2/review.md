# W2 trust-chain repair R1 — independent round-2 review

## Decision

`rework_required`. The seven original findings are substantively closed by the R1 contract, but the repaired package has a new exact-set defect: `manifest.json` and `cleanup_inventory.json` enumerate only the first raw stream while `validation_receipt.json` and the directory retain a second final raw stream. This prevents an exact, lossless artifact handoff. Claim ceiling remains `preparation_only`; no trusted attestation, authority, T0, B00, B04, R, L4, or parent credit is granted.

## Scope and read-only boundary

Reviewed the prior W2 review and `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/trust_chain/**`. No trust-chain input, source, test, AD, registry, key, certificate, CRL/OCSP response, timestamp, or production trust material was changed. Only this r2 review directory is written. Prior failure/raw material remains retained.

## Recomputed checks

- All nine current trust-chain files were enumerated. Every JSON file parsed with a duplicate-key rejecting hook. The 11 register IDs map losslessly to `validation_receipt.expected_absence`.
- The documented canonicalization was independently reimplemented: UTF-8, recursive key sort, `input_records` sorted by `id`, no whitespace, no terminal LF, fingerprint field excluded. Preimage length is 5250 bytes and SHA-256 is `46bdf639a83f158307dfa0e1abb304c907449025f3e5ca8cc645c5aad763e5cd`, exactly matching the register.
- Revocation semantics are now distinct: revoked/unknown/expired/invalid response is `fail_closed`; unavailable or untrusted external service is `revocation_status_unavailable`, `typed_absence`, `terminal_deferred`, `no_publish=true`. The trust-path `fail_closed_on` list no longer conflates unavailable.
- Validation stages 0–8 explicitly put canonical schema/digest/scope/source binding before root/path construction. The six HEAD owners and three AD56 dirty executor paths were checked against current bytes, `git hash-object`, and `HEAD:path` blob OIDs; all matched the recorded values.
- `TEST_ONLY-W2-R1` is explicitly `production_use:false`; production profile is `typed_absent`; unknown/missing profile is `fail_closed`. Authority decisions are the closed enum `unknown`, `unavailable`, `rejected`, `accepted_for_declared_scope`.
- Both retained raw streams match their recorded byte counts and SHA-256 values. Independent checker PID 30136 ran 2026-09-16T15:32:42.675845+00:00–15:32:43.926266+00:00, exit 0, raw result SHA `069d1f1b89dcdbd0e8005217c152d4baa38410eb8368545b5fc6662e3df9803c`.

## Original finding closure

`W2-P1-001` (11 IDs), `W2-P1-002` (recomputable fingerprint/no-repeat rule), `W2-P1-003` (revocation unavailable taxonomy), `W2-P2-004` (stage 0/1 ordering), `W2-P2-005` (6+3 exact source inventory), `W2-P2-006` (concrete TEST_ONLY profile plus typed-absent production), and `W2-P3-007` (closed authority enum) are closed in substance and independently verified above.

## New residual finding

`validation_receipt.json.raw` and `manifest.json.current_artifact_sha256_excluding_manifest_self` include `raw/static_json_validation_r1_final.stdout.raw`, but `manifest.json.outputs`, `cleanup_inventory.json.owned_products`, and `final_exact_owned_set` mention only `raw/static_json_validation_r1.stdout.raw`. The actual set is therefore 9 files, not the declared 8-product set. The final raw is not safe to hand off or clean up by manifest-driven tooling. Repair by adding the final raw to the declared outputs/owned set and recomputing all dependent hashes, then obtain another independent review.

## Gate decision

Do not run fresh S3 or create a synonymous AD for the unchanged fingerprint. This package is a useful preparation contract only. Sol/high retains all scope and formal-gate decisions; this Luna review does not open any gate.
