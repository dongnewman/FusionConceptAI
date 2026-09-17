# UP1-04A parent-baseline binding PREC — agent_local R8

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

R8 is a minimal test/static repair after the unique R7 focused-run receipt
`runs/agent_local_up1_04a_parent_r7_focused_julia_20260917`. That run reached
the contract body and reported `75 pass / 1 fail / 1 error` (outer total 77;
the nested factory-constructor negative group was 2/2).

The two failures were test defects, not product defects:

1. Test line 174 applied `in` to a single `Symbol` reason. R8 compares the G1
   and G2 reason fields independently with `===`.
2. The tamper test copied canonical bytes before mutating the state, then
   demanded that the failure receipt equal both the mutated state and the
   pre-mutation copy. R8 mutates the local state snapshot first and copies that
   tampered snapshot, then checks that the failure receipt echoes it exactly,
   while state canonical/state/source hashes and history remain unchanged and
   publication/history advancement remain false.

No product source was changed in R8. The static QA implementation now guards
both test patterns: Symbol equality is required, and the tampered snapshot
must be echoed without advancing state integrity fields.

Original R7 focused-run receipt and hashes:

- directory: `runs/agent_local_up1_04a_parent_r7_focused_julia_20260917`
- manifest SHA-256: `5d31c125dad9110554a151973eaa53c9064b0cb1fde649e2ef202262f4fb63f7`
- report SHA-256: `74674f19674324bdbf64502521b3f91c29a7969476f99dc090f46e5867ef9e7b`
- run JSON SHA-256: `6b0c4d63a60cd7ed62e5d281c05b4a8f2305d3d23a9861965b2628968d865671`
- stdout SHA-256: `bb25567de7df7d6eb7fb0907d5ec4b7117bf062f524317d412792c2f3a9582db`
- stderr SHA-256: `ba9cd545e98116cac6c47ddb35dfc4cf6910dea94a9ad04669947c53fcbd46c3`
- original wrapper interval: `2026-09-17T13:20:12.166286+00:00`–`2026-09-17T13:20:21.249307+00:00`, exit `1`

Static QA command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T13:23:15.3524103Z`
- UTC end: `2026-09-17T13:23:15.4726289Z`
- PID: `3672`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `d72360d447a0345ff83293abebcc0a454d7b70a55d6e04b43ed9e1d2c1062d51`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=133`, `passed=133`, `errors=[]`

No Julia, DESC, provider, mesh, solver, or full regression was run in R8.
The package remains `prepare_only_runtime_input_adapter`, with
`accepted=false` and `present_authority=false`; the upstream contract boundary
remains `accepted_local_contract`, while actual source-backed parent present
authority remains pending this node verification. R8 is ready for independent
review and a later focused Julia rerun; it is not final freeze.

Final PowerShell JSON/product-hash/negative-pattern/trailing-whitespace
validation ran at UTC `2026-09-17T13:26:20.8584329Z`–
`2026-09-17T13:26:20.9447520Z`, PID `44052`, exit `0`; all scoped JSON parsed,
product hashes matched the R8 manifest, the Symbol-membership anti-pattern had
zero matches (rg exit `1`), the tampered-snapshot coverage scan passed, and no
scoped file had trailing whitespace.

Cleanup: temporary files removed `0`; no process left running; no commit.
