# UP1-04A-VNEXT-G3-BINDING-EDIT-PREC status sync R1

Date: 2026-09-15  
Decision: `accepted_limited`  
Scope: local typed-absence software precursor only  
Architecture boundary: AD-34 `accepted_limited`; evidence-sidecar policy: AD-36 `accepted_limited`/`accepted=true`

The local software precursor is accepted from repair R2/archive r5 and the
different-Luna independent review R3 `pass_limited`. The six product paths
remain exact and the source, focused test, fixture, and static-QA product bytes
were not modified in this status sync. Only the product README and manifest
were updated to record the local acceptance state. The machine work-order node
remains `planned`/`proposal`/`accepted=false`/`review_pending`.

## Fresh read-only evidence

The current checkout was run directly from the repository root with Python
3.13.5 (`D:\\Users\\Newman\\anaconda3\\python.exe`) and Julia 1.10.5
(`C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe`).

| check | command/result | PID | UTC | exit | raw stdout | raw stderr |
|---|---|---:|---|---:|---|---|
| static QA | `python test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`; `PASS` | 78144 | 07:53:27.8569508Z–07:53:27.9710737Z | 0 | `status_sync_r1/static_qa.stdout`, SHA `ea5184a08ce941d92c1cf7cc8173401f2f020681c66b496d6d100f43839afa1e`, 49 bytes | `status_sync_r1/static_qa.stderr`, SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, 0 bytes |
| focused Julia | `julia --project=. test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`; `70/70` | 65368 | 07:53:39.7522479Z–07:53:51.1940367Z | 0 | `status_sync_r1/focused_julia.stdout`, SHA `1da1e1bc5dcfbef5a299c1ca9666b11b0eda4771c6876924a2018f7db18d07ab`, 134 bytes | `status_sync_r1/focused_julia.stderr`, SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, 0 bytes |
| direct present constructor probe | module-qualified probe asserted `ArgumentError: binding_authority_typed_absent` | unavailable by desktop execution wrapper | 07:54:39.7817007Z–07:54:41.6766946Z | 0 | `status_sync_r1/direct_constructor_probe_retry.stdout`, SHA `5af8686405d5c78b86d8138d6aaf1a7207e6d6d66f37a8acbd80f9d0b3676e9a`, 47 bytes | `status_sync_r1/direct_constructor_probe_retry.stderr`, SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, 0 bytes |

The first probe attempt used an invalid `GenomeContractRef` arity and exited
1; it is retained as `status_sync_r1/direct_constructor_probe.stdout` with
its raw output and was not used as passing evidence. The corrected direct
probe passed with the PID explicitly recorded as unavailable; no PID was
invented.

The focused result confirms the typed-absence boundary, compatibility
`complete=true` behavior, legacy `:actual` terminal deferral, pairing
fail-closed cases, and atomic disabled-CAS behavior for `insert_link`,
`replace_link`, and `delete_link`. The direct constructor rejects caller
supplied present values. These are software-contract facts only.

## Product closure and ceiling

The six exact product files and current SHA-256/byte values are recorded in
`manifest.json`. Archive rounds r0-r5 and independent reviews R1-R3 remain
append-only. Cleanup was limited to the task-owned status sidecars listed in
`cleanup_inventory.json`; no unrelated dirty file, source, test, fixture,
static-QA, launcher, registry, core task manifest, T0, T1, or T2 file was
removed or rewritten.

This acceptance does not provide checked-present authority, actual binding,
feedback, control, T0/T1/T2, provider, mesh, engineering, physical, search,
B00, B04, or R01-R10 credit. The parent goal remains open and the current
binding result remains `AbsentChildBindingV1` with
`authority_recheck_not_published` and `terminal_deferred`.
