# UP1-04A parent-baseline binding PREC — agent_local R3

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

## Scope and status

R3 addresses the independent R2 `NO-GO` findings by modifying only the four
LocalV1 product files. The old R1 files, R2 archive, public entry, manifests,
T0/T1/T2 sources, old archives, and `runs/` were not modified. No Julia,
DESC, provider, mesh, solver, or full regression command was run.

The package remains `prepare_only_runtime_input_adapter`: G1/G2 repairs are
still pending, the three V1 declarations are not formally accepted, and no
current source-backed runtime authority was supplied. `accepted=false` and
`present_authority=false` remain the claim ceiling; this is not final freeze.

## R3 repairs

1. Missing declaration records and missing child records are classified before
   the generic `missing_layer` errors. Empty records, a single declaration
   layer, empty children, or a single child layer return deterministic
   `typed_absent/terminal_deferred`; any additional contradiction (duplicate,
   unknown, foreign, or hash mismatch) remains `fail_closed`.
2. History is now part of canonical state bytes and the state hash through a
   bounded history commitment. CAS input carries and checks
   `expected_prior_history` alongside expected source/state hashes. A stale or
   tampered history is rejected atomically with prior bytes, hashes, and
   history returned unchanged.
3. The unbound review boolean was replaced by the closed
   `LocalCandidateIdentityReviewReceiptV1`, retaining review bytes/claimed and
   recomputed hashes, status, version, reviewer ref, candidate, layer, source
   ref, declaration ref, and four axes. The binder and public verifier require
   a fresh review receipt bound to the exact candidate and declaration.
4. The public present verifier now rechecks factory identity versus locator,
   factory receipt axes, review receipt joins, source/declaration bytes and
   hashes, candidate, layer, child, refs, and parent-binding hash.

## Static execution receipt

Command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T12:08:25.6460728Z`
- UTC end: `2026-09-17T12:08:25.7329364Z`
- PID: `39256`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `c3f6c07b10871a3f825adab70a63900876d27003c17c7897fc9b98d0d88f4701`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=102`, `passed=102`, `errors=[]`

The retained raw-output representations and receipt are in this directory.
No Julia was invoked in R3.

Final JSON/trailing-whitespace/old-R1-hash validation ran with PowerShell at
UTC `2026-09-17T12:11:00.3767729Z`–`2026-09-17T12:11:00.4215874Z`, PID
`39944`, exit `0`; JSON parsed, no scoped file had trailing whitespace, old
R1 hashes were unchanged, fixture authority was false, and temporary files
removed was `0`.

## Cleanup and handoff

Created only `agent_local_r3/` evidence files; temporary files removed: `0`;
no process was left running; no commit was created. Focused Julia remains
blocked until the mainline explicitly releases it and supplies current
runtime inputs.
