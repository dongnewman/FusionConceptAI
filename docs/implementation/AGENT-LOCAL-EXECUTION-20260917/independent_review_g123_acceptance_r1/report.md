# Independent read-only review: G1/G2/G3 acceptance and status sync R1

Date: 2026-09-17. Reviewer: separate Luna. Product checkout inspected at
`8dbbb68b065c3ccd9a9f0f97a879aae8665eb2e9` (working tree intentionally dirty).
No Julia, DESC, product source, task status, or acceptance record was modified.

## Verdict

`PASS` for the recorded `accepted_local_contract` status of the three V1
declaration nodes, with the claim ceiling `contract_only`. The three current
source/test/fixture/static-QA byte hashes match their acceptance manifests and
the immutable wrapper records. All three acceptance records and wrapper
manifests parse as JSON/text; acceptance paths exist. Wrapper exits are zero,
stderr is empty, and the independently recorded focused totals are G1
`88/88`, G2 `85/85`, and G3 `63/63`.

G3 actual source bytes/source authority remain `terminal_deferred`; its
accepted record explicitly defers locator reading, byte-count/SHA recompute,
and same-candidate joining to T0/recheck. This review does not promote that
boundary.

## Independent checks

| node | current input hashes | wrapper | acceptance status | result |
|---|---|---|---|---|
| G1 diffusion V1 | 4/4 match; source `8bf9e1b4…1a756`, test `51ce669c…2cd8b`, fixture `47eab33a…ba19`, QA `4677ac7f…2790` | R4 `exit=0`, stdout 454 bytes / `d42a20cb…1ca1`, stderr 0 / empty hash `e3b0c442…b855` | `accepted=true`, `accepted_local_contract`, `contract_only` | `88/88` |
| G2 metric/boundary V1 | 4/4 match; source `a52ea1a6…37b3`, test `61602826…3636`, fixture `c7b417e3…a3f5`, QA `b329b50f…dd94b` | R3 `exit=0`, stdout 1338 bytes / `275f6ffb…4c71`, stderr 0 / empty hash `e3b0c442…b855` | `accepted=true`, `accepted_local_contract`, `contract_only` | `85/85` |
| G3 source/feedback V1 | 4/4 match; source `616bda1a…ed8e7`, test `25690868…a9f31`, fixture `7a09ec15…3fc40`, QA `9e6ba50e…54875` | R3 `exit=0`, stdout 516 bytes / `49e44ef8…2b82`, stderr 0 / empty hash `e3b0c442…b855` | `accepted=true`, `accepted_local_contract`, `contract_only`; source authority `terminal_deferred` | `63/63` |

The complete SHA-256 values and byte sizes are recorded in
`manifest.json`; wrapper `run.json`, stdout, and stderr were also inspected.
Each independent wrapper manifest has `accepted=false`,
`claim_scope=contract_only`, and `r01_r10_changed=false`.

## Plan and status boundary

- `validate_plan.py`: exit `0`; 34 Markdown files, 378 relative links, 39
  tasks, acyclic DAG, no reported errors.
- `tools/agent_local_execution.py`: exit `0`; current ready list is exactly
  `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`,
  `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC`,
  `UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`, `UP1-04A-VNEXT-T0`, and
  `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC`. This is dispatchability only; it is
  consistent with the manifest dependencies and does not accept T0.
- `git diff --check`: exit `0`; only pre-existing LF/CRLF normalization
  warnings were emitted.
- The current manifest remains 39 nodes and the status sync lists nine
  downstream items unchanged. `UP2-01` total, T0, parent-baseline binding,
  T1, T2, `UP2-00`, `UP1-04B`, and `UP1-04` remain planned/unaccepted.
  B00/B04, compiler, mesh, provider, solver, numerical, physical,
  engineering, search, and R01-R10 remain outside the accepted scope.

The inspected diffs in `16_execution_work_orders.md`,
`21_next_execution_batches.md`, the v4 README, implementation index, and
`task_manifest.json` are coherent with this boundary: they add the three
acceptance links/status records and preserve the explicit no-credit language.

## Selective-commit recommendation

`PASS — eligible for a selective commit`, provided the integrator stages only
the reviewed G1/G2/G3 source, tests, fixtures, G3 static QA, their acceptance /
review archives, the agent-local policy/tool archive, and the matching 16/21/
README/implementation-index/manifest status-sync edits. Do not stage the dirty
M4 adapter/probe, M5 performance files, parent-binding work, unrelated
`runs/`, `tmp/`, scratch files, or other workers' artifacts. Re-run
`git diff --cached --check` and inspect the staged path list before committing.
