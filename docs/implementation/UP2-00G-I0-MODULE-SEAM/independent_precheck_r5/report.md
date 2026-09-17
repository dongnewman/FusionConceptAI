# G-I0 independent dependency reconciliation R5

Verdict: **ready_for_serial_focused_r2**. This is a fresh static freeze only; Julia/DESC and the G-I0 runner/probe were not started.

## Dependency reconciliation

The prior focused R2 hold was caused by the old R4 core18 hash `a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713` (37,859 bytes) versus the then-current AD-26-repaired core. The current accepted-limited AD-26 state is now frozen consistently: core18 is `a7bffc313dfef35c7e302dd251709491a4a91e15d37a275d92fd6fe9d5aca28` (40,362 bytes), README is `d1f0923b41dc793e0c8a0036aee892e98f400b050f49bffedd51dabfda0b8b6c` (20,109 bytes), and work orders 16 is `f6da71dc768aea6e98adffeacc61358054f520f6a89a605035b8ba5b2d0460b2` (56,934 bytes). README and 16 both state `accepted_limited` for architecture/protocol only; core18 decision text was not edited in this review.

The G-I0 runtime-relevant freeze is current and internally consistent: entry `7eb7ed593fbac217ea925830e53b675a38760aed708c7864bd43c436f74d8937`, focused test `3d595b399f8e9681881f61fa2e25590dd6646986385af72021a33672c96b4cb5`, corrected runner `2847d1b98455a2fb4186be491cc00c09e5f475f83e14e1b26b7a246bf4b19cab`, failure probe `59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591`, FusionConceptAI loader `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783`, and GenomeV5Integration `391a7f32ce22c73244ac41f0d6e5c321e98931649491d3fd3a52f907ffaf44c4`. All direct UP2 source definitions loaded by the entry, including N05 (`3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`) and N06 (`69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c`), are included in the fresh input hash set.

## External E1/E2 changes

The N05 receipt-export focused test/runner (`f7bf3b1dcdc2caeb99030082426c56acbf31ad575434866da204bbf13a611547`, `e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec`) is a separate focused test and is not included by `UP2ModuleEntryV1.jl`; it cannot alter this loader freeze. The N06 current source remains the loader input above. N06 test-only R9 changes are external to the G-I0 loader: current N06 test/fixture hashes are `d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1` and `e37314924102c75ac47a34652d0a480c4730e04590cb17294033719ce92d37b8`, while the older N06 implementation manifest records `dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce` and `361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2`. This mismatch is explicitly classified as external test-only drift, not silently substituted into the loader freeze; the current test/fixture hashes are recorded in `input_hashes.json`.

## Historical protection and QA

The focused R2 `hold_dependency_drift` record, focused R1 raw evidence, independent R1 `changes_requested`, R2 `changes_requested`, and R3 reconciliation archives remain byte-preserved. The protected dirty set has 19 files and zero mismatches. A process sweep during QA transiently observed two processes, then an immediate process-identity sweep and a final `Get-Process` sweep observed zero; no process identity was stable enough to attribute. This review started no process. The serial runner must perform its own immediate lane preflight and must not launch while N06 or any other Julia/DESC process is present.

Static QA: JSON parse exit `0`; `validate_plan.py` exit `0` (31 markdown files, 329 links, acyclic DAG); scoped `git diff --check` exit `0` with existing line-ending warnings only; control scan exit `0`. No runtime result or acceptance is claimed.

## Restricted conclusion

This is sufficient to release the serial focused R2 gate for the frozen G-I0 runner. It grants only a fresh static dependency freeze; it grants no UP2-total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit. A future G-I0 focused run must record its own command, PID, exit, logs, and post-process sweep, and any change to the frozen loader or core files invalidates this gate.
