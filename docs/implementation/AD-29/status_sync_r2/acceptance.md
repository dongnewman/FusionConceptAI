# AD-29 status sync R2 — accepted_limited

- **decision:** `accepted_limited`
- **independent review:** `independent_review_r1 = pass_limited`
- **execution authorization:** `false`
- **date:** 2026-09-15

Sol accepts AD-29 only as an environment evidence gate and contract-only planning boundary. UP1/UP2 contract-only static work may continue. Before any future `UP2-01` provider, mesh, physical, or related combination execution, a fresh candidate-bound environment receipt is required.

The receipt must bind current source/input/candidate identity; interpreter and imported module paths with SHA256; complete dependency versions/build/channel or package metadata and hashes; command, exit code, stdout/stderr and artifact hashes; applicable profile and classification; FreeGS inherited base packages; VMEX and Pleiades external source tree identity and complete digest; and the C/Fortran/NetCDF/HDF5 CQL3D build toolchain. The DESC fixed-boundary profile retains the documented missing `jax-finufft` limitation. NUFFT paths remain `unsupported`/`terminal_deferred`; AD-29 does not require installing it.

Historical provider and physical receipts remain limited to their original environment/source/input/run scope and cannot be promoted to current reproducibility. This decision does not authorize provider, mesh, physical, engineering, B00, B04, or R01–R10 claims.

The 31-task DAG and requirements `R01`–`R10` are unchanged. `UP2-01-G1-DIFFUSION-V1`, `UP2-01-G2-METRIC-BOUNDARY-V1`, `UP2-01-G3-SOURCE-FEEDBACK-V1`, `UP1-04A-VNEXT`, `UP2-00`, `UP1-04B`, `UP1-04`, and `UP2-01` remain `planned`/`accepted=false` where applicable. The original [AD-29 proposal](../proposal.md) and [independent review R1](../independent_review_r1/report.md) are retained as historical inputs; this status sync is the current limited decision record.

No source, tests, environment prefixes, historical receipts, or runs were changed. No Julia, DESC, provider, mesh, or physical command was run. See [evidence_manifest.json](evidence_manifest.json) and [command_receipts.json](command_receipts.json).