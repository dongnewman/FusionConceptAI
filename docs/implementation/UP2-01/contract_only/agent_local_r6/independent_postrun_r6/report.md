# UP2 pre-T0 TypedCompilerIR/Lowering R6 independent postrun

Date: 2026-09-18 (Asia/Shanghai). This is a read-only independent postrun
audit of the already serialized R6 runtime receipt. No Julia, DESC, compiler,
provider, mesh, or solver command was run by this audit; no product/test/
manifest file was changed and no commit was created.

## Verdict and boundary

**GO for postrun contract-only; NO-GO for formal UP2 acceptance.** The source
run receipt is internally consistent, the four current input bytes still
match the R6 receipt, the isolated contract output is `89/89` in `1.6s` with
empty stderr and exit `0`, and R3/R4/R5 failure receipts remain present. This
does not grant T0/T1/T2, integration, numerical, physical, engineering, or
R01--R10 credit. The permanent ceiling remains
`contract_only / accepted=false / formal_credit=none`.

## Static command and result

```text
python -B docs/implementation/UP2-01/contract_only/agent_local_r6/independent_postrun_r6/static_qa_independent_postrun_r6.py
exit=0; checks=56; passed=56; failed=0
verdict=GO_CONTRACT_ONLY_NO_GO_FORMAL
```

The checker only reads JSON, raw receipts, source bytes, Git HEAD, and
historical failure directories. Its output is archived in
`static_qa.stdout.raw`; stderr is zero bytes in `static_qa.stderr.raw`.

## R6 receipt and current bytes

Source run: `runs/agent_local_up2_tcir_contract_matrix_20260918_r6/`.
Archived run metadata records:

- HEAD: `23baee9f889713655b04f108f49f8dd0213e3ddf` (also current HEAD)
- exit: `0`
- started: `2026-09-17T16:02:52.5544292Z`
- finished: `2026-09-17T16:02:54.8604662Z`
- stdout: `89 pass / 89 total`, `1.6s`
- stderr: empty (`0` bytes)
- pre/post input hashes: equal

The four current input SHA-256 values equal both R6 pre/post receipts:

| Input | SHA-256 |
|---|---|
| `src/RuntimeV4/TypedCompilerIRV1.jl` | `ff05ba2d3d81c5170f83c36dfddb9cd307b6ceec849cc0e7ecff440853197d3c` |
| `src/RuntimeV4/TypedCompilerLoweringV1.jl` | `452758e71f6bb8d50257dad77e39fd3ec1e2aea81830d838fa93cb144b0f427c` |
| `test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl` | `0c5d79d0b259d1efa1b863db90ff64fca0a4c12b9fb9381b320daac15a3ff732` |
| `test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` | `0e1b40e116e5bb6e38aff0c978b8c339ca4e475261322374ece730ac4e12e09d` |

The `runtime/` copy and source run are semantically identical. JSON/newline
normalization makes some archive bytes differ from the source-run copies; the
archived `archive_manifest.json` records both archive and source-file hashes.

## Retained failure receipts

The historical runs remain intact and are checked by metadata plus raw output:

- R3: exit `1`, `0 passed / 0 failed / 1 errored`.
- R4: exit `1`, `71 passed / 0 failed / 1 errored`.
- R5: exit `1`, `83 passed / 5 failed / 0 errored`.

Each retains `hashes_unchanged=true`; no failure receipt was overwritten.

## Process and repository boundary

The read-only process snapshot found no Julia/DESC process. The existing
`phase5_remote_session.py` process (PID `40216`) was observed and left
untouched. `git diff --check` for this archive is clean. The only new files
from this audit are under `independent_postrun_r6/`; no source, test, run, or
manifest state was modified.

Required next evidence remains a separately authorized T0 -> recheck -> T1/T2
-> integration sequence; this postrun receipt is not that evidence.
