# W3 source/G2/environment independent review — R3

## Decision

`rework_required` for preparation only. The two R2 findings are materially closed for a bounded, non-authoritative screen: the production-profile evaluator rejects duplicate and unknown fields, checks every declared security field, rejects all 24 parameterized negative cases plus the duplicate-key case, and returns `TEST_ONLY` as `non_evidence`. Input/output artifact hash maps and explicit self-hash exclusions are present and were independently observed in a fresh run. No production G2 profile or trust root is present, and no UP1/B00/B04/R/L4/parent credit is granted.

Two R3 metadata defects remain open: `cleanup_inventory.json` says 48 exact paths while the manifest and disk contain 47, and manifest `allowed_files` contains five duplicate entries. These are receipt exactness defects, not evidence of a newly supplied external input. They require a future source-owned repair; this review does not modify the source directory.

## Fresh authoritative rerun

Command: `python -B static_validator.py` with cwd `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/source_g2_environment`.

- PID: `78268`
- UTC: `2026-09-16T16:20:53.3369625Z` to `2026-09-16T16:20:55.3910840Z`
- exit: `0`
- stdout: `raw/static_validator_r3.stdout.raw`, SHA-256 `d19d838579973178502abbd2efef6d2d2ca7f82d56b49db1c19b63af75babc4d`
- stderr: `raw/static_validator_r3.stderr.raw`, SHA-256 `c511c32526b0565e9bd4b55a25cb749bc8d063f98ee2acee024e1b55933de6fb`
- combined: `raw/static_validator_r3.combined.raw`, SHA-256 `7209eb8efa0fc50a07d7ce6e490e51a7693ba06653de336995c91d40e5491c3f`

The fresh JSON result is `status=pass`, `negative_case_count=25`, `production_profile=pass_non_evidence_only`, `test_only=non_evidence`, and `artifact_hash_policy` reports 22 inputs and 22 outputs with `manifest.json`, `cleanup_inventory.json`, and `validation_receipt.json` excluded. The validator source does not read an expected-output fixture; it constructs each negative mutation and requires an evaluator exception.

The prior authoritative R3 run remains preserved unchanged: PID `102332`, exit `0`, UTC `2026-09-16T16:15:11.1677142Z`–`2026-09-16T16:15:12.2042822Z`, with its raw/hash maps in `source_g2_environment/validation_receipt.json` and `repair_r3/ledger.json`. Both R2 failures (PIDs 24644 and 111940) remain retained as failures.

## Adversarial checks

The evaluator's closed schema validates namespace, version, effective interval/trusted time, issuer and chain, signature algorithm/bytes/key/certificate chain, trust-root fingerprint/policy OID/EKU/key usage/name constraints, revocation status/source/time/freshness, nonce/sequence/idempotency/replay, ambiguity/conflict, and bidirectional source/candidate/evidence hash edges. Its duplicate-key object hook and unknown-field rejection are exercised. `valid_present.json` is explicitly `TEST_ONLY`; structural acceptance returns `non_evidence` and `production_admissible=false`.

The source validator checks HEAD/tree and typed dirty drift, four source-only axis materials, typed absence accountability, canonical input fingerprint/no-repeat state, environment and binary typed absence, exact input set, and artifact maps. R3's targeted diagnostic records the current dirty status/patch mismatch as `typed_drift_terminal_deferred`; it does not rewrite the old freeze or create an AD. No Julia, DESC, mesh, solver, recomputation, or physical execution was performed. No `__pycache__` directory exists under the source scope.

Independent exact-set check found 47 actual files and 47 manifest `input_exact_set` entries with equality and no missing/extra paths. The cleanup receipt's textual cardinality is stale (`48`), and `allowed_files` has duplicate list elements; these are the open findings above. Stderr contains only the known Git LF→CRLF warnings, and its fresh hash matches the preserved R3 warning stream.

## Scope and claim ceiling

This review writes only its own `reviews/W3-source-g2-environment-independent-review-r3/` directory. It does not change `source_g2_environment`, upstream registers, AD-55/AD-56, tests, source, or shared registries. Conclusion: `rework_required`; claim ceiling `preparation_only/screen_only`; formal credit `false`.
