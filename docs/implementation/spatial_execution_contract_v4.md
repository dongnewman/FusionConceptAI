# Spatial execution contract v1 — original goal remains active

Frozen by the integrating agent on 2026-09-12 before this parallel implementation.
The previous four-amplitude milestone is actual reduced-model execution, not
completion of the user's spatial multiregion goal. Do not broaden its claims.

## Isolation and ownership

While the r3 reduced runner is sealing its source, implement new files under
`runs/spatial_chain_20260912_staging/`, preserving the eventual `src/RuntimeV4`,
`scripts`, `test`, `docs/implementation` and `docs/reports` layout. Main promotes
reviewed files only after the earlier execution is sealed and delivered.
No branch launches Julia/DESC, stages Git files, or changes existing source.

- Main: this contract; `SpatialExecutionTypesV4.jl`, `SpatialCandidateV4.jl`,
  `SpatialWholeDeviceV4.jl`, candidate example, unified runner/integration tests,
  report/index, execution queue and final Git acceptance.
- Physics: `SpatialMultiRegionV4.jl`, `spatial_multiregion_desc_sample.py`,
  `runtime_v4_spatial_multiregion_tests.jl`, own implementation/report.
- Engineering: `SpatialPickupEngineeringV4.jl`,
  `runtime_v4_spatial_pickup_engineering_tests.jl`, own implementation/report.
- Verification: `SpatialVerificationUQV4.jl`, optional independent
  `spatial_verification_oracle_v4.py`, focused tests, own implementation/report.

Each branch records extract/wrap/test-only/reject decisions from legacy code.
No old authority, model-family routing or manufactured acceptance inputs.

## Candidate and spatial equations

Create a new candidate revision, record its actual parent and semantic changes,
rebuild hashes/typed graphs and execute the required new upstream. DESC geometry
and p/iota fields serve explicitly as geometry/initialization data. Spatial
derivatives and currents must come from the current field state, not DESC's J.
The toroidal flux target has a declared Wb design interval [0.95,1.05] times the
inherited nominal flux, not a probability distribution. No hidden anchoring to
the initial pressure or current topology supplies missing physical closure.

Use full-torus periodic local Q1 states (B_R,B_phi,B_Z,p), with independent
unknowns in different field periods. Coarse: rho=(0,.5,1), theta=4, zeta=2*NFP.
Fine: rho=(0,.25,.5,.75,1), theta=8, zeta=4*NFP. For NFP=5 this is 360/2640
unknowns and 80/640 cells. Axis trial nodes AND test hats are merged; axis cells
have 6 local bases, other cells 8. Each local basis contributes three momentum
and one divB equation. Expected total rows, including exterior trace and flux:
2881 coarse and 21761 fine. Counts are checked against generated ownership.

Both regions describe continuous same-material static plasma, with a shared
interface trace and no prescribed internal sheet current. This is not a general
heterogeneous interface solver. Explicit zero body source, all local faces,
exact rho=.5/1 traces, periodic pairing, exterior reference traction and Bn=0
face moments, and a toroidal flux cut enter the residual. Record nonuniqueness
or missing pressure/current-topology closure; no artificial regularization or
locking most fields to the initializer can hide it.

Fresh sampling supplies actual nodes, cell/unique-face quadrature, R/lab-phi,
covariant E, inverse E, signed determinant and SI measures. Negative detE is
allowed; dV uses abs(detE). Do not invert the singular axis metric. In cylindrical
components H[:,a]=partial_a(B)+(E[2,a]/R)*(-B_phi,B_R,0), G=H*inverse(E),
divB=tr(G), curlB=(G32-G23,G13-G31,G21-G12), J=curlB/mu0. gradp comes from the
current pressure field. Distinguish div(T) from J cross B-gradp by B*divB/mu0.

Momentum/traction rows retain N; div/normal-flux/total-flux rows retain Wb.
Only declared scales may combine them into a dimensionless objective. Report
each raw block, all field states, constraints, accepted updates, stopping reason,
linear residual, Jacobian sparsity/rank/nullspace diagnostics and exact exit code.
Use the full sparse Jacobian; fine must not densify a 21761x2640 matrix every
step. Actual coarse solve and bounded fine attempt are mandatory. All failures
remain real failures, including budget stops and nonidentifiability.

