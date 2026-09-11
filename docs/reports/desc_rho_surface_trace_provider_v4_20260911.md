# DESC rho-surface trace provider milestone — 2026-09-11

## Outcome

Implemented an isolated, candidate-bound fresh-process provider that consumes
the accepted structural rho partition and evaluates real DESC geometry and
field traces at each interface and at `rho=c±epsilon`.

## Delivered files

- `src/RuntimeV4/DESCRhoSurfaceTraceProviderV4.jl`
- `examples/runtime_v4_desc_rho_surface_trace_provider.jl`
- `scripts/run_v4_desc_rho_surface_trace_provider.jl`
- `test/runtime_v4_desc_rho_surface_trace_provider_tests.jl`
- `docs/implementation/desc_rho_surface_trace_provider_v4.md`
- this report

## Executed facts

The real candidate HDF5 was loaded by DESC 0.17.3. The provider returned and
validated surface positions, `grad(rho)`, `n_rho`, covariant tangents, magnetic
field, force-balance residual and Jacobian values. It explicitly converted
DESC embedded orthonormal cylindrical components to laboratory Cartesian
components. Both epsilon samples were verified to lie strictly inside their
named adjacent regions.

Security hardening from independent review was incorporated: built-in adapter
hash pinning, imported-module path attestation, process-hash recomputation,
strict output headers, explicit `theta/zeta/NFP` round trips, three-point
normal/tangent checks, canonical command/input reconstruction and direct
interface/support identity reconnection.

## Verification

All commands below ran from the repository root against the final hardened
source and returned definitive process exit code zero:

- parse/load smoke: all four Julia code files parsed; isolated module load and
  manifest evaluation succeeded;
- focused provider test: `56/56`, printed
  `DESC_RHO_SURFACE_TRACE_PROVIDER_FOCUSED_EXIT_CODE=0`;
- standalone runner: real provider receipt exit `0`, printed
  `DESC_RHO_SURFACE_TRACE_PROVIDER_OK`,
  `DESC_RHO_SURFACE_TRACE_PROVIDER_RUN_EXIT_CODE=0`, and wrapper exit `0`;
- structural rho-partition regression: `64/64`, marker and wrapper exit `0`;
- Cartesian field-basis bridge regression: `95/95`, marker and wrapper exit
  `0`;
- real DESC field-provider regression: `62/62`, marker and wrapper exit `0`;
- repository `julia --project=. test/runtests.jl`: all reported testsets passed
  and `FULL_RUNTESTS_EXIT_CODE=0`.

Three independent read-only final reviews inspected the hardened current-file
version and returned `ACCEPT` with no remaining P1/P2 findings. One transient
command-argument finding came from a concurrent pre-fix snapshot; reinspection
confirmed that the adapter invocation, its `sys.argv[4]` DESC-module check and
the reconstructed expected command all contain the same sealed module path.

## Boundary and next blocker

This is sampled provider execution, not a global spatial-partition proof.
`spatial_partition_geometry_validated`, `interface_flux_executed`, solver
convergence, multi-region closure, physical/engineering validation, evidence,
pass, promotion, P5 and terminal authority all remain false. Credible physical
device count remains zero.

The next real blocker is a candidate-derived constitutive/material law plus a
typed conservative interface-flux execution over these two-sided traces,
including residual/Jacobian ownership and closure checks.
