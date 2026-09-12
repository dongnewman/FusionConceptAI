# Runtime V4 spatial coupled execution — 2026-09-13

## Scope and disposition

This milestone promotes the existing staged implementation, executes a fresh
same-identity upstream and the four declared spatial cases, propagates their
actual currents into pickup engineering, executes independent numerical checks,
and runs the whole-device assessment. It reaches the requested minimum of a real
spatial solve attempt and real engineering execution. It does **not** complete a
scientifically converged or physically validated chain.

The run started from source commit `c2352f2943a9c4477144d8b5c9e79a00c371b6a8`.
The runtime recovery/audit fix is pushed as
`91dc908dbcbcf7761a8984cbba2b68d4435805a6`. The sealed parent/spatial/context
identities are respectively `7b44ba5…`, `3de9cf4…`, and `0f7521a…`.

## Stage ledger

| Stage | Declaration / implementation | Actually executed | Scientific status | Exit | Upstream validity / boundary |
| --- | --- | --- | --- | ---: | --- |
| Candidate and G1/G2/G3 identity | complete / yes | yes | observed | 0 | new child identity; no old receipts attached |
| Fresh DESC request/provider/HDF5 | complete / yes | yes | observed, screen-only | 0 | provider execution is not equilibrium validation |
| Spatial multi-region | complete / yes | four cases | fail | 4 | all iteration-limit stops |
| Pickup engineering/control/fault | complete / yes | four failed states | fail | 0 | calculation valid for bound inputs; physical upstream invalid |
| Numerical formulation/Jacobian/MMS/circuit | complete / yes | yes | numerical pass; aggregate verification fail | 0 | aggregate inherits invalid physical upstream; zero physical-validation credit |
| Flux ±5% deterministic propagation | complete / yes | both endpoint solves and engineering | fail | 0 | conditional failed-state range only |
| Physical validation | incomplete / no | no | unsupported | n/a | missing experiments/independent physical model/discrepancy basis |
| Whole assessment | complete / yes | yes after checkpoint recovery | deferred | 0 | P5 false; credible device count 0 |

The first whole-stage call hit a Julia world-age `MethodError` after all upstream,
physics, engineering and verification checkpoints were written. The ledger marks
that event `program_exception`; the outer process exited 1. A one-line
`Base.invokelatest` repair was applied, the same run directory was resumed, and
the four expensive checkpoints were reused. Integration then passed 43/43 and
the runner exited 0. The ledger contains one program exception and zero human
interruptions. The earlier interrupted preflight remains a separate historical
unexecuted event and is not relabeled as scientific failure.

## Main numerical results

All four spatial cases assembled complete 360/2640-unknown and 2881/21761-row
systems and formed full sparse Jacobians. The final scaled residual norms are
0.1614574 (nominal coarse), 0.1379660 (nominal fine), 0.1563471 (flux low), and
0.1653056 (flux high). They accepted 12, 4, 12, and 12 updates, respectively,
but all stopped at their iteration budgets with exit 4. Rank estimates are
360/360 and 2640/2640; continuum uniqueness is still unsupported.

Actual static pickup linkages are -1.37600894e-5, -1.87299636e-5,
-1.29970922e-5, and -1.37598689e-5 Wb. Static EMF is zero. Under the conditional
prescribed ramp, nominal current peaks range from 0.0638866 to 0.0920663 mA and
short-circuit peaks from 0.647402 to 0.932964 mA; no trip occurs. Independent
reciprocity relative differences are 4.23e-14 to 5.98e-14.

Every actual Jacobian column and residual block was independently checked. Both
nonzero-source MMS levels ran, and all independent circuit energy/emf checks
passed. These are software/numerical checks only. Failed coarse/fine states do
not establish a physical convergence order, and the deterministic flux endpoints
do not create statistics.

## Reproduction and evidence

Fresh execution:

```powershell
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl runs/spatial_chain_20260912_r1
```

Recorded recovery:

```powershell
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl runs/spatial_chain_20260912_r1 --resume
```

Independent byte/stage audit:

```powershell
& 'D:\Users\Newman\anaconda3\python.exe' scripts/verify_v4_spatial_manifest.py runs/spatial_chain_20260912_r1 runs/spatial_chain_20260912_acceptance/manifest_audit_r2.json
```

The audit passes 549 records / 548 unique paths with zero mismatches. The full
143-file, 120314228-byte run stays under
`runs/spatial_chain_20260912_r1/`; `execution_manifest.json` binds source,
Project/Manifest, executable, environment, ledger and output bytes. A compact
committed evidence record is
`docs/reports/spatial_coupled_execution_v4_20260913_evidence.json`. Package-wide
regression passed 2631/2631 assertions in 105 groups, process exit 0.

## Remaining recovery edges

- **Missing model:** pressure/current-topology closure; external coils, outer K
  and return path; self-consistent transient plasma/circuit coupling; broader
  device/component/thermal/environment physics.
- **Missing declaration:** complete hardware envelope and applicable component
  declarations beyond the frozen ideal pickup aperture.
- **Missing data/evidence:** experiments, independent physical solver, held-out
  validation, model discrepancy and probability distributions.
- **Implementation error:** the world-age failure was fixed and replay-tested;
  the first manifest-audit script assumption also failed once and was corrected.
  Both failures remain in acceptance logs instead of being erased.
- **Computational/scientific failure:** all four nonlinear spatial attempts hit
  iteration limits; their downstream diagnostics are not qualified designs.
- **Unexecuted:** physical validation and the absent model/data-dependent device
  calculations. No four-scenario numerical/engineering/verification item remains
  unexecuted within the declared implementation.

Whole status is `deferred`, `p5_ready=false`, physical validation is
`unsupported`, and credible device count is 0.
