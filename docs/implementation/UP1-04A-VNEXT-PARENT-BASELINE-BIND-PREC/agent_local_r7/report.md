# UP1-04A parent-baseline binding PREC — agent_local R7

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

R7 is a minimal static repair after the original focused Julia receipt
`runs/agent_local_up1_04a_parent_r6_focused_julia_20260917`. That run reached
the positive test construction and failed `0 passed / 0 failed / 1 error`:
`ArgumentError: factory identity required` at source line 184, called from
test line 72 and surfaced at test line 88.

Static contract inspection showed the product constructor, not the fixture,
was wrong: both required-field guards used the inverted form
`isempty(value) || throw`. Consequently a legitimate non-empty factory
identity/version was rejected, while an empty value would be accepted. R7
corrected only those guards to `!isempty(...) || throw`; it did not weaken the
factory identity/version validity contract. The test now adds direct
`@test_throws ArgumentError` controls for empty factory identity and empty
factory version. The fixture records both negative controls, and static QA
checks the positive guard forms plus the test/fixture coverage.

Original focused-run receipt and hashes:

- directory: `runs/agent_local_up1_04a_parent_r6_focused_julia_20260917`
- manifest SHA-256: `d62c012e3943a80ca5c82dbcf2b9cd2ba4e2d838393445ed25e58876e01c9f6e`
- report SHA-256: `07866aeb914775d979e06936feae6d84f80cb6d278e9753a0490b870b91e0392`
- run JSON SHA-256: `ea53f121f0f6a8ff7eb564476c7d29646045cf1e56f7a1b486c93fe85276cfb2`
- stdout SHA-256: `d20838342bd317a924b29bdd1ffe91d4b15c06bb912f6eb4a740f03a4bd0241c`
- stderr SHA-256: `10bf605ee7454e1f5dd6d093071d294440e09863b293dc1bded6ab3cabe20959`
- original wrapper interval: `2026-09-17T13:03:27.051655+00:00`–`2026-09-17T13:03:29.292356+00:00`, exit `1`

Static QA command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T13:07:01.0368211Z`
- UTC end: `2026-09-17T13:07:01.1645147Z`
- PID: `38648`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `bbb786afa2073799ba075c0f308f00a2440437d8c19e9c414607afe22f8bea10`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=129`, `passed=129`, `errors=[]`

The source guard audit command was
`rg -n 'isempty([^\\n]*) || throw|!isempty([^\\n]*) || throw|all(!isempty'`
against the LocalV1 source. It exited `0` and found only the valid aggregate
guard plus the two corrected positive factory guards. No Julia, DESC, provider,
mesh, solver, or full regression was run in R7.

The G1/G2 V1 schemas and candidate/source metadata contracts are accepted at
`accepted_local_contract`; actual source-backed parent present authority
remains pending this node verification. The package remains
`prepare_only_runtime_input_adapter`, with `accepted=false` and
`present_authority=false`. R7 is ready for a different independent reviewer
and a later focused Julia rerun; it is not final freeze.

Final PowerShell JSON/product-hash/trailing-whitespace/guard/interpolation
validation ran at UTC `2026-09-17T13:10:36.5257889Z`–
`2026-09-17T13:10:36.6201432Z`, PID `41508`, exit `0`; all scoped JSON parsed,
product and evidence hashes matched their receipts, no scoped file had trailing
whitespace, the illegal interpolation scan had zero matches (rg exit `1`), and
the required-field guard scan exited `0`.

Cleanup: temporary files removed `0`; no process left running; no commit.
