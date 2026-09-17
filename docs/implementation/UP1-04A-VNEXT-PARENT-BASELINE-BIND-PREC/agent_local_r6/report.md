# UP1-04A parent-baseline binding PREC — agent_local R6

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

R6 is a minimal wrapper-parse repair. The independent `agent_local_r6_wrapper`
receipt failed before test execution because Julia does not accept `${prefix}`
inside a string. Only the three corresponding test interpolations were changed
from `${prefix}DeclarationV1` / `${prefix}FactoryV1` to the legal Julia form
`$(prefix)DeclarationV1` / `$(prefix)FactoryV1`. The LocalV1 product source,
fixture, static-QA implementation, public entry, manifests, T0/T1/T2 sources,
R1–R5 archives, and `runs/` were not modified.

The independent failure receipt is retained at
`docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/independent_agent_local_r6_wrapper/`.
It records command exit `1`, no parsed test groups, parse error at test line 67,
wrapper interval `2026-09-17T12:51:21.364991+00:00`–
`2026-09-17T12:51:23.634532+00:00`, empty stdout SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, and
stderr SHA-256 `fe6009d987bed400ac78cae61eeb427f8f179b747a59d40a3fa0d336b1382a4f`.
That receipt is a failed development replay only and claims no authority.

Static QA command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T12:53:58.0315248Z`
- UTC end: `2026-09-17T12:53:58.0946816Z`
- PID: `43128`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `729502a9e1919d83ffee3d1784ea42f61fdaa112d57cc56035c904edb3f220db`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=124`, `passed=124`, `errors=[]`

The scoped full-text scan for `${` returned no matches (rg exit `1`,
no-match semantics). A legal `$(prefix)` scan found the two repaired lines.
No Julia, DESC, provider, mesh, solver, or full regression was run in R6.

The package remains `prepare_only_runtime_input_adapter`, with
`accepted=false` and `present_authority=false`; current G1/G2 declarations
remain pending formal acceptance. R6 is ready for independent review and the
focused Julia rerun after review; it is not final freeze.

Final PowerShell JSON/product-hash/trailing-whitespace/interpolation validation
ran at UTC `2026-09-17T12:57:48.3369943Z`–
`2026-09-17T12:57:48.3991322Z`, PID `35508`, exit `0`; all scoped JSON parsed,
product hashes matched the R6 manifest, the file-representation hashes matched
the receipt, no scoped file had trailing whitespace, and the illegal-
interpolation scan returned exit `1` with zero matches (rg no-match result).

Cleanup: temporary files removed `0`; no process left running; no commit.
