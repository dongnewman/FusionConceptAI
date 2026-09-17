# AD-29 independent static review R1

Verdict: `pass_limited`.

This different-Luna review covers the three read-only Python environment audit reports, the AD-29 proposal/status/evidence/receipt archive, and the current README, execution work orders, architecture decisions, task manifest, and validator evidence at frozen HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. No source, core document, manifest, environment, historical receipt, Julia run, DESC run, provider run, mesh run, or physical run was changed or started.

The architecture ruling is correctly scoped. A fresh candidate-bound environment receipt is required before future `UP2-01` provider, mesh, physical, or related combination execution. The gate does not block UP1/UP2 contract-only static work. The receipt requirements bind current source/input/candidate identity, interpreter and module paths plus hashes, complete dependency/build metadata, command and exit/output/artifact hashes, and the applicable profile. Historical provider and physical receipts remain valid only for their original scope and cannot be promoted to current reproducibility.

The runtime role statements are supported by the three audits:

- DESC fixed-boundary retains the documented missing `jax-finufft` limitation. The audit records successful fixed-boundary imports while `pip check` reports the absent package; NUFFT paths remain `unsupported`/`terminal_deferred`, and AD-29 does not require installation now.
- FreeGS uses `include-system-site-packages=true`, so the receipt must bind the inherited NumPy/SciPy/h5py set and its provenance rather than recording only FreeGS/freeqdsk.
- VMEX and Pleiades resolve from external source trees. Their future receipt must bind source location/version and complete tree digest in addition to interpreter/module/package identity.
- CQL3D is a C/Fortran/NetCDF/HDF5 build prefix with no Python identity. The proposal correctly requires the build toolchain receipt and does not substitute a Python environment.

The plan topology is coherent and acyclic. Independent static traversal reaches all 31 tasks. The new preparation chain is:

`UP1-01/02/03 → {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

The three upstream nodes, `UP1-04A-VNEXT`, and `UP2-00` are `planned` with explicit `accepted=false`. Downstream execution and physical work remain `planned`; the AD-29 proposal, status, README, architecture decision, and execution work order explicitly keep `UP2-01`, provider, mesh, physical, engineering, and related combination execution at `accepted=false`. The manifest retains all ten requirements `R01` through `R10`; no task or dependency was added by AD-29. The recorded final `validate_plan.py` receipt is exit `0` with 31 tasks, an acyclic DAG, 31 markdown files, 354 relative links, and 16 snapshot files. The earlier exit `1` is correctly classified as a transient missing-link attempt before `evidence_manifest.json` existed.

The archive's identity evidence is consistent. Every source-audit hash and every authorized core/proposal/status hash in AD-29's evidence manifest matches the current bytes. The pre/post core hashes are equal to the recorded post-change hashes, so the AD-29 documentation update did not rewrite historical source or acceptance evidence. The archive's 3,607-entry full-status snapshot is historical; the current pre-write full-status snapshot is 3,610 entries because later independent-review directories exist. This is expected dirty-worktree growth and does not indicate a core or history mutation.

The claim ceiling is preserved: AD-29 is `proposal`/`review_pending`, `accepted=false`, and `execution_authorized=false`. It grants only an environment evidence gate and contract-only planning boundary. It grants no current provider, mesh, physical, engineering, B00, B04, or R01-R10 credit.

No repair is required for this review. Sol may accept AD-29 only at this limited architecture/evidence scope. Future implementation should keep the receipt gate candidate-bound and preserve the explicit runtime role details and status ceiling; it should not install the missing dependency, alter the DAG, or rewrite historical receipts as part of this proposal.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Current pre-write full dirty snapshot: 3,610 entries, SHA-256 `1060d963ab126a8886ce3cf2ff97ea17d41da6407708fa30ac88eed67aee998c` using UTF-8 LF serialization; no matching Julia/DESC process observed.
- AD-29 archived status snapshot: 3,607 entries, SHA-256 `6b5ae355a8736a786a1375dbad6b2e1f3c47e1c4d2826af1dec2251b398321c9`; this is retained as historical receipt evidence.
- Reviewed source/core/archive hashes are enumerated in `evidence_manifest.json`.

