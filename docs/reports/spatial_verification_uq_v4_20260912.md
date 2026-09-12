# Spatial verification and deterministic propagation record — 2026-09-13

Verification executed on the actual four spatial states and their actual
engineering outputs. Numerical/formulation checks pass with exit 0; this grants
zero physical-validation credit and does not repair upstream nonconvergence.
Consequently the aggregate verification status is `fail` even though its
numerical substage is `pass` and its process/solver exit is 0.

## Executed checks

- Independent same-geometry/same-quadrature residual formulations pass every
  momentum, divB, traction, normal-B and total-flux block for all four cases.
- Every structural Jacobian column was checked: 360 coarse columns, 2640 fine
  columns, then 360 at each flux endpoint. All cases used 32 colors and 65
  residual evaluations; maximum relative column differences were
  `2.74e-7`, `3.87e-7`, `2.65e-7`, and `2.67e-7`, within their declared gates.
  No structural column was empty.
- Two nonzero-source curved MMS levels executed. The independently evaluated
  source norms are `33462.1132` and `33465.0286 N m^-3 sqrt(m^3)`; all four
  residual columns are complete and finite. MMS solution solves were not
  requested, so no solution convergence order is claimed.
- The independent 256-bit analytic circuit oracle checked induced-EMF peak,
  total energy identity and maximum segment energy identity for all four actual
  engineering cases; all passed with exit 0.
- Focused Julia verification passes 57/57, the independent Python oracle passes
  3/3, and graph/binding checks pass 15/15, all with process exit 0.

Strong/weak identity differences are integration/geometry diagnostics, not a
certified isolated quadrature error. Nominal coarse/fine momentum scaled identity
differences are `1.56852e-4` and `8.67903e-6`; divB values are `3.06582e-4`
and `2.47578e-5`. Failed nonlinear states cannot establish physical
discretization error or a convergence order.

## Actual parameter propagation

The declared toroidal-flux endpoints 0.95 and 1.05 Wb were each spatially solved
and propagated through actual J/K artifacts, finite-aperture transfer and circuit
execution. The failed-state conditional nominal current range is
`6.3886611e-5` to `6.7637089e-5 A`; static linkage at the low/high endpoint cases
is `-1.2997092e-5` / `-1.3759869e-5 Wb`. This is a deterministic sampled interval
with a secant, not a distribution, confidence interval, certified global bound
or robustness claim.

## Unsupported evidence

No experiment, independent physical solver, model-discrepancy basis or applicable
held-out validation data exists. Physical validation is `unsupported`, not
failed and not executed. The numerical stage is implemented/executed/pass with
exit 0; whole-device authority remains deferred because its physical inputs fail
or are missing.

Detailed independent residual tables, per-column records, MMS rows and circuit
oracle outputs are under `runs/spatial_chain_20260912_r1/verification/` and bound
by `execution_manifest.json`.
