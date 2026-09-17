# UP1-04A parent-baseline binding PREC — agent_local R4

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

## Scope and status

R4 addresses the independent R3 `NO-GO` findings by modifying only the four
LocalV1 product files and adding this evidence directory. R1/R2/R3 archives,
the public entry, manifests, T0/T1/T2 sources, old archives, and `runs/` were
not modified. No Julia, DESC, provider, mesh, solver, or full regression was
run.

The package remains `prepare_only_runtime_input_adapter`: G1/G2 repairs are
pending, the three V1 declarations are not formally accepted, and no current
source-backed runtime authority was supplied. `accepted=false` and
`present_authority=false` remain the claim ceiling; this is not final freeze.

## R4 repairs

1. Each declaration record now retains `child_contract_ref` and
   `child_contract_hash`. The binder cross-checks the corresponding child
   request's layer, kind, child ID, contract ref, and contract hash before a
   present result. These fields are included in the parent-binding hash and
   are rechecked by the public present verifier.
2. The public absent verifier now requires G1/G2 layer, layer-specific child
   kind, nonempty child ID, closed `terminal_deferred` resolution, and an
   allowed absence reason. Tests construct self-consistent malformed absent
   digests and verify both direct and canonical-state rejection.
3. Factory and candidate-review versions are bound to explicit LocalV1 schema
   domains (`factory-v1` and `review-v1`), included in the parent binding, and
   mismatched/future versions fail closed.

## Static execution receipt

Command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T12:32:23.6292699Z`
- UTC end: `2026-09-17T12:32:23.7620079Z`
- PID: `43848`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `18109d5453cafd89b513a74a6829195d799f5c520baaff51ed90fa729f9f6ecd`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=118`, `passed=118`, `errors=[]`

The retained output representations and process receipt are in this directory.
No Julia was invoked in R4.

Final JSON/product-hash/trailing-whitespace/old-R1-hash validation ran with
PowerShell at UTC `2026-09-17T12:34:21.1018925Z`–
`2026-09-17T12:34:21.1607271Z`, PID `22900`, exit `0`; JSON parsed, product
hashes matched the manifest, no scoped file had trailing whitespace, old R1
hashes were unchanged, fixture authority was false, and temporary files
removed was `0`.

## Cleanup and handoff

Created only `agent_local_r4/` evidence files; temporary files removed: `0`;
no process was left running; no commit was created. Focused Julia remains
blocked until the mainline explicitly releases it and supplies current
runtime inputs.
