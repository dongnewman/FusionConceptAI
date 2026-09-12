# Spatial multi-region execution record — 2026-09-13

The staged spatial implementation was promoted and executed on the revised
candidate. This record supersedes the earlier execution-pending handoff; it
does not turn a failed nonlinear solve into an equilibrium result.

## Bound execution

- Parent candidate: `7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548`.
- Spatial candidate: `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`.
- Context: `0f7521a157ca710b195f82757a8d204058d99231b12346f9c8f37d9be526b10d`.
- Fresh same-revision DESC provider process: exit 0; geometry sampler: exit 0.
  DESC 0.17.3/Python 3.13.5 produced the HDF5 and coarse/fine volume and face
  tables. The HDF5 SHA-256 is
  `ed68641512138db071e465567140e83a78821fad88544a500d6446a8e0ceaeb4`.
- Coarse/fine spaces contain 360/2640 state unknowns and 2881/21761 residual
  rows. All body/source/local-face/periodic/interface/exterior/flux terms were
  assembled. The full sparse analytic Jacobian was formed for every case.

## Actual coupled attempts

| Case | DOF / rows | Attempts / accepted | Initial → final scaled norm | Final scaled max | Stop / exit |
| --- | ---: | ---: | ---: | ---: | --- |
| nominal_coarse | 360 / 2881 | 12 / 12 | 0.1687785 → 0.1614574 | 0.0129390 | iteration_limit / 4 |
| nominal_fine | 2640 / 21761 | 4 / 4 | 0.1796848 → 0.1379660 | 0.00626347 | iteration_limit / 4 |
| flux_low_coarse | 360 / 2881 | 12 / 12 | 0.1759700 → 0.1563471 | 0.0104157 | iteration_limit / 4 |
| flux_high_coarse | 360 / 2881 | 12 / 12 | 0.1760879 → 0.1653056 | 0.0112583 | iteration_limit / 4 |

The primary nominal-coarse final raw block norms are momentum
`649750.058 N`, divB `0.287018 Wb`, traction `776638.764 N`, normal-B
`0.407633 Wb`, and total-flux `0.0129390 Wb`. These quantities are not mixed
before the declared scaling. The `B divB / mu0` momentum contribution is kept;
its independent nominal-coarse norm is `378576.099 N`.

Sparse QR reported numerical column ranks 360/360 and 2640/2640 at the declared
relative threshold, but continuum uniqueness remains unsupported because
pressure/current-topology closure is not fixed. A full column-rank estimate is
not a physical uniqueness proof. The persisted attempts, accepted-update counts,
iteration histories, raw/scaled blocks, rank diagnostics, states, currents,
resources and exit codes replay from `physics.json`, `physics.jls`, and each
case directory.

## Failure-ledger acceptance

Focused tests now pass 67/67 with process exit 0. They include deterministic
test-only sparse-QR and feasible-line-search failures and verify attempts,
accepted-update counts, status histories, stopping reasons and replay. Production
defaults remain the real SuiteSparse QR and Armijo search; no injected failure
path is used by the actual run.

The physics process completed normally and the aggregate physics solver exit is
4. This is a scientific/computational nonconvergence, not a program exception,
human interruption or unexecuted stage. The later whole-stage world-age exception
occurred after physics was checkpointed and did not change or rerun these states.

## Remaining model limits

Missing pressure/current-topology closure, external electromagnetic/current-return
closure, transport/time-dependent plasma equations, heterogeneous material
interfaces and physical validation prevent equilibrium or device claims. The
reported coarse/fine differences and MMS diagnostics do not establish a solved
mesh-convergence order because neither physical state converged.

Reproduce the full fresh run from the repository root:

```powershell
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl runs/spatial_chain_20260912_r1
```

After the recorded whole-stage program exception, the exact recovery command was:

```powershell
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl runs/spatial_chain_20260912_r1 --resume
```
