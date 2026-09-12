# Current-candidate weak-volume execution report

Date: 2026-09-12. Development baseline: `793109c`.

The new implementation executes static ideal-MHD constitutive weak-volume
integrals, nonconstant strong force moments and a sampled-state analytic
Jacobian from the same candidate's real DESC field/basis artifacts. Complete
weak residual, body source, exterior boundary, global conservation and
actual multi-region coupled solve remain unexecuted. The result is deferred.

## Completed local verification

Command:

```powershell
julia --project=. --startup-file=no test/runtime_v4_candidate_coupled_physics_kernel_tests.jl
```

Final result: **26/26 passed, process exit 0**. The tests use explicitly
test-only states and check hand-calculable pressure/magnetic stress,
nonconstant tests, pressure Jacobian, NFP tensor/vector rotation, scalar
volume invariance and all sampled-state finite-difference columns. A first
small-step FD check exposed cancellation near zero rotated components; the
final implementation uses a stress-scaled centered step appropriate to the
exact quadratic constitutive polynomial. These software tests do not count
as physical-stage execution.

The new module starts no DESC process. Its real execution below consumes the
single integration runner's already produced provider artifacts.

The reusable real test entry is
`test_candidate_coupled_physics(owner, upstream, regional_execution, result)`;
including its file does not run providers.

## Actual same-candidate measurements and integration acceptance

The single integration run at
`runs/candidate_chain_20260912_integrated` has completed its upstream chain
with `CHAIN_UPSTREAM_EXIT_CODE=0`. The real physics TSV and its typed semantic
snapshot `physics.json` have been written and were independently read for this
report. The same-process real physics checks have now passed **15/15** and
emitted `CANDIDATE_COUPLED_PHYSICS_FOCUSED_EXIT_CODE=0`. The whole-device
bookkeeping assessment has emitted `CHAIN_WHOLE_DEVICE_ASSESSMENT_EXIT_CODE=0`
and produced `result.md`/`result.json`. The complete same-candidate integration
checks have passed **108/108**. The final operating-system process exit is
**0**, independently recorded in
`runs/candidate_chain_20260912/integrated.exit`; the run's `runner.exit` and
`execution_manifest.json` also record **0**. The substage markers are not
separate operating-system process exits. This accepts the recorded software
execution and replay boundaries, not physical-device feasibility.

The core regression has exited 0. This report does not attest to spine or
package regression acceptance; their definitive outcomes belong in the main
integration report. Complete weak residual, external source, boundary,
global conservation and actual multi-region coupled solve remain unexecuted
regardless of the software test outcomes.

- Candidate hash:
  `0619e5bbd0537caad9bec630db6667b2e37c1346fb24ce86e4f10db39af16f10`.
- Context hash:
  `88464c462e6009e930efef24ea1a1a20f16d8a3a449d0a9853c940f325a7afd5`.
- Declared diagnostic reference length: `5.5 m`; NFP: `5`.
- Measured sampled-constitutive Jacobian FD maximum scaled error:
  `2.7106651733016967e-9`, below the declared `1e-6` diagnostic tolerance.

| Diagnostic region | Integral of local force magnitude (N) | Volume (m³) | Peak sampled force density (N/m³) |
|---|---:|---:|---:|
| `rho_inner` | 499803.561246086 | 9.837212398549502 | 128198.82402881836 |
| `rho_outer` | 720499.9226808641 | 7.66872519715973 | 312311.72217592015 |

The constant-test reconstructed regional net forces are near floating-point
zero despite these large local force-magnitude integrals. This reflects
periodic/symmetry cancellation and is not evidence of equilibrium or
numerical convergence. The nonconstant x-test force moment, for example, is
`-1244.1807286201883 N` in the inner region and `18266.89339769665 N` in the
outer region. Complete weak residuals cannot be inferred from these moments
or from the constitutive weak-volume terms because the required source and
boundary terms were not executed.

The typed snapshot confirms real fields consumed, weak volume, nonconstant
strong moments, sample constitutive Jacobian, and periodic-model
reconstruction executed. It separately confirms external source, boundary,
complete weak residual, full-state Jacobian, global conservation, actual
coupled solve, full-torus direct sampling and physical validation remain
unexecuted. The physical result remains `deferred` with zero evidence credit.

The regions themselves are current-candidate-bound downstream diagnostic
declarations from `examples/runtime_v4_desc_rho_partition_trace.jl`, not
region/law declarations extracted from the current G2 operator AST. Binding
their hashes to the candidate preserves provenance; it does not establish
Genome ownership of a complete multi-region problem. The generated root
recovery queue now explicitly retains
`candidate_owned_region_partition_and_interface_laws`, including the missing
ownership and exact-cover obligation.

The generated `result.md` was reviewed against the physics snapshot. Its
physics stage remains `deferred`; source, boundary, complete weak residual,
full-state Jacobian, global conservation and actual coupled solve remain in
the unexecuted column. It also separates a completed whole-device bookkeeping
assessment from unexecuted integrated whole-device physics. The numerical
stage's `fail` records the observed `0.1188426977380375` relative spread of
three force-magnitude integration implementations; it does not classify the
complete PDE or a physical device. The reported net-force spread upper value
`2.2783650404334673e-8 N` is only an observed formulation envelope and does not
override the large `1.2203034839269503e6 N` integrated local force magnitude.

## New result boundaries

- Real upstream fields are consumed only after candidate/context/Genome/
  graph/partition/support/request/result/receipt and point checks.
- One-period Cartesian fields and positions are explicitly rotated into each
  field period before test evaluation. This is declared periodic-model
  reconstruction, not full-torus direct provider sampling.
- Force-magnitude integrals and peak sampled force norms retain non-closure
  even when symmetry makes the net Cartesian force approximately zero.
- The Jacobian differentiates the constitutive weak-volume term with respect
  to sampled p/B only; all-state residual and solve capabilities remain gaps.

See the exact legacy extract/wrap/test-only/reject decisions and blocked
producers in `docs/implementation/candidate_coupled_physics_weak_volume_v1.md`.
