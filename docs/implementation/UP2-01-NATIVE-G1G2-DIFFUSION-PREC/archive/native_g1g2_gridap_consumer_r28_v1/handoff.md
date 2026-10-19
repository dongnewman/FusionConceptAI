# R28 Native G1/G2 isolated static handoff

Date: 2026-09-26. Status: frozen candidate for independent static review; **no Julia or Gridap runtime was started**. This is not a runtime, numerical, or physical pass.

## Scope and repair

R27 remains frozen and is not dispatchable. Its independent Python-only review is `docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/independent_native_g1g2_r27_tester_search_chain_r1_20260926/review.md` (SHA-256 `b28dcddafb169bb09217516819707c90bb8c158668b095810515f8be0d76f93c`), review manifest SHA-256 `f8ddd4ce984e195ed87cd0e3a0c9f4bc0452dabe2e25505b63700e2ca5bbbd37`. It reproduced a false-complete chain: missing tracked parent B had an exact exit receipt, while a live digest child C named B as PPID; R27 seeded traversal only with present tracked rows, omitted C and later descendants, then reported complete and permitted a retry.

R28 changes only its versioned Python supervisor, Python tests, verifier, protocol and evidence leaf. Classification seeds ancestry with every exact tracked-before `(PID, raw FILETIME)` even when a tracked parent row is absent, then closes over all digest rows and emits `orphan_chain_roots` plus `orphan_chain_descendant_identities`. Recovery requires an exact exit receipt for every missing tracked identity. Each newly observed row is rejoined against a fresh SPI snapshot by exact generation and image name, then bound to an exact retained process handle. A changed PPID is accepted only when the exact old parent is missing and receipted exited and the child generation and new parent row remain verifiable; parent PID reuse, missing child, chronology ambiguity, malformed ancestry or failed handle binding yields unaccounted/incomplete, unclear residual and no next stage. `_bind_tree` runs only after these digest-observed rows are individually handled.

No product/shared entry, Julia source, fixture, mesh, or numerical threshold was changed. R27 and earlier evidence bytes remain immutable.

## Frozen consumer and resource contract

- Formal consumer: `NativeG1G2DiffusionCompilerV1 -> GridapNativeG1G2DiffusionAdapterV1` through the single frozen R28 supervisor; primary and replay use `test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl`.
- Per-stage wall budget remains 480 s; process-tree RSS remains a 2,147,483,648-byte sampled stop threshold at 0.2 s cadence (sampled stop, not a hard cap); `--compile=min`, 1G heap hint, single Julia and BLAS threads remain unchanged.
- Fixture and solver thresholds are declared unchanged. An incomplete/recovery-failed observation has no numerical or physical credit; all outputs remain no-credit/unknown.
- The frozen supervisor command is the exact `execution_plan`/`invocation_contract.actual_supervisor_argv` in `docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_gridap_consumer_r28_v1/protocol.json`; it was not invoked. Planned runtime output leaf is absent.

## Static QA

All commands were run with `D:\Users\Newman\anaconda3\python.exe -B`; raw stdout/stderr, argv and exit receipts are under `docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_gridap_consumer_r28_v1/`.

| Check | Exit | Result |
|---|---:|---|
| Full Python suite | 0 | 30/30 passed |
| Missing-parent/orphan-chain injection | 0 | 6/6 passed |
| Static protocol verifier | 0 | `static_protocol_check_pass`, 191 input pins, planned argv verified, output leaf absent, Julia not started |

The focused controls include nested orphan descendants, reparent-after-exit, stale PPID after exact parent exit, missing/reused child generation, parent PID reuse, ambiguous chronology, and serial stop before replay when an observed descendant is unaccounted. No numerical/physical claim is made by these tests.

## Frozen files

- Runner `test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r28_v1.py`: SHA-256 `20d64430f65c6c1c8c8377bc3336d2e58ce0a7ebc91131512728920ce36d41ca` (104633 bytes).
- Tests `test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r28_v1.py`: SHA-256 `d842ea08afd8b6d0a2a063d6ead5d8d437b21bdaa56029864e581bc6681d7cf8` (60751 bytes).
- Static verifier `test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r28_v1.py`: SHA-256 `e188e6974997db0dae05a7f1decc24c5c44aff81cccef7df9d7e1a555e452810` (2897 bytes).
- Protocol `docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_gridap_consumer_r28_v1/protocol.json`: SHA-256 `a0724674ff5ebec3d838fc646c376f307bac6ea0b2b5595de0e7abadf000ccee` (67613 bytes); 191 source/environment/evidence pins.
- The protocol pins R27 owner protocol/freeze manifest and independent review/manifest, plus the complete prior input chain. Static evidence entries are evidence-only JSON/raw/Markdown; no launcher or test code is stored in the archive.

Requested model was GPT-6 Luna/max; actual model/effort identifier is not exposed to this worker and is not asserted.
