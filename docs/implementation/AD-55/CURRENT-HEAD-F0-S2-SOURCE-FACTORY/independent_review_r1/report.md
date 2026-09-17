# AD-55 F0/S2 independent review R1

Verdict: **pass_limited**; `accepted=false`.

This independent review replayed the current HEAD source-stage factory closure in strict serial order: F0, S2 run1, then S2 run2. HEAD is `b2c04d8339774635aaecd73651efcdb101e01b5d`. Each stage has a real Julia PID, UTC start/end, exit code, raw stdout/stderr and hashes in `test_receipts.json`; all three exited 0 and no Julia/DESC process remained.

The independent probes loaded the six canonical source-owner paths from the working checkout while deriving locator bytes and OIDs from `git show HEAD:path` / filtered `git hash-object --path`. All six are tracked, path-clean, and their filtered working OID equals the HEAD blob. The independently recomputed task manifest hash is `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`. The plan validator had exit 0 with 31 markdown files, 534 relative links, 39 tasks and an acyclic DAG.

The 18 canonical G1/G2/G3 identity, declaration and receipt JSON outputs are byte-for-byte and SHA-256 equal between S2 run1 and run2. Negative controls are `fail_closed`; the three `nothing` controls are `typed_absent`. No AD-56 S2 output was reused. The prior AD-55 F0 failure history remains present and hashed in `hash_inventory.json`; outside-scope dirty status is unchanged.

Claim ceiling: this evidence covers only source-stage factory software identities and receipts. It does not create source authority, trusted attestation, candidate or final identity, provider, mesh, solver, engineering, physics, search, R01-R10, or L4 credit. Fresh S3 remains pending.

The initial wrapper recording errors occurred before the successful replay and did not modify source, tests, old evidence, index, or commit; the observed PowerShell encoding error is retained in `runner_debug.raw`.

Scope: f0_s2_execution_r2. The authoritative review manifest is the top-level manifest.json. The copied F0 probe auxiliary manifest is retained as a stage trace.


