# AD-56 independent review r1

Verdict: `pass_limited`; `accepted=false`.

The review confirms the AD-56 provenance portability repair within its narrow software scope. The three validators derive `source_bytes`, `source_sha256` and `head_blob_sha256` from `HEAD:path` blob bytes, require the real working file to exist and be readable, and compare the working checkout through an argument-array `git hash-object --path <repo-relative-path> <working-file>` filtered OID. Root/top-level, observed HEAD, HEAD tree path, unique stage-zero index entry, index flags, porcelain status, canonical length/hash, filtered OID, and path/status labels are jointly checked. No clean-porcelain-only or caller-field-only route to present was found. The old raw `bytes == head_bytes` gate is absent from all three validators.

Independent serial focused execution passed: G1 `35/35`, G2 `35/35`, and G3 `356/356`, all exit `0`; exact PID/UTC/stdout/stderr/hash receipts are in `test_receipts.json`. The additional current-repository adversarial probe passed `20/20`, exit `0`; source length, source hash, HEAD blob hash, and HEAD relabel mutations all failed closed while valid locators remained present. Its receipt is `adversarial_receipt.json`.

The current Windows checkout reproduces the AD55 portability condition: G3 realization raw bytes are `33751` versus canonical HEAD blob `33750`, and G3 control raw bytes are `10297` versus canonical `10287`; both raw comparisons are false while filtered OIDs equal their HEAD blob OIDs and porcelain is clean. The current canonical locator probe returned `present` for realization, control, binding and bundle. Canonical source inventory, stage-zero records, flags, porcelain and root/HEAD/tree results are in `hash_inventory.json`.

Scope protection held across the review. The existing dirty and untracked worktree was preserved; no source, tests, registry loader, runs, task manifest, old evidence, index or commit was mutated by this review. AD55 F0/S2 failure history remains retained. Cleanup was limited to review-owned generated artifacts; no Julia process, temporary fixture, `__pycache__`, or temporary file remains. See `dirty_protection.json` and `cleanup_inventory.json`.

The planning validator independently reports `31` markdown files, `534` relative links, `39` tasks and an acyclic DAG. The current task manifest hash is recorded as `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`. The pre-existing AD56 implementation manifest records a different observed hash (`f514c155...`) and labels the four plan counts differently; this is an evidence freshness discrepancy, not a validator or portability failure, so the review remains `pass_limited` and `accepted=false`.

Claim ceiling: this review establishes only provenance portability software behavior. It grants no source-authority, trusted, candidate, final, provider, mesh, solver, physics, search, R01-R10, or L4 credit (`L4=0`).
