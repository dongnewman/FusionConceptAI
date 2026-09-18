# VNext T1 candidate binding V2 local profile R3 preflight

Status: `preflight_only`; accepted: `false`; claim ceiling: `contract_only`.

This independent second-process replay profile is frozen against HEAD
`3e5eec7`. It protects 35 exact-byte/ SHA-256 assets: the current binding
contract and dirty-worktree inputs, the R2 runner/manifest/report, and every
R2 lock and receipt artifact required to establish the reference stdout. R2
is read-only for this profile and is never overwritten. The R3 runner is a
separate self-contract (`runner.ps1`, 16534 bytes) whose canonical hash is
`2747220c3b555bd74bf204f1152f20e040ee340a1dd520f67ff51f82193db9c4`; it
replaces only its fixed hash literal with 64 ASCII zeroes before hashing.

No Julia/DESC process was started by this preflight. R3 has no `runtime.lock`
or `run_*` receipt directory yet. The runner permits exactly one explicit
invocation of the existing T1 test command, forces `JULIA_NUM_THREADS=1`,
uses a 300-second `WaitForExit(milliseconds)` bound without retry, requires
zero Julia/DESC processes before launch, kills only its owned process tree on
timeout, and requires two consecutive zero-process postflight observations
250 ms apart.

R3 reads the frozen R2 `julia.stdout.raw` and requires the new process's
stdout replay line to match R2 exactly for `schema`, `version`, `status`,
`candidate_digest`, `wire_hash`, and `receipt_hash`; both receipts must also
show the named T1 test summary at `24/24`. A mismatch is a distinct
`replay_mismatch` status and cannot receive runtime credit.

Static validation completed without Julia:

- binding static QA: PASS, 26 checks;
- independent Python oracle: PASS, 14 checks;
- PowerShell AST parse: PASS, 0 errors;
- runner canonical self-hash and frozen 35-file byte/hash contract: PASS;
- R2 stdout receipt: present, 464 bytes, SHA-256 pinned in `manifest.json`;
- R3 `runtime.lock` and `run_*` receipt: absent as required before execution.

This preflight grants no T1, integration, or UP1 runtime credit. Acceptance
requires the separately authorized single R3 runtime attempt, exact R2
fingerprint equality, and independent review.
