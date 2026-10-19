# Native axisymmetric source fields v2

This package turns the two frozen shot-30421 acquisitions into a verified,
device-neutral axisymmetric source snapshot.  The loader reads the real
compressed chunks, independently decompresses them, reconstructs every array,
and checks the result against the pinned acquisition, selection, consolidated
metadata, and raw-array hashes.

The public entry points are in `native_axisymmetric_adapter.py`:

- `load_native_axisymmetric_series()` verifies all 48 acquired arrays.
- `snapshot_native_axisymmetric(series, efm_time_index,
  amc_max_delta_s=...)` selects one explicit finite EFM profile row and records
  the exact nearest AMC sample and signed time offset.
- `validate_native_axisymmetric_snapshot(snapshot, series)` re-derives the
  snapshot from the frozen source at every consumer boundary.
- `write_native_axisymmetric_snapshot(...)` writes the strict JSON ABI consumed
  by the FreeGS profile runner.
- `require_native_likelihood_ready(...)` always fails in this version.

The v2 decoder runtime is explicit and hash-bound.  The adapter resolves
`Library/bin/blosc.dll` only under Python's `sys.base_prefix`, verifies its
exact SHA-256 before loading it, configures the declared ctypes ABI, and then
passes that library to the immutable acquisition decoder's `decode_chunk`
function.  This keeps the acquired producer snapshot unchanged and allows the
pinned virtual-environment interpreter to use its real base Conda runtime.
Validation receipts record the executable, `sys.prefix`, `sys.base_prefix`,
resolved DLL path, DLL hash, and ABI.  A missing or changed DLL fails before
any canonical output is written.

Example:

```powershell
python benchmarks/reference_source_fields_v1/native_axisymmetric_adapter.py verify
python benchmarks/reference_source_fields_v1/native_axisymmetric_adapter.py materialize `
  --efm-time-index 80 --amc-max-delta-s 0.000001 `
  --output tmp/native_axisymmetric_snapshot_30421_t80.json
```

The raw `psirz` representation is `[time, profile_z, profile_r]` with shape
`[120, 65, 129]`.  All 120 time planes and all 65 vertical rows share the same
65 finite radial columns.  The adapter selects those declared raw columns and
transposes `[z, r]` to canonical `[r, z]`; it does not resample or impute.
`efm/r` is bit-identical to `efm/profile_r[support]` and supplies the metre
unit.  `efm/gridr` is retained as a distinct observed array whose maximum
difference from `efm/r` is `1.1920928955078125e-7 m`; it is never accepted as a
tolerance substitute for the exact dimension binding.  `efm/rvals` has blank
units and remains evidence-only.

The ten internal PF-current signals are present and explicitly time-aligned.
A separate 13-field geometry acquisition now exists, but it is outside this v1
protocol and its circuit/element and signed-shape semantics are unresolved.
The currents therefore remain `present_unmapped`, and the free-boundary machine
input is `typed_absent_unmapped_coil_geometry`.  The fixed-boundary runner uses
an explicit empty machine plus the observed Dirichlet flux boundary and
tabulated `p'`/`FF'`.  That calculation is conditional on the reconstructed
boundary.  The output reports FreeGS iteration convergence and an independently
computed discrete GS residual as separate measurements; this version defines
no residual acceptance threshold and grants no PDE or physical acceptance.

The consumed flux/profile subset uses an identity COCOS mapping.  The official
OMFIT MAST EFM reader interprets its incoming product as COCOS 3; this is an
upstream software interpretation rather than a shot-30421 metadata attestation.
For COCOS 3, `e_Bp=0` and `sigma_Bp=-1`.  Those values are algebraically
consistent with FreeGS 0.8.2's `Br=-psi_Z/R`, `Bz=psi_R/R`,
`Jtor=R*pprime+FFprime/(mu0*R)`, and `rhs=-mu0*R*Jtor`, so this runner does not
change signs or apply a `2*pi` scale.  This statement covers only the consumed
Grad-Shafranov/poloidal-field subset.  Poloidal-angle and q conventions are not
consumed and remain unverified.  The evidence and derivation are in
`docs/implementation/GOAL-EXECUTION-20260922/reference_gs_conventions_r1/`.

This executable bridge binds a real G2 profile/fixed-boundary source.  G1 and
G3 still come from the generic declared fixture, so
`reference_inversion_G1_G2_G3=false` and
`executable_source_scope=G2_profile_fixed_boundary`.

The Level-1 EFM product is an EFIT reconstruction, not an independent
measurement.  Source-field uncertainty, diagnostic response, error
statistics, EOS/transport closure, and a likelihood are absent.  Nothing in
this package establishes formal inverse acceptance, B03, B07B, physical or
engineering validation, ITER measurement status, or completion of UP4-03.
