# UP5-01 ConditionEnvelope R8 — independent postrun audit

Date: 2026-09-18 (Asia/Shanghai).

## Verdict

**GO for limited runtime-evidence handoff; NO-GO for formal UP5 acceptance.**
The R8 parent receipt and its runtime archive agree on HEAD
`a6b9de90143dd46cbfc81243735e1d2ba7eb6bf6`, exit `0`, `136/136`, `0.7s`,
empty stderr, and unchanged four-input hashes. The runtime archive records
the source and archive-copy SHA-256 for every raw artifact; all six pairs
reconcile to the recorded values. Current protected inputs equal the receipt.

This is an isolated contract/replay suite only. The permanent boundary remains
`contract_only / screen_only / accepted=false / no_publish=true`, with no UP5
or R01-R10 credit. R3-R6 failure receipts and the R7 independent **NO-GO**
identity-ordering review remain preserved; R8's runtime pass does not erase
that lineage or substitute for broader engineering/physical evidence.

## Runtime receipt reconciliation

Reviewed read-only:

- `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r8/`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-UP5-01-CONDITION-REPLAY-R1/agent_local_r8/runtime/`
- R8 `agent_local_r8/manifest.json`, `report.md`, and static-QA raw output
- R3-R7 failure/review lineage referenced by `runtime/lineage.json`

The source run reports:

```text
UP5-01 isolated condition/replay contract | 136 136 0.7s
exit_code=0
stderr_bytes=0
hashes_unchanged=true
```

`runtime/run.json` matches the source `run.json` for HEAD, exit code, and
`hashes_unchanged`. `input_hashes_pre.json` and `input_hashes_post.json` are
equal; their four listed hashes equal the current protected source, test,
fixture, and static-QA bytes. The archive's JSON/head copies are newline-
normalized, so their byte counts differ from the source receipt as documented;
the archive manifest records both source and archive hashes rather than hiding
that transformation. `stdout.raw` and zero-byte `stderr.raw` are byte-identical.

## Raw artifact SHA-256 audit

| artifact | source bytes / SHA-256 | archive bytes / SHA-256 | result |
|---|---|---|---|
| `head.txt` | 42 / `c44b2634ca72a19edd7c8333aff351e8bdf313255b5c24114764a0ae6c93fa17` | 41 / `ff15039a81236eeb9a0c3bf2b3d86301c7b73f3b283ddf53727a87e46edcab19` | manifest match; normalized copy |
| `input_hashes_pre.json` | 742 / `76ca0d09affcd8688b4b9286348d30c8ff47596b7af117f120322944ee4d28c1` | 724 / `90bfa79a66b3bd8e68865957f8c0dfb632c5d1680cc849cc06ef534fa647d509` | manifest match; normalized copy |
| `input_hashes_post.json` | 742 / `76ca0d09affcd8688b4b9286348d30c8ff47596b7af117f120322944ee4d28c1` | 724 / `90bfa79a66b3bd8e68865957f8c0dfb632c5d1680cc849cc06ef534fa647d509` | manifest match; normalized copy |
| `run.json` | 424 / `170ed43d1d52d9b5e8528ada83a4c42e6986163cf79555719e964124c2a7f4b4` | 416 / `94bf96d2f5907a1ef92a19cd386f2b9b4370fe63e1a1cff7d95bf5f9cef02fac` | manifest match; normalized copy |
| `stdout.raw` | 124 / `7d3ab18fbd7d89a66a001a4ee86b6fc7fd44c6d2e2652d313b9deec40531788c` | 124 / `7d3ab18fbd7d89a66a001a4ee86b6fc7fd44c6d2e2652d313b9deec40531788c` | byte-identical |
| `stderr.raw` | 0 / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 / `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855` | byte-identical |

## Failure lineage and claim boundary

`runtime/lineage.json` points to existing R3 ParseError, R4 test-macro
failure, R5 `sort(::Base.Generator)` failure, R6 `91/107` evaluation-binding
failure, and R7 independent `NO_GO` identity-bypass review. All referenced
directories were present during this audit. R8's 136/136 result demonstrates
the repaired isolated contract test only; it does not grant UP5, solver,
numerical, physical, engineering, conservation, convergence, VVUQ, or
R01-R10 credit.

## Current protected inputs

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `6d1076cd2d755932d6ecf0e016e188cc8b4f5471af10f1f6029f36379953586a` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `1468a3b0f1304540e0acc748e3308c777cef960ffb7b8ceec61da70946ccd242` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `245fb79a7f08fb6b509bf32186a56defd1a4f9cfd8be93f47bbbc56a83890a48` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `c4d5e29dfd60cd0ac7a160f65abb231e3974bcacabf75f11b2fafbd61fec1678` |

No Julia/DESC was started for this audit. No product/test file was modified;
only this postrun report and manifest were added. No commit was created.
