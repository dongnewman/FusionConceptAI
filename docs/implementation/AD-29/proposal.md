# AD-29 environment reinstallation and fresh provider receipt gate

- **status:** `proposal`
- **resolution:** `review_pending`
- **accepted:** `false`
- **independent review:** pending different-Luna static review
- **Sol decision:** pending
- **date:** 2026-09-15

## Scope and ruling

This archive records the environment evidence gate derived from the three independent read-only audits under `docs/implementation/PYTHON-ENV-REINSTALL-AUDIT/`. It does not install, update, remove, or resolve any dependency; run Julia, DESC, FreeGS, VMEX, Pleiades, CQL3D, or another provider; or change source, tests, environment prefixes, runs, the 31-task dependency graph, or R01-R10.

Contract-only static work in UP1/UP2 may continue. Before any future `UP2-01` provider, mesh, physical, or related combination execution, the current environment must first produce a fresh candidate-bound environment receipt. That receipt is a prerequisite evidence artifact, not an execution result and not a promotion of historical evidence.

The receipt must bind the current source, inputs, candidate identity, applicable profile, interpreter path and SHA256, imported module paths and SHA256, complete dependency versions/build/channel or package metadata and hashes, command and exit code, stdout/stderr and artifact hashes, and the resulting classification. It must represent each runtime by its actual role:

- FreeGS must include the packages visible through its `include-system-site-packages` base inheritance, rather than recording only the FreeGS package.
- VMEX and Pleiades must bind their external source trees, source/version identity, and complete tree digest in addition to installed modules.
- CQL3D must record the C/Fortran/NetCDF/HDF5 build toolchain and prefix; it has no Python identity to substitute for that role.

The DESC fixed-boundary profile keeps the audited missing `jax-finufft` dependency as an explicit scope limitation. NUFFT paths remain `unsupported`/`terminal_deferred`; AD-29 does not require installing that dependency now.

Historical provider and physical receipts remain valid only for their original environment, source, inputs, and run scope. They cannot be promoted automatically to current reproducibility. Missing fresh evidence keeps the relevant work at `review_pending`/`terminal_deferred`.

## Topology and claim ceiling

AD-29 leaves the 31-task machine DAG unchanged:

`UP1-01/02/03 → {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`

The task manifest still contains 31 tasks and requirements `R01` through `R10`. `UP2-01`, provider, mesh, physical, and related combination execution remain `accepted=false`. This proposal grants no B00, B04, provider, mesh, engineering, physical, or R01-R10 credit.

The three audit reports, modified architecture/work-order/index files, task manifest, and validator receipt are enumerated in [evidence_manifest.json](evidence_manifest.json). The read-only command record is in [command_receipts.json](command_receipts.json). A different Luna must independently review this archive before Sol decides whether the gate is accepted.

## Review state

`proposal`/`review_pending` is deliberate. The gate is written for review and does not authorize provider or physical execution. The independent reviewer may return `changes_requested` or `ready_for_sol_decision`; only Sol may change the decision state.