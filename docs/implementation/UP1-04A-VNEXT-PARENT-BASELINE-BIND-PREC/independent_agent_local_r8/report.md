# Independent static review — parent LocalV1 R8

Date: 2026-09-17 (Asia/Shanghai). Julia/DESC were not run; no product file was modified and no commit was made.

## Verdict

**PASS — one new focused `agent_local` wrapper run is allowed.** The R7
`75 passed / 1 failed / 1 errored` receipt is a valid test-repair trigger, not
evidence of a product-source defect:

1. The R7 line-174 failure applied `in` to a single Julia `Symbol`. R8 uses
   independent `===` comparisons for the G1 and G2 reasons.
2. The R7 tamper assertion captured canonical bytes before mutating the state,
   so it compared the receipt against the wrong snapshot. R8 mutates the local
   state snapshot first, copies that tampered snapshot, and requires the
   rejection receipt to echo it exactly.

The source implementation remains unchanged from R7 (`e70b3058...a5bf60`).
Its `_vnl_failure` path copies the exact current state bytes, preserves the
canonical/state/source/history values, and sets `published=false` and
`history_advanced=false`; `verify_local_state_v1` rejects the tampered state
before publication. The R8 test therefore checks the intended failure
atomicity rather than weakening it.

## Evidence

- R7 raw receipt is unchanged: outer `75/1/1` (`75` pass, `1` fail,
  `1` error, total `77`); nested empty-factory negative group `2/2`.
- R7 stdout SHA-256:
  `bb25567de7df7d6eb7fb0907d5ec4b7117bf062f524317d412792c2f3a9582db`.
- R7 stderr SHA-256:
  `ba9cd545e98116cac6c47ddb35dfc4cf6910dea94a9ad04669947c53fcbd46c3`.
- Static QA independently rerun without Julia: exit `0`, `133/133`,
  `errors=[]`.
- Current product hashes match `agent_local_r8/evidence_manifest.json`:
  source `e70b30588f95d76c0c840fe73f2363e174c992f521dba875d255a3b862a5bf60`;
  test `e3fec0bbe0ed6975f162c1c31227f8ca29ae85e899ac24f3745c8d372136d721`;
  fixture `73b5f76bcab418147bd380abd05ecfe9d306b6d5c986090f30410d14ac5a2882`;
  static QA `4e82b7708e90e8d064208d6d5d790593ab776e920bf2235a22ff056c92c22a2e`.
- R8 remains `prepare_only_runtime_input_adapter`, `accepted=false`,
  `present_authority=false`; the upstream boundary is
  `accepted_local_contract`, while actual source-backed parent present
  authority remains pending this node verification.

## Authorized next action

Run exactly once, writing only to:
`runs/agent_local_up1_04a_parent_r8_focused_julia_20260917`.

```powershell
python -B tools/agent_local_execution.py `
  --task UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC `
  --input src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json `
  --input test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py `
  --output runs/agent_local_up1_04a_parent_r8_focused_julia_20260917 `
  --timeout 300 `
  --run C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe `
    --startup-file=no --project=. `
    test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
```

That run remains contract-only/prepare-only. It must not be interpreted as
parent authority, formal acceptance, or R01–R10 credit.
