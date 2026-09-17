# W1 witness/authority repair R1 — independent round-2 review

## Decision

`rework_required`. The repaired package closes the six original contract findings in substance, and the 37-file cleanup inventory is exact with hashes matching every cleanup row. However, the manifest's `product_hashes_at_manifest_preimage.report.md` is stale: it records `d6b46b...`, while the current report and cleanup row are `346432...`. In addition, the negative fixtures are checked by a static assertion of their `expected=reject_fail_closed` labels, not by an executable acceptance/rejection implementation. These prevent a clean closure claim.

Claim ceiling remains `preparation_only`; this review grants no UP1, T0/T1/T2, B00/B04, R01–R10, L4, trusted authority, or parent-goal credit.

## Scope and boundary

Read-only review of `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/witness_authority/**` and the prior W1 review. Only this r2 review directory is written. No witness-authority input, source, test, AD, registry, key, certificate, timestamp, CRL/OCSP response, or production trust material was changed.

## Checks performed

- Actual recursive set is exactly 37 files and equals every path in `cleanup_inventory.final_exact_owned_set`; every cleanup-row SHA matches its current file, with only the cleanup file using the documented circular self-hash marker.
- All JSON parsed with a duplicate-key rejecting hook. Validation receipt input/output/artifact map covers 14 files and every recorded hash matches. The four failure records retain `exit_code=1`, raw paths, and explicit `collection_failure:pid_not_exposed_by_exec_capture` / timestamp markers; no PID or UTC was guessed. Successful PID `93696`, exit `0`, and raw SHA records are present and match the retained raw streams.
- External register has 10 typed-absence IDs. Each provider/owner/responsible party/authoritative source/authority reference/recovery/expiry value is non-null and agrees with the corresponding gap record. `verifier_ref` and `idempotency_key` have field contracts.
- Canonical preimage, digest equality, signature scope, request candidate/G1/G2/G3/four-axis/source/version/nonce/time bindings, freshness/revocation/trusted-time fields, and closed rejection semantics are all present. The positive fixture is typed absence/no-publish; placeholder, retry-policy, and foreign-layer fixtures are labelled `reject_fail_closed` and the static validator reports them as passing negative expectations.
- The independent checker PID 108788 ran 2026-09-16T15:45:37.433425+00:00–15:45:37.458587+00:00, exit 0, raw result SHA `108c5e074c200c703e27912ae15f228d05f76466c0a50e7270923f86288279d1`; it found the single manifest report hash mismatch described above. A fresh static-validator rerun PID 79076 exited 0 with stdout SHA `e89e9b25fb778f7c0f6d96e1ef23be7acf077855b4ee25dfc9e53381915499b5` and empty stderr.

## Original finding status

W1-F001 through W1-F005 are substantively closed. W1-F006 is closed at the contract-fixture expectation level, but its evidence is static-label based rather than a real verifier behavior test; this is retained as residual P2 rather than promoted to a production claim.

## Required rework

Update the manifest's report hash (or explicitly add a post-repair hash ledger) and rehash dependent evidence without changing the frozen scope. Add a small independent fixture evaluator that actually rejects placeholder, retry-policy and foreign-edge records, preserving raw/PID/UTC/exit/hash. Then obtain another independent review. Do not create a fresh S3 attempt or synonymous AD while inputs remain unchanged.