## Shared execution API

All modules load into the same new runner namespace. Main supplies
`validate_spatial_candidate_v4(context)` and
`spatial_candidate_geometry_bound_v4(context)` (analytic R_upper_m and bound
provenance from the candidate geometry, not the largest sampled radius).
The upstream NamedTuple retains bridge/geometry/proof/request/result/probe.

- `spatial_multiregion_declaration_v4(; flux_Wb)` creates the complete immutable
  G2 declaration, including both spaces, nominal and endpoint cases, tolerances
  and computational budgets. flux_Wb is supplied from the parent declaration.
- `execute_spatial_multiregion_v4(context,upstream,run_dir)` executes the four
  declared cases sequentially: nominal_coarse, nominal_fine, flux_low_coarse,
  flux_high_coarse. `validate_spatial_result_v4(context,result)` replays actual
  state-to-residual/current and source/artifact bindings.
- Physics result exposes candidate_hash, context_hash, declaration, cases,
  executed, status, solver_exit_code, result_hash. Each case exposes case_id,
  level, flux_Wb, state hash, executed/status/solver_exit_code,
  `engineering_input::SpatialCurrentInputV4`, artifacts and actual diagnostics.
  The named primary case is always nominal_coarse; do not select a favorable case.
- `spatial_engineering_declaration_v4()` declares an external circular pickup:
  center at (analytic R_upper+0.05 m,0,0), normal z, radius 0.005 m, 10 turns.
  These are explicit exploratory design inputs; include SI values/ranges/source.
- `execute_spatial_engineering_v4(context,physics,run_dir)` consumes every case's
  actual current artifacts and returns same-identity result/case records.
- `spatial_verification_declaration_v4()` freezes verification tolerances and
  independent methods. `execute_spatial_verification_v4(context,upstream,
  physics,engineering,run_dir)` consumes executed cases; it does not start DESC.

## Real engineering inputs and computations

`SpatialExecutionTypesV4.jl` defines content-bound artifacts and
`SpatialCurrentInputV4`. Physics writes its exact current state into the frozen
CSV schemas there. Volume data contains J=current curl(B), B, pressure/gradient,
divB, SI position and dV. Interface data contains both B traces, derived K,
normal current traces and dA. Exterior data contains B/J/p, n and dA. Record
external Bout/Kouter as unknown rather than inventing closure. Physics validator
must reproduce these files from the state and geometry before engineering use.

Execute Biot-Savart of the actual volume/sheet current to the declared exterior
finite disk, then N*integral(B.n dA). This is the plasma-current contribution,
not the total external field: missing external coils/boundary/current closure
remain explicit. Check clearance against the analytic geometry bound. An
independent unit-test-current reciprocity integral can verify the flux transfer;
the normalization is mathematical, not a manufactured actual excitation.

Static real upstream yields static flux and zero induced emf for a stationary
ideal coil. Keep the old ramp as a separately identified conditional design
scenario, never as solved plasma dynamics. For that conditional circuit,
implement exact piecewise-exponential RL propagation and analytic i/i² integrals,
retaining the 10 us detection cadence and switch event left/right limits. This
removes BE integration dissipation without disguising a changed controller.

## Verification and acceptance

Independent strong/weak comparison must include B*divB/mu0 and all faces/source
terms. Curved-domain MMS uses independently specified B=(B0+alpha*y,
B1+beta*z,B2+gamma*x), p=p0+k.x and analytic source, not the production residual
as its own source generator. Execute both spaces and distinguish residual
consistency/discrete difference from an established convergence order.

All spatial Jacobian columns need derivative verification with per-column or
per-block gates; an aggregate norm cannot hide pressure blocks. Execute actual
flux endpoint spatial solves and their actual engineering propagation. Failed
endpoints yield conditional failed-state ranges, not physical robustness.
Use source-bound independent formulas and preserve explicit exits. Missing
experimental/independent physical validation and model discrepancy remain
unsupported; software checks grant no such credit. Main audits these original
requirements before deciding goal completion and commits/pushes only reviewed
executed milestones.
