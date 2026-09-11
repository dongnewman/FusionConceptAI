# Runtime V4 local ideal-MHD interface traction report — 2026-09-11

## Scope

Implemented the first candidate-bound local interface constitutive execution
on the real DESC chain.  It resamples pressure and B at the exact two-sided
rho points, cross-checks B against the accepted surface provider, evaluates
static ideal-MHD momentum traction in SI, and constructs an explicitly paired
central interface flux.

Legacy review found no accepted traction/interface-flux/Jacobian provider that
could be wrapped.  Older scalar-pressure and residual scripts were retained as
test intent only; no old Genome, family routing, device preference, or authority
was imported.

## Evidence boundary

This is real candidate-bound provider execution, not a manufactured fixture.
It proves local data identity, constitutive evaluation, one-sided traction, and
paired flux assembly.  It does not prove boundary-limit convergence,
Rankine-Hugoniot/jump closure, region PDE residuals, a Jacobian, global
conservation, solver convergence, validation, or a feasible device.

## Verification

All accepted commands below ran from the repository root against the final
source and returned definitive process exit code zero:

- prerequisite DESC field receipt hardening: process-hash focused test `64/64`,
  then sealed-module-path focused test `65/65`;
- focused ideal-MHD interface traction test: `62/62`, printed
  `IDEAL_MHD_INTERFACE_TRACTION_FOCUSED_EXIT_CODE=0`,
  `FINAL_IDEAL_MHD_INTERFACE_TRACTION_EXIT_CODE=0`, and wrapper exit `0`;
- standalone real-chain runner: pressure provider exit `0`, printed
  `IDEAL_MHD_INTERFACE_TRACTION_OK`,
  `IDEAL_MHD_INTERFACE_TRACTION_RUN_EXIT_CODE=0`, and wrapper exit `0`;
- rho-surface/two-sided-trace regression: `56/56`, marker and wrapper exit `0`;
- Cartesian field-basis regression: `95/95`, marker and wrapper exit `0`;
- repository `julia --project=. test/runtests.jl`: all reported testsets passed,
  `FULL_RUNTESTS_EXIT_CODE=0`, and wrapper exit `0`.

The first parallel surface/basis regression attempt shared an upstream default
field-output directory; one process overwrote the other's sealed artifact and
the hardened receipt validator correctly rejected it. The final surface run
used unique directories for every DESC execution, field, basis, and surface
artifact and passed `56/56`. This is orchestration contention, not accepted
verification evidence.

Three independent final read-only reviews inspected the current six-file slice
and returned `ACCEPT` with no P1/P2 finding. They separately checked pressure
point and HDF5 identity, B-basis conversion, SI convention and momentum-flux
sign, outward-normal orientation, independent result recomputation, interface
and support ownership, adversarial authority tests, and the distinction between
central pair cancellation and physical/regional closure.

The prerequisite receipt fixes were committed and pushed independently as
`5d87bbb` (process-hash recomputation) and `8ad464b` (sealed DESC module path and
canonical command binding).

## Remaining critical path

Add a typed conservative regional residual/Jacobian owner and independently
validated interface jump ledger, then connect that real multi-region solve to
the already prototyped engineering/control/fault and validation/UQ layers.
