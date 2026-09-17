# UP1-04A parent-baseline binding PREC — agent_local R5

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

R5 is a minimal state-integrity repair. Only the four LocalV1 product files
were modified and this `agent_local_r5/` evidence directory was added. R1–R4
archives, the public entry, manifests, T0/T1/T2 sources, old archives, and
`runs/` were not modified. No Julia, DESC, provider, mesh, solver, or full
regression was run.

`verify_local_state_v1` now independently recomputes the stored bundle hash,
requires it to equal `bundle.bundle_hash`, and requires bundle candidate,
both binding candidates, and both parent-binding candidates to be identical.
Canonical/state hashes therefore cannot conceal a tampered bundle hash or a
cross-candidate bundle. Direct cross-candidate and recomputed tampered-bundle
canonical/state negative controls were added.

The package remains `prepare_only_runtime_input_adapter`, with
`accepted=false` and `present_authority=false`; current G1/G2 declarations
remain pending formal acceptance and this is not final freeze.

Static command:

`D:\Users\Newman\anaconda3\python.exe -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T12:44:08.7445742Z`
- UTC end: `2026-09-17T12:44:08.8681552Z`
- PID: `22744`
- exit: `0`
- raw stdout: `554` bytes, SHA-256 `729502a9e1919d83ffee3d1784ea42f61fdaa112d57cc56035c904edb3f220db`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=124`, `passed=124`, `errors=[]`

Cleanup: temporary files removed `0`; no process left running; no commit.

Final JSON/product-hash/trailing-whitespace validation ran with PowerShell at
UTC `2026-09-17T12:45:58.9199676Z`–`2026-09-17T12:45:58.9553360Z`, PID
`42276`, exit `0`; JSON parsed, product hashes matched the manifest, no
scoped file had trailing whitespace, and `formal_acceptance=false`.
