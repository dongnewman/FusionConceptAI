# Independent T2 R19 postrun review

**Verdict: NO-GO — run incomplete.** This review classifies the captured R19 attempt only. It does not grant T2 acceptance, scientific credit, or a new run.

## What happened

The outer shell exit was reported as 1 by the root task. The actual-run leaf has no separate outer invocation stdout/stderr/exit sidecar, so that outer code is not independently rehashed here. The immutable pipeline record itself is `status=fail`.

The three pre-baseline phases ended naturally with exit 0: `parse_gate` (1.0217 s), `coverage_ast_inventory` (2.8327 s), and `projection24_cross_run_validation` (0.3857 s). `actual_formal_baseline` ran for 48.7539746 s of its 480 s limit, then ended with child exit 15 and `stop_reason=process_tree_monitor_incomplete`. Peak process-tree working set was 819,822,592 B against 2,147,483,648 B; this was not a resource-limit stop or wall timeout.

There were 161 samples: 160 complete and one incomplete. At sample 161 (48.4503469 s), the authoritative before-SPI snapshot contained a direct child row `[18528, 86060, 134348254310869192, "git.exe"]`. Controller R19 `independent_negative_controller_r19.py:4643` re-queries SPI inside the row handle provider. The row was absent from that fresh table, so R23 `ProcessHandleRegistry.for_row` (`supervise_r16_root_audit_r23_v1.py:112–118`, rejection at line 117) raised `MonitorIncomplete: cannot open a process absent from current SPI snapshot`. The post-snapshot and resource receipt for that sample are null; it was correctly not treated as a complete measurement.

This is a process-monitor/program interruption, not a science or numerical failure. The final exact process-tree audit and termination receipt are complete, report no residual descendants/heavy processes, and confirm the Julia root and conhost exited. A current `Get-Process` probe found none of the historical PIDs and no Julia process.

## Evidence boundary

The pipeline has only four phase records; no authority phase or negative shard began. Case/site/hit aggregate receipts are absent or null, `formal_t2_accepted=false`, and science/physical acceptance are false. The recorded zero case counts do not constitute a coverage result.

I rehashed all 655 frozen input pins against pipeline start, final-before, final-after, and current disk: 655/655 matched at each point, zero mismatches. The 104 positive-reuse pins, 4 positive-dispatch file pins, 10 positive-evidence file pins, 9 active-guidance pins, and current controller/driver/map/R23 helper hashes also matched. Pipeline-start/final input dicts were equal; HEAD remained `63792ca22958ffca8c3fa8e642256eb9f7240724` before, after, and at review time.

Key frozen hashes:

- Protocol: `1b0e6f4e2267b32c83195b7cf0cf0b92c3b8d356b8fd69b6840f3cfdcf6810b8`
- Controller R19: `1d955e17b4b9634ab5288ada36d4e30d6402bf56670b14f8e9afabfde1f252ca`
- Coverage map R16: `7cb1c9ed0d32c5ef09c135b185d42865fa22ed7381907a325ed63561fe19db56`
- `pipeline_final.json`: `02b42759ed668bf6e822fbede824ffcc69091a10498c131e383aa7baae510e9b`
- Baseline `phase.json`: `3046341512e9067ec13c349f7c9beaa23430d2fb921c9b04dee534c523bcecda`
- Baseline `samples.jsonl`: `72ff60839fc1b1bc96e9385d6c7e8e2ea3eb6f73cc9fa731a1698a49f1f94a18`
- Baseline `stdout.raw`: `96cf04a7c90b44dd8ee696fd080cce878af64ec93c246f10211122581dbae495`

Full per-file actual-leaf hashes and the independent input audit are in `actual_raw_file_hashes.json` and `verification_receipt.json`.

## R20 criteria

1. Preserve this R19 failure leaf. Use a new versioned controller/protocol and a fresh output path.
2. Bind each row's handle validation to the exact authoritative before-snapshot row; remove R19's per-row fresh SPI query at line 4643. Keep exact `(pid, FILETIME)` handle checks and post-read identity verification.
3. Never drop or zero-measure a process found in the before snapshot. If exact handle acquisition or resource reading fails, keep the sample incomplete unless a fully specified bounded retry obtains a new complete sample.
4. A child that is measured through an exact handle and exits before the after-snapshot may only be represented with a typed measured-then-exited receipt binding the before row, handle identity, resource read, and after snapshot. Detect PID reuse and never signal or count the new generation as the old one.
5. Add deterministic tests for the observed before-row/fresh-query-missing race, exit before handle acquisition, exit after successful measurement, PID reuse, a child appearing after the before snapshot, malformed snapshots, and handle/resource-read errors. Keep failures fail-closed when measurement is incomplete.
6. Run Python-only Windows host smoke with a controlled short-lived child and retain exact before/after generation data, measurement/termination receipts, and no-residual-process evidence.
7. Preserve all R19 coverage and resource gates: 30 phases, 45 formal cases, 60 unique cases/68 case hits, 214 source-site IDs/622 planned hits, 480 s ordinary phases, 600 s preflight override only, 2400 s authority limits, 2 GiB sampled stop, and one Julia/BLAS thread.
8. Before any new serialized run, rehash the frozen closure, preserve R19 as failure lineage, ensure the new output leaf is absent, and verify the heavy lane is empty. This NO-GO is not itself authorization to run.

## Review execution

Read-only commands exited 0: Python `-B` pin/raw/sample audit; Python `-B` protocol SHA check; Python source-line inspection; PowerShell exact-PID/Julia process probe. No Julia was started and no implementation source was changed. The command/result record is `commands.json`.
