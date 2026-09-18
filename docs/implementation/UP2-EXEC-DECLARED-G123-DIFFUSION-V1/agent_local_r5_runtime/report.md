# UP2-EXEC-DECLARED-G123-DIFFUSION-V1 — agent-local R5 runtime

## Execution boundary

The approved command was started exactly once in the foreground:

```text
JULIA_NUM_THREADS=1 julia --startup-file=no --history-file=no --project=. test/RuntimeV4/DeclaredG123DiffusionExecution/focused_tests.jl
```

No DESC command was started. The wrapper failed immediately after Julia start
when assigning the read-only PowerShell automatic variable `$PID`; therefore
the Julia process's PID, stdout, stderr, exit code, and duration were not
captured. The command was not rerun. Post-failure process inspection found
zero Julia/DESC processes.

## Result ceiling

This is an incomplete runtime receipt. `claim_ceiling=screen_only` and
`accepted=false`; no UP or R credit is issued. Positive assertion groups
(compile/transfer/composition/numerical/aggregate), negative dispatch groups,
numeric matrix/RHS/solution, and conservation were **not measured in this
receipt**. Existing R4 Python/static results are retained separately and are
not relabeled as Julia evidence.

For handoff completeness, the ten negative cases and numeric values that the
focused test is designed to check are listed here as **prior contract
expectations only**, not as observations from R5: `invalid_overlap` =>
`terminal_deferred:invalid_overlap`; candidate, bundle-hash, and body-hash
mismatches => `fail_closed`; unsupported expression subset =>
`terminal_deferred`; missing G2 mesh authority and missing G3 feedback
authority => `terminal_deferred`; singular and nonfinite derived systems =>
`numerical_fail`; ledger contradiction => `fail_closed`. The prior fixture
expects a ready compile/transfer, deferred composition and aggregate, ready
numerical solve, transfer state `(0.25, 0.75)`, matrix
`[[9.1125,-4.6125],[-4.6125,9.3375]]`, RHS
`[1.1666666666666667,2.666666666666667]`, solution
`[0.36346540908222763,0.4651299454948799]`, and zero conservation residual.
R5 measured none of these because stdout/stderr/exit capture failed.

## Integrity

All six owned source/test files have identical SHA-256 hashes before and after;
no product or test file was modified. Both pre-run and post-run Julia/DESC
process counts are zero. See `run_metadata.json`, `raw_capture_status.json`,
`owned_hashes_before.json`, and `owned_hashes_after.json`.
